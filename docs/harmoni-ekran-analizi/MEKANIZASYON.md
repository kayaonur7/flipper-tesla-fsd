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
>
> İlk sürüm bu ismi metot sanıp arıyordu ve 71 geçişin 60'ını "bulunamadı"
> diye işaretliyordu — tamamı yanlış alarmdı.

Bu blok üç tutarlılık kontrolü yapar:

| Bölüm | Kontrol | Bulgu |
|---|---|---|
| A | CCT'deki her `ControllerEvent` token'ı kodda üretiliyor mu | `URETILMIYOR` → **ulaşılamayan geçiş** |
| B | Kodda `setControllerEvent(X)` ile üretilen her token CCT'de bekleniyor mu | `CCT-DE YOK` → **ölü sonuç**, kullanıcı takılır |
| C | CCT'deki `Event` için `onXxx` handler'ı var mı | `YOK` → eksik handler |

````powershell
$J = "src\main\java\com\ykb\hmn\acq\application\entry\controllers"
$W = "src\main\webapp\page\acq\application\entry"
$O = "docs\entry-akis\_tarama"
if (-not $trans -or @($trans).Count -eq 0) { $trans = @(Import-Csv "$O\cct-trans.csv") }

$javaFiles = @(Get-ChildItem $J -File -Filter *.java)
$rows = New-Object System.Collections.ArrayList

# --- A: CCT'deki ControllerEvent token'i kodda uretiliyor mu ---
[void]$rows.Add("=== A. CCT ControllerEvent token'i kodda uretiliyor mu ===")
[void]$rows.Add("URETILIYOR   : token kodda geciyor")
[void]$rows.Add("URETILMIYOR  : hicbir yerde uretilmiyor -> ULASILAMAYAN GECIS")
[void]$rows.Add("")
$tokens = @($trans | ForEach-Object { [string]$_.CtrlEvent } | Where-Object { $_ } | Sort-Object -Unique)
$sA = @{ VAR = 0; YOK = 0 }
foreach ($t in $tokens) {
    $h = @($javaFiles | Select-String -Pattern ('\b' + [regex]::Escape($t) + '\b') -ErrorAction SilentlyContinue)
    if ($h.Count -gt 0) {
        $sA.VAR++
        [void]$rows.Add(('URETILIYOR '.PadRight(14) + $t.PadRight(34) + $h.Count.ToString().PadLeft(4) + ' yer  ilk: ' + $h[0].Filename + ':' + $h[0].LineNumber))
    } else {
        $sA.YOK++
        [void]$rows.Add(('URETILMIYOR'.PadRight(14) + $t))
    }
}

# --- B: koddaki setControllerEvent(...) CCT'de tanimli mi ---
[void]$rows.Add("")
[void]$rows.Add("=== B. kodda uretilen token CCT'de tanimli mi ===")
[void]$rows.Add("ESLESTI   : CCT'de bu token'i bekleyen bir TRANSITION var")
[void]$rows.Add("CCT-DE YOK: hicbir gecis bu token'i beklemiyor -> OLU SONUC")
[void]$rows.Add("DEGISKEN  : arguman sabit degil, elle incelenmeli")
[void]$rows.Add("")
$rxSet = [regex]'setControllerEvent\s*\(\s*([^)]*?)\s*\)'
$sB = @{ OK = 0; YOK = 0; DEG = 0 }
foreach ($f in $javaFiles) {
    foreach ($h in @(Select-String -LiteralPath $f.FullName -Pattern 'setControllerEvent\s*\(' -ErrorAction SilentlyContinue)) {
        $m = $rxSet.Match([string]$h.Line)
        if (-not $m.Success) { continue }
        $arg = $m.Groups[1].Value.Trim().Trim('"')
        if ($arg.Contains('.')) { $arg = @($arg -split '\.')[-1] }
        $arg = $arg.Trim()
        if (-not $arg) { continue }
        if ($arg -cmatch '^[a-z]') { $sB.DEG++; [void]$rows.Add(('DEGISKEN  '.PadRight(12) + $arg.PadRight(34) + $f.Name + ':' + $h.LineNumber)); continue }
        if ($tokens -contains $arg) { $sB.OK++;  [void]$rows.Add(('ESLESTI   '.PadRight(12) + $arg.PadRight(34) + $f.Name + ':' + $h.LineNumber)) }
        else                        { $sB.YOK++; [void]$rows.Add(('CCT-DE YOK'.PadRight(12) + $arg.PadRight(34) + $f.Name + ':' + $h.LineNumber)) }
    }
}

# --- C: CCT Event (ACTION/DECISION) -> onXxx handler ---
[void]$rows.Add("")
[void]$rows.Add("=== C. CCT Event -> handler ===")
[void]$rows.Add("")
$sC = @{ VAR = 0; YOK = 0 }
foreach ($e in @($trans | Select-Object FromPage, Event -Unique)) {
    $ev = [string]$e.Event; $cls = [string]$e.FromPage
    if ([string]::IsNullOrWhiteSpace($ev) -or [string]::IsNullOrWhiteSpace($cls)) { continue }
    $hit = $null
    foreach ($cand in @(($cls + '.java'), ($cls + 'Super.java'))) {
        $p = Join-Path $J $cand
        if (-not (Test-Path $p)) { continue }
        $h = @(Select-String -LiteralPath $p -Pattern ('\b' + [regex]::Escape($ev) + '\s*\(') -ErrorAction SilentlyContinue)
        if ($h.Count -gt 0) { $hit = $cand + ':' + $h[0].LineNumber; break }
    }
    if ($hit) { $sC.VAR++; [void]$rows.Add(('VAR '.PadRight(6) + $cls.PadRight(38) + $ev.PadRight(24) + $hit)) }
    else      { $sC.YOK++; [void]$rows.Add(('YOK '.PadRight(6) + $cls.PadRight(38) + $ev)) }
}

Set-Content "$O\21-event-handler.txt" -Value ($rows -join "`r`n") -Encoding UTF8
"A token      : uretiliyor={0}  ULASILAMAYAN={1}   (distinct token: {2})" -f $sA.VAR, $sA.YOK, $tokens.Count
"B setCtrlEv  : eslesti={0}  OLU SONUC={1}  degisken={2}" -f $sB.OK, $sB.YOK, $sB.DEG
"C Event      : handler var={0}  yok={1}" -f $sC.VAR, $sC.YOK
"21-event-handler : " + $rows.Count + " satir"
````

---

## M3 — Dil durumu

**Önce M0.**

Ekran başına tr/en key farkı ve html+js'te hiç geçmeyen ölü key'ler.

````powershell
$rxKey = [regex]'"([^"]+)"\s*:'
$out = New-Object System.Collections.ArrayList
foreach ($d in (Get-ChildItem $W -Directory | Sort-Object Name)) {
    $n = $d.Name
    $kt = @(); $ke = @()
    $ptr = Join-Path $d.FullName "${n}_lang_tr.json"
    $pen = Join-Path $d.FullName "${n}_lang_en.json"
    if (Test-Path $ptr) { $t = Get-Content -LiteralPath $ptr -Raw; if ($t) { $kt = @($rxKey.Matches($t) | ForEach-Object { $_.Groups[1].Value }) } }
    if (Test-Path $pen) { $t = Get-Content -LiteralPath $pen -Raw; if ($t) { $ke = @($rxKey.Matches($t) | ForEach-Object { $_.Groups[1].Value }) } }

    $src = ''
    foreach ($ext in 'html', 'js') {
        $p = Join-Path $d.FullName "$n.$ext"
        if (Test-Path $p) { $src += (Get-Content -LiteralPath $p -Raw) }
    }
    $trOnly = @($kt | Where-Object { $ke -notcontains $_ })
    $enOnly = @($ke | Where-Object { $kt -notcontains $_ })
    $olu    = @($kt | Where-Object { $src -notmatch [regex]::Escape($_) })

    [void]$out.Add("### $n")
    [void]$out.Add("  tr key: $($kt.Count)   en key: $($ke.Count)")
    if ($trOnly.Count) { [void]$out.Add("  TR'DE VAR EN'DE YOK : " + ($trOnly -join ', ')) }
    if ($enOnly.Count) { [void]$out.Add("  EN'DE VAR TR'DE YOK : " + ($enOnly -join ', ')) }
    if ($olu.Count)    { [void]$out.Add("  KULLANILMAYAN       : " + ($olu -join ', ')) }
    if (-not $trOnly.Count -and -not $enOnly.Count -and -not $olu.Count) { [void]$out.Add("  temiz") }
}
Set-Content "$O\22-lang-durumu.txt" -Value ($out -join "`r`n") -Encoding UTF8
"22-lang-durumu : " + $out.Count + " satir"
````

---

## M4 — Ekran kartı ön-doldurucu

**Önce M0.** Uzun blok — `.ps1` dosyasına kaydedip `Ctrl+A` → `F8` en rahatı.

Her ekran için tabloları dolu, yorum bölümleri boş bir kart üretir. Model
yalnızca `<!-- MODEL -->` işaretli yerleri doldurur.

**Önce Adım 7'yi çalıştır** ve `00a-envanter.md`'den gerçek servis sonekini
öğren; `$svcRx` içindeki listeyi ona göre daralt. Varsayılan geniş bırakıldı.

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

$svcRx = [regex]'([A-Za-z_][A-Za-z0-9_]*(?:Intf|Service|Manager|Facade|Delegate|Client|Proxy|Dao|DAO))\s*\.\s*([a-z][A-Za-z0-9_]*)\s*\('
$valRx = [regex]'(?i)validate|isValid|required|mandatory|isEmpty|isBlank|\.length|matches\(|showCustomMessageBox'

foreach ($d in (Get-ChildItem $W -Directory | Sort-Object Name)) {
    $n = $d.Name
    $k = New-Object System.Collections.ArrayList
    [void]$k.Add("# $n")
    [void]$k.Add("")
    [void]$k.Add("> Tablolar script tarafından dolduruldu. `<!-- MODEL -->` işaretli")
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
    }

    # --- servis cagrilari ---
    [void]$k.Add("")
    [void]$k.Add("## Servis Çağrıları (aday)")
    [void]$k.Add("")
    [void]$k.Add("| Nesne | Metot | Dosya:satır |")
    [void]$k.Add("|---|---|---|")
    foreach ($cand in @("$n.java", "${n}Super.java")) {
        $p = Join-Path $J $cand
        if (-not (Test-Path $p)) { continue }
        $ln = 0
        foreach ($line in (Get-Content -LiteralPath $p)) {
            $ln++
            foreach ($m in $svcRx.Matches($line)) {
                [void]$k.Add("| $($m.Groups[1].Value) | $($m.Groups[2].Value) | $cand`:$ln |")
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
        Select-String -LiteralPath $p -Pattern $valRx | Select-Object -First 40 | ForEach-Object {
            [void]$k.Add("- ``$f`:$($_.LineNumber)`` — $($_.Line.Trim())")
        }
    }

    # --- yetki ---
    [void]$k.Add("")
    [void]$k.Add("## Yetki")
    [void]$k.Add("")
    $pa = Join-Path $d.FullName "${n}_auth.properties"
    if (Test-Path $pa) {
        $ca = @(Get-Content -LiteralPath $pa)
        if ($ca.Count -eq 0) { [void]$k.Add("`${n}_auth.properties` mevcut ama **BOŞ**.") }
        else { $ca | ForEach-Object { [void]$k.Add("- ``$_``") } }
    } else { [void]$k.Add("_auth.properties **YOK**.") }

    # --- include ---
    [void]$k.Add("")
    [void]$k.Add("## Dahil Edilen Sayfalar")
    [void]$k.Add("")
    $inc = Get-ChildItem $d.FullName, $J -File -Include "$n.html", "$n.java", "${n}Super.java" -ErrorAction SilentlyContinue |
        Select-String -Pattern 'IncludedPage|data-page-name|PG_Include[A-Za-z0-9_]*'
    if ($inc) { $inc | ForEach-Object { [void]$k.Add("- ``$(Split-Path $_.Path -Leaf):$($_.LineNumber)`` — $($_.Line.Trim())") } }
    else { [void]$k.Add("yok") }

    # --- dil ---
    [void]$k.Add("")
    [void]$k.Add("## Dil Durumu")
    [void]$k.Add("")
    [void]$k.Add("22-lang-durumu.txt içindeki `### $n` bölümüne bak.")

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
Boş NextConvID/NextTaskID ile biten çıkmazlar; hiçbir geçişin hedefi olmayan
TASK'lar; handler'ı bulunamayan ControllerEvent'ler; aynı TASK'ın birden çok
conversation'da geçmesi — her biri için neden ve risk.
## 7. Açık Sorular

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

M4'ü Adım 7'den sonraya koymanın sebebi: servis deseni oradan çıkıyor. Şimdi
çalıştırırsan "Servis Çağrıları (aday)" tablosu gürültülü olur — sonra tekrar
çalıştırıp kartları yenilemen gerekir, ama `<!-- MODEL -->` bölümlerini
doldurmadan önce yaparsan kayıp olmaz.
