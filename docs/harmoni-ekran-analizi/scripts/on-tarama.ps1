# Harmoni akış analizi — ön-tarama (PowerShell)
#
# Kullanım (FE repo kökünde):
#   powershell -ExecutionPolicy Bypass -File docs\harmoni-ekran-analizi\scripts\on-tarama.ps1
#   ... -Entry cct\page\acq\entry -Out docs\entry-akis\_tarama
#
# Git Bash / WSL / macOS / Linux kullanıyorsan on-tarama.sh dosyasını çalıştır.

param(
    [string]$Entry = "cct/page/acq/entry",
    [string]$Out   = "docs/entry-akis/_tarama"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -PathType Container $Entry)) {
    Write-Error "'$Entry' klasoru bulunamadi. FE repo kokunde calistirdigindan emin ol, veya -Entry parametresi ver."
    exit 1
}

$Acq = Split-Path -Parent $Entry
New-Item -ItemType Directory -Force -Path $Out | Out-Null

Write-Host "Akis  : $Entry"
Write-Host "Cikti : $Out"
Write-Host ""

function Save-Matches {
    param([string[]]$Paths, [string]$Pattern, [string]$File, [switch]$CaseSensitive)

    $files = Get-ChildItem -Path $Paths -Recurse -File -ErrorAction SilentlyContinue
    if (-not $files) { Set-Content -Path $File -Value "" -Encoding UTF8; return }

    $sel = if ($CaseSensitive) {
        $files | Select-String -Pattern $Pattern -CaseSensitive -ErrorAction SilentlyContinue
    } else {
        $files | Select-String -Pattern $Pattern -ErrorAction SilentlyContinue
    }

    $lines = $sel | ForEach-Object {
        "{0}:{1}:{2}" -f (Resolve-Path -Relative $_.Path), $_.LineNumber, $_.Line.Trim()
    }
    # Bos sonucta da dosyayi olustur: "arandi, bulunamadi" ile "hic aranmadi"
    # ayrimini korumak icin.
    Set-Content -Path $File -Value (@($lines) -join "`r`n") -Encoding UTF8
}

# 1. Dosya envanteri + satir sayilari
$inv = Get-ChildItem -Path $Entry -Recurse -File -Include *.java, *.html, *.js, *.json |
    ForEach-Object {
        $n = (Get-Content -LiteralPath $_.FullName -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
        "{0,8} {1}" -f $n, (Resolve-Path -Relative $_.FullName)
    } | Sort-Object { ($_ -split '\s+', 3)[2] }
Set-Content -Path "$Out/01-dosyalar.txt" -Value (@($inv) -join "`r`n") -Encoding UTF8

# 2. Navigasyon / dialog / event cagrilari
Save-Matches -Paths $Entry -CaseSensitive `
    -Pattern 'startNewProcess|showCustomMessageBox|fireEvent|CCT|openDialog|closeDialog' `
    -File "$Out/02-gecisler.txt"

# 3. Servis (Intf) cagrilari
Save-Matches -Paths $Entry -CaseSensitive `
    -Pattern 'HMN_[A-Za-z_]*Intf|[A-Za-z]+Intf\s*\.|[A-Za-z]+Service\s*\.' `
    -File "$Out/03-servisler.txt"

# 4. Akisa DISARIDAN yapilan cagrilar (giris noktalari)
# Klasor adini degil EKRAN ADLARINI ariyoruz - navigasyon sayfa sinifini
# referansliyor, klasoru degil.
$names = (Get-ChildItem -Path $Entry -Directory).Name -join '|'
if ($names) {
    $outside = Get-ChildItem -Path $Acq -Recurse -File -Include *.java, *.js -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/]entry[\\/]' } |
        Select-String -Pattern $names -ErrorAction SilentlyContinue |
        ForEach-Object { "{0}:{1}:{2}" -f (Resolve-Path -Relative $_.Path), $_.LineNumber, $_.Line.Trim() }
} else { $outside = @() }
Set-Content -Path "$Out/04-giris-noktalari.txt" -Value (@($outside) -join "`r`n") -Encoding UTF8

# 5. Session / global state kullanimi
Save-Matches -Paths $Entry `
    -Pattern 'session|getAttribute|setAttribute|processContext|globalMap' `
    -File "$Out/05-state.txt"

# 6. Ekran boyutlari (toplam satir, buyukten kucuge)
$sizes = Get-ChildItem -Path $Entry -Directory | ForEach-Object {
    $total = (Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue |
        ForEach-Object { (Get-Content -LiteralPath $_.FullName -ErrorAction SilentlyContinue | Measure-Object -Line).Lines } |
        Measure-Object -Sum).Sum
    [PSCustomObject]@{ Lines = [int]$total; Name = $_.Name }
} | Sort-Object Lines -Descending | ForEach-Object { "{0} {1}" -f $_.Lines, $_.Name }
Set-Content -Path "$Out/06-ekran-boyutlari.txt" -Value (@($sizes) -join "`r`n") -Encoding UTF8

# Ozet
Write-Host "Sonuc:"
foreach ($f in '01-dosyalar', '02-gecisler', '03-servisler', '04-giris-noktalari', '05-state', '06-ekran-boyutlari') {
    $path = Join-Path $Out "$f.txt"
    $n = @(Get-Content -LiteralPath $path -ErrorAction SilentlyContinue).Count
    if ($n -eq 0) {
        Write-Host ("  {0,-22} {1,5} satir   << BOS - deseni kontrol et" -f "$f.txt", $n)
    } else {
        Write-Host ("  {0,-22} {1,5} satir" -f "$f.txt", $n)
    }
}

$screens = @(Get-ChildItem -Path $Entry -Directory).Count
Write-Host ""
Write-Host "Ekran sayisi: $screens"
Write-Host ""
Write-Host "BOS dosya varsa: o mekanizma bu akista kullanilmiyor olabilir, ya da isim"
Write-Host "farklidir. Koddan dogrulayip script'teki deseni guncelle."
Write-Host "Bos ciktiyi silme - modelin 'arandi, bulunamadi' ile 'hic aranmadi'"
Write-Host "arasindaki farki bilmesi gerekiyor."
