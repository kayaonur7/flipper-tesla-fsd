# entry Akışı — Uçtan Uca Runbook

`hmnfe_acq_merchant` reposundaki üye işyeri başvuru (entry) akışının uçtan uca
analizi ve iyileştirme planı. Tek geçişte bitirmek için tasarlandı.

- `[PS]` adımları → PowerShell'e yapıştır (repo kökü: `D:\Repo\hmnfe_acq_merchant`)
- `[CP]` adımları → Copilot **agent mode + Opus**, her adım **yeni chat**

Toplam: 7 PowerShell bloğu + 13-16 Copilot turu.

---

## Doğrulanmış yapı

Bu runbook aşağıdaki gerçek yapıya göre yazıldı — tahmin yok, hepsi repoda
doğrulandı.

### Bir ekranın ayak izi (örnek: `PG_ApplicationAccount`)

```
src\main\java\com\ykb\hmn\acq\application\entry\controllers\
    PG_ApplicationAccount.java           ← geliştirici kodu
    PG_ApplicationAccountSuper.java      ← ÜRETİLMİŞ taban sınıf
    Con_acqapplicationaccount.java       ← conversation controller (dev)
    Con_acqapplicationaccountSuper.java  ← ÜRETİLMİŞ
src\main\webapp\cct\
    con_acqapplicationaccount.cct        ← AKIŞ TANIMI (XML)
src\main\webapp\page\acq\application\entry\PG_ApplicationAccount\
    PG_ApplicationAccount.html
    PG_ApplicationAccount.js
    PG_ApplicationAccount.properties
    PG_ApplicationAccount_auth.properties    ← rolü DOĞRULANMADI, aşağıya bak
    PG_ApplicationAccount_lang_en.json
    PG_ApplicationAccount_lang_tr.json
```

### Kökler

| Değişken | Yol | İçerik |
|---|---|---|
| `$W` | `src\main\webapp\page\acq\application\entry` | 14 ekran klasörü, html/js/properties/lang |
| `$J` | `src\main\java\com\ykb\hmn\acq\application\entry\controllers` | 50 java — PG_ ve Con_ sınıfları |
| `$JD` | `src\main\java\com\ykb\acq\application\entry` | 6 java — request / response / util DTO'ları |
| `$CCT` | `src\main\webapp\cct` | 79 `.cct` — akış tanımları |
| `$INC` | `src\main\webapp\page\acq\include` | paylaşılan include sayfaları |

### `.cct` formatı — akışın kaynağı

```xml
<CONVERSATION ApplicationID="app_acqadditionalinformation"
              ConvID="con_acqadditionalinformation"
              ConvController="...controllers.Con_acqadditionalinformation"
              DefaultTaskID="task_additionalinformation"
              FunctionalArea="acq/application/entry">
  <TASK PageName="PG_AdditionalInformation"
        PageController="...controllers.PG_AdditionalInformation"
        TaskID="task_additionalinformation"
        CancelButton="True" ConfirmButton="True" TabVisible="True">
    <ACTION Event="onBack">
      <TRANSITION InvocationMode="NORMAL" FlagEOC="True"
                  ControllerEvent="onBack" NextConvID="" NextTaskID=""/>
    </ACTION>
    <DECISION Event="onSecurityClick"> ...
```

Geçiş grafiği buradan çıkıyor — `startNewProcess` grep'lemeye gerek yok.

### Repoda doğrulanmış olgular

| Olgu | Sayı / detay |
|---|---|
| Ekran klasörü (`$W`) | 14, kökte dosya yok |
| webapp dosyası | 90 — her ekran 6'lı set + fazlalıklar |
| java (`$J`) | 50 — dev + üretilmiş `Super`, `PG_` + `Con_` |
| entry CCT'si | 9 dosya — 19 TASK, 71 TRANSITION |
| CCT'de TASK'ı olmayan ekran | 4: `PG_AccountWalletPopup`, `PG_AddNote`, `PG_LoyaltyProgramRatePopup`, `PG_TagOperation` — koddan açılan popup'lar |
| Birden çok conversation'da geçen TASK | `PG_MerchantSecurityCheck`, `PG_PricingTrioEdit` |
| `_auth.properties` | 15 dosyanın 14'ü **boş**. Dolu olan tek dosya (`PG_TerminalInfo`) **validasyon hata mesajları** içeriyor, yetki tanımı değil — dosyanın rolü doğrulanmadı |

### M2'nin doğruladığı bulgular

Mekanizasyon M2 bloğunun ürettiği, kapsam artefaktları elenmiş bulgu seti.
Hiç Copilot turu harcanmadan çıktı; Adım 16'da kanıtı hazır girdi olarak
kullanılacak, model bunları yeniden keşfetmeye çalışmamalı.

| # | Bulgu | Kanıt |
|---|---|---|
| 1 | `event236608` — CCT'de tanımlı, kodda üretilmiyor, handler'ı da yok | `PG_ApplicationAccount` TASK'ı |
| 2 | **7 adet `setControllerEvent` çağrısı yoruma alınmış.** En belirgini: ürün tipine göre yönlendirme — `merchantHasTrioProduct` → `GO_TO_PRICING`, `merchantHasNonVirtualPosProduct` → `GO_TO_TERMINAL`, aksi hâlde `GOTO_PRODUCTAUTH` dallanmasının tamamı yorum satırında — hem `onBackClicked` hem `onNextClicked` içinde | `PG_ApplicationPricing.java:1142-1149`, `:1156+`, `PG_ApplicationPricingTrio.java:576` |
| 3 | `con_point` / `task_merchantpoint` conversation'ının **çağıran tarafı bulunamadı**. Sınıf, CCT ve sayfa tanımı mevcut (`Con_point.java`, `con_acqpoint.cct`, `PG_MerchantPoint`), ancak repo genelinde hiçbir çağrı yok — muhtemelen başka bir modüldeki menü tanımından açılıyor | M5 bölüm C |
| 4 | Handler'ı olmayan 3 CCT olayı | `PG_MerchantUpdate`: `onTblProductsClicked`, `onTrioTableCellClicked`, `onBtnAddNewProduct` |

**Düzeltme:** 2 numaralı bulgu ilk taramada "kodun ürettiği ama hiçbir geçişin
beklemediği ölü sonuç" olarak kaydedilmişti. M5'in bağlam dökümü gösterdi ki
satırlar **yoruma alınmış**. Kullanıcının takıldığı bir hata değil, kasıtlı
devre dışı bırakılmış bir dallanma — ama neden kapatıldığı ve CCT'deki
karşılığının ne olduğu açık soru. M2 artık yorum satırlarını ayırıyor.

**Yorum filtresiyle doğrulanmış sayılar:**
- A — 32 token: 19 lokal, 12 dış paket, 1 **ULASILAMAZ**, 0 sadece-yorum
- B — 18 entry CCT, 0 dış CCT, **0 ölü sonuç**, **7 YORUMDA**, 3 değişken
- C — 25 PG, 0 CON, 16 dış paket, 4 **YOK**

Gerçek ölü sonuç yok; ilk taramadaki 3 kayıt yoruma alınmış koddan geliyordu.
Buna karşılık yoruma alınmış yönlendirme sayısı 7 — sanılandan fazla.

### Analizi bozabilecek dört tuzak

1. **`*Super.java` üretilmiş koddur** — ama boş değil. İş mantığı `Super`'siz
   sınıftadır; **yapısal sözleşme** (alan/widget tanımları, included page'ler)
   `Super`'dedir. İkisini karıştırma: Super'den iş kuralı çıkarma, ama
   included page ve alan sözleşmesini oradan oku.
2. **Include mekanizması gerçek ve iki yerde tanımlı:**
   - HTML: `<div data-type="IncludedPage" data-page-name="acq/include/account/PG_IncludeApplicationAccount">`
   - Super: `protected IIncludedPage<PG_IncludeApplicationAccount> getPageAccount()`
   Entry'de en az `PG_ApplicationAccount` ve `PG_AdditionalInformation` bunu
   kullanıyor. Include sayfaları `page\acq\include\...` altında, ayrı ağaçta.
3. **Conversation'lar akış sınırını aşıyor.** `con_acqmerchantupdate.cct`
   entry klasöründe olmayan ekranları (`PG_MerchantUpdate`,
   `PG_MerchantProductAuthorizationsDefinition`, `PG_NewPricingTrio`,
   `PG_MerchantPricingSponsor`) TASK olarak içeriyor. Akış grafiği entry
   klasörüyle sınırlı değil.
4. **İki ayrı java ağacı var.** Controller'lar `com.ykb.hmn.acq...`,
   DTO'lar `com.ykb.acq...` altında (`hmn` yok).

---

## İlerleme listesi

```
[ ] 0  [PS] Kökler ve kontrol
[ ] 1  [PS] CCT akış tanımları
[ ] 2  [PS] Envanterler (webapp + java + boyut)
[ ] 3  [PS] Konvansiyon hammaddesi
[ ] 4  [PS] Anahtar kelime, geçiş, state, include
[ ] 5  [PS] Yetki, lang, DTO, dışarıdan çağrılar, eşleme, include
[ ] 6  [PS] Özet
[ ] 7  [CP] Envanter + konvansiyon türetme   → 00a-envanter.md
[ ] 8  [CP] Akış grafiği (CCT tabanlı)       → 00b-akis.md
[ ] 9a [CP] Paylaşılan state sözlüğü        → 00c1-state.md
[ ] 9b [CP] Servis, DTO, auth, ikizler      → 00c2-servis-dto.md
[ ] 9c [CP] Grup planı + açık sorular       → 00c3-plan.md
[ ] 10 [CP] Doğrulama
[ ] 11 [--] Elle spot-check
[ ] 12 [CP] Ekran kartları — grup başına 1   → ekranlar/*.md
[ ] 13 [CP] Konsolidasyon                    → 90-konsolidasyon.md
[ ] 14 [CP] Doğrulama
[ ] 15 [--] Elle spot-check
[ ] 16 [CP] İyileştirme planı                → 99-iyilestirme.md
```

---

# BÖLÜM 1 — PowerShell

Blokları **olduğu gibi**, sırayla yapıştır. Terminal sekmesini değiştirme —
değişkenler kaybolur. Kaybolursa Adım 0'ı tekrar çalıştır.

## [PS] Adım 0 — Kökler ve kontrol

```powershell
$W   = "src\main\webapp\page\acq\application\entry"
$J   = "src\main\java\com\ykb\hmn\acq\application\entry\controllers"
$JD  = "src\main\java\com\ykb\acq\application\entry"
$CCT = "src\main\webapp\cct"
$INC = "src\main\webapp\page\acq\include"
$O   = "docs\entry-akis\_tarama"
New-Item -ItemType Directory -Force $O, "docs\entry-akis\ekranlar" | Out-Null

"W   : {0,-6} ekran klasoru : {1}" -f (Test-Path $W),   @(Get-ChildItem $W -Directory -ErrorAction SilentlyContinue).Count
"J   : {0,-6} java          : {1}" -f (Test-Path $J),   @(Get-ChildItem $J -File -Filter *.java -ErrorAction SilentlyContinue).Count
"JD  : {0,-6} java          : {1}" -f (Test-Path $JD),  @(Get-ChildItem $JD -Recurse -File -Filter *.java -ErrorAction SilentlyContinue).Count
"CCT : {0,-6} cct           : {1}" -f (Test-Path $CCT), @(Get-ChildItem $CCT -Recurse -File -Filter *.cct -ErrorAction SilentlyContinue).Count
"INC : {0,-6} klasor        : {1}" -f (Test-Path $INC), @(Get-ChildItem $INC -Directory -Recurse -ErrorAction SilentlyContinue).Count
```

**Beklenen:** W 14, J 50, JD 6, CCT 79. Sapma varsa devam etme.

## [PS] Adım 1 — CCT akış tanımları

Akış grafiğinin kaynağı. Önce entry'ye ait olanları süz, sonra hem tam içeriği
hem kompakt özeti yaz.

```powershell
$cctAll = Get-ChildItem $CCT -Recurse -File -Filter *.cct
$cctEntry = $cctAll | Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match 'acq/application/entry' }
"entry CCT sayisi : " + @($cctEntry).Count
$cctEntry | ForEach-Object { "  " + $_.Name }

# Tam icerik
$buf = New-Object System.Collections.ArrayList
foreach ($f in $cctEntry) {
    [void]$buf.Add("===== " + (Resolve-Path -Relative $f.FullName) + " =====")
    [void]$buf.Add((Get-Content -LiteralPath $f.FullName -Raw))
}
Set-Content "$O\01-cct-entry.txt" -Value (@($buf) -join "`r`n")

# Kompakt yapisal ozet
$sum = New-Object System.Collections.ArrayList
foreach ($f in $cctEntry) {
    [void]$sum.Add("### " + $f.Name)
    Get-Content -LiteralPath $f.FullName | Where-Object {
        $_ -match '<(/?)(CONVERSATION|TASK|ACTION|TRANSITION|DECISION|CONDITION)\b' -or
        $_ -match '(PageName|PageController|ConvController|ConvID|TaskID|NextConvID|NextTaskID|Event|ControllerEvent|ApplicationID|DefaultTaskID|InvocationMode|MasterConvID|FunctionalArea)\s*='
    } | ForEach-Object { [void]$sum.Add("  " + $_.Trim()) }
}
Set-Content "$O\02-cct-ozet.txt" -Value (@($sum) -join "`r`n")

"01-cct-entry : " + @($buf).Count + " satir"
"02-cct-ozet  : " + @($sum).Count + " satir"
```

**`entry CCT sayisi` 0 çıkarsa:** `FunctionalArea` değeri farklı yazılmış
olabilir. Şunu çalıştır ve gerçek değeri gör, sonra yukarıdaki `-match`
desenini düzeltip tekrarla:

```powershell
$cctAll | ForEach-Object { (Select-String -LiteralPath $_.FullName -Pattern 'FunctionalArea="([^"]*)"' | ForEach-Object { $_.Matches[0].Groups[1].Value }) } | Group-Object | Sort-Object Count -Descending | Select-Object -First 20 Count, Name
```

## [PS] Adım 2 — Envanterler

```powershell
# 03 - webapp dosya envanteri
$inv = Get-ChildItem $W -Recurse -File | ForEach-Object {
    "{0,7} {1}" -f (Get-Content -LiteralPath $_.FullName | Measure-Object -Line).Lines, (Resolve-Path -Relative $_.FullName)
} | Sort-Object
Set-Content "$O\03-webapp-dosyalar.txt" -Value (@($inv) -join "`r`n")

# 04 - java envanteri, URETILMIS/DEV ve PAGE/CONV ayrimiyla
$ji = Get-ChildItem $J -File -Filter *.java | ForEach-Object {
    $kind = if ($_.BaseName -match 'Super$') { 'URETILMIS' } else { 'DEV' }
    $type = if ($_.BaseName -match '^Con_') { 'CONV' } elseif ($_.BaseName -match '^PG_') { 'PAGE' } else { 'DIGER' }
    "{0,7} {1,-10} {2,-6} {3}" -f (Get-Content -LiteralPath $_.FullName | Measure-Object -Line).Lines, $kind, $type, $_.Name
} | Sort-Object { ($_ -split '\s+')[-1] }
Set-Content "$O\04-java-envanter.txt" -Value (@($ji) -join "`r`n")

# 05 - ekran boyutlari: webapp + eslesen java birlikte
$sz = Get-ChildItem $W -Directory | ForEach-Object {
    $n = $_.Name
    $wl = ((Get-ChildItem $_.FullName -Recurse -File | ForEach-Object { (Get-Content -LiteralPath $_.FullName | Measure-Object -Line).Lines }) | Measure-Object -Sum).Sum
    $jl = ((Get-ChildItem $J -File -Filter "$n*.java" -ErrorAction SilentlyContinue | ForEach-Object { (Get-Content -LiteralPath $_.FullName | Measure-Object -Line).Lines }) | Measure-Object -Sum).Sum
    [PSCustomObject]@{ T = [int]$wl + [int]$jl; W = [int]$wl; J = [int]$jl; N = $n }
} | Sort-Object T -Descending | ForEach-Object { "{0,7} (web {1,6} / java {2,6})  {3}" -f $_.T, $_.W, $_.J, $_.N }
Set-Content "$O\05-ekran-boyutlari.txt" -Value (@($sz) -join "`r`n")

"03-webapp-dosyalar : " + @($inv).Count
"04-java-envanter   : " + @($ji).Count
"05-ekran-boyutlari : " + @($sz).Count
```

## [PS] Adım 3 — Konvansiyon hammaddesi

Desen tahmin etmiyoruz; kodun kendi idiomlarını döküyoruz. **Sadece DEV
sınıfları** taranıyor — üretilmiş `Super` dosyaları istatistiği bozar.

```powershell
$devJava = Get-ChildItem $J -File -Filter *.java | Where-Object { $_.BaseName -notmatch 'Super$' }
$jsFiles = Get-ChildItem $W -Recurse -File -Filter *.js
$srcAll  = @($devJava) + @($jsFiles)

# 06 - en cok cagrilan nesneler (servis adlandirmasi buradan cikacak)
$rx = [regex]'([A-Za-z_][A-Za-z0-9_]*)\s*\.\s*[a-z][A-Za-z0-9_]*\s*\('
$h = New-Object System.Collections.ArrayList
foreach ($f in $srcAll) {
    $t = Get-Content -LiteralPath $f.FullName -Raw
    if ($t) { foreach ($m in $rx.Matches($t)) { [void]$h.Add($m.Groups[1].Value) } }
}
$o6 = $h | Group-Object | Sort-Object Count -Descending | ForEach-Object { "{0,6} {1}" -f $_.Count, $_.Name }
Set-Content "$O\06-cagri-hedefleri.txt" -Value (@($o6) -join "`r`n")

# 07 - import satirlari
$o7 = $devJava | Select-String '^\s*import\s' |
    ForEach-Object { $_.Line.Trim() -replace '^import\s+(static\s+)?','' -replace ';\s*$','' } |
    Group-Object | Sort-Object Count -Descending | ForEach-Object { "{0,6} {1}" -f $_.Count, $_.Name }
Set-Content "$O\07-importlar.txt" -Value (@($o7) -join "`r`n")

# 08 - erisimci metotlar (state tasima buradan cikacak)
$rx = [regex]'\b(?:get|set|put|add|read|write|load|save|fetch|clear)[A-Z][A-Za-z0-9_]*(?=\s*\()'
$h = New-Object System.Collections.ArrayList
foreach ($f in $srcAll) {
    $t = Get-Content -LiteralPath $f.FullName -Raw
    if ($t) { foreach ($m in $rx.Matches($t)) { [void]$h.Add($m.Value) } }
}
$o8 = $h | Group-Object | Sort-Object Count -Descending | ForEach-Object { "{0,6} {1}" -f $_.Count, $_.Name }
Set-Content "$O\08-erisimciler.txt" -Value (@($o8) -join "`r`n")

# 09 - DEV siniflarindaki metot imzalari (yasam dongusu buradan cikacak)
$o9 = $devJava | Select-String -Pattern '^\s*(public|protected|private)\s+[\w<>\[\],\s]+\s+\w+\s*\(' |
    ForEach-Object { "{0}:{1}:{2}" -f $_.Filename, $_.LineNumber, $_.Line.Trim() }
Set-Content "$O\09-metot-imzalari.txt" -Value (@($o9) -join "`r`n")

"06-cagri-hedefleri : " + @($o6).Count + " farkli hedef"
"07-importlar       : " + @($o7).Count + " farkli import"
"08-erisimciler     : " + @($o8).Count + " farkli metot"
"09-metot-imzalari  : " + @($o9).Count + " imza"
```

## [PS] Adım 4 — Anahtar kelime, geçiş, state, include

Önce sayım, sonra **yalnızca gerçekten geçen** kelimelerin satırları.

```powershell
$scan = @($devJava) + @($jsFiles) + @(Get-ChildItem $W -Recurse -File -Filter *.html)

$navKw   = 'startNewProcess','showCustomMessageBox','fireEvent','openDialog','closeDialog','showDialog','showPopup','openPopup','navigate','goPage','openPage','callPage','redirect','forward','closePage','onBack','onConfirm','onCancel','startConversation','callConversation'
$stateKw = 'setPageData','getPageData','getProcessData','setProcessData','processContext','getConvData','setConvData','session','getAttribute','setAttribute','globalMap','sharedModel','getContext','putValue','getValue','getModel','setModel','getRequest','getResponse'

$cnt = foreach ($k in ($navKw + $stateKw)) {
    [PSCustomObject]@{ K = $k; N = @($scan | Select-String -SimpleMatch $k).Count }
}
Set-Content "$O\10-anahtar-kelimeler.txt" -Value ((@($cnt | Sort-Object N -Descending | ForEach-Object { "{0,6} {1}" -f $_.N, $_.K })) -join "`r`n")

$liveNav = @($cnt | Where-Object { $_.K -in $navKw -and $_.N -gt 0 }).K
if ($liveNav) {
    $o11 = $scan | Select-String -Pattern (($liveNav | ForEach-Object { [regex]::Escape($_) }) -join '|') |
        ForEach-Object { "{0}:{1}:{2}" -f (Resolve-Path -Relative $_.Path), $_.LineNumber, $_.Line.Trim() }
} else { $o11 = @() }
Set-Content "$O\11-gecisler.txt" -Value (@($o11) -join "`r`n")

$liveState = @($cnt | Where-Object { $_.K -in $stateKw -and $_.N -gt 0 }).K
if ($liveState) {
    $o12 = $scan | Select-String -Pattern (($liveState | ForEach-Object { [regex]::Escape($_) }) -join '|') |
        ForEach-Object { "{0}:{1}:{2}" -f (Resolve-Path -Relative $_.Path), $_.LineNumber, $_.Line.Trim() }
} else { $o12 = @() }
Set-Content "$O\12-state.txt" -Value (@($o12) -join "`r`n")

# 13 - include kullanimi: akisa disaridan dahil edilen sayfalar
$o13 = $scan | Select-String -Pattern 'PG_Include[A-Za-z0-9_]*|[Ii]nclude\s*\(|includePage|IncludeArea' |
    ForEach-Object { "{0}:{1}:{2}" -f (Resolve-Path -Relative $_.Path), $_.LineNumber, $_.Line.Trim() }
Set-Content "$O\13-include.txt" -Value (@($o13) -join "`r`n")

"Gecen nav   : " + ($liveNav -join ', ')
"Gecen state : " + ($liveState -join ', ')
"11-gecisler : " + @($o11).Count
"12-state    : " + @($o12).Count
"13-include  : " + @($o13).Count
```

## [PS] Adım 5 — Yetki, lang, DTO, dışarıdan çağrılar

```powershell
# 14 - yetki tanimlari (_auth.properties)
$buf = New-Object System.Collections.ArrayList
Get-ChildItem $W -Recurse -File -Filter *_auth.properties | ForEach-Object {
    [void]$buf.Add("===== " + (Resolve-Path -Relative $_.FullName) + " =====")
    Get-Content -LiteralPath $_.FullName | ForEach-Object { [void]$buf.Add($_) }
}
Set-Content "$O\14-yetki.txt" -Value (@($buf) -join "`r`n")

# 15 - sayfa properties (auth disindakiler)
$buf2 = New-Object System.Collections.ArrayList
Get-ChildItem $W -Recurse -File -Filter *.properties | Where-Object { $_.Name -notmatch '_auth\.properties$' } | ForEach-Object {
    [void]$buf2.Add("===== " + (Resolve-Path -Relative $_.FullName) + " =====")
    Get-Content -LiteralPath $_.FullName | ForEach-Object { [void]$buf2.Add($_) }
}
Set-Content "$O\15-properties.txt" -Value (@($buf2) -join "`r`n")

# 16 - lang key'leri
$rxL = [regex]'"([^"]+)"\s*:'
$rows = New-Object System.Collections.ArrayList
Get-ChildItem $W -Recurse -File -Filter *_lang_*.json | ForEach-Object {
    $p = (Resolve-Path -Relative $_.FullName)
    $t = Get-Content -LiteralPath $_.FullName -Raw
    if ($t) { foreach ($m in $rxL.Matches($t)) { [void]$rows.Add("$p`t$($m.Groups[1].Value)") } }
}
Set-Content "$O\16-lang-keyleri.txt" -Value (@($rows) -join "`r`n")

# 17 - DTO'lar (request / response / util) - alan ve metot satirlari
$buf3 = New-Object System.Collections.ArrayList
Get-ChildItem $JD -Recurse -File -Filter *.java | ForEach-Object {
    [void]$buf3.Add("===== " + (Resolve-Path -Relative $_.FullName) + " =====")
    Get-Content -LiteralPath $_.FullName | Where-Object { $_ -match '^\s*(public|private|protected|@)' } | ForEach-Object { [void]$buf3.Add("  " + $_.Trim()) }
}
Set-Content "$O\17-dto.txt" -Value (@($buf3) -join "`r`n")

# 18 - akisa DISARIDAN yapilan cagrilar
$names = @(Get-ChildItem $W -Directory).Name + @(Get-ChildItem $J -File -Filter Con_*.java | ForEach-Object { $_.BaseName -replace 'Super$','' })
$rxN = (($names | Sort-Object -Unique) | ForEach-Object { [regex]::Escape($_) }) -join '|'
$o18 = Get-ChildItem . -Recurse -File -Include *.java,*.js,*.cct |
    Where-Object { $_.FullName -notmatch 'application[\\/]entry' } |
    Select-String -Pattern $rxN |
    ForEach-Object { "{0}:{1}:{2}" -f (Resolve-Path -Relative $_.Path), $_.LineNumber, $_.Line.Trim() }
Set-Content "$O\18-disaridan-cagrilar.txt" -Value (@($o18) -join "`r`n")

# 19 - ekran -> conversation eslemesi (hangi ekran hangi CCT'de TASK)
$o19 = $cctEntry | ForEach-Object {
    $f = $_.Name
    Select-String -LiteralPath $_.FullName -Pattern 'PageName="([^"]+)"' |
        ForEach-Object { "{0,-45} {1}" -f $f, $_.Matches[0].Groups[1].Value }
}
Set-Content "$O\19-ekran-conversation.txt" -Value (@($o19) -join "`r`n")

# 20 - include baglantilari. DIKKAT: baglanti URETILMIS Super dosyalarinda ve
# HTML data-page-name attribute'unda tanimli, o yuzden Super HARIC TUTULMUYOR.
$o20 = Get-ChildItem . -Recurse -File -Include *.java,*.js,*.html,*.cct |
    Select-String -Pattern 'IncludedPage|PG_Include[A-Za-z0-9_]*|data-page-name' |
    ForEach-Object { "{0}:{1}:{2}" -f (Resolve-Path -Relative $_.Path), $_.LineNumber, $_.Line.Trim() }
Set-Content "$O\20-include.txt" -Value (@($o20) -join "`r`n")

"14-yetki      : " + @($buf).Count
"15-properties : " + @($buf2).Count
"16-lang       : " + @($rows).Count
"17-dto        : " + @($buf3).Count
"18-disaridan  : " + @($o18).Count
"19-ekran-conv : " + @($o19).Count
"20-include    : " + @($o20).Count

# Kontrol: TASK'i olmayan ekranlar ve klasoru olmayan TASK'lar
$taskPages = @($o19 | ForEach-Object { ($_ -split '\s+')[-1] } | Sort-Object -Unique)
$folders   = @(Get-ChildItem $W -Directory).Name
"--- TASK'i olmayan ekranlar (koddan acilan popup adaylari) ---"
$folders   | Where-Object { $_ -notin $taskPages } | ForEach-Object { "  " + $_ }
"--- Klasoru olmayan TASK'lar (baska akisa ait ekranlar) ---"
$taskPages | Where-Object { $_ -notin $folders }   | ForEach-Object { "  " + $_ }
```

`13-include.txt` yerine **`20-include.txt`** kullanılacak — 13 yalnızca HTML
tarafını yakalıyor, java bağlantısı üretilmiş `Super` dosyalarında olduğu için
Adım 4'ün taramasının dışında kalıyor.

## [PS] Adım 6 — Özet

```powershell
Get-ChildItem $O -Filter *.txt | Sort-Object Name | ForEach-Object {
    $n = @(Get-Content -LiteralPath $_.FullName).Count
    if ($n -le 1) { "{0,-26} {1,7}  << BOS" -f $_.Name, $n } else { "{0,-26} {1,7}" -f $_.Name, $n }
}
```

20 dosya olmalı. `<< BOS` olanı **silme** — promptlar boş taramayı "TARAMA BOŞ"
diye işaretleyip devam edecek şekilde yazıldı.

PowerShell taramaları bitti.

> ## ► Buradan [MEKANIZASYON.md](./MEKANIZASYON.md)'ye geç
>
> Aşağıdaki Copilot adımlarına doğrudan girebilirsin, ama önce M1-M4
> bloklarını çalıştırmak akış grafiğini, olay↔handler eşlemesini, dil
> durumunu ve ekran kartlarının %70'ini script'e ürettirir. Adım 8 ve 12
> orada kısaltılmış hâlleriyle veriliyor ve Opus turu 16'dan 5-6'ya iner.

---

# BÖLÜM 2 — Copilot

## Sabit başlık (P0)

> **Kopyalaman gerekmiyor:** [promptlar/](./promptlar) altında her adım için
> P0 birleştirilmiş, kopyala-yapıştır hazır `.txt` dosyaları var. Aşağısı
> referans içindir.

**Her `[CP]` prompt'unun başına yapıştır.**

```
# HARMONİ — TEMEL
Kuruma özel, kapalı kaynak framework. Eğitim verinde YOK. Spring/JSF/Struts
konvansiyonlarını VARSAYMA. Bilmediğin bir mekanizmayı repodaki başka
örneklerden türet ve "TÜRETİLDİ (kaynak: <dosya>)" diye işaretle.
Türetemezsen "BİLİNMİYOR" yaz. Tahmin etme.

## Bir ekranın ayak izi
java\...\hmn\acq\application\entry\controllers\
    PG_X.java              geliştirici kodu — İŞ MANTIĞI BURADA
    PG_XSuper.java         ÜRETİLMİŞ taban sınıf — widget binding, iş kuralı DEĞİL
    Con_acqX.java          conversation controller (dev)
    Con_acqXSuper.java     ÜRETİLMİŞ
webapp\cct\con_acqX.cct    AKIŞ TANIMI (XML)
webapp\page\acq\application\entry\PG_X\
    PG_X.html, PG_X.js, PG_X.properties,
    PG_X_auth.properties       rolü DOĞRULANMADI
    PG_X_lang_en.json / PG_X_lang_tr.json

## CCT olay modeli — DİKKAT
Event           : ACTION/DECISION üzerindeki UI olayı. Koddaki onXxx handler'ına
                  karşılık gelir.
ControllerEvent : geçişin SONUÇ TOKEN'ı. HANDLER METODU DEĞİLDİR.
                  Sayfa controller'ı çalışma zamanında
                  eventData.setControllerEvent(TOKEN) ile üretir; framework bu
                  token'a bakıp hangi TRANSITION'ın işleyeceğine karar verir.
                  Token sabit olarak tanımlı olabilir:
                    public static final String STAY_ON_PAGE = "STAY_ON_PAGE";
                    eventData.setControllerEvent(PricingConstants.STAY_ON_PAGE);
                  ControllerEvent adında metot ARAMA — bulamazsın.
                  İki argümanlı overload da var:
                    setControllerEvent(eventData, "TOKEN")

## CCT — akışın kaynağı
CONVERSATION (ConvID, ConvController, DefaultTaskID, FunctionalArea)
  └ TASK (PageName, PageController, TaskID, CancelButton/ConfirmButton/TabVisible)
      └ ACTION (Event)
          └ TRANSITION (ControllerEvent, NextConvID, NextTaskID, InvocationMode, FlagEOC)
      └ DECISION (Event, koşullu dallanma)
Geçişler burada deklaratif olarak tanımlı.

## KRİTİK KURALLAR
1. *Super.java ÜRETİLMİŞ koddur — ama boş değil.
   İŞ MANTIĞI: Super'siz sınıfta. Super'den iş kuralı ÇIKARMA.
   YAPISAL SÖZLEŞME: Super'de — alan/widget tanımları ve included page'ler.
   Bunları Super'den okumak DOĞRU. İkisini karıştırma.
2. INCLUDE mekanizması iki yerde tanımlı:
   HTML   : <div data-type="IncludedPage" data-page-name="acq/include/account/PG_IncludeApplicationAccount">
   Super  : protected IIncludedPage<PG_IncludeApplicationAccount> getPageAccount()
   Include sayfaları page\acq\include\... altında, ayrı ağaçta. Akışın parçası.
3. 14 ekranın 4'ünün CCT'de TASK'ı YOK — PG_AccountWalletPopup, PG_AddNote,
   PG_LoyaltyProgramRatePopup, PG_TagOperation. Bunlar koddan açılıyor;
   CCT grafiğinde bulamazsan bu yüzdendir, uydurma.
4. Conversation'lar akış sınırını aşıyor. con_acqmerchantupdate.cct entry
   klasöründe olmayan ekranları TASK olarak içeriyor.
5. İki java ağacı var: controller'lar com.ykb.hmn.acq...,
   DTO'lar com.ykb.acq.application.entry.{request,response,util}
6. _auth.properties'in ROLÜ DOĞRULANMADI. Adından yetki dosyası sanılabilir
   ama 15 dosyanın 14'ü boş, dolu olan tek dosya (PG_TerminalInfo) validasyon
   HATA MESAJLARI içeriyor:
     INVALID_FINANCIAL_ID_ERROR = Girilen Mali ID ... uygun degil.
   Bu dosyaya "yetki tanımı" deme. Ne olduğunu framework'ten veya başka
   akışlardaki örneklerden türet; türetemezsen "BİLİNMİYOR" yaz.

## Repolar
FE: hmnfe_acq_merchant (bu repo)   BE: hmn_acq_merchant
  HMN_ACQ_Merchant_Intf (servis arayüzü) / _Model (DTO) / _Internal (impl)
Jackson 2.9.6. Excel rapor: HopeReportGenerator (server-side, reportId).

## Kapsam
cct/page/acq/application/entry — üye işyeri başvuru akışı, 14 ekran + include'lar.
Kardeş akışlar (kapsam dışı, bağımlılık olabilir): annulment, branchopening,
inquiry, template. ACQ = Acquiring / üye işyeri.

# ÇALIŞMA DİSİPLİNİ
- docs/entry-akis/_tarama/ altındaki dosyalarda olan bilgi için ARAMA YAPMA,
  dosyayı oku. Tarama çıktısı tek doğruluk kaynağıdır.
- Her ana bölümü bitirir bitmez hedef dosyaya YAZ. Sonda toplu yazma.
- Aynı dosyayı iki kez okuma.
- Sohbette özet yapma; hedef dosyaya yaz, sonunda tek paragraf durum bildir.
- Bir tarama dosyası boşsa "TARAMA BOŞ" yaz, tahminle doldurma.
- Kesilirsen hedef dosyayı oku, KALDIĞIN YERDEN devam et.
- Türkçe yaz, teknik terimleri İngilizce bırak.
```

---

## [CP] Adım 7 — Envanter + konvansiyon türetme

Yeni chat. P0 + aşağısı.

```
# GİRDİ
#file:docs/entry-akis/_tarama/03-webapp-dosyalar.txt
#file:docs/entry-akis/_tarama/04-java-envanter.txt
#file:docs/entry-akis/_tarama/05-ekran-boyutlari.txt
#file:docs/entry-akis/_tarama/06-cagri-hedefleri.txt
#file:docs/entry-akis/_tarama/07-importlar.txt
#file:docs/entry-akis/_tarama/09-metot-imzalari.txt

# GÖREV
(a) Ekran envanteri, (b) bu kod tabanının KONVANSİYONLARINI türet.
(b) sonraki tüm turların temeli — özenli ol.

# YÖNTEM
1. Envanter: her ekran için webapp 6'lısı ve java karşılıkları (PG_, PG_Super,
   Con_, Con_Super) eşleşiyor mu? Eksik/fazla olanları işaretle.
2. Sınıflandır: adım sayfası / modal popup / include (paylaşılan) / yardımcı.
   Kanıt: 09-metot-imzalari ve gerekirse .java ilk 60 satırı. İsim soneki tek
   başına gerekçe değil.
3. SUPER vs DEV: 04-java-envanter'e bak. Super dosyaları ortalama kaç satır,
   dev dosyaları kaç? Dev sınıfların Super'den ne devraldığını bir örnekten
   türet (bir PG_X.java + PG_XSuper.java çiftini aç).
4. CON_ SINIFLARININ ROLÜ: Con_acqX conversation controller ne yapıyor?
   PG_ ile ilişkisi ne? Bir örnekten türet.
5. YAŞAM DÖNGÜSÜ: 09-metot-imzalari'nda birden çok DEV sınıfında TEKRAR EDEN
   metot adlarını bul — bunlar framework'ün çağırdığı yaşam döngüsü metotları.
   Sırasını ve amacını türet.
6. SERVİS KONVANSİYONU: 06 + 07. Servis benzeri isimler hangi sonekle bitiyor?
   Servis çağrısı kodda tam olarak nasıl görünüyor?
7. STATE KONVANSİYONU: 06 ve 07'de ekranlar arası veri taşımaya aday ne var?

# ÇIKTI — docs/entry-akis/00a-envanter.md
## 1. Ekran Envanteri
Ekran | Tip | Gerekçe | PG_ satır | Super satır | Con_ var mı | html | js |
lang key | Eksik dosya | Bir cümlelik rol

## 2. Türetilen Konvansiyonlar
### Super / Dev ayrımı
Super'de ne var, dev sınıfta ne var, örnek çiftten kanıt
### Con_ conversation controller'ın rolü
### Yaşam döngüsü metotları
Metot | Kaç DEV sınıfında | Türetilen amaç | Kanıt (dosya:satır)
### Servis çağrısı deseni
Sonek, kodda görünümü, örnek satır
### State taşıma adayları
Aday | Neden aday | Kanıt
### Sonraki turlar için ARAMA DESENLERİ
Servis çağrısı, state erişimi, olay tetikleme için somut desenler

## 3. Boyut Dağılımı
En büyük 5 ekran (web + java ayrı)

## 4. Anomaliler
Eksik dosya, Super'i olmayan PG_, PG_'si olmayan Super, isim konvansiyonu
dışına çıkanlar

# KURAL
Akış grafiği, state sözlüğü, validasyon analizine GİRME. İyileştirme yazma.
```

**Kontrol:** "Türetilen Konvansiyonlar" dolu mu? Boşsa turu tekrarla.

---

## [CP] Adım 8 — Akış grafiği (CCT tabanlı)

Yeni chat. P0 + aşağısı.

```
# GİRDİ
#file:docs/entry-akis/00a-envanter.md
#file:docs/entry-akis/_tarama/02-cct-ozet.txt
#file:docs/entry-akis/_tarama/01-cct-entry.txt
#file:docs/entry-akis/_tarama/10-anahtar-kelimeler.txt
#file:docs/entry-akis/_tarama/11-gecisler.txt
#file:docs/entry-akis/_tarama/19-ekran-conversation.txt
#file:docs/entry-akis/_tarama/20-include.txt
#file:docs/entry-akis/_tarama/18-disaridan-cagrilar.txt

# GÖREV
Akış grafiğini çıkar. BİRİNCİL KAYNAK CCT DOSYALARIDIR — grafiği önce
02-cct-ozet ve 01-cct-entry üzerinden kur, sonra 11-gecisler ile doğrula.
İkisi çelişirse CCT'yi esas al ve ÇELİŞKİ olarak işaretle.

# YÖNTEM
1. CCT ENVANTERİ: her .cct için ConvID, ConvController, DefaultTaskID,
   ApplicationID, kaç TASK içeriyor.
2. TASK HARİTASI: her TASK için PageName, PageController, TaskID,
   CancelButton/ConfirmButton/TabVisible/TabEnabled.
3. GEÇİŞLER: her ACTION/TRANSITION için Event, ControllerEvent, NextConvID,
   NextTaskID, InvocationMode, FlagEOC. NextConvID boşsa ne anlama geliyor —
   bir örnekten türet.
4. DECISION düğümleri: hangi olayda, hangi koşullarla dallanıyor.
5. KOD KARŞILIĞI: 11-gecisler.txt'de CCT'de görünmeyen programatik geçiş var mı?
   (kod içinden açılan popup/dialog). Bunları ayrı işaretle.
6. INCLUDE: 20-include.txt — hangi ekran hangi PG_Include* sayfasını dahil
   ediyor. Bağlantı HTML'de data-page-name, java'da Super sınıfındaki
   IIncludedPage<> ile kuruluyor. Bunlar envanterdeki 14'e EK sayfalardır.
7. TASK'SIZ EKRANLAR: 19-ekran-conversation.txt'de PageName olarak geçmeyen
   ekranlar koddan açılıyor. Bunları 11-gecisler.txt'de ara ve nereden
   açıldıklarını bul. Bulamazsan "AÇILIŞ NOKTASI BULUNAMADI" yaz.
8. AKIŞ DIŞI TASK'LAR: 19'da geçip entry klasöründe karşılığı olmayan
   PageName'ler başka akışın ekranlarıdır. Grafikte ayrı renkte/notla göster.
9. GİRİŞ/ÇIKIŞ: 18-disaridan-cagrilar.txt ile akışa dışarıdan girişler.

# ÇIKTI — docs/entry-akis/00b-akis.md
## 1. CCT Envanteri
Dosya | ConvID | ConvController | DefaultTaskID | TASK sayısı | Kapsadığı ekranlar

## 2. Akış Grafiği
Mermaid flowchart. Düğüm = TASK/ekran, ok = TRANSITION.
Ok etiketi: Event → ControllerEvent. DECISION'ları karar şekliyle,
modal/popup'ları farklı şekille, include'ları kesikli çerçeveyle göster.

## 3. Geçiş Tablosu
Kaynak TASK | Event | ControllerEvent | NextConvID | NextTaskID |
InvocationMode | FlagEOC | Kaynak dosya:satır

## 4. Karar Noktaları
DECISION | Olay | Koşullar | Dallar | Kaynak

## 5. Kod İçinden Geçişler
CCT'de tanımlı olmayan, koddan tetiklenen açılışlar

## 6. Include Haritası
Dahil eden ekran | Dahil edilen sayfa | Nerede tanımlı | Kod referansı

## 7. Giriş ve Çıkış Noktaları
Dışarıdan girişler (kardeş akışlar dahil), tamamlanma ve iptal sonrası

## 8. Ekran ↔ Conversation Eşlemesi
Ekran | Geçtiği CCT dosyaları | TaskID | Birden çok conversation'da mı

## 9. CCT Dışı Ekranlar
TASK'ı olmayan 4 ekran: nereden, hangi kodla açılıyor, hangi parametreyle,
kapanınca parent'a ne dönüyor

## 10. Akış Dışı TASK'lar
Entry conversation'larının çağırdığı ama entry klasöründe olmayan ekranlar —
hangi akışa ait, neden buradan çağrılıyor

## 11. CCT ile Kod Arasındaki Çelişkiler

# KURAL
Her satırın yanında kaynak referansı. İyileştirme yazma.
```

---

## [CP] Adım 9a — Paylaşılan state'i yorumla

Yeni chat, **Sonnet**. **Önce M7'yi çalıştır.**

İki kez zaman aşımı aldı. Birincisi keşif yüzündendi (M7 çözdü), ikincisi
üretim uzunluğu yüzünden: 106 alanın tamamını yorumlaması isteniyordu. Artık
sadece `24b-state-paylasilan.txt` okunuyor — yerel alanlar elenmiş hâli.

```
# GİRDİ
#file:docs/entry-akis/_tarama/24b-state-paylasilan.txt

# GÖREV
Dosya script tarafından üretildi. Tabloları DOĞRU kabul et, kod okuma,
başka dosya açma. Sadece yorumla.

# ÇIKTI — docs/entry-akis/00c1-state.md
## 1. Paylaşılan Alanlar
PAYLASILAN tablosundaki her satır için TEK CÜMLE: bu alan hangi adımda
doluyor, hangi adımda tüketiliyor, taşınamazsa ne bozulur.
Alanları taşıyıcı tipine göre grupla.

## 2. Çok Yazanlı Alanlar
Birden fazla ekranın yazdığı alanlar: sıra bağımlılığı var mı, son yazan
kazanıyorsa bu risk mi? Sadece bu gruba odaklan.

## 3. OKUYAN-YOK
Yazılıp hiç okunmayan alanlar. Her biri için: ölü veri mi, yoksa BE'ye giden
DTO'da mı tüketiliyor? Ayırt edemiyorsan "BELİRSİZ" yaz.

## 4. YAZAN-YOK
Okunan ama bu akışta yazılmayan alanlar — veri akışa nereden giriyor?
Gelmezse ekran ne yapıyor?

## 5. Açık Sorular

# KURAL
Kısa yaz. Bölüm 1'de alan başına tek cümleyi aşma.
Tabloları tekrar etme. Kod okuma. İyileştirme yazma.
```

**Yine zaman aşımı alırsan:** prompt'u ikiye böl — önce Bölüm 1-2, sonra
ayrı turda Bölüm 3-5 (ilk turun çıktısını `#file:` ile vererek).

---

## [CP] Adım 9b — Servis, DTO, auth, ikizler

Yeni chat, **Sonnet** yeterli.

```
# GİRDİ
#file:docs/entry-akis/00a-envanter.md
#file:docs/entry-akis/_tarama/25-servis-matrisi.txt
#file:docs/entry-akis/_tarama/17-dto.txt
#file:docs/entry-akis/_tarama/14-yetki.txt
#file:docs/entry-akis/_tarama/05-ekran-boyutlari.txt

# GÖREV
Servis kesişimi, DTO envanteri, _auth.properties'in rolü, ikiz ekranlar.
State ve grup planı bu turda YOK.

# ÇIKTI — docs/entry-akis/00c2-servis-dto.md
## 1. Servis Paylaşım Matrisi
25-servis-matrisi.txt script tarafından üretildi; tabloları DOĞRU kabul et.
Yorumla: hangi servisler akışın omurgası (çok ekrandan çağrılan), B
bölümündeki ortak metotlar aynı veriyi tekrar tekrar mı çekiyor, C
bölümündeki dağılım dengesiz mi (bir ekran servis çağrısı yığını mı)
## 2. DTO Envanteri
DTO | Paket | İlişkili ekranlar | Alan sayısı | İki adlandırma kalıbından hangisi
## 3. _auth.properties
Rolü ne? 15 dosyanın 14'ü boş, dolu olan validasyon hata mesajı içeriyor.
Framework'te bu dosyanın ne işe yaradığını başka akışlardaki örneklerden
türet. Türetemezsen "BİLİNMİYOR" yaz ve açık soruya ekle.
## 4. İkiz / Varyant Adayları
Ekran A | Ekran B | Benzerlik kanıtı | Kopya şüphesi (VAR/YOK/İNCELENMELİ)
Zorunlu incelenecekler: ApplicationAccount/ApplicationAccountEdit,
ApplicationPricing/ApplicationPricingTrio, TagInquiry/TagOperation
## 5. Açık Sorular

# KURAL
İyileştirme yazma.
```

---

## [CP] Adım 9c — Grup planı ve açık soru kapanışı

Yeni chat, **Opus**.

```
# GİRDİ
#file:docs/entry-akis/00c1-state.md
#file:docs/entry-akis/00c2-servis-dto.md
#file:docs/entry-akis/00b-akis.md
#file:docs/entry-akis/_tarama/05-ekran-boyutlari.txt
#file:docs/entry-akis/_tarama/23-acik-sorular.txt

# GÖREV
(a) Derin analiz planı, (b) açık soruların kapanış durumu.

# ÇIKTI — docs/entry-akis/00c3-plan.md
## 1. DERİN ANALİZ PLANI
Grup no | Grup adı | Ekranlar | Neden birlikte | Derinlik TAM/ÖZET | Toplam satır
Kurallar:
- Grup 2000 satırı aşmasın; aşarsa böl
- İkiz ekranlar aynı grupta olmalı (yan yana karşılaştırılacaklar)
- Ortak state yazan/okuyan ekranlar aynı grupta olmaya çalışsın
- Include sayfalarını, onları kullanan ekranla aynı gruba koy
- CCT'de TASK'ı olmayan 4 popup'ı ayrı bir grupta topla
- 1'den başlayarak numaralandır — Adım 12 bu numarayla çalışacak

## 2. Açık Soru Durumu
00b-akis.md, 00c1 ve 00c2'deki tüm açık soruları tek listede topla.
Her biri için 23-acik-sorular.txt'ye bak:
Soru | Durum (KAPANDI / AÇIK) | Kapandıysa cevabı ve kanıtı | Açıksa kim
cevaplayacak (Adım 12 / insan)

## 3. Riskli Alanlar
Plana göre hangi grup en yüksek belirsizlik taşıyor, neden

# KURAL
İyileştirme yazma. Grup planı Adım 12'nin girdisi — özenli ol.
```

---

## [CP] Adım 10 — Doğrulama

Yeni chat — **aynı sohbette çalıştırma.** P0 + aşağısı.

```
# GİRDİ
#file:docs/entry-akis/00a-envanter.md
#file:docs/entry-akis/00b-akis.md
#file:docs/entry-akis/00c-plan.md

# GÖREV
Bu üç dosyayı ÜRETEN sen değilsin — eleştirel bir denetçisin. Her referansı
koda karşı doğrula. Özellikle şunlara bak:
- Bir iddia PG_XSuper.java'daki ÜRETİLMİŞ koda mı dayanıyor? Öyleyse geçersiz.
- CCT'den çıkarılan geçişler gerçekten o dosyada var mı?
- Include sayfaları atlanmış mı?

# ÇIKTI
## Yanlış Referanslar
İddia | Verilen referans | Kodda gerçekte ne var
## Üretilmiş Koda Dayanan İddialar
## Uydurulmuş İçerik
## Eksikler
Kodda/CCT'de var olup dokümanda geçmeyen
## Şüpheli Genellemeler

# KURAL
Sadece PROBLEMLİ olanları listele. Problem yoksa açıkça söyle, uydurma.
Düzeltmeleri doğrudan dosyalara uygula, sonunda neyi değiştirdiğini özetle.
```

---

## Adım 11 — Elle spot-check

- `00a` envanterinde 14 ekran + include'lar var mı
- `00b` geçiş tablosundan **3 satır** seç, ilgili `.cct` dosyasını aç — doğru mu
- `00c` state sözlüğünden **2 satır** seç, "yazan ekran" gerçekten yazıyor mu
- `00c` grup planı mantıklı mı — gerekirse elle düzelt

Hata bulursan düzelt, Adım 10'u tekrarla.

---

## [CP] Adım 12 — Ekran kartları

`00c`'deki **her grup için bir tur**, her tur yeni chat. P0 + aşağısı.

```
# GİRDİ
#file:docs/entry-akis/00a-envanter.md
#file:docs/entry-akis/00b-akis.md
#file:docs/entry-akis/00c-plan.md
#file:docs/entry-akis/_tarama/16-lang-keyleri.txt
#file:docs/entry-akis/_tarama/14-yetki.txt
#file:docs/entry-akis/_tarama/20-include.txt

# BU TURUN KAPSAMI
Grup     : <00c'deki grup no ve adı>
Ekranlar : <PG_X, PG_Y>
Derinlik : <TAM | ÖZET>
Dosyalar : <her ekran için #file: ile: PG_X.java, PG_X.html, PG_X.js,
            Con_acqX.java (varsa), con_acqX.cct>
NOT: PG_XSuper.java ve Con_acqXSuper.java ÜRETİLMİŞ. Sadece alan/widget
sözleşmesi için gerekirse aç; iş mantığı arama.

# YÖNTEM
Konvansiyonlar için 00a'daki "Türetilen Konvansiyonlar"ı kullan, yeniden türetme.
1. Yaşam döngüsü: bu ekranlarda hangi konvansiyon metotları var, ne yapıyorlar
2. CCT bağlamı: bu ekranın TASK tanımı ne diyor (butonlar, tab, geçişler)
3. Olay zinciri: ACTION/Event'ler ile koddaki handler'ları eşleştir.
   Karşılığı olmayan Event → "HANDLER BULUNAMADI".
   CCT'de olmayan handler → "CCT'DE TANIMSIZ".
4. Servis çağrıları: her çağrı için BE'deki HMN_ACQ_Merchant_Internal
   implementasyonunu bul. BE'ye erişemiyorsan arayüz imzası + DTO'yu çıkar,
   "BE TARAFI ANALİZ EDİLMEDİ" yaz — TAHMİN ETME.
5. DTO: kullanılan request/response sınıfları, Jackson anotasyonları
6. Validasyon: her kuralın NEREDE uygulandığı (js / PG_ / Con_ / Intf /
   Internal / DB / _auth.properties)
7. Yetki: bu ekranın _auth.properties tanımı ve kodda yetki kontrolü
8. i18n: 16-lang-keyleri'nden bu ekranların key'leri; tr-en eksikleri,
   kullanılmayanlar, hardcoded metinler
9. AKIŞ SÖZLEŞMESİ: akış state'inden NEYİ OKUYOR, NEYİ YAZIYOR? Beklediği veri
   gelmezse ne oluyor?
10. İkiz grupsa aynı işi yapan kodu YAN YANA karşılaştır

# ÇIKTI — docs/entry-akis/ekranlar/<grup-no>-<grup-adi>.md
Her ekran için:

## <PG_EkranAdı>
### Künye
Tip, CCT'deki TaskID/ConvID, akıştaki yeri, nereden açılıyor, yetki koşulu
### Akış Sözleşmesi
Yön (OKUR/YAZAR) | Veri | Kaynak/Hedef | Zorunlu mu | Yoksa ne oluyor
### Yaşam Döngüsü
### Olay Haritası
Event (CCT) | ControllerEvent | Handler (dosya:satır) | Durum
### İç Akışlar
Mutlu yol + alternatifler + hata yolları; Mermaid sequence diagram
### Servis Çağrıları
Metot | Impl | Girdi DTO | Çıktı DTO | Hata davranışı | Timeout/retry | Referans
### Veri Sözleşmesi
Alan | Tip | Zorunlu | Jackson anotasyonu | Null davranışı | Enum | UI karşılığı
### Validasyon
Alan | Kural | Nerede | Hata mesajı | Lang key var mı | Referans
Ayrıca: sadece js'te olanlar; sadece BE'de olup UI'a yansımayanlar
### Yetki
### Dialog ve Geri Bildirim
### i18n
### Ölü ve Şüpheli Kod
### Açık Sorular

## Grup İçi Karşılaştırma
(ikiz gruplarda) Konu | A | B | Fark kasıtlı mı | Referans

# KURAL
ÖZET derinlikte: Akış Sözleşmesi, Servis Çağrıları, Validasyon, Yetki, Dialog
doldur; gerisini tek paragrafla geç.
Üretilmiş Super sınıflarından iş kuralı çıkarma.
Kod bloğu yapıştırma; kritik 5-10 satırı alıntıla. İyileştirme yazma.
```

**Her turdan sonra:** "Akış Sözleşmesi" dolu mu? Boşsa o grubu tekrarla.

---

## [CP] Adım 13 — Konsolidasyon

Yeni chat. P0 + aşağısı.

```
# GİRDİ
#file:docs/entry-akis/00b-akis.md
#file:docs/entry-akis/00c-plan.md
#file:docs/entry-akis/ekranlar/<tüm kartları tek tek #file: ile ekle>

# GÖREV
Kartları birleştirip AKIŞ SEVİYESİNDE görünüm üret. Tek ekranın içinde
görünmeyen, ekranlar yan yana konunca ortaya çıkanı ara. Şüphelendiğin her
noktayı kodda doğrula.

# ÇIKTI — docs/entry-akis/90-konsolidasyon.md
## 1. Uçtan Uca Senaryolar
Mermaid sequence + adım adım: mutlu yol; geri dönüş (onBack); iptal
(CancelButton); onay (ConfirmButton); oturum kopması; adım bazlı hata yolları
## 2. Akış State Bütünlüğü
Yazılıp okunmayanlar; okunduğu halde her yoldan yazılmayanlar; aynı verinin
farklı ekranda farklı isim/tiple taşınması; geri dönüşte temizlenmeyen artıklar
## 3. Validasyon Tutarlılık Matrisi
Alan | Ekran | Kural | Nerede. Aynı alanı birden fazla ekran doğruluyorsa yan
yana koy, ÇELİŞKİLERİ işaretle. Ayrıca: sunucu karşılığı olmayan kurallar;
bir ekranda zorunlu diğerinde opsiyonel alanlar
## 4. Yetki Tutarlılığı
_auth.properties tanımları arasındaki boşluk ve çelişkiler
## 5. Birleşik Veri Sözleşmesi
## 6. Servis Çağrı Envanteri
Aynı veriyi tekrar tekrar çeken çağrılar
## 7. Olay/CCT Bütünlüğü
Handler'ı olmayan Event'ler; CCT'de tanımsız handler'lar; ulaşılamayan TASK'lar
## 8. Tekrarlanan Mantık Haritası
Ne tekrarlanıyor | Nerelerde | Tutarlı mı | Hangisi doğru davranış
## 9. i18n Bütünlüğü
## 10. Kapsam Dışına Bağımlılıklar
Include sayfaları ve kardeş akışlarla paylaşılanlar — bu akış değişirse
nereleri etkiler
## 11. Açık Sorular

# KURAL
Kartlarda yazana körü körüne güvenme; çelişkiyi kodda doğrula.
Kartlarda zaten yazılanı TEKRAR ETME — sadece birleştirince ortaya çıkanı yaz.
İyileştirme yazma.
```

Kesilirse: aynı prompt'u yeni chat'te tekrar gönder, ya da Bölüm 1-6 ve
Bölüm 7-11 olarak ikiye böl.

---

## [CP] Adım 14 — Doğrulama

Adım 10'un aynısı, girdi: `#file:docs/entry-akis/90-konsolidasyon.md`

## Adım 15 — Elle spot-check

**Validasyon Tutarlılık Matrisi**'nden 3 satır seç, kod referanslarını aç.
En sık hata var olmayan bir validasyonun raporlanması — bu yanlış Adım 16'ya
taşınırsa tüm plan çürük temele oturur.

---

## [CP] Adım 16 — İyileştirme planı

Yeni chat. P0 + aşağısı.

```
# GİRDİ
#file:docs/entry-akis/00b-akis.md
#file:docs/entry-akis/00c-plan.md
#file:docs/entry-akis/90-konsolidasyon.md

# GÖREV
entry akışı için iyileştirme alanlarını çıkar. Kod yazma, plan üret.
Dokümanlar doğrulandı ama iddia ettiğin her problemi kodda TEKRAR doğrula.

# EKSENLER — AKIŞ SEVİYESİ
1. Adım yapısı: gereksiz/birleştirilebilir TASK'lar, ileri-geri gezdirme
2. State taşıma: mekanizmanın kırılganlığı, geri dönüşte kaybolan veya
   temizlenmeyen state, yarıda kalan başvuru, oturum kopmasında veri kaybı
3. Ekranlar arası tutarsızlık: aynı alanın farklı doğrulanması, aynı kavramın
   farklı isim/tiple taşınması
4. CCT hijyeni: ulaşılamayan TASK, handler'ı olmayan Event, boş NextConvID ile
   kalan çıkmazlar, DECISION dallarının kapsanmaması
5. İkiz ekranların konsolidasyonu: birleştirme mi, ortak parçayı çıkarma mı,
   olduğu gibi bırakma mı — gerekçesiyle
6. Include kullanımı: paylaşılan sayfaların sözleşmesi net mi, sürprizli
   bağımlılık var mı
7. Modal/popup: bloklayıcılık, iptalde parent'ta kalan yarım state, dönüş
   değerinin doğrulanmaması

# EKSENLER — EKRAN SEVİYESİ
8. Validasyon boşluğu: sadece js'te olan (atlatılabilir) kurallar; BE'de olup
   UI'a yansımayan hatalar; FE-BE çelişkileri
9. Yetki: _auth.properties ile kod içi kontrolün uyuşmaması, tanımsız ekran
10. Sözleşme sağlığı: DTO-UI uyuşmazlıkları, Jackson anotasyon eksikleri
11. Kullanıcı geri bildirimi: sessizce yutulan hatalar, teknik mesajlar,
    loading/empty/kısmi veri eksikliği
12. Dayanıklılık: timeout/retry eksikleri, HopeReportGenerator senkron rapor
    riski, exception yutan catch'ler, yarım işlemde tutarlılık
13. Performans: adım geçişlerinde tekrar eden çağrılar, N+1, seri çağrılar
14. i18n: eksik key, hardcoded metin, ölü key
15. Güvenlik: istemci tarafı yetki kontrolü, loglara düşen PII/işyeri verisi,
    bağımlılık sürümleri (Jackson 2.9.6 — doğrula, risk varsa NOT olarak yaz)
16. Değişim riski: hangi karakterizasyon testleri önce yazılmalı
17. İzolasyon fırsatları

# HER BULGU İÇİN
### [B-01] <Kısa başlık>
- Eksen / Kapsam (akış geneli veya ekran)
- Kanıt: dosya:satır — kodda tam olarak ne var.
  ÜRETİLMİŞ Super dosyasına dayanan bulgu YAZMA.
- Neden problem: SOMUT başarısızlık senaryosu (hangi input/durum → hangi yanlış
  sonuç). "Best practice değil" KABUL EDİLMEZ
- Etki: kullanıcı + teknik
- Önerilen çözüm: somut yaklaşım, hangi dosyalar değişir
  (üretilmiş dosyalar değişecekse ÜRETİCİ ŞABLONU sorunudur, ayrıca belirt)
- Etkilenen diğer ekran/akış/include
- Nasıl geri alınır / kırılırsa nereden anlarız
- Efor S/M/L — Risk düşük/orta/yüksek
- Alternatifler ve neden bunu seçtin

# ÇIKTI — docs/entry-akis/99-iyilestirme.md
1. Bulgular, etki × efor sıralı
2. QUICK WINS (S + düşük risk)
3. YAPISAL DEĞİŞİKLİKLER (M/L), before/after Mermaid
4. DAVRANIŞ KORUYAN / DAVRANIŞ DEĞİŞTİREN ayrı listeler
5. ÖNCE YAZILMASI GEREKEN TESTLER — akış ve ekran seviyesi ayrı
6. BİLİNÇLİ OLARAK ÖNERMEDİKLERİM

# KURAL
"Yeniden yazalım / modern framework'e taşıyalım / mimariyi değiştirelim"
YASAK. Her öneri mevcut yapı içinde, artımlı, geri alınabilir olmalı.
Kanıtı olmayan bulgu yazma. En fazla 15 bulgu. Kod yazma.
```

---

# Bitti

```
docs/entry-akis/
  _tarama/             18 tarama çıktısı
  00a-envanter.md      envanter + türetilen konvansiyonlar
  00b-akis.md          CCT tabanlı akış grafiği
  00c-plan.md          state + servis + DTO + yetki + grup planı
  ekranlar/*.md        ekran kartları
  90-konsolidasyon.md  akış seviyesi birleşik görünüm
  99-iyilestirme.md    bulgular + testler + öncelik
```

Uygulamaya geçerken bulguları **teker teker** iste:

```
#file:docs/entry-akis/99-iyilestirme.md
[B-03] numaralı bulguyu uygula. Plandaki "Önerilen çözüm"e sadık kal.
Önce karakterizasyon testini yaz, mevcut davranışta geçtiğini doğrula, sonra
değişikliği yap. Üretilmiş Super dosyalarına dokunma.
```

## Takıldığın yer olursa

| Belirti | Çözüm |
|---|---|
| Değişkenler kaybolmuş (`Get-ChildItem $null` boş dönüyor) | Terminal sekmesi değişmiş. Adım 0'ı tekrar çalıştır |
| Tur uzun sürüp kesiliyor | Aynı prompt'u yeni chat'te tekrar gönder; Çalışma Disiplini kaldığı yerden devam ettirir |
| "Continue to iterate?" | Devam et. Sıklaşıyorsa model hâlâ kendi araması yapıyordur — tarama dosyalarını `#file:` ile verdiğinden emin ol |
| BE tarafı analiz edilmemiş | `File > Add Folder to Workspace` ile `hmn_acq_merchant` ekle |
| Model Super dosyalarından iş kuralı çıkarıyor | P0'daki "KRİTİK KURALLAR" bölümünü yapıştırmayı atlamışsın |
| Akış grafiği eksik | CCT taraması boş olabilir — Adım 1'deki `FunctionalArea` kontrolünü çalıştır |
| Bir tarama boş kaldı | Bırak. Promptlar "TARAMA BOŞ" yazıp devam edecek |
