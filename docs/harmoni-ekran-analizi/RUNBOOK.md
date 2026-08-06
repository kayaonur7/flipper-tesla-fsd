# entry Akışı — Uçtan Uca Runbook

Tek geçişte bitirmek için tasarlanmış doğrusal koşu. **Sırayla uygula, atlama.**

- `[PS]` adımları → PowerShell'e yapıştır
- `[CP]` adımları → Copilot **agent mode + Opus**, her adım **yeni chat**

Toplam: 6 PowerShell bloğu + 13-16 Copilot turu.

> Referans doküman: [PROMPTS.md](./PROMPTS.md) — tek ekran modu, çok büyük ekran
> bölme stratejisi ve alternatif çalıştırma yolları orada. Bu runbook kendi
> kendine yeterli; PROMPTS.md'yi açmana gerek yok.

## İlerleme listesi

```
[ ] 0  [PS] Kurulum ve kontrol
[ ] 1  [PS] Envanter ve boyutlar
[ ] 2  [PS] Çağrı hedefleri, import'lar, erişimciler
[ ] 3  [PS] Anahtar kelime sayımı, geçiş ve state satırları
[ ] 4  [PS] Dışarıdan çağrılar, metot imzaları, lang key'leri
[ ] 5  [PS] Özet — hepsi dolu mu
[ ] 6  [CP] Envanter + konvansiyon türetme      → 00a-envanter.md
[ ] 7  [CP] Geçiş grafiği                       → 00b-gecis.md
[ ] 8  [CP] State + servis + ikiz + grup planı  → 00c-plan.md
[ ] 9  [CP] Doğrulama (00a/00b/00c)
[ ] 10 [--] Elle spot-check
[ ] 11 [CP] Ekran kartları — grup başına 1 tur  → ekranlar/*.md
[ ] 12 [CP] Konsolidasyon                       → 90-konsolidasyon.md
[ ] 13 [CP] Doğrulama (konsolidasyon)
[ ] 14 [--] Elle spot-check
[ ] 15 [CP] İyileştirme planı                   → 99-iyilestirme.md
```

---

# BÖLÜM 1 — PowerShell

FE repo kökünde (`D:\Repo\hmnfe_acq_merchant`). Blokları **olduğu gibi**,
sırayla yapıştır. Her blok sonunda ne yazdığını söylüyor.

## [PS] Adım 0 — Kurulum ve kontrol

```powershell
$E = "cct\page\acq\entry"
$O = "docs\entry-akis\_tarama"
New-Item -ItemType Directory -Force $O, "docs\entry-akis\ekranlar" | Out-Null
"PS surumu     : " + $PSVersionTable.PSVersion.ToString()
"entry var mi  : " + (Test-Path $E)
"ekran sayisi  : " + @(Get-ChildItem $E -Directory).Count
"java sayisi   : " + @(Get-ChildItem $E -Recurse -File -Include *.java).Count
"html sayisi   : " + @(Get-ChildItem $E -Recurse -File -Include *.html).Count
"js sayisi     : " + @(Get-ChildItem $E -Recurse -File -Include *.js).Count
```

**Beklenen:** `entry var mi : True`, `ekran sayisi : 14`.
Ekran sayısı farklıysa `$E` yolunu düzelt, sonra devam et.

## [PS] Adım 1 — Envanter ve boyutlar

```powershell
$inv = Get-ChildItem $E -Recurse -File -Include *.java,*.html,*.js,*.json | ForEach-Object {
    "{0,7} {1}" -f (Get-Content -LiteralPath $_.FullName | Measure-Object -Line).Lines, (Resolve-Path -Relative $_.FullName)
} | Sort-Object
Set-Content "$O\01-dosyalar.txt" -Value (@($inv) -join "`r`n")

$sz = Get-ChildItem $E -Directory | ForEach-Object {
    $n = ((Get-ChildItem $_.FullName -Recurse -File | ForEach-Object { (Get-Content -LiteralPath $_.FullName | Measure-Object -Line).Lines }) | Measure-Object -Sum).Sum
    [PSCustomObject]@{ L = [int]$n; N = $_.Name }
} | Sort-Object L -Descending | ForEach-Object { "{0,7} {1}" -f $_.L, $_.N }
Set-Content "$O\02-ekran-boyutlari.txt" -Value (@($sz) -join "`r`n")

"01-dosyalar        : " + @($inv).Count + " satir"
"02-ekran-boyutlari : " + @($sz).Count + " satir"
```

## [PS] Adım 2 — Çağrı hedefleri, import'lar, erişimciler

Bu blok desen tahmin etmiyor; kodun kendi idiomlarını döküyor.

```powershell
# 03 - en cok cagrilan nesneler (servis adlandirmasi buradan cikacak)
$rx = [regex]'([A-Za-z_][A-Za-z0-9_]*)\s*\.\s*[a-z][A-Za-z0-9_]*\s*\('
$h = New-Object System.Collections.ArrayList
Get-ChildItem $E -Recurse -File -Include *.java,*.js | ForEach-Object {
    $t = Get-Content -LiteralPath $_.FullName -Raw
    if ($t) { foreach ($m in $rx.Matches($t)) { [void]$h.Add($m.Groups[1].Value) } }
}
$o3 = $h | Group-Object | Sort-Object Count -Descending | ForEach-Object { "{0,6} {1}" -f $_.Count, $_.Name }
Set-Content "$O\03-cagri-hedefleri.txt" -Value (@($o3) -join "`r`n")

# 04 - import satirlari
$o4 = Get-ChildItem $E -Recurse -File -Include *.java | Select-String '^\s*import\s' |
    ForEach-Object { $_.Line.Trim() -replace '^import\s+(static\s+)?','' -replace ';\s*$','' } |
    Group-Object | Sort-Object Count -Descending | ForEach-Object { "{0,6} {1}" -f $_.Count, $_.Name }
Set-Content "$O\04-importlar.txt" -Value (@($o4) -join "`r`n")

# 05 - erisimci metotlar (state tasima buradan cikacak)
$rx = [regex]'\b(?:get|set|put|add|read|write|load|save|fetch|clear)[A-Z][A-Za-z0-9_]*(?=\s*\()'
$h = New-Object System.Collections.ArrayList
Get-ChildItem $E -Recurse -File -Include *.java,*.js | ForEach-Object {
    $t = Get-Content -LiteralPath $_.FullName -Raw
    if ($t) { foreach ($m in $rx.Matches($t)) { [void]$h.Add($m.Value) } }
}
$o5 = $h | Group-Object | Sort-Object Count -Descending | ForEach-Object { "{0,6} {1}" -f $_.Count, $_.Name }
Set-Content "$O\05-erisimciler.txt" -Value (@($o5) -join "`r`n")

"03-cagri-hedefleri : " + @($o3).Count + " farkli hedef"
"04-importlar       : " + @($o4).Count + " farkli import"
"05-erisimciler     : " + @($o5).Count + " farkli metot"
```

## [PS] Adım 3 — Anahtar kelime sayımı, geçiş ve state satırları

Önce sayım yapılıyor, sonra **yalnızca gerçekten geçen** kelimelerin satırları
dökülüyor. Böylece boş desen sorunu kendiliğinden çözülüyor.

```powershell
$navKw   = 'startNewProcess','showCustomMessageBox','fireEvent','CCT','openDialog','closeDialog','showDialog','showPopup','openPopup','navigate','goPage','openPage','callPage','redirect','forward','closePage','back'
$stateKw = 'setPageData','getPageData','getProcessData','setProcessData','processContext','session','getAttribute','setAttribute','globalMap','sharedModel','getContext','putValue','getValue','getModel','setModel'
$files = Get-ChildItem $E -Recurse -File

$cnt = foreach ($k in ($navKw + $stateKw)) {
    [PSCustomObject]@{ K = $k; N = @($files | Select-String -SimpleMatch $k).Count }
}
Set-Content "$O\06-anahtar-kelimeler.txt" -Value ((@($cnt | Sort-Object N -Descending | ForEach-Object { "{0,6} {1}" -f $_.N, $_.K })) -join "`r`n")

$liveNav = @($cnt | Where-Object { $_.K -in $navKw -and $_.N -gt 0 }).K
if ($liveNav) {
    $o7 = $files | Select-String -Pattern (($liveNav | ForEach-Object { [regex]::Escape($_) }) -join '|') |
        ForEach-Object { "{0}:{1}:{2}" -f (Resolve-Path -Relative $_.Path), $_.LineNumber, $_.Line.Trim() }
} else { $o7 = @() }
Set-Content "$O\07-gecisler.txt" -Value (@($o7) -join "`r`n")

$liveState = @($cnt | Where-Object { $_.K -in $stateKw -and $_.N -gt 0 }).K
if ($liveState) {
    $o8 = $files | Select-String -Pattern (($liveState | ForEach-Object { [regex]::Escape($_) }) -join '|') |
        ForEach-Object { "{0}:{1}:{2}" -f (Resolve-Path -Relative $_.Path), $_.LineNumber, $_.Line.Trim() }
} else { $o8 = @() }
Set-Content "$O\08-state.txt" -Value (@($o8) -join "`r`n")

"Gecen nav kelimeleri   : " + ($liveNav -join ', ')
"Gecen state kelimeleri : " + ($liveState -join ', ')
"07-gecisler : " + @($o7).Count + " satir"
"08-state    : " + @($o8).Count + " satir"
```

**`Gecen state kelimeleri` boş çıkarsa panik yok** — Adım 6'daki prompt
`05-erisimciler.txt` üzerinden gerçek state mekanizmasını bulacak ve Adım 8
onu kullanacak.

## [PS] Adım 4 — Dışarıdan çağrılar, metot imzaları, lang key'leri

```powershell
# 09 - kardes akislardan entry ekranlarina yapilan cagrilar
$names = (Get-ChildItem $E -Directory).Name
$rxN = ($names | ForEach-Object { [regex]::Escape($_) }) -join '|'
$o9 = Get-ChildItem (Split-Path $E) -Recurse -File -Include *.java,*.js |
    Where-Object { $_.FullName -notmatch '[\\/]entry[\\/]' } |
    Select-String -Pattern $rxN |
    ForEach-Object { "{0}:{1}:{2}" -f (Resolve-Path -Relative $_.Path), $_.LineNumber, $_.Line.Trim() }
Set-Content "$O\09-disaridan-cagrilar.txt" -Value (@($o9) -join "`r`n")

# 10 - PG_ siniflarindaki metot imzalari (yasam dongusu buradan cikacak)
$o10 = Get-ChildItem $E -Recurse -File -Include *.java |
    Select-String -Pattern '^\s*(public|protected|private)\s+[\w<>\[\],\s]+\s+\w+\s*\(' |
    ForEach-Object { "{0}:{1}:{2}" -f (Resolve-Path -Relative $_.Path), $_.LineNumber, $_.Line.Trim() }
Set-Content "$O\10-metot-imzalari.txt" -Value (@($o10) -join "`r`n")

# 11 - lang key'leri (dosya + key)
$rxL = [regex]'"([^"]+)"\s*:'
$rows = New-Object System.Collections.ArrayList
Get-ChildItem $E -Recurse -File -Filter *.json | ForEach-Object {
    $p = (Resolve-Path -Relative $_.FullName)
    $t = Get-Content -LiteralPath $_.FullName -Raw
    if ($t) { foreach ($m in $rxL.Matches($t)) { [void]$rows.Add("$p`t$($m.Groups[1].Value)") } }
}
Set-Content "$O\11-lang-keyleri.txt" -Value (@($rows) -join "`r`n")

"09-disaridan-cagrilar : " + @($o9).Count + " satir"
"10-metot-imzalari     : " + @($o10).Count + " satir"
"11-lang-keyleri       : " + @($rows).Count + " satir"
```

## [PS] Adım 5 — Özet

```powershell
Get-ChildItem $O -Filter *.txt | Sort-Object Name | ForEach-Object {
    $n = @(Get-Content -LiteralPath $_.FullName).Count
    if ($n -le 1) { "{0,-26} {1,6}  << BOS" -f $_.Name, $n } else { "{0,-26} {1,6}" -f $_.Name, $n }
}
```

11 dosyanın hepsi listede olmalı. `<< BOS` işaretli varsa **silme, öylece
bırak** — promptlar boş taramayı "TARAMA BOŞ" diye işaretleyip devam edecek
şekilde yazıldı.

PowerShell işi bitti. Bundan sonrası Copilot.

---

# BÖLÜM 2 — Copilot

## Sabit başlık (P0)

**Her `[CP]` prompt'unun en başına bunu yapıştır.** Kısa tutuldu, context
yemiyor.

```
# HARMONİ — TEMEL
Kuruma özel, kapalı kaynak framework. Eğitim verinde YOK. Spring/JSF/Struts
konvansiyonlarını VARSAYMA. Bilmediğin bir mekanizmayı repodaki başka PG_*
ekranlarından türet ve "TÜRETİLDİ (kaynak: <dosya>)" diye işaretle.
Türetemezsen "BİLİNMİYOR" yaz. Tahmin etme.

Ekran = klasör: PG_<X>.java (controller) + <x>.html (widget) + <x>.js
        + _lang_tr.json / _lang_en.json
FE repo: hmnfe_acq_merchant   BE repo: hmn_acq_merchant
  HMN_ACQ_Merchant_Intf (servis arayüzü) / _Model (DTO) / _Internal (impl)
Bilinen mekanizmalar: startNewProcess, CCT, dialog, showCustomMessageBox
  (bloklayıcı), fireEvent, HopeReportGenerator (server-side Excel + reportId)
Jackson 2.9.6.

KAPSAM: cct/page/acq/entry — üye işyeri başvuru akışı, 14 alt ekran.
Kardeş akışlar (kapsam dışı ama bağımlılık olabilir): annulment, application,
branchopening, inquiry.
ACQ = Acquiring / üye işyeri (kartlı ödeme kabul tarafı).

# ÇALIŞMA DİSİPLİNİ
- docs/entry-akis/_tarama/ altındaki dosyalarda olan bilgi için ARAMA YAPMA,
  dosyayı oku. Tarama çıktısı tek doğruluk kaynağıdır.
- Her ana bölümü bitirir bitmez hedef dosyaya YAZ. Sonda toplu yazma.
- Aynı dosyayı iki kez okuma.
- Sohbette özet/açıklama yapma; doğrudan hedef dosyaya yaz, sonunda tek
  paragraf durum bildir.
- Bir tarama dosyası boşsa ilgili bölüme "TARAMA BOŞ — mekanizma kullanılmıyor
  veya farklı adlandırılmış" yaz. Boşluğu tahminle doldurma.
- Tur kesilirse hedef dosyanın mevcut halini oku ve KALDIĞIN YERDEN devam et.
- Türkçe yaz, teknik terimleri İngilizce bırak.
```

---

## [CP] Adım 6 — Envanter + konvansiyon türetme

Yeni chat. P0 + aşağısı.

```
# GİRDİ
#file:docs/entry-akis/_tarama/01-dosyalar.txt
#file:docs/entry-akis/_tarama/02-ekran-boyutlari.txt
#file:docs/entry-akis/_tarama/03-cagri-hedefleri.txt
#file:docs/entry-akis/_tarama/04-importlar.txt
#file:docs/entry-akis/_tarama/10-metot-imzalari.txt

# GÖREV
İki şey: (a) ekran envanteri, (b) bu kod tabanının KONVANSİYONLARINI türet.
(b) sonraki tüm turların temeli — özenli ol.

# YÖNTEM
1. Envanter: her PG_* klasörünü ve dosyalarını tabloya dök, eksik dosyaları
   işaretle.
2. Sınıflandır: adım sayfası / modal popup / yardımcı görünüm / arama ekranı.
   İsim soneki tek başına gerekçe değil — 10-metot-imzalari ve gerekiyorsa
   .java dosyasının ilk 60 satırından kanıt bul.
3. YAŞAM DÖNGÜSÜ KONVANSİYONU: 10-metot-imzalari.txt'de birden çok PG_
   sınıfında TEKRAR EDEN metot adlarını bul. Bunlar framework tarafından
   çağrılan yaşam döngüsü metotlarıdır. Sırasını ve amacını türet.
4. SERVİS KONVANSİYONU: 03-cagri-hedefleri + 04-importlar. Servis benzeri
   isimler hangi sonekle bitiyor (Intf / Service / Manager / Facade /
   Delegate / başka)? Servis çağrısının kodda tam olarak nasıl göründüğünü yaz.
5. STATE KONVANSİYONU: 03 ve 04'te ekranlar arası veri taşımaya aday ne var?
   (context, model, process, holder, cache, map benzeri isimler)
6. Kodda göremediğini yazma.

# ÇIKTI — docs/entry-akis/00a-envanter.md
## 1. Ekran Envanteri
Ekran | Tip | Sınıflandırma gerekçesi | java | html | js | lang key | Eksik dosya | Bir cümlelik rol

## 2. Türetilen Konvansiyonlar
### Yaşam döngüsü metotları
Metot | Kaç PG_ sınıfında var | Türetilen amaç | Kanıt (dosya:satır)
### Servis çağrısı deseni
Kodda nasıl görünüyor, hangi sonek, örnek satır
### State taşıma adayları
Aday | Neden aday | Kanıt
### Sonraki turlar için ARAMA DESENLERİ
Servis çağrısı, state erişimi ve olay tetikleme için kullanılacak somut
desenler — Adım 7 ve 8 bunları kullanacak

## 3. Boyut Dağılımı
En büyük 5 ekran

## 4. Anomaliler
Eksik dosya, isim konvansiyonu dışına çıkanlar, beklenmedik ek dosyalar

# KURAL
Geçiş grafiği, state sözlüğü ve validasyon analizine GİRME — sonraki turlarda.
İyileştirme önerisi yazma.
```

**Kontrol:** "Türetilen Konvansiyonlar" bölümü dolu mu? Boşsa bu turu tekrarla —
sonraki iki tur buna dayanıyor.

---

## [CP] Adım 7 — Geçiş grafiği

Yeni chat. P0 + aşağısı.

```
# GİRDİ
#file:docs/entry-akis/00a-envanter.md
#file:docs/entry-akis/_tarama/06-anahtar-kelimeler.txt
#file:docs/entry-akis/_tarama/07-gecisler.txt
#file:docs/entry-akis/_tarama/09-disaridan-cagrilar.txt

# GÖREV
Ekranlar arası geçiş grafiğini ve akışın giriş/çıkış noktalarını çıkar.
State ve servis analizine GİRME — sonraki tur.

# YÖNTEM
1. 06-anahtar-kelimeler.txt'ye bak: hangi navigasyon mekanizmaları gerçekten
   kullanılıyor? Sayısı 0 olanları yok say.
2. 07-gecisler.txt'deki her satırı incele: kim çağırıyor, hangi ekranı açıyor,
   hangi koşulla, hangi parametreyi taşıyarak. Hedef satırdan anlaşılmıyorsa
   SADECE o dosyanın ilgili bölümünü aç.
3. Geri dönüş yolları: modal kapanınca / adım tamamlanınca parent'a nasıl
   dönülüyor, dönüş değeri var mı.
4. 09-disaridan-cagrilar.txt ile akışa dışarıdan girişleri belirle.
5. Akış tamamlanınca ve iptal edilince nereye gidiliyor.

# ÇIKTI — docs/entry-akis/00b-gecis.md
## 1. Kullanılan Navigasyon Mekanizmaları
Mekanizma | Kaç kez | Ne için kullanılıyor | Örnek (dosya:satır)

## 2. Geçiş Grafiği
Mermaid flowchart. Düğüm = ekran, ok = geçiş. Ok etiketi: tetikleyici +
taşınan parametre. Modal'ları farklı şekille göster.

## 3. Geçiş Tablosu
Kaynak | Hedef | Mekanizma | Koşul | Taşınan parametre | Dönüş değeri | Kod referansı

## 4. Giriş ve Çıkış Noktaları
Dışarıdan girişler (kardeş akışlar dahil), ön koşullar, tamamlanma ve iptal
sonrası nereye gidildiği

## 5. Ulaşılamayan Ekranlar
Envanterde olup hiçbir geçişle açılmayan ekranlar — ölü ekran şüphesi

# KURAL
Her geçişin yanında dosya:satır. İyileştirme önerisi yazma.
```

---

## [CP] Adım 8 — State, servis, ikizler ve grup planı

Yeni chat. P0 + aşağısı. **Bu turun çıktısı sonraki her şeyin girdisi.**

```
# GİRDİ
#file:docs/entry-akis/00a-envanter.md
#file:docs/entry-akis/00b-gecis.md
#file:docs/entry-akis/_tarama/03-cagri-hedefleri.txt
#file:docs/entry-akis/_tarama/05-erisimciler.txt
#file:docs/entry-akis/_tarama/08-state.txt
#file:docs/entry-akis/_tarama/02-ekran-boyutlari.txt

# GÖREV
Paylaşılan state'i, servis kesişimini ve ikiz ekranları çıkar; sonra derin
analiz planını üret.

# YÖNTEM
1. PAYLAŞILAN STATE — en kritik adım.
   00a'daki "State taşıma adayları" ve 05-erisimciler.txt'yi kullan.
   08-state.txt boşsa mekanizma farklı adlandırılmış demektir; 05'teki
   erişimcilerden doğru olanı seç ve kodda doğrula.
   Adımlar arası taşınan her veri için: nerede saklanıyor, hangi ekranda
   YAZILIYOR, hangi ekranda OKUNUYOR. 00b'deki "taşınan parametre" sütunuyla
   çapraz kontrol et.
2. SERVİS KESİŞİMİ: 00a'daki servis konvansiyonunu kullanarak 03'ten servis
   çağrılarını ayıkla. Hangi metot kaç farklı ekrandan çağrılıyor?
3. İKİZLER: ApplicationAccount/ApplicationAccountEdit,
   ApplicationPricing/ApplicationPricingTrio, TagInquiry/TagOperation ve
   envanterden çıkan diğer benzerler. Yüzeysel karşılaştır — boyut, ortak
   metot adları, ortak lang key'leri. "Kopya şüphesi VAR/YOK/İNCELENMELİ".
4. GRUP PLANI: 14 ekranı 6-8 gruba indir.

# ÇIKTI — docs/entry-akis/00c-plan.md
## 1. Paylaşılan State Sözlüğü
Veri | Saklandığı yer | Yazan ekran(lar) | Okuyan ekran(lar) | Tip | Akış sonunda ne oluyor
Ayrıca: yazılıp hiç okunmayanlar; okunup hiç yazılmayanlar

## 2. Servis Paylaşım Matrisi
Servis metodu | Çağıran ekranlar | Çağrı sayısı | Aynı parametrelerle mi

## 3. İkiz / Varyant Adayları
Ekran A | Ekran B | Benzerlik kanıtı | Kopya şüphesi

## 4. DERİN ANALİZ PLANI
Her grup için: grup adı | ekranlar | neden birlikte (ortak state / ikiz /
ardışık adım) | derinlik TAM veya ÖZET | toplam satır
Kural: bir grup 2000 satırı aşmasın, aşıyorsa ikiye böl.
Grupları 1'den başlayarak numaralandır — Adım 11'de sırayla kullanılacak.

## 5. Açık Sorular

# KURAL
Ekranların iç mantığına girme (validasyon detayı, DTO alan listesi YOK).
İyileştirme önerisi yazma.
```

---

## [CP] Adım 9 — Doğrulama

Yeni chat — **aynı sohbette çalıştırma**, model kendi çıktısını savunur.
P0 + aşağısı.

```
# GİRDİ
#file:docs/entry-akis/00a-envanter.md
#file:docs/entry-akis/00b-gecis.md
#file:docs/entry-akis/00c-plan.md

# GÖREV
Bu üç dosya önceki turlarda üretildi. Onları ÜRETEN sen değilsin — eleştirel
bir denetçisin. Her dosya:satır referansını koda karşı doğrula.

# ÇIKTI
## Yanlış Referanslar
İddia | Verilen referans | Kodda gerçekte ne var

## Uydurulmuş İçerik
Kodda hiç karşılığı olmayan iddialar

## Eksikler
Kodda var olup dokümanda geçmeyen: ekran, geçiş, servis, state alanı

## Şüpheli Genellemeler
"Muhtemelen / genellikle / standart olarak" ile geçiştirilmiş kanıtsız yerler

# KURAL
Doğru maddeleri tek tek onaylama, sadece PROBLEMLİ olanları listele.
Problem bulamazsan açıkça söyle; uydurma bulgu üretme.
Düzeltmeleri doğrudan ilgili dosyaya uygula, sonunda neyi değiştirdiğini özetle.
```

---

## Adım 10 — Elle spot-check (atlama)

5 dakika. Harita yanlışsa 6-8 kart da yanlış çıkar.

- `00a` envanterinde 14 ekranın hepsi var mı
- `00b` geçiş tablosundan **3 ok** seç, kod referanslarını aç — gerçekten var mı
- `00c` state sözlüğünden **2 satır** seç, "yazan ekran" gerçekten yazıyor mu
- `00c` grup planı mantıklı mı — sen daha iyi biliyorsun, gerekirse elle düzelt

Hata bulursan düzelt, Adım 9'u tekrarla.

---

## [CP] Adım 11 — Ekran kartları

`00c`'deki **her grup için bir tur**, her tur yeni chat. P0 + aşağısı.

```
# GİRDİ
#file:docs/entry-akis/00a-envanter.md
#file:docs/entry-akis/00c-plan.md
#file:docs/entry-akis/_tarama/11-lang-keyleri.txt

# BU TURUN KAPSAMI
Grup     : <00c'deki grup no ve adı>
Ekranlar : <PG_X, PG_Y>
Derinlik : <TAM | ÖZET>
Dosyalar : <her ekranın .java / .html / .js yolunu #file: ile tek tek ver>

# YÖNTEM
Konvansiyonlar için 00a'daki "Türetilen Konvansiyonlar" bölümünü kullan —
yeniden türetme.
1. Yaşam döngüsü: bu ekranlarda hangi konvansiyon metotları var, ne yapıyorlar
2. Olay zinciri: fireEvent (veya 00a'daki gerçek mekanizma) çağrılarını bul;
   her olay adını STRING olarak iki repoda ara. Dinleyicisi yoksa "DİNLEYİCİSİ
   BULUNAMADI", tetikleyicisi yoksa "ÖLÜ HANDLER ŞÜPHESİ"
3. Servis çağrıları: her çağrı için BE'deki HMN_ACQ_Merchant_Internal
   implementasyonunu bul. BE'ye erişemiyorsan arayüz imzası + DTO'yu çıkar ve
   "BE TARAFI ANALİZ EDİLMEDİ" yaz — implementasyonu TAHMİN ETME
4. DTO: HMN_ACQ_Merchant_Model sınıfları, alan bazlı Jackson anotasyonları
5. Validasyon: her kuralın NEREDE uygulandığı (js / controller / Intf /
   Internal / DB)
6. i18n: 11-lang-keyleri.txt'den bu ekranların key'lerini süz; tr-en eksikleri,
   kullanılmayan key'ler, kodda hardcoded metinler
7. AKIŞ SÖZLEŞMESİ: bu ekran akış state'inden NEYİ OKUYOR, NEYİ YAZIYOR?
   Beklediği veri gelmezse ne oluyor?
8. Gruptaki ekranlar ikizse aynı işi yapan kodu YAN YANA karşılaştır

# ÇIKTI — docs/entry-akis/ekranlar/<grup-no>-<grup-adi>.md
Her ekran için ayrı kart:

## <PG_EkranAdı>
### Künye
Tip, akıştaki yeri, nereden açılıyor, yetki/rol koşulu
### Akış Sözleşmesi
Yön (OKUR/YAZAR) | Veri | Kaynak/Hedef | Zorunlu mu | Yoksa ne oluyor
### Yaşam Döngüsü
Çağrılan metotlar, sırası, her adımda ne olduğu
### Olay Haritası
Olay | Tetikleyen | Dinleyen | Taşıdığı veri | Durum
### İç Akışlar
Mutlu yol + alternatifler + hata yolları; her biri için Mermaid sequence diagram
### Servis Çağrıları
Metot | Impl | Girdi DTO | Çıktı DTO | Hata davranışı | Timeout/retry | Referans
### Veri Sözleşmesi
Alan | Tip | Zorunlu | Jackson anotasyonu | Null davranışı | Enum | UI karşılığı
### Validasyon
Alan | Kural | Nerede | Hata mesajı | Lang key var mı | Referans
Ayrıca: sadece js'te olanlar; sadece BE'de olup UI'a yansımayanlar
### Dialog ve Geri Bildirim
Bloklayıcı mı, lokalize mi, iptal edilirse ne oluyor
### i18n
tr'de var en'de yok / en'de var tr'de yok / kullanılmayan / hardcoded
### Ölü ve Şüpheli Kod
### Açık Sorular

## Grup İçi Karşılaştırma
(sadece ikiz gruplarda) Konu | A davranışı | B davranışı | Fark kasıtlı mı | Referans

# KURAL
Derinlik ÖZET ise: Akış Sözleşmesi, Servis Çağrıları, Validasyon ve Dialog
bölümlerini doldur, diğerlerini tek paragrafla geç.
Kod bloğu yapıştırma; kritik 5-10 satırı alıntıla, gerisine referans ver.
İyileştirme önerisi yazma.
```

**Her turdan sonra:** "Akış Sözleşmesi" bölümü dolu mu bak. Boşsa o grubu
tekrar çalıştır — Adım 12 buna dayanıyor.

---

## [CP] Adım 12 — Konsolidasyon

Yeni chat. P0 + aşağısı.

```
# GİRDİ
#file:docs/entry-akis/00b-gecis.md
#file:docs/entry-akis/00c-plan.md
#file:docs/entry-akis/ekranlar/<hepsini tek tek #file: ile ekle>

# GÖREV
Kartları birleştirip AKIŞ SEVİYESİNDE görünüm üret. Tek ekranın içinde
görünmeyen, ancak ekranlar yan yana konunca ortaya çıkanı ara. Şüphelendiğin
her noktayı kodda doğrula.

# ÇIKTI — docs/entry-akis/90-konsolidasyon.md
## 1. Uçtan Uca Senaryolar
Her biri Mermaid sequence diagram + adım adım: mutlu yol; geri dönüş; iptal;
oturum kopması; adım bazında başlıca hata yolları

## 2. Akış State Bütünlüğü
Yazılıp hiç okunmayanlar; okunduğu halde her yoldan yazılmayanlar; aynı verinin
farklı ekranda farklı isim/tiple taşınması; geri dönüşte temizlenmeyen artıklar

## 3. Validasyon Tutarlılık Matrisi
Alan | Ekran | Kural | Nerede. Aynı alanı birden fazla ekran doğruluyorsa
satırları yan yana koy, ÇELİŞKİLERİ işaretle. Ayrıca: hiçbir yerde sunucu
karşılığı olmayan kurallar; bir ekranda zorunlu diğerinde opsiyonel alanlar

## 4. Birleşik Veri Sözleşmesi
Akışta kullanılan DTO'lar, hangi ekranda hangi alt kümesi, aynı kavramı
temsil eden farklı DTO'lar

## 5. Servis Çağrı Envanteri
Birleşik tablo + aynı veriyi tekrar tekrar çeken çağrılar

## 6. Olay Bütünlüğü
Dinleyicisi olmayan olaylar; birden çok dinleyicisi olup sıra bağımlılığı olanlar

## 7. Tekrarlanan Mantık Haritası
Ne tekrarlanıyor | Nerelerde | Versiyonlar tutarlı mı | Hangisi doğru davranış

## 8. i18n Bütünlüğü
Eksik / hardcoded / ölü key'lerin birleşik listesi

## 9. Kapsam Dışına Bağımlılıklar
Kardeş akışlarla paylaşılan servis, DTO, utility, state — bu akış değişirse
nereleri etkiler

## 10. Açık Sorular
Tüm kartlardan gelen soruların tekilleştirilmiş listesi

# KURAL
Kartlarda yazana körü körüne güvenme; çelişki gördüğün yeri kodda doğrula.
Kartlarda zaten yazılanı TEKRAR ETME — sadece birleştirince ortaya çıkanı yaz.
İyileştirme önerisi yazma.
```

Kart sayısı fazlaysa bu tur uzayabilir. Kesilirse: aynı prompt'u yeni chat'te
tekrar gönder (Çalışma Disiplini kaldığı yerden devam ettirir), ya da Bölüm
1-5 ve Bölüm 6-10 olarak iki tura böl.

---

## [CP] Adım 13 — Doğrulama

Adım 9'un aynısı, girdi tek dosya:

```
#file:docs/entry-akis/90-konsolidasyon.md
```

## Adım 14 — Elle spot-check

**Validasyon Tutarlılık Matrisi**'nden 3 satır seç, kod referanslarını aç.
En sık hata var olmayan bir validasyonun raporlanması — bu yanlış Adım 15'e
taşınırsa tüm plan çürük temele oturur.

---

## [CP] Adım 15 — İyileştirme planı

Yeni chat. P0 + aşağısı.

```
# GİRDİ
#file:docs/entry-akis/00b-gecis.md
#file:docs/entry-akis/00c-plan.md
#file:docs/entry-akis/90-konsolidasyon.md

# GÖREV
entry akışı için iyileştirme alanlarını çıkar. Kod yazma, plan üret.
Bu dokümanlar doğrulama pasından geçti, ama iddia ettiğin her problemi kodda
TEKRAR doğrula.

# EKSENLER — AKIŞ SEVİYESİ
1. Adım yapısı: gereksiz/birleştirilebilir adımlar, ileri-geri gezdirme
2. State taşıma: mekanizmanın kırılganlığı, geri dönüşte kaybolan veya
   temizlenmeyen state, yarıda kalan başvuru, oturum kopmasında veri kaybı
3. Ekranlar arası tutarsızlık: aynı alanın farklı doğrulanması, aynı kavramın
   farklı isim/tiple taşınması
4. İkiz ekranların konsolidasyonu: birleştirme mi, ortak parçayı çıkarma mı,
   olduğu gibi bırakma mı — gerekçesiyle
5. Modal/popup davranışı: bloklayıcılık, iptalde parent'ta kalan yarım state,
   dönüş değerinin doğrulanmaması

# EKSENLER — EKRAN SEVİYESİ
6. Validasyon boşluğu: sadece js'te olan (atlatılabilir) kurallar; BE'de olup
   UI'a yansımayan hatalar; FE-BE çelişkileri
7. Sözleşme sağlığı: DTO-UI uyuşmazlıkları, Jackson anotasyon eksikleri,
   tip güvenliğinin kaybedildiği dönüşümler
8. Olay hijyeni: dinleyicisi olmayan olaylar, örtük sıra bağımlılığı
9. Kullanıcı geri bildirimi: sessizce yutulan hatalar, teknik mesajlar,
   loading/empty/kısmi veri eksikliği
10. Dayanıklılık: timeout/retry eksikleri, HopeReportGenerator senkron rapor
    riski, exception yutan catch'ler, yarım işlemde tutarlılık
11. Performans: adım geçişlerinde tekrar eden çağrılar, N+1,
    paralelleştirilebilir seri çağrılar, over-fetching
12. i18n: eksik key, hardcoded metin, ölü key
13. Güvenlik/yetki: sadece istemci tarafı yetki kontrolü, loglara düşen PII
    veya işyeri/kart verisi, bağımlılık sürümleri (Jackson 2.9.6 dahil —
    sürümü doğrula, bilinen risk varsa NOT olarak yaz, kesin iddia etme)
14. Değişim riski: dokunmadan önce hangi karakterizasyon testleri yazılmalı
15. İzolasyon fırsatları: net sınırı olan, parça parça çıkarılabilir alt-akışlar

# HER BULGU İÇİN
### [B-01] <Kısa başlık>
- Eksen / Kapsam (akış geneli veya ekran adı)
- Kanıt: dosya:satır — kodda tam olarak ne var
- Neden problem: SOMUT başarısızlık senaryosu (hangi input/durum → hangi yanlış
  sonuç). "Best practice değil" gibi soyut gerekçe KABUL EDİLMEZ
- Etki: kullanıcı + teknik
- Önerilen çözüm: somut yaklaşım, hangi dosyalar değişir
- Etkilenen diğer ekran/akış/job (konsolidasyon Bölüm 9)
- Nasıl geri alınır / kırılırsa nereden anlarız
- Efor S/M/L — Risk düşük/orta/yüksek
- Alternatifler ve neden bunu seçtin

# ÇIKTI — docs/entry-akis/99-iyilestirme.md
1. Bulgular, etki × efor'a göre sıralı
2. QUICK WINS (S efor + düşük risk)
3. YAPISAL DEĞİŞİKLİKLER (M/L), her biri için before/after Mermaid diyagramı
4. DAVRANIŞ KORUYAN (refactor) ve DAVRANIŞ DEĞİŞTİREN (fix/feature) ayrı listeler
5. ÖNCE YAZILMASI GEREKEN TESTLER — akış seviyesi ve ekran seviyesi ayrı
6. BİLİNÇLİ OLARAK ÖNERMEDİKLERİM — eledikleri ve nedeni

# KURAL
"Yeniden yazalım / modern framework'e taşıyalım / mimariyi değiştirelim" türü
öneriler YASAK. Her öneri mevcut yapı içinde, artımlı ve geri alınabilir olmalı.
Kanıtı olmayan bulgu yazma. En fazla 15 bulgu.
Bir davranışın NEDEN öyle olduğu belirsizse öneri üretme, "Açık Sorular"a ekle.
Kod yazma.
```

---

# Bitti

Elinde şunlar olacak:

```
docs/entry-akis/
  _tarama/        11 tarama çıktısı
  00a-envanter.md      envanter + türetilen konvansiyonlar
  00b-gecis.md         geçiş grafiği + giriş/çıkış
  00c-plan.md          state sözlüğü + servis matrisi + grup planı
  ekranlar/*.md        ekran kartları
  90-konsolidasyon.md  akış seviyesi birleşik görünüm
  99-iyilestirme.md    bulgular + testler + öncelik
```

Uygulamaya geçerken bulguları **teker teker** iste:

```
#file:docs/entry-akis/99-iyilestirme.md
[B-03] numaralı bulguyu uygula. Plandaki "Önerilen çözüm"e sadık kal.
Önce bulgudaki karakterizasyon testini yaz, mevcut davranışta geçtiğini
doğrula, sonra değişikliği yap.
```

## Takıldığın yer olursa

| Belirti | Çözüm |
|---|---|
| Tur uzun sürüp kesiliyor | Aynı prompt'u yeni chat'te tekrar gönder; Çalışma Disiplini kaldığı yerden devam ettirir |
| "Continue to iterate?" | Devam et. Sık oluyorsa model hâlâ kendi araması yapıyordur — tarama dosyalarını `#file:` ile verdiğinden emin ol |
| BE tarafı analiz edilmemiş | İki repo tek workspace'te mi? `File > Add Folder to Workspace` ile `hmn_acq_merchant` ekle |
| Bir tarama boş kaldı | Bırak. Promptlar "TARAMA BOŞ" yazıp devam edecek şekilde yazıldı |
| Model konvansiyonu Spring/JSF gibi anlatıyor | P0 başlığını yapıştırmayı atlamışsın |
| Sonraki tur öncekini hatırlamıyor | Çıktıyı `#file:` ile ver; chat geçmişine güvenme |
