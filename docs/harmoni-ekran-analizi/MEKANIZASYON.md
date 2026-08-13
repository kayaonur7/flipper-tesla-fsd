# Mekanizasyon — Çıkarımı Script'e, Yargıyı Modele

Analizin deterministik kısmını PowerShell üretir; Copilot yalnızca yorumlar.
Bu, Opus turunu **16'dan 5-6'ya** indirir ve kaliteyi düşürmez — tam tersine
modelin bütçesi tablo doldurmaya değil "bu neden böyle ve nesi yanlış"
sorusuna gider.

## Ne üretiliyor

| Blok | Üretilen | Hangi Copilot adımının yerini alıyor |
|---|---|---|
| M1 | `00b-akis-otomatik.md` — conversation/task/transition tabloları + Mermaid grafiği | Adım 8'in tamamına yakını |
| M2 | `_tarama/21-event-handler.txt` — CCT olayı ↔ java handler eşlemesi | Adım 12'nin olay haritası bölümü |
| M3 | `_tarama/22-lang-durumu.txt` — tr/en farkı, ölü key'ler | Adım 12'nin i18n bölümü |
| M4 | `ekranlar/<PG_X>.hazir.md` — ekran başına ön-doldurulmuş kart | Adım 12'nin %70'i |

---

## Nasıl çalıştırılır

Üç yol var; ikisi execution policy'ye takılmaz.

**1. Doğrudan terminale yapıştır** — M0, M1, M2, M3 için. VS Code'un entegre
terminali çok satırlı yapıştırmayı düzgün işler. Blok bittiğinde `>>` istemi
kalırsa bir kez daha Enter'a bas.

**2. VS Code "Run Selection"** — uzun bloklar (M4) için. Bloğu bir `.ps1`
dosyasına kaydet, dosyayı aç, `Ctrl+A` → **`F8`**. Bu dosyayı *çalıştırmaz*,
seçili metni terminale gönderir; execution policy dosya çalıştırmayı engeller,
metin göndermeyi değil. PowerShell eklentisi kilitli ortamda açılmıyorsa 3. yol.

**3. Copilot agent mode'a çalıştırt** — "aşağıdaki komutları terminalde
çalıştır, değiştirme, sadece çalıştır" deyip bloğu ver.

### Oturum bağımlılığı

**M0'ı bir kez çalıştırman yeterli** — parse sonucunu `_tarama/cct-*.csv`
dosyalarına da yazar. M1, M2 ve M4 bellekte veri bulamazsa CSV'den yükler, yani
yeni terminalde de çalışırlar.

Buna rağmen kökler (`$W`, `$J`, `$CCT`, `$O`) her blokta yeniden tanımlanıyor,
o yüzden hiçbir blok başka bir bloğun oturumuna bağlı değil.

> Bu koruma eklenmeden önce M0'ı bir sekmede, M1'i başkasında çalıştırmak
> tabloları boş üretiyordu. Artık üretemez.

### Çalıştırma sırası

```
M0  oturum kurulumu          (her yeni terminalde)
M1  CCT -> grafik
M2  olay <-> handler
M3  dil durumu
Adım 7  envanter + konvansiyon        [Copilot]
M0  (yeni sekmedeysen tekrar)
M4  kart on-doldurma          ($svcRx'i 00a'ya gore daralt)
Adım 8'den itibaren devam            [Copilot]
```

---

## M0 — Oturum kurulumu

Kökleri kurar ve CCT'yi belleğe parse eder. **Her yeni terminalde çalıştır.**

````powershell
$W   = "src\main\webapp\page\acq\application\entry"
$J   = "src\main\java\com\ykb\hmn\acq\application\entry\controllers"
$JD  = "src\main\java\com\ykb\acq\application\entry"
$CCT = "src\main\webapp\cct"
$O   = "docs\entry-akis\_tarama"
New-Item -ItemType Directory -Force $O, "docs\entry-akis\ekranlar" | Out-Null

$cctEntry = Get-ChildItem $CCT -Recurse -File -Filter *.cct |
    Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match 'acq/application/entry' }

$convs = @(); $tasks = @(); $trans = @()
foreach ($f in $cctEntry) {
    $raw = (Get-Content -LiteralPath $f.FullName -Raw) -replace '(?s)<!DOCTYPE.*?>', ''
    try { [xml]$x = $raw }
    catch { Write-Warning ("PARSE HATASI: " + $f.Name + " -> " + $_.Exception.Message); continue }

    $c = $x.CONVERSATION
    $convs += [PSCustomObject]@{
        File = $f.Name; ConvID = $c.ConvID; AppID = $c.ApplicationID
        Controller = $c.ConvController; DefaultTask = $c.DefaultTaskID; Area = $c.FunctionalArea
    }
    foreach ($t in $x.SelectNodes('//TASK')) {
        $tasks += [PSCustomObject]@{
            File = $f.Name; ConvID = $c.ConvID; TaskID = $t.TaskID; Page = $t.PageName
            Controller = $t.PageController; Cancel = $t.CancelButton
            Confirm = $t.ConfirmButton; Tab = $t.TabVisible; TabEnabled = $t.TabEnabled
        }
        foreach ($tr in $t.SelectNodes('.//TRANSITION')) {
            $p = $tr.ParentNode
            $trans += [PSCustomObject]@{
                File = $f.Name; ConvID = $c.ConvID; FromTask = $t.TaskID; FromPage = $t.PageName
                ParentTag = $p.Name; Event = $p.Event; CtrlEvent = $tr.ControllerEvent
                NextConv = $tr.NextConvID; NextTask = $tr.NextTaskID
                Mode = $tr.InvocationMode; EOC = $tr.FlagEOC
            }
        }
    }
}
# Diske de yaz: sonraki bloklar yeni terminalde de calissin
$convs | Export-Csv "$O\cct-convs.csv" -NoTypeInformation -Encoding UTF8
$tasks | Export-Csv "$O\cct-tasks.csv" -NoTypeInformation -Encoding UTF8
$trans | Export-Csv "$O\cct-trans.csv" -NoTypeInformation -Encoding UTF8

"kok kontrol  : W={0} J={1} CCT={2}" -f (Test-Path $W), (Test-Path $J), (Test-Path $CCT)
"CONVERSATION : " + $convs.Count
"TASK         : " + $tasks.Count
"TRANSITION   : " + $trans.Count
````

**Beklenen:** `CONVERSATION 9`, `TASK 19`, `TRANSITION 71`. Sapma varsa
M1'e geçmeden sebebini bul.

`PARSE HATASI` uyarısı çıkarsa dosya adını not et — o CCT atlanır, kalanlar
yine işlenir.

---

## M1 — CCT'den akış grafiği

**Önce M0.** M0'ın parse ettiği veriden tabloları ve Mermaid grafiğini yazar.
Modelin CCT okuyup grafik çizmesine gerek kalmaz.

````powershell
# Kokler + bellekte yoksa CSV'den yukle (M0 baska terminalde calismis olabilir)
$W   = "src\main\webapp\page\acq\application\entry"
$J   = "src\main\java\com\ykb\hmn\acq\application\entry\controllers"
$CCT = "src\main\webapp\cct"
$O   = "docs\entry-akis\_tarama"
if (-not $tasks -or @($tasks).Count -eq 0) {
    $convs = @(Import-Csv "$O\cct-convs.csv"); $tasks = @(Import-Csv "$O\cct-tasks.csv"); $trans = @(Import-Csv "$O\cct-trans.csv")
    "CSV'den yuklendi: conv={0} task={1} trans={2}" -f $convs.Count, $tasks.Count, $trans.Count
}

$fence = '```'
$md = New-Object System.Collections.ArrayList
[void]$md.Add("# entry Akışı — Otomatik Üretilmiş Grafik")
[void]$md.Add("")
[void]$md.Add("Kaynak: entry FunctionalArea'sına sahip .cct dosyaları. Script üretti,")
[void]$md.Add("elle düzenleme. Yorum ve değerlendirme 00b-akis.md dosyasında.")
[void]$md.Add("")

[void]$md.Add("## 1. Conversation'lar")
[void]$md.Add("")
[void]$md.Add("| Dosya | ConvID | DefaultTask | Controller | ApplicationID |")
[void]$md.Add("|---|---|---|---|---|")
foreach ($c in $convs) { [void]$md.Add("| $($c.File) | $($c.ConvID) | $($c.DefaultTask) | $($c.Controller) | $($c.AppID) |") }

[void]$md.Add("")
[void]$md.Add("## 2. TASK'lar")
[void]$md.Add("")
[void]$md.Add("| ConvID | TaskID | PageName | Cancel | Confirm | Tab | Controller |")
[void]$md.Add("|---|---|---|---|---|---|---|")
foreach ($t in ($tasks | Sort-Object ConvID, TaskID)) { [void]$md.Add("| $($t.ConvID) | $($t.TaskID) | $($t.Page) | $($t.Cancel) | $($t.Confirm) | $($t.Tab) | $($t.Controller) |") }

[void]$md.Add("")
[void]$md.Add("## 3. Geçişler")
[void]$md.Add("")
[void]$md.Add("| Kaynak TASK | Sayfa | Etiket | Event | ControllerEvent | NextConvID | NextTaskID | Mode | EOC |")
[void]$md.Add("|---|---|---|---|---|---|---|---|---|")
foreach ($r in $trans) { [void]$md.Add("| $($r.FromTask) | $($r.FromPage) | $($r.ParentTag) | $($r.Event) | $($r.CtrlEvent) | $($r.NextConv) | $($r.NextTask) | $($r.Mode) | $($r.EOC) |") }

# --- Mermaid ---
$convDefault = @{}
foreach ($c in $convs) { if ($c.ConvID) { $convDefault[$c.ConvID] = $c.DefaultTask } }
function Norm($s) { if (-not $s) { return 'X' } ; return ($s -replace '[^A-Za-z0-9_]', '_') }

[void]$md.Add("")
[void]$md.Add("## 4. Akış Grafiği")
[void]$md.Add("")
[void]$md.Add($fence + "mermaid")
[void]$md.Add("flowchart TD")
foreach ($t in ($tasks | Sort-Object TaskID -Unique)) {
    [void]$md.Add("  " + (Norm $t.TaskID) + "[""" + $t.Page + "<br/>" + $t.TaskID + """]")
}
$seen = @{}
foreach ($r in $trans) {
    $from = Norm $r.FromTask
    $toTask = $r.NextTask
    if (-not $toTask -and $r.NextConv) { $toTask = $convDefault[$r.NextConv] }
    if (-not $toTask) {
        $to = $from + "_SON"
        if (-not $seen.ContainsKey($to)) { [void]$md.Add("  $to((son))"); $seen[$to] = $true }
    } else { $to = Norm $toTask }
    $lbl = $r.Event; if (-not $lbl) { $lbl = $r.CtrlEvent }
    $edge = "  $from -->|$lbl| $to"
    if (-not $seen.ContainsKey($edge)) { [void]$md.Add($edge); $seen[$edge] = $true }
}
[void]$md.Add($fence)

Set-Content "docs\entry-akis\00b-akis-otomatik.md" -Value ($md -join "`r`n") -Encoding UTF8
"00b-akis-otomatik.md : " + $md.Count + " satir"
````

`$convs` boş dönerse M0'ı çalıştırmamışsındır.

---

## M2 — Olay modeli tutarlılığı

> **Önemli:** `ControllerEvent` bir handler metodu **değildir**. Geçişin sonuç
> token'ıdır; sayfa controller'ı çalışma zamanında
> `eventData.setControllerEvent(TOKEN)` ile üretir, framework bu token'a bakıp
> hangi `TRANSITION`'ın işleyeceğine karar verir. Token sabit olarak tanımlı
> olabilir (`STAY_ON_PAGE`, `PricingConstants.STAY_ON_PAGE`).

Üç tutarlılık kontrolü yapar. Negatif çıkan her kaydı **repo genelinde** tekrar
arar — entry conversation'ları akış sınırını aştığı için `$J` ile sınırlı arama
yanlış alarm üretiyordu.

| Bölüm | Kontrol | Etiketler |
|---|---|---|
| A | CCT'deki `ControllerEvent` token'ı nerede üretiliyor | `LOKAL` / `DIS PAKET` / **`SADECE YORUM`** / **`ULASILAMAZ`** → ulaşılamayan geçiş |
| B | Kodda üretilen token'ı hangi CCT bekliyor | `ENTRY CCT` / `DIS CCT` / **`OLU SONUC`** → kullanıcı takılır / **`YORUMDA`** → yoruma alınmış yönlendirme / `DEGISKEN` → elle bak |
| C | CCT `Event`'inin handler'ı nerede | `PG` / `CON` / `DIS PAKET` / **`YOK`** |

`<< BULGU` işaretli satırlar kapsam artefaktı elenmiş, gerçek bulgulardır.

> **Overload ve değişken çözümleme B bölümüne katıldı.** Ayrı bir M2-B2 bloğu
> yok; `setControllerEvent(eventData, "TOKEN")` formu ve sabit yerine değişken
> geçirilen çağrılar burada çözülüyor.
>
> **Yorum farkındalığı şart.** İlk sürüm yoruma alınmış `setControllerEvent`
> çağrılarını çalışan kod sandı ve `PG_ApplicationPricing`'deki tamamen
> devre dışı bırakılmış ürün-tipi yönlendirmesini "ölü sonuç" olarak raporladı.
> Blok artık `//`, `/* */` ve `*` satırlarını ayırıyor; yorumdaki kod ayrı
> etiketle raporlanıyor — yanlış alarm değil, farklı türde bir bulgu.

Tüm java ağacını bir kez belleğe alır, sonra negatifleri orada arar — dosya
başına tekrar okuma yok.

````powershell
$J   = "src\main\java\com\ykb\hmn\acq\application\entry\controllers"
$SRC = "src\main\java"
$CCT = "src\main\webapp\cct"
$O   = "docs\entry-akis\_tarama"
if (-not $trans -or @($trans).Count -eq 0) { $trans = @(Import-Csv "$O\cct-trans.csv") }
if (-not $convs -or @($convs).Count -eq 0) { $convs = @(Import-Csv "$O\cct-convs.csv") }

$localJava = @(Get-ChildItem $J -File -Filter *.java)
$allJava   = @(Get-ChildItem $SRC -Recurse -File -Filter *.java)
$allCct    = @(Get-ChildItem $CCT -Recurse -File -Filter *.cct)

# Bir java dosyasinin AKTIF (yorum olmayan) satirlarini dondurur.
# Yoruma alinmis kod, calisan kod sanilirsa yanlis bulgu uretir.
function Get-Aktif($path) {
    $res = New-Object System.Collections.ArrayList
    $blok = $false
    $no = 0
    foreach ($l in (Get-Content -LiteralPath $path)) {
        $no++
        $t = $l.Trim()
        if ($blok) { if ($t -match '\*/') { $blok = $false }; continue }
        if ($t -match '^/\*') { if ($t -notmatch '\*/') { $blok = $true }; continue }
        if ($t.StartsWith('//') -or $t.StartsWith('*')) { continue }
        [void]$res.Add([PSCustomObject]@{ No = $no; Text = $l })
    }
    return $res
}
"tarama kapsami: local={0} java  repo={1} java  cct={2}" -f $localJava.Count, $allJava.Count, $allCct.Count

$idx = @{}
foreach ($f in $allJava) { $idx[$f.FullName] = (Get-Content -LiteralPath $f.FullName -Raw) }
$byName = @{}
foreach ($f in $allJava) { $byName[$f.BaseName] = $f.FullName }

function Find-Repo($token) {
    $rx = [regex]('\b' + [regex]::Escape($token) + '\b')
    foreach ($k in $idx.Keys) { if ($rx.IsMatch($idx[$k])) { return $k } }
    return $null
}

$rows = New-Object System.Collections.ArrayList
$tokens = @($trans | ForEach-Object { [string]$_.CtrlEvent } | Where-Object { $_ } | Sort-Object -Unique)

# --- A ---
[void]$rows.Add("=== A. ControllerEvent token'i nerede uretiliyor ===")
$sA = @{ L = 0; D = 0; Y = 0 }
$sA['Y2'] = 0
foreach ($t in $tokens) {
    $rx = [regex]('\b' + [regex]::Escape($t) + '\b')
    $aktif = $null; $yorumda = $false
    foreach ($f in $localJava) {
        foreach ($ln in (Get-Aktif $f.FullName)) {
            if ($rx.IsMatch($ln.Text)) { $aktif = $f.Name + ':' + $ln.No; break }
        }
        if ($aktif) { break }
        if (-not $yorumda) { $h = @(Select-String -LiteralPath $f.FullName -Pattern $rx -ErrorAction SilentlyContinue); if ($h.Count -gt 0) { $yorumda = $true } }
    }
    if ($aktif)  { $sA.L++;  [void]$rows.Add('LOKAL      '.PadRight(14) + $t.PadRight(34) + $aktif); continue }
    if ($yorumda) { $sA['Y2']++; [void]$rows.Add('SADECE YORUM'.PadRight(14) + $t + '   << BULGU (yoruma alinmis)'); continue }
    $d = Find-Repo $t
    if ($d) { $sA.D++; [void]$rows.Add('DIS PAKET  '.PadRight(14) + $t.PadRight(34) + (Split-Path $d -Leaf)) }
    else    { $sA.Y++; [void]$rows.Add('ULASILAMAZ '.PadRight(14) + $t + '   << BULGU') }
}

# --- B ---
[void]$rows.Add("")
[void]$rows.Add("=== B. kodda uretilen token hangi CCT bekliyor ===")
# Cagri formu iki turlu: setControllerEvent("TOKEN") ve
# setControllerEvent(eventData, "TOKEN"). Arguman listesindeki SON token alinir;
# sabit yerine degisken gecilmisse ayni dosyadaki atamasindan cozulur.
$rxCall = [regex]'setControllerEvent\s*\(([^;]*)\)'
$rxTok  = [regex]'([A-Z][A-Z0-9_]{2,})'
$sB = @{ E = 0; D = 0; Y = 0; V = 0 }
$sB['C'] = 0
foreach ($f in $localJava) {
    $aktifNo = @{}
    foreach ($al in (Get-Aktif $f.FullName)) { $aktifNo[$al.No] = $true }
    $ls = @(Get-Content -LiteralPath $f.FullName)
    for ($i = 0; $i -lt $ls.Count; $i++) {
        $m = $rxCall.Match($ls[$i])
        if (-not $m.Success) { continue }
        $argList = $m.Groups[1].Value
        $loc = $f.Name + ':' + ($i + 1)
        $toks = @($rxTok.Matches($argList) | ForEach-Object { $_.Groups[1].Value })
        if ($toks.Count -eq 0) {
            $v = ''
            $lastId = [regex]::Match($argList, '([A-Za-z_]\w*)\s*$')
            if ($lastId.Success) {
                $vn = $lastId.Groups[1].Value
                $asg = @($ls | Select-String -Pattern ('\b' + [regex]::Escape($vn) + '\s*=\s*[^;]*?([A-Z][A-Z0-9_]{2,})'))
                if ($asg.Count -gt 0) { $v = [regex]::Match($asg[0].Line, '([A-Z][A-Z0-9_]{2,})').Groups[1].Value }
            }
            if ($v) { $toks = @($v) }
            else { $sB.V++; [void]$rows.Add('DEGISKEN  '.PadRight(12) + $argList.Trim().PadRight(34) + $loc); continue }
        }
        $arg = $toks[-1]
        if (-not $aktifNo.ContainsKey($i + 1)) {
            $sB['C']++
            [void]$rows.Add('YORUMDA   '.PadRight(12) + $arg.PadRight(34) + $loc + '   << BULGU (yoruma alinmis yonlendirme)')
            continue
        }
        if ($tokens -contains $arg) { $sB.E++; [void]$rows.Add('ENTRY CCT '.PadRight(12) + $arg.PadRight(34) + $loc); continue }
        $inOther = $false
        foreach ($c in $allCct) { if ((Get-Content -LiteralPath $c.FullName -Raw) -match ('ControllerEvent="' + [regex]::Escape($arg) + '"')) { $inOther = $true; break } }
        if ($inOther) { $sB.D++; [void]$rows.Add('DIS CCT   '.PadRight(12) + $arg.PadRight(34) + $loc) }
        else          { $sB.Y++; [void]$rows.Add('OLU SONUC '.PadRight(12) + $arg.PadRight(34) + $loc + '   << BULGU') }
    }
}

# --- C ---
[void]$rows.Add("")
[void]$rows.Add("=== C. Event -> handler ===")
$convClass = @{}
foreach ($c in @($convs)) { $ctrl = [string]$c.Controller; if ($ctrl) { $convClass[[string]$c.ConvID] = @($ctrl -split '\.')[-1] } }
$sC = @{ P = 0; C = 0; D = 0; Y = 0 }
foreach ($e in @($trans | Select-Object FromPage, Event, ConvID -Unique)) {
    $ev = [string]$e.Event; $cls = [string]$e.FromPage
    if ([string]::IsNullOrWhiteSpace($ev) -or [string]::IsNullOrWhiteSpace($cls)) { continue }
    $rx = [regex]('\b' + [regex]::Escape($ev) + '\s*\(')
    $done = $false
    foreach ($cand in @(($cls + '.java'), ($cls + 'Super.java'))) {
        $p = Join-Path $J $cand
        if ((Test-Path $p) -and $rx.IsMatch((Get-Content -LiteralPath $p -Raw))) { $sC.P++; [void]$rows.Add('PG   '.PadRight(7) + $cls.PadRight(38) + $ev.PadRight(26) + $cand); $done = $true; break }
    }
    if ($done) { continue }
    $cc = $convClass[[string]$e.ConvID]
    if ($cc) {
        foreach ($cand in @($cc, ($cc + 'Super'))) {
            if ($byName.ContainsKey($cand) -and $rx.IsMatch($idx[$byName[$cand]])) { $sC.C++; [void]$rows.Add('CON  '.PadRight(7) + $cls.PadRight(38) + $ev.PadRight(26) + $cand + '.java'); $done = $true; break }
        }
    }
    if ($done) { continue }
    foreach ($cand in @($cls, ($cls + 'Super'))) {
        if ($byName.ContainsKey($cand) -and $rx.IsMatch($idx[$byName[$cand]])) { $sC.D++; [void]$rows.Add('DIS PAKET'.PadRight(7) + $cls.PadRight(38) + $ev.PadRight(26) + (Split-Path $byName[$cand] -Leaf)); $done = $true; break }
    }
    if (-not $done) { $sC.Y++; [void]$rows.Add('YOK  '.PadRight(7) + $cls.PadRight(38) + $ev + '   << BULGU') }
}

Set-Content "$O\21-event-handler.txt" -Value ($rows -join "`r`n") -Encoding UTF8
"A : lokal={0} dis-paket={1} SADECE-YORUM={2} ULASILAMAZ={3}" -f $sA.L, $sA.D, $sA['Y2'], $sA.Y
"B : entry-cct={0} dis-cct={1} OLU-SONUC={2} YORUMDA={3} degisken={4}" -f $sB.E, $sB.D, $sB.Y, $sB['C'], $sB.V
"C : pg={0} con={1} dis-paket={2} YOK={3}" -f $sC.P, $sC.C, $sC.D, $sC.Y
"21-event-handler : " + $rows.Count + " satir"
````

### Bulguları çıkarma

````powershell
$O = "docs\entry-akis\_tarama"
Select-String -LiteralPath "$O\21-event-handler.txt" -SimpleMatch "<< BULGU" | ForEach-Object { "  " + $_.Line }
Select-String -LiteralPath "$O\21-event-handler.txt" -SimpleMatch "DEGISKEN"  | ForEach-Object { "  " + $_.Line }
````

> `$O` tanımlı değilse `Select-String` yolu `D:\21-event-handler.txt` olarak
> çözer ve "cannot be read" hatası verir. Blokların başındaki kök tanımlarını
> atlama.

---

## M3 — Dil durumu

**Önce M0.**

Üç şeye dikkat eder:
- **UTF-8 okuma.** Lang json'ları UTF-8; Windows PowerShell varsayılanı ANSI
  olduğu için `-Encoding UTF8` şart, yoksa `Hayır` → `HayÄ±r` olur.
- **Çeviri eksikliği.** EN dosyası TR'nin yarısından azsa uyarı basar
  (örn. `PG_TerminalInfo`: tr 128 / en 4 — pratikte Türkçe-only).
- **Dinamik key ayrımı.** `lblOKCFirm7` gibi sonu rakamlı key'ler kodda
  `"lblOKCFirm" + i` şeklinde üretiliyor olabilir; düz arama bulamaz ve ölü
  sanar. Gövdesi kodda geçiyorsa `DINAMIK?` olarak ayrı listelenir, ölü
  sayılmaz.

Ekran başına tr/en key farkı ve html+js'te hiç geçmeyen ölü key'ler.

````powershell
$rxKey = [regex]'"([^"]+)"\s*:'
$out = New-Object System.Collections.ArrayList
foreach ($d in (Get-ChildItem $W -Directory | Sort-Object Name)) {
    $n = $d.Name
    $kt = @(); $ke = @()
    $ptr = Join-Path $d.FullName ($n + "_lang_tr.json")
    $pen = Join-Path $d.FullName ($n + "_lang_en.json")
    # lang json'lari UTF-8; -Encoding UTF8 sart, yoksa Turkce karakterler bozulur
    if (Test-Path $ptr) { $t = Get-Content -LiteralPath $ptr -Raw -Encoding UTF8; if ($t) { $kt = @($rxKey.Matches($t) | ForEach-Object { $_.Groups[1].Value }) } }
    if (Test-Path $pen) { $t = Get-Content -LiteralPath $pen -Raw -Encoding UTF8; if ($t) { $ke = @($rxKey.Matches($t) | ForEach-Object { $_.Groups[1].Value }) } }

    $src = ''
    foreach ($ext in 'html', 'js') {
        $p = Join-Path $d.FullName ($n + "." + $ext)
        if (Test-Path $p) { $src += (Get-Content -LiteralPath $p -Raw -Encoding UTF8) }
    }
    $trOnly = @($kt | Where-Object { $ke -notcontains $_ })
    $enOnly = @($ke | Where-Object { $kt -notcontains $_ })

    # Kullanilmayan key'leri ikiye ayir: gercekten olu vs dinamik uretilmis olabilir
    # (lblOKCFirm7 gibi sonu rakamli key'ler dongude "lblOKCFirm" + i seklinde
    #  uretiliyor olabilir; duz string aramasi bunlari olu sanar)
    $olu = New-Object System.Collections.ArrayList
    $dyn = New-Object System.Collections.ArrayList
    foreach ($key in $kt) {
        if ($src -match [regex]::Escape($key)) { continue }
        $stem = $key -replace '\d+$', ''
        if ($stem -ne $key -and $stem.Length -ge 3 -and $src -match [regex]::Escape($stem)) { [void]$dyn.Add($key) }
        else { [void]$olu.Add($key) }
    }

    [void]$out.Add("### $n")
    [void]$out.Add("  tr key: $($kt.Count)   en key: $($ke.Count)")
    if ($ke.Count -gt 0 -and $kt.Count -gt 0 -and ($ke.Count * 2) -lt $kt.Count) {
        [void]$out.Add("  UYARI: EN dosyasi TR'nin yarisindan az - ceviri eksik")
    }
    if ($trOnly.Count) { [void]$out.Add("  TR'DE VAR EN'DE YOK : " + ($trOnly -join ', ')) }
    if ($enOnly.Count) { [void]$out.Add("  EN'DE VAR TR'DE YOK : " + ($enOnly -join ', ')) }
    if ($olu.Count)    { [void]$out.Add("  KULLANILMAYAN       : " + ($olu -join ', ')) }
    if ($dyn.Count)    { [void]$out.Add("  DINAMIK? (govdesi kodda geciyor, tam adi gecmiyor) : " + ($dyn -join ', ')) }
    if (-not $trOnly.Count -and -not $enOnly.Count -and -not $olu.Count -and -not $dyn.Count) { [void]$out.Add("  temiz") }
}
Set-Content "$O\22-lang-durumu.txt" -Value ($out -join "`r`n") -Encoding UTF8 -Encoding UTF8
"22-lang-durumu : " + $out.Count + " satir"
````

---

## M4 — Ekran kartı ön-doldurucu

**Önce M0.** Uzun blok — `.ps1` dosyasına kaydedip `Ctrl+A` → `F8` en rahatı.

Her ekran için tabloları dolu, yorum bölümleri boş bir kart üretir. Model
yalnızca `<!-- MODEL -->` işaretli yerleri doldurur.

Servis desenleri Adım 7'de repodan türetildi ve buraya sabitlendi. Harmoni'de
servis erişimi **dört mekanizmayla** oluyor:

```
RemoteUtility.getServiceCloudVersion(XController.class)   Cloud/REST
RemoteUtility.getXController()                            kısayol erişimci
JABSSupport.getJABS().getRemote(X.class)                  JABS remote (EJB benzeri)
getService(X.class)                                       generic sarmalayıcı
```

Ekranlar bunları lazy getter içinde sarmalıyor, bazen alan cache'liyor. Bu
yüzden kart iki ayrı tablo üretir: **bağımlı olunan servisler** (edinme
noktaları) ve **çağrılan metotlar** (kullanım noktaları).

````powershell
# Kokler + bellekte yoksa CSV'den yukle (M0 baska terminalde calismis olabilir)
$W   = "src\main\webapp\page\acq\application\entry"
$J   = "src\main\java\com\ykb\hmn\acq\application\entry\controllers"
$CCT = "src\main\webapp\cct"
$O   = "docs\entry-akis\_tarama"
if (-not $tasks -or @($tasks).Count -eq 0) {
    $convs = @(Import-Csv "$O\cct-convs.csv"); $tasks = @(Import-Csv "$O\cct-tasks.csv"); $trans = @(Import-Csv "$O\cct-trans.csv")
    "CSV'den yuklendi: conv={0} task={1} trans={2}" -f $convs.Count, $tasks.Count, $trans.Count
}

# Servis EDINME noktalari (dort mekanizma)
$rxAcq = @(
    @{ K = 'Cloud';   R = [regex]'RemoteUtility\.getServiceCloudVersion\s*\(\s*(\w+)\.class' },
    @{ K = 'Kisayol'; R = [regex]'RemoteUtility\.get(?!ServiceCloudVersion)(\w+)\s*\(' },
    @{ K = 'JABS';    R = [regex]'getRemote\s*\(\s*(\w+)\.class' },
    @{ K = 'Generic'; R = [regex]'\bgetService\s*\(\s*(\w+)\.class' }
)
# Servis KULLANIM noktalari
$rxUse = [regex]'\b([a-z]\w*(?:Controller|Service))\s*\.\s*([a-z]\w*)\s*\('
# catch bloklari (dayaniklilik ekseni)
$rxCatch = [regex]'catch\s*\(\s*([\w\.]+)\s+(\w+)\s*\)'
$valRx = [regex]'(?i)validate|isValid|required|mandatory|isEmpty|isBlank|\.length|matches\(|showCustomMessageBox'

# Bir java/js dosyasindaki YORUM satirlarinin numaralarini dondurur.
# Yoruma alinmis kod, calisan kod gibi raporlanirsa yanlis bulgu uretir.
function Get-YorumSatirlari($path) {
    $set = @{}
    $blok = $false
    $no = 0
    foreach ($l in (Get-Content -LiteralPath $path)) {
        $no++
        $t = $l.Trim()
        if ($blok) { $set[$no] = $true; if ($t -match '\*/') { $blok = $false }; continue }
        if ($t -match '^/\*') { $set[$no] = $true; if ($t -notmatch '\*/') { $blok = $true }; continue }
        if ($t.StartsWith('//') -or $t.StartsWith('*')) { $set[$no] = $true }
    }
    return $set
}
function Durum($set, $no) { if ($set.ContainsKey($no)) { return 'YORUM' } else { return 'aktif' } }

# M3'un urettigi dil durumunu ekran bazinda oku (karta gomulecek)
$langMap = @{}
$langFile = Join-Path $O "22-lang-durumu.txt"
if (Test-Path $langFile) {
    $cur = $null
    foreach ($l in (Get-Content -LiteralPath $langFile -Encoding UTF8)) {
        if ($l -match '^###\s+(\S+)') { $cur = $Matches[1]; $langMap[$cur] = New-Object System.Collections.ArrayList; continue }
        if ($cur) { [void]$langMap[$cur].Add($l) }
    }
}

foreach ($d in (Get-ChildItem $W -Directory | Sort-Object Name)) {
    $n = $d.Name
    $k = New-Object System.Collections.ArrayList
    [void]$k.Add("# $n")
    [void]$k.Add("")
    [void]$k.Add("> Tablolar script tarafından dolduruldu. ``<!-- MODEL -->`` işaretli")
    [void]$k.Add("> bölümleri Copilot dolduracak. Tablolara dokunma.")
    [void]$k.Add("")

    # --- dosya ayak izi ---
    [void]$k.Add("## Dosya Ayak İzi")
    [void]$k.Add("")
    [void]$k.Add("| Dosya | Satır |")
    [void]$k.Add("|---|---|")
    Get-ChildItem $d.FullName -File | Sort-Object Name | ForEach-Object {
        [void]$k.Add("| $($_.Name) | " + (Get-Content -LiteralPath $_.FullName | Measure-Object -Line).Lines + " |")
    }
    foreach ($cand in @("$n.java", "${n}Super.java")) {
        $p = Join-Path $J $cand
        if (Test-Path $p) { [void]$k.Add("| $cand | " + (Get-Content -LiteralPath $p | Measure-Object -Line).Lines + " |") }
    }

    # --- CCT kunyesi ---
    [void]$k.Add("")
    [void]$k.Add("## CCT Künyesi")
    [void]$k.Add("")
    $myTasks = @($tasks | Where-Object { $_.Page -eq $n })
    if ($myTasks.Count -eq 0) {
        [void]$k.Add("**CCT'de TASK'ı YOK** — koddan açılıyor. Açılış noktası:")
        [void]$k.Add("")
        $callers = Get-ChildItem $W, $J -Recurse -File -Include *.js, *.html, *.java |
            Select-String -SimpleMatch $n | Where-Object { $_.Path -notlike "*$n*" }
        foreach ($c in ($callers | Select-Object -First 15)) {
            [void]$k.Add("- ``$(Split-Path $c.Path -Leaf):$($c.LineNumber)`` — $($c.Line.Trim())")
        }
        if (-not $callers) { [void]$k.Add("- AÇILIŞ NOKTASI BULUNAMADI") }
    } else {
        [void]$k.Add("| ConvID | TaskID | Cancel | Confirm | Tab |")
        [void]$k.Add("|---|---|---|---|---|")
        foreach ($t in $myTasks) { [void]$k.Add("| $($t.ConvID) | $($t.TaskID) | $($t.Cancel) | $($t.Confirm) | $($t.Tab) |") }
    }

    # --- olaylar ---
    [void]$k.Add("")
    [void]$k.Add("## Olaylar")
    [void]$k.Add("")
    [void]$k.Add("| Event | ControllerEvent | NextConvID | NextTaskID | Handler |")
    [void]$k.Add("|---|---|---|---|---|")
    foreach ($r in @($trans | Where-Object { $_.FromPage -eq $n })) {
        $hit = 'BULUNAMADI'
        foreach ($cand in @("$n.java", "${n}Super.java")) {
            $p = Join-Path $J $cand
            if ((Test-Path $p) -and $r.CtrlEvent) {
                $m = Select-String -LiteralPath $p -Pattern ("\b" + [regex]::Escape($r.CtrlEvent) + "\s*\(")
                if ($m) { $hit = "$cand" + ":" + $m[0].LineNumber; break }
            }
        }
        [void]$k.Add("| $($r.Event) | $($r.CtrlEvent) | $($r.NextConv) | $($r.NextTask) | $hit |")
        # not: handler yorumdaysa "Durum" sutunu yerine dosya:satirdan bakilir
    }

    # --- bagimli olunan servisler (edinme) ---
    [void]$k.Add("")
    [void]$k.Add("## Bağımlı Olunan Servisler")
    [void]$k.Add("")
    [void]$k.Add("| Servis | Mekanizma | Durum | Dosya:satır |")
    [void]$k.Add("|---|---|---|---|")
    foreach ($cand in @("$n.java", "${n}Super.java")) {
        $p = Join-Path $J $cand
        if (-not (Test-Path $p)) { continue }
        $yor = Get-YorumSatirlari $p
        $ln = 0
        foreach ($line in (Get-Content -LiteralPath $p)) {
            $ln++
            foreach ($a in $rxAcq) {
                foreach ($m in $a.R.Matches($line)) {
                    [void]$k.Add("| $($m.Groups[1].Value) | $($a.K) | $(Durum $yor $ln) | $cand`:$ln |")
                }
            }
        }
    }

    # --- cagrilan metotlar (kullanim) ---
    [void]$k.Add("")
    [void]$k.Add("## Çağrılan Servis Metotları")
    [void]$k.Add("")
    [void]$k.Add("| Nesne | Metot | Durum | Dosya:satır |")
    [void]$k.Add("|---|---|---|---|")
    foreach ($cand in @("$n.java", "${n}Super.java")) {
        $p = Join-Path $J $cand
        if (-not (Test-Path $p)) { continue }
        $yor = Get-YorumSatirlari $p
        $ln = 0
        foreach ($line in (Get-Content -LiteralPath $p)) {
            $ln++
            foreach ($m in $rxUse.Matches($line)) {
                [void]$k.Add("| $($m.Groups[1].Value) | $($m.Groups[2].Value) | $(Durum $yor $ln) | $cand`:$ln |")
            }
        }
    }

    # --- catch bloklari ---
    [void]$k.Add("")
    [void]$k.Add("## Catch Blokları")
    [void]$k.Add("")
    [void]$k.Add("| Exception | Değişken | Dosya:satır | Sonraki 2 satır |")
    [void]$k.Add("|---|---|---|---|")
    foreach ($cand in @("$n.java", "${n}Super.java")) {
        $p = Join-Path $J $cand
        if (-not (Test-Path $p)) { continue }
        $ls = @(Get-Content -LiteralPath $p)
        for ($i = 0; $i -lt $ls.Count; $i++) {
            foreach ($m in $rxCatch.Matches($ls[$i])) {
                $nx = ''
                if ($i + 1 -lt $ls.Count) { $nx += $ls[$i + 1].Trim() + ' ' }
                if ($i + 2 -lt $ls.Count) { $nx += $ls[$i + 2].Trim() }
                $nx = $nx -replace '\|', '\\|'
                if ($nx.Length -gt 90) { $nx = $nx.Substring(0, 90) }
                [void]$k.Add("| $($m.Groups[1].Value) | $($m.Groups[2].Value) | $cand`:$($i+1) | $nx |")
            }
        }
    }

    # --- DTO ---
    [void]$k.Add("")
    [void]$k.Add("## Kullanılan DTO / Model import'ları")
    [void]$k.Add("")
    foreach ($cand in @("$n.java", "${n}Super.java")) {
        $p = Join-Path $J $cand
        if (-not (Test-Path $p)) { continue }
        Select-String -LiteralPath $p -Pattern '^\s*import\s+(com\.ykb\S+)' | ForEach-Object {
            [void]$k.Add("- ``" + $_.Matches[0].Groups[1].Value.TrimEnd(';') + "``  ($cand)")
        }
    }

    # --- validasyon adaylari ---
    [void]$k.Add("")
    [void]$k.Add("## Validasyon Aday Satırları")
    [void]$k.Add("")
    foreach ($p in @((Join-Path $d.FullName "$n.js"), (Join-Path $J "$n.java"))) {
        if (-not (Test-Path $p)) { continue }
        $f = Split-Path $p -Leaf
        $yor = Get-YorumSatirlari $p
        Select-String -LiteralPath $p -Pattern $valRx | Select-Object -First 40 | ForEach-Object {
            [void]$k.Add("- [" + (Durum $yor $_.LineNumber) + "] ``$f`:$($_.LineNumber)`` — $($_.Line.Trim())")
        }
    }

    # --- _auth.properties (rolu dogrulanmadi) ---
    [void]$k.Add("")
    [void]$k.Add("## _auth.properties İçeriği")
    [void]$k.Add("")
    [void]$k.Add("> Dosyanın rolü DOĞRULANMADI. Adı yetki dosyası izlenimi veriyor ama")
    [void]$k.Add("> dolu olan tek örnek validasyon hata mesajları içeriyor. İçeriğe bak,")
    [void]$k.Add("> isme göre yorum yapma.")
    [void]$k.Add("")
    $pa = Join-Path $d.FullName ($n + "_auth.properties")
    $bt = [string][char]96
    if (Test-Path $pa) {
        $ca = @(Get-Content -LiteralPath $pa)
        if ($ca.Count -eq 0) { [void]$k.Add($bt + $n + "_auth.properties" + $bt + " mevcut ama **BOŞ**.") }
        else { $ca | ForEach-Object { [void]$k.Add("- " + $bt + $_ + $bt) } }
    } else { [void]$k.Add($bt + $n + "_auth.properties" + $bt + " **YOK**.") }

    # --- include ---
    [void]$k.Add("")
    [void]$k.Add("## Dahil Edilen Sayfalar")
    [void]$k.Add("")
    $inc = Get-ChildItem $d.FullName, $J -File -Include "$n.html", "$n.java", "${n}Super.java" -ErrorAction SilentlyContinue |
        Select-String -Pattern 'IncludedPage|data-page-name|PG_Include[A-Za-z0-9_]*'
    if ($inc) { $inc | ForEach-Object { [void]$k.Add("- ``$(Split-Path $_.Path -Leaf):$($_.LineNumber)`` — $($_.Line.Trim())") } }
    else { [void]$k.Add("yok") }

    # --- dil (22-lang-durumu.txt'den ilgili bolum) ---
    [void]$k.Add("")
    [void]$k.Add("## Dil Durumu")
    [void]$k.Add("")
    if ($langMap.ContainsKey($n) -and @($langMap[$n]).Count -gt 0) {
        foreach ($l in $langMap[$n]) { if ($l.Trim()) { [void]$k.Add($l.Trim()) } }
    } else { [void]$k.Add("22-lang-durumu.txt'de bu ekran için kayıt yok.") }

    # --- modelin dolduracagi bolumler ---
    foreach ($h in @(
        'Künye ve Rol', 'Akış Sözleşmesi (OKUR / YAZAR)', 'Yaşam Döngüsü',
        'İç Akışlar (Mermaid sequence)', 'Validasyon Değerlendirmesi',
        'Yetki Değerlendirmesi', 'Dialog ve Geri Bildirim',
        'Ölü ve Şüpheli Kod', 'Açık Sorular')) {
        [void]$k.Add("")
        [void]$k.Add("## $h")
        [void]$k.Add("")
        [void]$k.Add("<!-- MODEL -->")
    }

    Set-Content ("docs\entry-akis\ekranlar\$n.hazir.md") -Value ($k -join "`r`n") -Encoding UTF8
}
"Kart uretildi : " + @(Get-ChildItem 'docs\entry-akis\ekranlar' -Filter *.hazir.md).Count
````

---

## M5 — Açık Soru Kapatıcı

Adım 8'in ürettiği açık soruların çoğu deterministik: kod bağlamı, taranmamış
bir CCT, ya da daha geniş bir arama gerektiriyor. Bu blok dördünü de kapatır ve
`_tarama/23-acik-sorular.txt` yazar. Kalan sorular Adım 12'de ekran kartları
okunurken cevaplanır.

| Bölüm | Kapattığı soru |
|---|---|
| A | `setControllerEvent` çağrılarının çevresindeki if/else — hangi iş kuralı hangi token'ı seçiyor |
| B | Entry dışındaki hedef conversation'ların TASK/TRANSITION tanımları |
| C | Açılış noktası bulunamayan ekranların tüm repoda (xml, jsp, properties dahil) aranması |
| D | Conversation kapanışı: `FlagEOC` geçişleri + `onFooter*` / `After_Approve` / `close` arayışı |

````powershell
$J   = "src\main\java\com\ykb\hmn\acq\application\entry\controllers"
$CCT = "src\main\webapp\cct"
$SRC = "src\main"
$O   = "docs\entry-akis\_tarama"
if (-not $trans -or @($trans).Count -eq 0) { $trans = @(Import-Csv "$O\cct-trans.csv") }
if (-not $convs -or @($convs).Count -eq 0) { $convs = @(Import-Csv "$O\cct-convs.csv") }

$out = New-Object System.Collections.ArrayList

# --- A. setControllerEvent baglami ---
[void]$out.Add("===== A. setControllerEvent cagrilarinin baglami (+/- 12 satir) =====")
foreach ($f in @(Get-ChildItem $J -File -Filter *.java)) {
    $ls = @(Get-Content -LiteralPath $f.FullName -Encoding UTF8)
    for ($i = 0; $i -lt $ls.Count; $i++) {
        if ($ls[$i] -notmatch 'setControllerEvent\s*\(') { continue }
        $a = [Math]::Max(0, $i - 12); $b = [Math]::Min($ls.Count - 1, $i + 3)
        [void]$out.Add("")
        [void]$out.Add("--- " + $f.Name + ":" + ($i + 1) + " ---")
        for ($ix = $a; $ix -le $b; $ix++) {
            $mark = "  "; if ($ix -eq $i) { $mark = ">>" }
            [void]$out.Add($mark + " " + ($ix + 1).ToString().PadLeft(5) + "  " + $ls[$ix].TrimEnd())
        }
    }
}

# --- B. entry disindaki hedef conversation'lar ---
[void]$out.Add(""); [void]$out.Add("===== B. entry disindaki hedef conversation'lar =====")
$entryConv = @($convs | ForEach-Object { [string]$_.ConvID })
$targets = @($trans | ForEach-Object { [string]$_.NextConv } |
    Where-Object { $_ -and ($entryConv -notcontains $_) } | Sort-Object -Unique)
[void]$out.Add("hedef sayisi: " + $targets.Count)
foreach ($t in $targets) {
    [void]$out.Add(""); [void]$out.Add("--- " + $t + " ---")
    $cf = @(Get-ChildItem $CCT -Recurse -File -Filter ($t + ".cct"))
    if ($cf.Count -eq 0) { [void]$out.Add("  CCT DOSYASI BULUNAMADI"); continue }
    Get-Content -LiteralPath $cf[0].FullName | Where-Object {
        $_ -match '(PageName|PageController|TaskID|NextConvID|NextTaskID|Event|ControllerEvent|DefaultTaskID|FunctionalArea)\s*='
    } | ForEach-Object { [void]$out.Add("  " + $_.Trim()) }
}

# --- C. acilis noktasi aramasi ---
[void]$out.Add(""); [void]$out.Add("===== C. acilis noktasi aramasi (tum repo) =====")
$needles = @('con_point','task_merchantpoint','PG_MerchantPoint','PG_AccountWalletPopup',
             'PG_AddNote','PG_LoyaltyProgramRatePopup','PG_TagOperation')
$scanFiles = @(Get-ChildItem $SRC -Recurse -File -Include *.java,*.js,*.html,*.cct,*.xml,*.properties,*.jsp)
foreach ($needle in $needles) {
    [void]$out.Add(""); [void]$out.Add("--- " + $needle + " ---")
    $hits = @($scanFiles | Select-String -SimpleMatch $needle | Select-Object -First 25)
    if ($hits.Count -eq 0) { [void]$out.Add("  HIC GECMIYOR"); continue }
    foreach ($h in $hits) { [void]$out.Add("  " + (Split-Path $h.Path -Leaf) + ":" + $h.LineNumber + "  " + $h.Line.Trim()) }
}

# --- D. kapanis mekanizmasi ---
[void]$out.Add(""); [void]$out.Add("===== D. kapanis mekanizmasi =====")
[void]$out.Add("-- FlagEOC=True olan gecisler --")
foreach ($r in @($trans | Where-Object { [string]$_.EOC -eq 'True' })) {
    [void]$out.Add("  " + ([string]$r.FromPage).PadRight(38) + ([string]$r.Event).PadRight(24) +
                   "-> " + ([string]$r.CtrlEvent).PadRight(26) +
                   "next=" + [string]$r.NextConv + "/" + [string]$r.NextTask)
}
[void]$out.Add("")
[void]$out.Add("-- onFooter / Approve / close arayisi --")
foreach ($h in @(Get-ChildItem $J -File -Filter *.java |
        Select-String -Pattern 'onFooter\w*|After_Approve|closeConversation|endConversation|finishConversation|setEndOfConversation' |
        Select-Object -First 60)) {
    [void]$out.Add("  " + $h.Filename + ":" + $h.LineNumber + "  " + $h.Line.Trim())
}

Set-Content "$O\23-acik-sorular.txt" -Value ($out -join "`r`n") -Encoding UTF8
"23-acik-sorular : " + $out.Count + " satir"
````

Çıktı Adım 9'un girdisine eklenir. Kapanmayan sorular Adım 12'nin ilgili grup
turuna not olarak taşınır.

> **PowerShell tuzağı:** değişken adları büyük/küçük harf duyarsızdır — `$j`
> ile `$J` aynı değişkendir. Bu blokta döngü sayacı önce `$j` idi ve `$J` kök
> yolunu eziyordu; sayaç `$ix` olarak değiştirildi. Kendi bloklarını yazarken
> tek harfli sayaçları köklerle (`$W`, `$J`, `$O`) çakıştırma.

---

## M6 — Girdi kırpma

Frekans listeleri (`06`, `07`, `08`) azalan sırada; ilk ~60 satır dışındaki
kuyruk tek kullanımlık isimlerden ibaret ve modelin bütçesini yiyor.
`08-erisimciler.txt` tek başına 1384 satır. Bu blok kırpılmış kopyalar üretir;
Adım 9 bunları kullanır.

````powershell
$O = "docs\entry-akis\_tarama"
foreach ($n in @('06-cagri-hedefleri', '07-importlar', '08-erisimciler')) {
    $src = Join-Path $O ($n + '.txt')
    if (-not (Test-Path $src)) { "ATLANDI: $n" ; continue }
    $all = @(Get-Content -LiteralPath $src -Encoding UTF8)
    $top = @($all | Select-Object -First 60)
    Set-Content (Join-Path $O ($n + '-top.txt')) -Value ($top -join "`r`n") -Encoding UTF8
    "{0,-22} {1,6} -> {2}" -f $n, $all.Count, $top.Count
}
````

---

## M7 — State sözlüğü

Adım 9a zaman aşımına uğradı: modelden state mekanizmasını *keşfetmesi*
isteniyordu, yani onlarca java dosyasını açması. Oysa mekanizma deterministik
olarak çıkarılabiliyor.

Harmoni state'i **scope** API'si üzerinden tipli taşıyıcı nesnelerde tutuyor:

```java
ApplicationInfo applicationInfo = (ApplicationInfo) cc.getFromTabScope(ApplicationInfo.NAME);
```

Blok üç şey üretir:

| Bölüm | İçerik |
|---|---|
| A | Scope API sayımı — hangi scope türü kaç kez kullanılıyor |
| B | Ekran başına taşıyıcı nesneler ve scope türü |
| C | **Alan bazlı okuma/yazma matrisi** — `LOKAL` / `PAYLASILAN` / `OKUYAN-YOK` / `YAZAN-YOK` sınıflandırmasıyla |
| — | Ayrıca `24b-state-paylasilan.txt`: yalnızca paylaşılan ve anomalili alanlar. Adım 9a bunu okur, 106 satırlık tam matrisi değil |

C bölümü Adım 9a'nın asıl çıktısıydı; artık script üretiyor.

````powershell
$J = "src\main\java\com\ykb\hmn\acq\application\entry\controllers"
$O = "docs\entry-akis\_tarama"
$devJava = @(Get-ChildItem $J -File -Filter *.java | Where-Object { $_.BaseName -notmatch 'Super$' })

function Get-Aktif2($path) {
    $res = New-Object System.Collections.ArrayList
    $blok = $false; $no = 0
    foreach ($l in (Get-Content -LiteralPath $path)) {
        $no++; $t = $l.Trim()
        if ($blok) { if ($t -match '\*/') { $blok = $false }; continue }
        if ($t -match '^/\*') { if ($t -notmatch '\*/') { $blok = $true }; continue }
        if ($t.StartsWith('//') -or $t.StartsWith('*')) { continue }
        [void]$res.Add([PSCustomObject]@{ No = $no; Text = $l })
    }
    return $res
}

$out = New-Object System.Collections.ArrayList

# --- A. scope API sayimi ---
[void]$out.Add("===== A. scope API kullanimi =====")
$rxScope = [regex]'\b(\w*(?:get|put|set|remove)From?\w*Scope|\w*Scope)\s*\('
$sayim = @{}
foreach ($f in $devJava) {
    foreach ($ln in (Get-Aktif2 $f.FullName)) {
        foreach ($m in $rxScope.Matches($ln.Text)) {
            $k = $m.Groups[1].Value
            if (-not $sayim.ContainsKey($k)) { $sayim[$k] = 0 }
            $sayim[$k]++
        }
    }
}
foreach ($k in ($sayim.Keys | Sort-Object { -$sayim[$_] })) {
    [void]$out.Add(("  " + $sayim[$k].ToString().PadLeft(5) + "  " + $k))
}

# --- B. tasiyici TIPLERI (her cast formu) ---
[void]$out.Add(""); [void]$out.Add("===== B. tasiyici nesneler =====")
$rxCast = [regex]'\(\s*([A-Z]\w*)\s*\)\s*\w+\.(\w*Scope\w*)\s*\('
$tipler = @{}
foreach ($f in $devJava) {
    foreach ($ln in (Get-Aktif2 $f.FullName)) {
        foreach ($m in $rxCast.Matches($ln.Text)) {
            $tip = $m.Groups[1].Value
            if (-not $tipler.ContainsKey($tip)) { $tipler[$tip] = New-Object System.Collections.ArrayList }
            if ($tipler[$tip] -notcontains $m.Groups[2].Value) { [void]$tipler[$tip].Add($m.Groups[2].Value) }
        }
    }
}
[void]$out.Add("-- scope'tan alinan tipler --")
foreach ($t in ($tipler.Keys | Sort-Object)) { [void]$out.Add("  " + $t.PadRight(30) + ($tipler[$t] -join ', ')) }

# Her dev sinifta bu tiplerden degisken var mi (atama, parametre, yerel bildirim)
$holders = @{}
foreach ($f in $devJava) {
    $lst = New-Object System.Collections.ArrayList
    $aktif = Get-Aktif2 $f.FullName
    foreach ($tip in $tipler.Keys) {
        $rxDecl = [regex]('\b' + [regex]::Escape($tip) + '\s+(\w+)\s*[=;,\)]')
        foreach ($ln in $aktif) {
            foreach ($m in $rxDecl.Matches($ln.Text)) {
                $v = $m.Groups[1].Value
                if (-not ($lst | Where-Object { $_.Var -eq $v -and $_.Type -eq $tip })) {
                    [void]$lst.Add([PSCustomObject]@{ Var = $v; Type = $tip; No = $ln.No })
                }
            }
        }
    }
    if ($lst.Count -gt 0) {
        $holders[$f.BaseName] = $lst
        [void]$out.Add("--- " + $f.BaseName + " ---")
        foreach ($h in $lst) { [void]$out.Add("  " + $h.Type.PadRight(28) + $h.Var.PadRight(24) + "(satir " + $h.No + ")") }
    }
}
[void]$out.Add("")
[void]$out.Add("tasiyici bulunan ekran: " + $holders.Count + " / " + $devJava.Count)

# --- C. alan bazli okuma/yazma matrisi ---
[void]$out.Add(""); [void]$out.Add("===== C. alan bazli okuma / yazma =====")
$mat = @{}
foreach ($f in $devJava) {
    $aktif = Get-Aktif2 $f.FullName

    # C1: degisken uzerinden erisim
    if ($holders.ContainsKey($f.BaseName)) {
        $varType = @{}
        foreach ($h in $holders[$f.BaseName]) { $varType[$h.Var] = $h.Type }
        foreach ($v in $varType.Keys) {
            $rx = [regex]('\b' + [regex]::Escape($v) + '\.(get|set|is)([A-Z]\w*)\s*\(')
            foreach ($ln in $aktif) {
                foreach ($m in $rx.Matches($ln.Text)) {
                    $key = $varType[$v] + '.' + $m.Groups[2].Value
                    if (-not $mat.ContainsKey($key)) { $mat[$key] = @{ R = New-Object System.Collections.ArrayList; W = New-Object System.Collections.ArrayList } }
                    if ($m.Groups[1].Value -eq 'set') { if ($mat[$key].W -notcontains $f.BaseName) { [void]$mat[$key].W.Add($f.BaseName) } }
                    else { if ($mat[$key].R -notcontains $f.BaseName) { [void]$mat[$key].R.Add($f.BaseName) } }
                }
            }
        }
    }

    # C2: zincirleme erisim  getApplicationInfo().getX()  /  ((Tip) ...).getX()
    foreach ($tip in $tipler.Keys) {
        $rxChain = [regex]('(?:get' + [regex]::Escape($tip) + '\s*\(\s*\)|\(\s*' + [regex]::Escape($tip) + '\s*\)[^;]{0,120}?\))\s*\.\s*(get|set|is)([A-Z]\w*)\s*\(')
        foreach ($ln in $aktif) {
            foreach ($m in $rxChain.Matches($ln.Text)) {
                $key = $tip + '.' + $m.Groups[2].Value
                if (-not $mat.ContainsKey($key)) { $mat[$key] = @{ R = New-Object System.Collections.ArrayList; W = New-Object System.Collections.ArrayList } }
                if ($m.Groups[1].Value -eq 'set') { if ($mat[$key].W -notcontains $f.BaseName) { [void]$mat[$key].W.Add($f.BaseName) } }
                else { if ($mat[$key].R -notcontains $f.BaseName) { [void]$mat[$key].R.Add($f.BaseName) } }
            }
        }
    }
}
# Kapsam siniflandirmasi: gercek paylasilan state = bir ekranin yazip
# BASKA ekranin okudugu alan. Ayni ekranin yazip okudugu alan yereldir.
$kapsam = @{}
foreach ($key in $mat.Keys) {
    $w = @($mat[$key].W); $r = @($mat[$key].R)
    if ($w.Count -eq 0)      { $kapsam[$key] = 'YAZAN-YOK' }
    elseif ($r.Count -eq 0)  { $kapsam[$key] = 'OKUYAN-YOK' }
    else {
        $capraz = $false
        foreach ($x in $r) { if ($w -notcontains $x) { $capraz = $true; break } }
        if ($w.Count -gt 1) { $capraz = $true }
        if ($capraz) { $kapsam[$key] = 'PAYLASILAN' } else { $kapsam[$key] = 'LOKAL' }
    }
}
# --- Genisletme: OKUYAN-YOK / YAZAN-YOK alanlarini TUM repoda ara ---
# entry/controllers disinda (Super siniflar, diger paketler, BE eslemesi)
# okuyan/yazan olabilir. Kapsam darligini olu veri sanmamak icin.
$SRC = "src\main\java"
$supheli = @($mat.Keys | Where-Object { $kapsam[$_] -eq 'OKUYAN-YOK' -or $kapsam[$_] -eq 'YAZAN-YOK' })
if ($supheli.Count -gt 0) {
    $alanlar = @($supheli | ForEach-Object { @($_ -split '\.')[-1] } | Sort-Object -Unique)
    $rxOku = [regex]('\.(?:get|is)(' + (($alanlar | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\s*\(')
    $rxYaz = [regex]('\.set(' + (($alanlar | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\s*\(')
    $disOku = @{}; $disYaz = @{}
    $devAdlari = @($devJava | ForEach-Object { $_.BaseName })
    foreach ($f in @(Get-ChildItem $SRC -Recurse -File -Filter *.java)) {
        if ($devAdlari -contains $f.BaseName) { continue }
        $txt = Get-Content -LiteralPath $f.FullName -Raw
        if (-not $txt) { continue }
        foreach ($m in $rxOku.Matches($txt)) { if (-not $disOku.ContainsKey($m.Groups[1].Value)) { $disOku[$m.Groups[1].Value] = $f.BaseName } }
        foreach ($m in $rxYaz.Matches($txt)) { if (-not $disYaz.ContainsKey($m.Groups[1].Value)) { $disYaz[$m.Groups[1].Value] = $f.BaseName } }
    }
    foreach ($key in $supheli) {
        $alan = @($key -split '\.')[-1]
        if ($kapsam[$key] -eq 'OKUYAN-YOK' -and $disOku.ContainsKey($alan)) { $kapsam[$key] = 'OKUYAN: ' + $disOku[$alan] }
        if ($kapsam[$key] -eq 'YAZAN-YOK'  -and $disYaz.ContainsKey($alan)) { $kapsam[$key] = 'YAZAN: '  + $disYaz[$alan] }
    }
}

[void]$out.Add("| Tasiyici.Alan | Kapsam | YAZAN | OKUYAN |")
[void]$out.Add("|---|---|---|---|")
foreach ($key in ($mat.Keys | Sort-Object)) {
    [void]$out.Add("| " + $key + " | " + $kapsam[$key] + " | " + (@($mat[$key].W) -join ', ') + " | " + (@($mat[$key].R) -join ', ') + " |")
}

# --- 24b: yalnizca yorumlanmaya deger satirlar ---
$kisa = New-Object System.Collections.ArrayList
[void]$kisa.Add("# Paylasilan state ve anomaliler")
[void]$kisa.Add("")
[void]$kisa.Add("LOKAL alanlar (ayni ekran yazip okuyor) bu dosyada YOK - tam liste 24-state-sozlugu.txt")
foreach ($grp in @('PAYLASILAN', 'OKUYAN-YOK', 'YAZAN-YOK', 'DIS-KULLANIM')) {
    if ($grp -eq 'DIS-KULLANIM') {
        $satirlar = @($mat.Keys | Where-Object { $kapsam[$_] -like 'OKUYAN: *' -or $kapsam[$_] -like 'YAZAN: *' } | Sort-Object)
    } else {
        $satirlar = @($mat.Keys | Where-Object { $kapsam[$_] -eq $grp } | Sort-Object)
    }
    [void]$kisa.Add("")
    [void]$kisa.Add("## " + $grp + "  (" + $satirlar.Count + " alan)")
    [void]$kisa.Add("")
    [void]$kisa.Add("| Tasiyici.Alan | YAZAN | OKUYAN | Not |")
    [void]$kisa.Add("|---|---|---|---|")
    foreach ($key in $satirlar) {
        $not = ''
        if ($kapsam[$key] -like '*: *') { $not = 'entry disinda: ' + (@($kapsam[$key] -split ': ')[-1]) }
        [void]$kisa.Add("| " + $key + " | " + (@($mat[$key].W) -join ', ') + " | " + (@($mat[$key].R) -join ', ') + " | " + $not + " |")
    }
}
Set-Content "$O\24b-state-paylasilan.txt" -Value ($kisa -join "`r`n") -Encoding UTF8

Set-Content "$O\24-state-sozlugu.txt" -Value ($out -join "`r`n") -Encoding UTF8
"scope api cesidi : " + $sayim.Count
"tasiyici tipi    : " + $tipler.Count
"tasiyicili ekran : " + $holders.Count + " / " + $devJava.Count
"alan sayisi      : " + $mat.Count
"  paylasilan     : " + @($mat.Keys | Where-Object { $kapsam[$_] -eq 'PAYLASILAN' }).Count
"  lokal          : " + @($mat.Keys | Where-Object { $kapsam[$_] -eq 'LOKAL' }).Count
"  okuyan yok     : " + @($mat.Keys | Where-Object { $kapsam[$_] -eq 'OKUYAN-YOK' }).Count + "   << gercekten olu aday"
"  yazan yok      : " + @($mat.Keys | Where-Object { $kapsam[$_] -eq 'YAZAN-YOK' }).Count
"  entry disinda  : " + @($mat.Keys | Where-Object { $kapsam[$_] -like '*: *' }).Count
"24-state-sozlugu : " + $out.Count + " satir"
````

> İlk sürüm taşıyıcıyı yalnızca `var = (Tip) cc.getFromTabScope(...)` kalıbında
> arıyordu ve 25 dev sınıfın 7'sini yakalıyordu. Artık önce scope çağrılarından
> **taşıyıcı tipleri** çıkarılıyor, sonra o tipten değişkenler her bildirim
> biçiminde (atama, parametre, yerel) taranıyor, ayrıca `getApplicationInfo().getX()`
> ve `((Tip) ...).getX()` zincirleme erişimleri de yakalanıyor.

> **Kapsam genişletme pası.** İlk sınıflandırma yalnızca `entry/controllers`
> altındaki 27 dev sınıfa bakıyordu ve 166 alanın 80'ini "okuyan yok" sayıyordu.
> Bu alanların okuyucuları çoğunlukla `Super` sınıflarında, BE'ye giden DTO
> eşlemesinde veya entry dışı ekranlarda. Blok artık şüpheli alanları tüm java
> ağacında arayıp `entry disinda: <sinif>` notuyla ayırıyor; geriye kalan
> `OKUYAN-YOK` gerçekten ölü veri adayı.

`YAZAN YOK` = veri akışa dışarıdan giriyor veya başka bir ekran yazıyor olabilir.
`OKUYAN YOK` = yazılıp hiç okunmayan alan — potansiyel ölü veri. İkisi de
Adım 9a'nın yorumlayacağı bulgular.

---

## Copilot tarafı nasıl değişiyor

### Adım 8 → sadece yorum turu

Grafik zaten üretildi. Prompt kısalıyor:

```
[P0 BAŞLIĞI]

# GİRDİ
#file:docs/entry-akis/00a-envanter.md
#file:docs/entry-akis/00b-akis-otomatik.md
#file:docs/entry-akis/_tarama/21-event-handler.txt
#file:docs/entry-akis/_tarama/20-include.txt
#file:docs/entry-akis/_tarama/18-disaridan-cagrilar.txt
#file:docs/entry-akis/_tarama/23-acik-sorular.txt

# GÖREV
Grafik ve tablolar script tarafından CCT'den üretildi; DOĞRU kabul et,
yeniden çıkarma. Senin işin yorumlamak.

# ÇIKTI — docs/entry-akis/00b-akis.md
## 1. Akışın Sözlü Anlatımı
Grafiği okuyup akışı adım adım anlat: kullanıcı nereden girer, hangi kararla
nereye dallanır, nasıl biter.
## 2. CCT Dışı Ekranlar
TASK'ı olmayan 4 ekran: 21-event-handler ve 18-disaridan'a bakarak nereden
açıldıklarını tespit et. Bulamazsan "AÇILIŞ NOKTASI BULUNAMADI".
## 3. Akış Dışı TASK'lar
Entry conversation'larının çağırdığı ama entry klasöründe olmayan ekranlar —
hangi akışa ait, neden buradan çağrılıyor.
## 4. Include Haritası
## 5. Giriş ve Çıkış Noktaları
## 6. Grafikteki Anomaliler
21-event-handler.txt'deki `<< BULGU` satırlarını yorumla — bunlar script
tarafından doğrulandı, yeniden tespit etmeye çalışma:
- `ULASILAMAZ` token: CCT'de tanımlı ama kodun hiç üretmediği geçiş
- `OLU SONUC` token: kodun ürettiği ama hiçbir geçişin beklemediği sonuç —
  kullanıcı o noktada takılıyor olabilir
- `YOK` handler: CCT olayının karşılığı olan metot bulunamadı
Ayrıca grafikten: boş NextConvID/NextTaskID ile biten çıkmazlar; hiçbir
geçişin hedefi olmayan TASK'lar; aynı TASK'ın birden çok conversation'da
geçmesi. Her biri için neden ve risk yaz.
## 7. Açık Sorular
23-acik-sorular.txt zaten dört kategoride cevap içeriyor: setControllerEvent
çağrılarının bağlamı, entry dışı conversation tanımları, açılış noktası
aramaları, kapanış mekanizması. Soru yazmadan önce oraya bak — cevabı varsa
soru değil, bulgudur. Sadece o dosyada da cevabı olmayanları listele.

# KURAL
Tabloları tekrar etme, üzerine yorum yap. İyileştirme yazma.
```

Model burada 1030 satır XML okumuyor; hazır grafiği okuyup yorumluyor.

### Adım 12 → ön-doldurulmuş kartı tamamlama

Grup başına:

```
[P0 BAŞLIĞI]

# GİRDİ
#file:docs/entry-akis/00a-envanter.md
#file:docs/entry-akis/00c-plan.md
#file:docs/entry-akis/ekranlar/<PG_X>.hazir.md
#file:docs/entry-akis/ekranlar/<PG_Y>.hazir.md
#file:docs/entry-akis/_tarama/22-lang-durumu.txt
Kaynak: #file:<PG_X.java> #file:<PG_X.html> #file:<PG_X.js> (her ekran için)

# GÖREV
Kartlardaki tablolar script tarafından dolduruldu — DOĞRU kabul et, yeniden
üretme, değiştirme. Sadece `<!-- MODEL -->` işaretli bölümleri doldur.

Her bölüm için:
- Künye ve Rol: ekran ne işe yarıyor, akıştaki yeri
- Akış Sözleşmesi: akış state'inden NEYİ OKUYOR / NEYİ YAZIYOR, veri gelmezse
  ne oluyor
- Yaşam Döngüsü: 00a'daki konvansiyon metotları bu ekranda ne yapıyor
- İç Akışlar: mutlu yol + hata yolları, Mermaid sequence
- Validasyon Değerlendirmesi: karttaki aday satırları değerlendir — hangisi
  gerçek kural, NEREDE uygulanıyor, sadece js'te olan hangisi
- Yetki Değerlendirmesi: _auth.properties boşsa kontrol kodda mı, hiç mi yok
- Dialog, Ölü Kod, Açık Sorular

# KURAL
Üretilmiş Super sınıflarından iş kuralı çıkarma; yapısal sözleşme için oku.
Kod bloğu yapıştırma. İyileştirme yazma.
Çıktıyı aynı dosyaya yaz (`.hazir.md`), tabloları koruyarak.
```

### Model kademelendirmesi

| Adım | Model | Neden |
|---|---|---|
| 7 Envanter + konvansiyon | Sonnet | Ağırlıklı çıkarım |
| 8 Akış yorumu | Sonnet | Grafik hazır, yorum sığ |
| 9 State + plan | **Opus** | Asıl yargı burada |
| 10 / 14 Doğrulama | Sonnet | Karşılaştırma işi |
| 12 Kart tamamlama | Sonnet | Kart %70 dolu |
| 13 Konsolidasyon | **Opus** | Ekranlar arası çıkarım |
| 16 İyileştirme | **Opus** | En yüksek yargı yoğunluğu |

Opus turu: **3 + kart gruplarından zor olanlar**. Toplam 5-6.

---

## Sıra

```
Adım 0-6        PowerShell taramaları        (yapıldı)
M1              CCT -> grafik
M2              olay <-> handler
M3              dil durumu
Adım 7          envanter + konvansiyon       [Sonnet]
M4              kart ön-doldurma             (svcRx'i 00a'ya göre daralt)
Adım 8          akış yorumu                  [Sonnet]
Adım 9          state + plan                 [Opus]
Adım 10-11      doğrulama + spot-check
Adım 12         kart tamamlama × grup        [Sonnet]
Adım 13         konsolidasyon                [Opus]
Adım 14-15      doğrulama + spot-check
Adım 16         iyileştirme                  [Opus]
```

M4 Adım 7'den sonra çalışır çünkü servis desenleri oradan türetilmişti; artık
bloğa sabitlendiler, ek ayar gerekmiyor.

Tablolardaki **Durum** sütunu `aktif` veya `YORUM` değerini alır. Yoruma
alınmış satırlar silinmez — devre dışı bırakılmış mantık kendi başına bulgudur
(bkz. `PG_ApplicationPricing`'deki ürün-tipi yönlendirmesi) — ama çalışan kodla
karıştırılmaz.

**Catch blokları tablosu** dayanıklılık ekseninin hammaddesi: "sonraki 2 satır"
sütunu boşsa veya sadece `}` içeriyorsa exception sessizce yutuluyor demektir.
Adım 7'de tespit edilen katmanlama — servis tarafı `HmnServiceException` /
`JABSBusinessServiceNotFoundException` / `JABSRemoteException`, ekran tarafı
`FWAbendException` / `FWScopeException` / `FWTypeException` /
`FWInfrastructureException` — hangi katmanın hangi hatayı yuttuğunu görmeyi
sağlar.
