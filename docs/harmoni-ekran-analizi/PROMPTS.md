# Harmoni Legacy Akış Analizi — Prompt Seti

Harmoni (kuruma özel, kapalı kaynak) legacy akışlarının uçtan uca analizi ve
iyileştirme planı için hazırlanmış prompt seti. GitHub Copilot **agent mode** +
**Opus** ile kullanılmak üzere yazıldı.

Hedef: `cct/page/acq/entry` — 14 alt ekrandan oluşan üye işyeri başvuru akışı.
Set, tek ekranlık analiz için de kullanılabilir (bkz. [Tek ekran modu](#tek-ekran-modu)).

Çalıştırma adımları: [README.md](./README.md)

| Blok | Amaç | Kaç kez |
|---|---|---|
| [A](#blok-a--framework--akış-primer) | Framework + akış primer | Her prompt'un başına yapıştırılır |
| [Ön-tarama](#ön-tarama-script) | Keşif çıktılarını script ile üret | 1 (Copilot'suz) |
| [B0a](#b0a--envanter-ve-sınıflandırma) | Ekran envanteri, sınıflandırma | 1 |
| [B0b](#b0b--geçiş-grafiği-ve-girişçıkış) | Geçiş grafiği, giriş/çıkış noktaları | 1 |
| [B0c](#b0c--state-servis-ikizler-ve-plan) | Paylaşılan state, servis matrisi, derin analiz planı | 1 |
| [B1](#blok-b1--ekran-kartı) | Tek ekran/grup derin analizi | Grup sayısı kadar (~6-8) |
| [B2](#blok-b2--konsolidasyon) | Ekranlar arası birleşik görünüm | 1 |
| [C](#blok-c--doğrulama-pası) | Doğrulama | B0c ve B2'den sonra |
| [D](#blok-d--iyileştirme-planı) | İyileştirme planı | 1 |

**Neden bu sırayla:** B0 olmadan hangi ekranın çekirdek hangisinin yardımcı
olduğu bilinmiyor ve 14 ekrana eşit efor harcanıyor. B2 olmadan akışın asıl
problemleri — adımlar arası tutarsızlıklar — hiç görünmüyor, çünkü hiçbiri tek
ekranın içinde durmuyor.

**Neden B0 üçe bölünmüş:** Tek turda 14 klasör okuma + iki repoda string
taraması + matris üretme, Copilot agent mode'da tool-call limitine ve istek
zaman aşımına takılıyor. Keşfin pahalı kısmı ön-tarama script'ine devredildi;
kalan iş üç kısa tura bölündü.

---

## Çalışma Disiplini

> Bu kısa blok **B0a, B0b, B0c, B1 ve B2**'nin `# KURALLAR` bölümüne eklenir.
> Uzun turların yarıda kesilmesine karşı koruma.

```
# ÇALIŞMA DİSİPLİNİ
- Her ana bölümü bitirir bitmez dosyaya YAZ. Sonda toplu yazma — tur kesilirse
  o ana kadarki iş kaybolmasın.
- Ön-tarama çıktılarında (docs/entry-akis/_tarama/) zaten olan bilgi için
  dosya AÇMA, arama YAPMA. Tarama çıktısı tek doğruluk kaynağıdır.
- Aynı dosyayı iki kez okuma.
- Sohbette açıklama/özet yapma. Doğrudan hedef dosyaya yaz, sonunda tek
  paragraf durum bildir.
- Tur kesilirse: hedef dosyanın mevcut halini oku, KALDIĞIN YERDEN devam et,
  baştan yazma.
```

---

## Ön-tarama (script)

> Copilot'ta değil, **terminalde sen çalıştır** — tek komut. Model 14 klasörü
> tarayarak bulacağına hazır çıktıyı okusun: hem çok daha hızlı, hem tarama
> eksiksiz oluyor (model bazı klasörleri atlayabiliyor, `grep` atlamaz).

**FE repo kökünde** çalıştır:

```bash
# macOS / Linux / WSL / Windows'ta Git Bash
bash docs/harmoni-ekran-analizi/scripts/on-tarama.sh
```

```powershell
# Windows PowerShell (VS Code'un varsayılan terminali)
powershell -ExecutionPolicy Bypass -File docs\harmoni-ekran-analizi\scripts\on-tarama.ps1
```

Akış yolu farklıysa parametre ver:

```bash
bash docs/harmoni-ekran-analizi/scripts/on-tarama.sh cct/page/acq/application
```
```powershell
... on-tarama.ps1 -Entry cct\page\acq\application
```

Script şu altı dosyayı `docs/entry-akis/_tarama/` altına yazar ve sonunda her
birinin satır sayısını özetler:

| Dosya | İçerik | Kullanan blok |
|---|---|---|
| `01-dosyalar.txt` | Dosya envanteri + satır sayıları | B0a |
| `02-gecisler.txt` | `startNewProcess`, `showCustomMessageBox`, `fireEvent`, `CCT`, `openDialog` | B0b |
| `03-servisler.txt` | `HMN_*Intf` / `*Service` çağrıları | B0c |
| `04-giris-noktalari.txt` | Akışa dışarıdan yapılan çağrılar | B0b |
| `05-state.txt` | `session`, `getAttribute`, `setAttribute`, `processContext` | B0c |
| `06-ekran-boyutlari.txt` | Ekran başına toplam satır, büyükten küçüğe | B0a, B0c |

Çıktılar workspace içinde dosya olduğu için prompt'a **`#file:` ile referans
verilir** — chat'e yapıştırmaya gerek yok, context de şişmez.

**Özette `<< BOŞ` uyarısı çıkarsa:** o mekanizma bu akışta kullanılmıyor
olabilir, ya da isim farklıdır. Koddan doğrulayıp script içindeki deseni
güncelle ve tekrar çalıştır. Boş çıktıyı silme — modelin "arandı, bulunamadı"
ile "hiç aranmadı" arasındaki farkı bilmesi gerekiyor.

**Ekran sayısı** satırını kontrol et: beklediğin sayı (entry için 14) gelmiyorsa
yol yanlış.

### Script çalıştırılamıyorsa

Kurumsal politika `.ps1` **dosyalarının** çalıştırılmasını engelliyor olabilir.
Bu kısıt terminale doğrudan yazılan komutları kapsamıyor. Üç alternatif —
sondaki hiç terminal gerektirmiyor.

#### Alternatif 1 — Git Bash

Git for Windows kuruluysa Git Bash, PowerShell execution policy'sinden
etkilenmiyor. VS Code'da terminal panelinde `+` yanındaki oka tıkla →
**Git Bash** seç, sonra:

```bash
bash docs/harmoni-ekran-analizi/scripts/on-tarama.sh
```

#### Alternatif 2 — PowerShell'e komutları doğrudan yapıştır

Script dosyası yerine komutları tek tek yapıştır. Önce değişkenler:

```powershell
$E = "cct\page\acq\entry"; $O = "docs\entry-akis\_tarama"
New-Item -ItemType Directory -Force $O | Out-Null
```

Sonra altı komut. **Her biri iki satır** — sonucu önce değişkene alıp sonra
yazıyoruz, çünkü boş pipeline `Set-Content`'e ulaşmıyor ve dosya hiç
oluşmuyor:

```powershell
$r = Get-ChildItem $E -Recurse -File -Include *.java,*.html,*.js,*.json | ForEach-Object { "{0,8} {1}" -f (Get-Content $_.FullName | Measure-Object -Line).Lines, (Resolve-Path -Relative $_.FullName) } | Sort-Object
Set-Content "$O\01-dosyalar.txt" -Value (@($r) -join "`r`n")
```
```powershell
$r = Get-ChildItem $E -Recurse -File | Select-String -CaseSensitive 'startNewProcess|showCustomMessageBox|fireEvent|CCT|openDialog|closeDialog' | ForEach-Object { "{0}:{1}:{2}" -f (Resolve-Path -Relative $_.Path), $_.LineNumber, $_.Line.Trim() }
Set-Content "$O\02-gecisler.txt" -Value (@($r) -join "`r`n")
```
```powershell
$r = Get-ChildItem $E -Recurse -File | Select-String -CaseSensitive 'HMN_[A-Za-z_]*Intf|[A-Za-z]+Intf\s*\.|[A-Za-z]+Service\s*\.' | ForEach-Object { "{0}:{1}:{2}" -f (Resolve-Path -Relative $_.Path), $_.LineNumber, $_.Line.Trim() }
Set-Content "$O\03-servisler.txt" -Value (@($r) -join "`r`n")
```
```powershell
$names = (Get-ChildItem $E -Directory).Name -join '|'
$r = Get-ChildItem (Split-Path $E) -Recurse -File -Include *.java,*.js | Where-Object { $_.FullName -notmatch '\\entry\\' } | Select-String -Pattern $names | ForEach-Object { "{0}:{1}:{2}" -f (Resolve-Path -Relative $_.Path), $_.LineNumber, $_.Line.Trim() }
Set-Content "$O\04-giris-noktalari.txt" -Value (@($r) -join "`r`n")
```
```powershell
$r = Get-ChildItem $E -Recurse -File | Select-String 'session|getAttribute|setAttribute|processContext|globalMap' | ForEach-Object { "{0}:{1}:{2}" -f (Resolve-Path -Relative $_.Path), $_.LineNumber, $_.Line.Trim() }
Set-Content "$O\05-state.txt" -Value (@($r) -join "`r`n")
```
```powershell
$r = Get-ChildItem $E -Directory | ForEach-Object { $n = ((Get-ChildItem $_.FullName -Recurse -File | ForEach-Object { (Get-Content $_.FullName | Measure-Object -Line).Lines }) | Measure-Object -Sum).Sum; "$n $($_.Name)" } | Sort-Object { [int]($_ -split ' ')[0] } -Descending
Set-Content "$O\06-ekran-boyutlari.txt" -Value (@($r) -join "`r`n")
```

Kontrol:

```powershell
Get-ChildItem $O | Select-Object Name, @{n='Satir';e={ @(Get-Content $_.FullName).Count }}
```

### Desen tutmadıysa: gerçek desenleri koddan çıkar

Bir tarama boş dönerse (veya PowerShell'de dosya hiç oluşmazsa — boş pipeline
`Set-Content`'e ulaşmaz) sebep neredeyse her zaman desenin bu kod tabanına
uymamasıdır. Harmoni'nin kendi idiomları var; tahmin etmek yerine koddan çıkar.

Önce değişkenler:

```powershell
$E = "cct\page\acq\entry"; $O = "docs\entry-akis\_tarama"
```

#### K0 — Ortam kontrolü

```powershell
$PSVersionTable.PSVersion
@(Get-ChildItem $E -Recurse -File -Include *.java).Count
```

İkincisi `0` dönerse `PG_*.java` dosyaları bu klasörün altında değil; keşfi
ona göre yeniden yönlendir.

#### K1 — En sık çağrılan nesneler (servis deseni için)

`Select-String -AllMatches` çıktısındaki `.Matches`, sonuç boş veya tek
olduğunda sürüme göre `$null` dönüp "Cannot index into a null array" hatası
veriyor. `[regex]::Matches` her sürümde güvenli — blok halinde yapıştır:

```powershell
$rx = [regex]'([A-Za-z_][A-Za-z0-9_]*)\s*\.\s*[a-z][A-Za-z0-9_]*\s*\('
$hits = New-Object System.Collections.ArrayList
Get-ChildItem $E -Recurse -File -Include *.java | ForEach-Object {
    $t = Get-Content -LiteralPath $_.FullName -Raw
    if ($t) { foreach ($m in $rx.Matches($t)) { [void]$hits.Add($m.Groups[1].Value) } }
}
$hits | Group-Object | Sort-Object Count -Descending | Select-Object -First 40 Count, Name
```

Çıktıdaki servis benzeri isimler (`...Intf`, `...Service`, `...Manager`,
`...Facade`, `...Delegate`, `...Client`, `...Proxy` veya kuruma özel bir sonek)
`03-servisler` deseninin doğrusudur.

#### K2 — import satırları (hangi modüller gerçekten kullanılıyor)

```powershell
Get-ChildItem $E -Recurse -File -Include *.java | Select-String '^\s*import\s+' | ForEach-Object { ($_.Line.Trim() -replace '^import\s+(static\s+)?','' -replace ';$','') } | Group-Object | Sort-Object Count -Descending | Select-Object -First 40 Count, Name
```

`HMN_*_Intf` / `HMN_*_Model` paketleri buradan net görünür. Servis arayüzü
sınıf adlarını da buradan al.

#### K3 — get/set çağrıları (state deseni için)

```powershell
$rx = [regex]'\b(?:get|set|put|read|write)[A-Z][A-Za-z0-9_]*(?=\s*\()'
$hits = New-Object System.Collections.ArrayList
Get-ChildItem $E -Recurse -File -Include *.java,*.js | ForEach-Object {
    $t = Get-Content -LiteralPath $_.FullName -Raw
    if ($t) { foreach ($m in $rx.Matches($t)) { [void]$hits.Add($m.Value) } }
}
$hits | Group-Object | Sort-Object Count -Descending | Select-Object -First 40 Count, Name
```

Harmoni state'i `session` üzerinden taşımıyor olabilir. Çıktıda `getPageData`,
`getProcessData`, `getContext`, `getSharedModel` gibi bir şey görürsen
`05-state` deseni odur.

#### K4 — Navigasyon deseninin doğrulanması

```powershell
foreach ($k in 'startNewProcess','showCustomMessageBox','fireEvent','CCT','openDialog','closeDialog','navigate','goPage','openPage','callPage') { $n = @(Get-ChildItem $E -Recurse -File | Select-String -SimpleMatch $k).Count; "{0,-22} {1}" -f $k, $n }
```

Hangi anahtar kelimenin kaç kez geçtiğini gösterir. `02-gecisler` beklediğinden
az satır döndüyse burada gerçek mekanizmayı görürsün.

#### K5 — Ekran adlarının dışarıda geçtiği yerler (04 için doğrusu)

Orijinal 04 komutu literal `entry` kelimesini arıyordu; navigasyon klasör adını
değil **sayfa sınıfını** referansladığı için çoğu repoda boş döner. Doğrusu:

```powershell
$names = (Get-ChildItem $E -Directory).Name -join '|'
$r = Get-ChildItem (Split-Path $E) -Recurse -File -Include *.java,*.js | Where-Object { $_.FullName -notmatch '\\entry\\' } | Select-String -Pattern $names | ForEach-Object { "{0}:{1}:{2}" -f (Resolve-Path -Relative $_.Path), $_.LineNumber, $_.Line.Trim() }
Set-Content "$O\04-giris-noktalari.txt" -Value (@($r) -join "`r`n")
```

### Boş dönse bile dosyayı oluşturan yazım

PowerShell'de `... | Set-Content x.txt` boş pipeline'da dosya yaratmıyor.
Sonuçları önce değişkene al, sonra yaz — böylece boş sonuç da dosya olarak
kalır ve model "arandı, bulunamadı" ile "hiç aranmadı" arasındaki farkı görür:

```powershell
$r = <arama komutu>
Set-Content "$O\03-servisler.txt" -Value (@($r) -join "`r`n")
```

### Yeni deseni bulduktan sonra

Deseni `scripts/on-tarama.ps1` ve `scripts/on-tarama.sh` içinde de güncelle ki
bir sonraki akışta (annulment, application, branchopening) tekrar uğraşma.

Hâlâ boş dönen bir tarama varsa **onu boş bırak ve devam et**. B0b/B0c
prompt'larına şu satırı ekle:

```
NOT: <dosya adı> taraması boş döndü. Bu mekanizmanın bu akışta kullanılmadığı
anlamına gelebilir. İlgili bölümde "TARAMA BOŞ — mekanizma kullanılmıyor veya
farklı adlandırılmış" yaz ve kalan girdilerle devam et. Bu boşluğu tahminle
doldurma.
```

#### Alternatif 3 — VS Code arama arayüzü (terminal yok)

Terminalin tamamı kapalıysa VS Code'un kendi aramasıyla aynı çıktıyı
üretebilirsin:

1. `Ctrl+Shift+F` ile aramayı aç
2. Sağdaki **`.*`** düğmesine bas (regex modu)
3. **files to include** kutusuna `cct/page/acq/entry` yaz
4. Arama kutusuna deseni yaz
5. Sonuç panelinin üstündeki **Open in Editor** bağlantısına tıkla
6. Açılan sekmeyi `docs/entry-akis/_tarama/<ad>.txt` olarak kaydet

Desenler:

| Kaydedilecek dosya | Arama deseni | files to include |
|---|---|---|
| `02-gecisler.txt` | `startNewProcess\|showCustomMessageBox\|fireEvent\|CCT\|openDialog\|closeDialog` | `cct/page/acq/entry` |
| `03-servisler.txt` | `HMN_[A-Za-z_]*Intf\|[A-Za-z]+Intf\s*\.\|[A-Za-z]+Service\s*\.` | `cct/page/acq/entry` |
| `04-giris-noktalari.txt` | `entry` | `cct/page/acq` + **files to exclude**: `cct/page/acq/entry` |
| `05-state.txt` | `session\|getAttribute\|setAttribute\|processContext\|globalMap` | `cct/page/acq/entry` |

`01-dosyalar.txt` ve `06-ekran-boyutlari.txt` bu yolla üretilemiyor (satır
sayımı gerekiyor). İkisini de atla ve B0a prompt'undaki girdi satırlarından
çıkar; onun yerine B0a'ya şunu ekle:

```
Envanteri kendin çıkar: entry altındaki klasörleri listele, her klasörün
dosyalarını göster. Satır sayısı yerine dosya boyutu kullan. Önce klasör
sayısını yaz, sonra devam et.
```

Bu, B0a turunu biraz uzatıyor ama diğer beş tur ön-tarama çıktılarıyla
çalışmaya devam ettiği için zaman aşımı riski düşük kalıyor.

#### Alternatif 4 — Copilot agent mode'a çalıştırt

Agent mode terminal komutu çalıştırabiliyor (her komut için onay ister).
Yeni bir chat'te:

```
Aşağıdaki komutları sırayla terminalde çalıştır ve her birinin çıktı dosyası
kaç satır oldu bana söyle. Komutları değiştirme, yorumlama, sadece çalıştır.

<Alternatif 2'deki komutları buraya yapıştır>
```

Bu yol da execution policy'ye takılmıyor, çünkü script dosyası çalıştırılmıyor.

---

## Blok A — Framework + Akış Primer

> Tek başına çalıştırılmaz. B0, B1, B2, C ve D bloklarının **her birinin başına**
> aynen yapıştırılır. Amacı, modelin bilmediği bir framework'ü tanıdığı bir
> framework'e benzeterek uydurmasını engellemek.

```
# HARMONİ FRAMEWORK — TEMEL BİLGİ
Bu, kuruma özel kapalı kaynak bir framework. Eğitim verinde YOK.
Spring / JSF / Struts / JSP konvansiyonlarını VARSAYMA. Bilmediğin bir
mekanizmayla karşılaşırsan repodaki BAŞKA PG_* ekranlarına bakıp konvansiyonu
oradan türet ve çıktında "TÜRETİLEN KONVANSİYON (kaynak: <dosya>)" diye işaretle.
Türetemiyorsan "BİLİNMİYOR" yaz — tahmin etme.

## Ekran anatomisi
Her PG_* klasörü bir alt ekrandır ve şu dosya grubunu içerir:
  PG_<Ekran>.java               → sayfa controller
  <ekran>.html                  → widget template
  <ekran>.js                    → sayfa script'i
  _lang_tr.json / _lang_en.json → i18n

## Repolar
hmnfe_acq_merchant — Legacy UI (Harmoni Frontend)
  Java + Maven, parent com.ykb.harmoni.fe:harmoni-fe-module-parent:3.1.0
  Jackson 2.9.6; bağımlılıklar: HMNFE_* / HMN_*_Intf + HMN_*_Model
hmn_acq_merchant — Legacy BE (Harmoni Backend)
  Java + Maven multi-module (pom packaging)
  parent com.ykb.harmoni.be:harmoni-be-module-parent:3.1.0
  HMN_ACQ_Merchant_Intf     → servis arayüzleri
  HMN_ACQ_Merchant_Model    → DTO / model
  HMN_ACQ_Merchant_Internal → implementasyon

## Mekanizmalar
Event      : Harmoni event / fireEvent — çağrı zinciri IMPLICIT, import ile izlenemez
Navigasyon : startNewProcess / CCT / dialog
Dialog     : showCustomMessageBox (bloklayıcı)
Rapor      : HopeReportGenerator — server-side Excel, reportId ile

## ANALİZ KAPSAMI — cct/page/acq/entry
Bu bir TEK EKRAN DEĞİL. 14 alt ekrandan oluşan bir üye işyeri başvuru (entry)
akışıdır. Her alt ekran kendi klasöründe, kendi dosya dörtlüsüyle durur.

Alt ekranlar:
  PG_AccountWalletPopup             PG_LoyaltyProgramRatePopup
  PG_AdditionalInformation          PG_MerchantPoint
  PG_AddNote                        PG_MerchantSecurityCheck
  PG_ApplicationAccount             PG_TagInquiry
  PG_ApplicationAccountEdit         PG_TagOperation
  PG_ApplicationEntryPersonalInfo   PG_TerminalInfo
  PG_ApplicationPricing
  PG_ApplicationPricingTrio

Kardeş akışlar — KAPSAM DIŞI, ama paylaşılan servis/DTO/utility olabilir:
  cct/page/acq/annulment
  cct/page/acq/application
  cct/page/acq/branchopening
  cct/page/acq/inquiry

## Bu akışta özellikle dikkat
- Ekranlar arası taşınan state (akış bağlamı) analizin merkezidir; tek bir
  ekranın içine bakarak görülemez.
- *Popup sonekli ekranlar modal'dır: farklı yaşam döngüsü, parent'a dönüş
  değeri ile veri verirler. Adım sayfalarından ayrı kategoridir.
- İsim benzeri ikizler kopya mantık adayıdır ve özel olarak karşılaştırılmalıdır:
  ApplicationAccount / ApplicationAccountEdit
  ApplicationPricing / ApplicationPricingTrio
  TagInquiry / TagOperation

## Domain
ACQ = Acquiring / Merchant (üye işyeri) — kartlı ödeme kabul tarafı.
entry = üye işyeri başvuru giriş akışı.
```

---

## B0a — Envanter ve Sınıflandırma

> Kısa tur. Ön-tarama çıktıları hazır olmalı.

```
[BLOK A BURAYA]

# ROL
Kıdemli yazılım mimarısın. Kod yazmayacaksın.

# GİRDİ — ön-tarama çıktıları (hazır, yeniden tarama YAPMA)
#file:docs/entry-akis/_tarama/01-dosyalar.txt
#file:docs/entry-akis/_tarama/06-ekran-boyutlari.txt

# GÖREV
entry akışının ekran envanterini çıkar ve her ekranı sınıflandır.
Bu turda SADECE envanter ve sınıflandırma var — geçiş grafiği, state, servis
analizi SONRAKİ turlarda. Onlara girme.

# YÖNTEM
1. Tarama çıktısından her PG_* klasörünü ve dosyalarını tabloya dök.
   Dosya dörtlüsü (java / html / js / lang) eksik olanları işaretle.
2. Her ekranın SADECE .java dosyasının ilk ~60 satırına ve .html dosyasının
   başlık/ana bölümüne bak — tam okuma yapma. Amacın rolü anlamak.
3. Her ekranı sınıflandır: adım sayfası / modal popup / yardımcı görünüm /
   arama-sorgu ekranı. Gerekçeni yaz (isim soneki tek başına gerekçe değil —
   kodda kanıt ara).
4. Kodda göremediğini yazma. "DOĞRULANAMADI: <neden>".

# ÇIKTI
## 1. Ekran Envanteri
Tablo: Ekran | Tip | Sınıflandırma gerekçesi | java satır | html satır |
js satır | lang key sayısı | Eksik dosya | Bir cümlelik rol

## 2. Boyut Dağılımı
En büyük 5 ekran ve satır sayıları — hangileri derin analiz gerektirecek

## 3. Anomaliler
Dosya dörtlüsü eksik olanlar, beklenmedik ek dosyalar, isim konvansiyonu
dışına çıkanlar

# KURALLAR
[ÇALIŞMA DİSİPLİNİ BLOĞUNU BURAYA EKLE]
- Türkçe yaz, teknik terimleri İngilizce bırak.
- Ekranların İÇ mantığına girme. Sadece envanter.
- İYİLEŞTİRME ÖNERİSİ YAZMA.
- Çıktıyı docs/entry-akis/00a-envanter.md dosyasına yaz.
```

---

## B0b — Geçiş Grafiği ve Giriş/Çıkış

> Kısa tur. Girdisi hazır grep çıktısı — model tarama yapmaz, yorumlar.

```
[BLOK A BURAYA]

# GİRDİ
#file:docs/entry-akis/00a-envanter.md
#file:docs/entry-akis/_tarama/02-gecisler.txt
#file:docs/entry-akis/_tarama/04-giris-noktalari.txt

# GÖREV
Ekranlar arası geçiş grafiğini ve akışın giriş/çıkış noktalarını çıkar.
Bu turda state ve servis analizi YOK — sonraki turda.

# YÖNTEM
1. 02-gecisler.txt içindeki her satırı incele. Her çağrı için: kim çağırıyor,
   hangi ekranı açıyor, hangi koşulla, hangi parametreyi taşıyarak.
   Hedefi satırdan anlaşılmıyorsa SADECE o dosyanın ilgili bölümünü aç.
2. Geri dönüş yollarını çıkar: modal kapanınca / adım tamamlanınca parent'a
   nasıl dönülüyor, dönüş değeri var mı.
3. 04-giris-noktalari.txt ile akışa dışarıdan girişleri belirle. Kardeş
   akışlardan (annulment / application / branchopening / inquiry) hangileri
   entry ekranlarını çağırıyor.
4. Akış tamamlanınca ve iptal edilince nereye gidiliyor.
5. Kodda göremediğini yazma. "DOĞRULANAMADI: <neden>".

# ÇIKTI
## 1. Geçiş Grafiği
Mermaid flowchart — düğümler ekranlar, oklar geçişler. Ok etiketi = tetikleyici
(buton/event) + taşınan parametre. Modal'ları farklı şekille göster.

## 2. Geçiş Tablosu
Kaynak | Hedef | Mekanizma (startNewProcess/CCT/dialog) | Koşul |
Taşınan parametre | Dönüş değeri | Kod referansı

## 3. Giriş ve Çıkış Noktaları
Akışa nereden giriliyor (kardeş akışlar dahil), hangi ön koşullarla,
tamamlanınca / iptal edilince nereye gidiliyor

## 4. Ulaşılamayan Ekranlar
Envanterde olup grafikte hiçbir geçişle açılmayan ekranlar — ölü ekran şüphesi

# KURALLAR
[ÇALIŞMA DİSİPLİNİ BLOĞUNU BURAYA EKLE]
- Türkçe yaz, teknik terimleri İngilizce bırak.
- Her geçişin yanında dosya:satır referansı olsun.
- State ve servis analizine GİRME.
- İYİLEŞTİRME ÖNERİSİ YAZMA.
- Çıktıyı docs/entry-akis/00b-gecis-grafigi.md dosyasına yaz.
```

---

## B0c — State, Servis, İkizler ve Plan

> B0'ın en değerli turu. Sonraki tüm adımların önceliğini bu belirliyor.

```
[BLOK A BURAYA]

# GİRDİ
#file:docs/entry-akis/00a-envanter.md
#file:docs/entry-akis/00b-gecis-grafigi.md
#file:docs/entry-akis/_tarama/03-servisler.txt
#file:docs/entry-akis/_tarama/05-state.txt
#file:docs/entry-akis/_tarama/06-ekran-boyutlari.txt

# GÖREV
Adımlar arası paylaşılan state'i, servis kesişimini ve ikiz ekranları çıkar;
sonra derin analiz planını üret.

# YÖNTEM
1. PAYLAŞILAN STATE — bu turun en kritik adımı:
   05-state.txt'deki her kullanımı incele. Adımlar arası taşınan her veri
   parçası için: nerede saklanıyor (session / process context / CCT parametresi /
   gizli form alanı / servisten yeniden okuma), hangi ekranda YAZILIYOR,
   hangi ekranda OKUNUYOR.
   Geçiş tablosundaki "taşınan parametre" sütunuyla çapraz kontrol et.

2. SERVİS KESİŞİMİ: 03-servisler.txt'den hangi arayüz metodunun kaç farklı
   ekrandan çağrıldığını çıkar. Aynı metot farklı parametrelerle mi çağrılıyor?

3. İKİZ / VARYANT TARAMASI: Primer'daki ikizleri (Account/AccountEdit,
   Pricing/PricingTrio, TagInquiry/TagOperation) ve envanterden tespit ettiğin
   diğer benzerleri karşılaştır: dosya boyutları, ortak metot adları, ortak
   DTO'lar, ortak lang key'leri. Bu turda YÜZEYSEL bak — "kopya şüphesi
   VAR / YOK / İNCELENMELİ" düzeyinde yeter.

4. DERİN ANALİZ PLANI: 14 ekranı 6-8 gruba indir.

5. Kodda göremediğini yazma. "DOĞRULANAMADI: <neden>".

# ÇIKTI
## 1. Paylaşılan State Sözlüğü
Tablo: Veri | Saklandığı yer | Yazan ekran(lar) | Okuyan ekran(lar) | Tip |
Akış sonunda ne oluyor
Ayrıca açıkça listele:
- Yazılıp hiç okunmayan veriler
- Okunup hiç yazılmayan (dışarıdan gelmesi beklenen) veriler

## 2. Servis Paylaşım Matrisi
Tablo: Intf metodu | Çağıran ekranlar | Çağrı sayısı | Aynı parametrelerle mi

## 3. İkiz / Varyant Adayları
Tablo: Ekran A | Ekran B | Benzerlik kanıtı | Kopya şüphesi (VAR/YOK/İNCELENMELİ)

## 4. DERİN ANALİZ PLANI
Ekranları önem sırasına diz ve gruplandır. Her grup için:
- Grup adı ve içindeki ekranlar
- Neden birlikte analiz edilmeli (ortak state / ikiz / ardışık adım)
- Derinlik: TAM (çekirdek adım) veya ÖZET (yardımcı/popup)
- Tahmini büyüklük (toplam satır) — 2000 satırı aşan grubu ikiye böl
Bu plan Blok B1 çalıştırmalarının girdisi olacak.

## 5. Açık Sorular
Haritadan çözülemeyen, koda derin bakmadan cevaplanamayacak sorular

# KURALLAR
[ÇALIŞMA DİSİPLİNİ BLOĞUNU BURAYA EKLE]
- Türkçe yaz, teknik terimleri İngilizce bırak.
- Her iddianın yanında dosya:satır referansı olsun.
- Ekranların İÇ mantığına girme (validasyon detayı, DTO alan listesi YOK).
- İYİLEŞTİRME ÖNERİSİ YAZMA.
- Çıktıyı docs/entry-akis/00c-state-ve-plan.md dosyasına yaz.
```

---

## Blok B1 — Ekran Kartı

> B0'ın ürettiği **Derin Analiz Planı**'ndaki her grup için bir kez çalıştırılır
> (~6-8 çalıştırma). Her seferinde yeni chat aç.

```
[BLOK A BURAYA]

# BAĞLAM
#file:docs/entry-akis/00a-envanter.md
#file:docs/entry-akis/00b-gecis-grafigi.md
#file:docs/entry-akis/00c-state-ve-plan.md
Akış haritası (B0a-b-c) doğrulandı. Bu turda plandaki tek bir gruba
derinlemesine bakacaksın.

# BU TURUN KAPSAMI
Grup      : <00c'deki Derin Analiz Planı'ndan grup adı>
Ekranlar  : <PG_X, PG_Y>
Derinlik  : <TAM | ÖZET>
Dosyalar  : #file:... (her ekranın java / html / js dosyalarını tek tek ver)

# YÖNTEM
1. YAŞAM DÖNGÜSÜ: PG_ sınıfında hangi metotlar framework tarafından çağrılıyor
   (init / load / prepare vb.), hangileri event handler? Komşu PG_ sınıflarıyla
   karşılaştırarak türet, kaynağını belirt.

2. EVENT ZİNCİRİ: .js ve .java içindeki TÜM fireEvent çağrılarını bul. Her event
   adını STRING olarak her iki repoda ara: kim tetikliyor, kim dinliyor.
   Dinleyicisi yoksa "DİNLEYİCİSİ BULUNAMADI", tetikleyicisi yoksa
   "ÖLÜ HANDLER ŞÜPHESİ" diye işaretle.

3. SERVİS ÇAĞRILARI: Çağrılan her HMN_*_Intf metodu için BE'deki
   HMN_ACQ_Merchant_Internal implementasyonunu bul. BE'ye erişemiyorsan
   arayüz imzası + Model DTO'sunu çıkar, "BE TARAFI ANALİZ EDİLMEDİ" notu düş —
   implementasyonu TAHMİN ETME.

4. DTO: HMN_ACQ_Merchant_Model içinde kullanılan sınıflar; alan bazlı Jackson
   anotasyonları (@JsonProperty, @JsonIgnore, @JsonFormat, @JsonInclude).

5. VALİDASYON: Her kuralın NEREDE uygulandığını tespit et (js / PG_ controller /
   Intf / Internal / DB).

6. i18n: Kullanılan lang key'leri; tr-en eksikleri; kullanılmayan key'ler;
   hardcoded metinler.

7. AKIŞ SÖZLEŞMESİ: Bu ekran akış state'inden NEYİ OKUYOR (ön koşul), akışa
   NEYİ YAZIYOR (son koşul)? Beklediği veri gelmezse ne oluyor?

8. Gruptaki ekranlar ikizse: aynı işi yapan kod parçalarını YAN YANA karşılaştır,
   davranış farklarını tek tek listele.

9. Kodda göremediğini yazma. "DOĞRULANAMADI: <neden>".

# ÇIKTI FORMATI — her ekran için ayrı kart

## <PG_EkranAdı>
### Künye
Tip, akıştaki yeri, nereden açılıyor, yetki/rol koşulu

### Akış Sözleşmesi
| Yön | Veri | Kaynak/Hedef | Zorunlu mu | Yoksa ne oluyor |
(Yön = OKUR / YAZAR)

### Yaşam Döngüsü
Framework tarafından çağrılan metotlar, sırası, her adımda ne olduğu

### Event Haritası
Event | Tetikleyen (dosya:satır) | Dinleyen (dosya:satır) | Taşıdığı veri | Durum

### İç Akışlar
Mutlu yol + alternatifler + hata yolları. Her biri için tetikleyici, adım adım
zincir (dosya:satır), Mermaid sequence diagram, yan etkiler

### Servis Çağrıları
Intf metodu | Impl | Girdi DTO | Çıktı DTO | Hata davranışı | Timeout/retry |
Kod referansı

### Veri Sözleşmesi
DTO alan tablosu: Alan | Tip | Zorunlu | Jackson anotasyonu | Null davranışı |
Enum değerleri | UI karşılığı

### Validasyon
Alan | Kural | Nerede | Hata mesajı | Lang key var mı | Kod referansı
Ayrıca: sadece js'te olanlar; sadece BE'de olup UI'a yansımayanlar

### Dialog ve Geri Bildirim
showCustomMessageBox ve diğer dialog çağrıları: nerede, bloklayıcı mı,
lokalize mi, iptal edilirse ne oluyor

### i18n
Dört liste: tr'de var en'de yok / en'de var tr'de yok / kullanılmayan / hardcoded

### Ölü ve Şüpheli Kod
Kanıtıyla birlikte

### Açık Sorular

## Grup İçi Karşılaştırma
(Sadece ikiz gruplarda) Tablo: Konu | Ekran A davranışı | Ekran B davranışı |
Fark kasıtlı mı görünüyor | Kod referansları

# KURALLAR
- Derinlik ÖZET ise: Akış Sözleşmesi, Servis Çağrıları, Validasyon ve Dialog
  bölümlerini doldur; diğerlerini tek paragrafla geç.
- Her iddianın yanında dosya:satır referansı.
- Kod bloğu yapıştırma; sadece kritik 5-10 satırı alıntıla.
- İYİLEŞTİRME ÖNERİSİ YAZMA.
- Çıktıyı docs/entry-akis/ekranlar/<grup-adi>.md dosyasına yaz.
```

---

## Blok B2 — Konsolidasyon

> Tüm kartlar bittikten sonra bir kez. Akışın asıl problemleri burada ortaya
> çıkıyor — hiçbiri tek ekranın içinde durmuyor.

```
[BLOK A BURAYA]

# BAĞLAM
#file:docs/entry-akis/00b-gecis-grafigi.md
#file:docs/entry-akis/00c-state-ve-plan.md
#file:docs/entry-akis/ekranlar/<grup-1>.md
#file:docs/entry-akis/ekranlar/<grup-2>.md
... (tüm kartları ekle)

# GÖREV
Ekran kartlarını birleştirip AKIŞ SEVİYESİNDE görünüm üret. Tek ekranın içinde
görünmeyen, ancak ekranlar yan yana konunca ortaya çıkan şeyleri ara.
Şüphelendiğin her noktayı kodda doğrula.

# ÇIKTI FORMATI

## 1. Uçtan Uca Senaryolar
Her biri için Mermaid sequence diagram + adım adım anlatım:
- Mutlu yol: başvuru baştan sona
- Geri dönüş: kullanıcı önceki adıma dönerse state'e ne oluyor
- İptal: yarıda bırakılırsa ne kaydedilmiş kalıyor
- Oturum kopması / timeout
- Her adımdaki başlıca hata yolları

## 2. Akış State Bütünlüğü
- Yazılıp hiç okunmayan veriler
- Okunduğu halde her yoldan yazılmayan veriler (bazı yollarda boş gelir)
- Aynı verinin farklı ekranlarda farklı isim/tiple taşındığı yerler
- Geri dönüşte temizlenmeyen artık state

## 3. Validasyon Tutarlılık Matrisi
Tablo: Alan | Ekran | Kural | Nerede uygulanıyor
Aynı alanı birden fazla ekran doğruluyorsa satırları yan yana koy ve
ÇELİŞKİLERİ işaretle. Ayrıca akış genelinde:
- Hiçbir yerde sunucu tarafı karşılığı olmayan kurallar
- Bir ekranda zorunlu, diğerinde opsiyonel olan alanlar

## 4. Birleşik Veri Sözleşmesi
Akışın tamamında kullanılan DTO'lar; hangi ekranda hangi alt kümesi kullanılıyor;
aynı kavramı temsil eden farklı DTO'lar

## 5. Servis Çağrı Envanteri
Birleşik tablo + tespit: aynı veriyi tekrar tekrar çeken çağrılar,
gereksiz tekrar eden sorgular

## 6. Event Bütünlüğü
Akış genelinde dinleyicisi olmayan event'ler, birden çok dinleyicisi olup
sıra bağımlılığı taşıyanlar

## 7. Tekrarlanan Mantık Haritası
İkiz ekranlar ve diğer kopya kod bulguları: Ne tekrarlanıyor | Nerelerde |
Versiyonlar birbiriyle tutarlı mı | Hangisi doğru davranış

## 8. i18n Bütünlüğü
Akış genelinde eksik/hardcoded/ölü key'lerin birleşik listesi

## 9. Kapsam Dışına Bağımlılıklar
Kardeş akışlarla (annulment / application / branchopening / inquiry) paylaşılan
servis, DTO, utility, state. Bu akışta değişiklik yapılırsa nereleri etkiler.

## 10. Açık Sorular
Tüm kartlardan gelen açık soruların birleşik ve tekilleştirilmiş listesi

# KURALLAR
- Kartlarda yazana körü körüne güvenme; çelişki gördüğün her yeri kodda doğrula.
- Kartlarda zaten yazılmış olanı tekrar etme; sadece BİRLEŞTİRİNCE ortaya
  çıkanı yaz.
- İYİLEŞTİRME ÖNERİSİ YAZMA.
- Çıktıyı docs/entry-akis/90-konsolidasyon.md dosyasına yaz.
```

---

## Blok C — Doğrulama Pası

> İki kez çalıştırılır: B0c'den sonra (harita için) ve B2'den sonra
> (konsolidasyon için). **Her zaman yeni chat'te** — aynı sohbette model kendi
> çıktısını savunma eğilimine giriyor.

```
[BLOK A BURAYA]

# GÖREV
#file:<doğrulanacak dosya>
Bu dosya bir önceki turda üretildi. Onu ÜRETEN sen değilsin — eleştirel bir
denetçisin. Her dosya:satır referansını tek tek koda karşı doğrula.

# ÇIKTI
## Yanlış Referanslar
Tablo: İddia | Verilen referans | Kodda gerçekte ne var | Durum

## Uydurulmuş İçerik
Kodda hiç karşılığı olmayan, tamamen üretilmiş iddialar

## Eksikler
Kodda var olup dokümanda hiç geçmeyen: ekran, geçiş, event, servis çağrısı,
validasyon, dialog, hata yolu

## Şüpheli Genellemeler
"Muhtemelen", "genellikle", "standart olarak" ile geçiştirilmiş kanıtsız yerler

# KURALLAR
- Doğru maddeleri tek tek onaylama, sadece PROBLEMLİ olanları listele.
- Hiç problem bulamazsan bunu açıkça söyle; uydurma bulgu üretme.
- Düzeltmeleri doğrudan dosyaya uygula ve neyi değiştirdiğini özetle.
```

---

## Blok D — İyileştirme Planı

> Harita + kartlar + konsolidasyon doğrulanıp elle gözden geçirildikten sonra.

```
[BLOK A BURAYA]

# BAĞLAM
#file:docs/entry-akis/00b-gecis-grafigi.md
#file:docs/entry-akis/00c-state-ve-plan.md
#file:docs/entry-akis/90-konsolidasyon.md
(gerekirse ilgili ekran kartları)
Bu dokümanlar gerçek koddan çıkarıldı, doğrulama pasından geçti ve tarafımdan
onaylandı. Başlangıç noktası al — ama iddia ettiğin her problemi kodda TEKRAR
doğrula.

# GÖREV
entry akışı için iyileştirme alanlarını çıkar. Kod yazma, plan üret.

# İNCELEME EKSENLERİ — AKIŞ SEVİYESİ
1. ADIM YAPISI
   Gereksiz adımlar; birleştirilebilir ekranlar; kullanıcıyı ileri-geri
   gezdiren düzen; adım sayısının iş değerine oranı

2. STATE TAŞIMA
   Adımlar arası veri taşıma mekanizmasının kırılganlığı; geri dönüşte kaybolan
   veya temizlenmeyen state; yarıda kalan başvurunun (draft) yönetimi;
   oturum kopmasında veri kaybı

3. EKRANLAR ARASI TUTARSIZLIK
   Aynı alanın farklı ekranlarda farklı doğrulanması; aynı kavramın farklı
   isim/tiple taşınması; farklı hata mesajı dili

4. İKİZ EKRANLARIN KONSOLİDASYONU
   ApplicationAccount / ApplicationAccountEdit,
   ApplicationPricing / ApplicationPricingTrio,
   TagInquiry / TagOperation ve konsolidasyonda çıkan diğer kopyalar.
   Birleştirme mi, ortak parçayı çıkarma mı, olduğu gibi bırakma mı — gerekçesiyle

5. MODAL / POPUP DAVRANIŞI
   showCustomMessageBox ve popup ekranların bloklayıcılığı; iptal edilince
   parent'ta kalan yarım state; popup'tan dönen değerin doğrulanmaması

# İNCELEME EKSENLERİ — EKRAN SEVİYESİ
6. VALİDASYON BOŞLUĞU
   Sadece .js'te olup sunucuda karşılığı olmayan kurallar (atlatılabilir);
   BE'de olup UI'a yansımayan hatalar; FE-BE çelişkileri

7. SÖZLEŞME SAĞLIĞI
   DTO-UI uyuşmazlıkları; Jackson anotasyon eksikleri (bilinmeyen alan, tarih
   formatı, null serialization); tip güvenliğinin kaybedildiği dönüşümler

8. EVENT HİJYENİ
   Dinleyicisi olmayan event'ler; örtük sıra bağımlılığı; event üzerinden
   taşınan implicit state

9. KULLANICI GERİ BİLDİRİMİ
   Sessizce yutulan hatalar; teknik mesajların kullanıcıya gösterilmesi;
   loading / empty / kısmi veri durumlarının eksikliği

10. DAYANIKLILIK
    Timeout / retry eksikleri; HopeReportGenerator senkron rapor üretiminin
    bloklama ve zaman aşımı riski; exception yutan catch blokları; yarım kalan
    işlemde veri tutarlılığı

11. PERFORMANS
    Adım geçişlerinde tekrar eden servis çağrıları; N+1; paralelleştirilebilir
    seri çağrılar; over-fetching

12. i18n
    Eksik key, hardcoded metin, ölü key

13. GÜVENLİK / YETKİ
    Sadece istemci tarafında yapılan yetki kontrolü; loglara düşen PII veya
    işyeri/kart hassas verisi; bağımlılık sürümlerinin durumu (Jackson 2.9.6
    dahil — sürümü doğrula, bilinen risk varsa NOT olarak yaz, kesin iddia etme)

14. DEĞİŞİM RİSKİ
    Bu akışa dokunmadan önce hangi karakterizasyon testleri (characterization
    test) yazılmalı

15. İZOLASYON FIRSATLARI
    Strangler fig ile parça parça çıkarılabilecek, net sınırı olan alt-akışlar

# HER BULGU İÇİN FORMAT
### [B-01] <Kısa başlık>
- **Eksen:** <yukarıdaki 15'ten biri>
- **Kapsam:** <akış geneli | ekran adı/adları>
- **Kanıt:** <dosya:satır> — kodda tam olarak ne var
- **Neden problem:** somut başarısızlık senaryosu (hangi input/durum → hangi
  yanlış sonuç). "Best practice değil" gibi soyut gerekçe KABUL EDİLMEZ.
- **Etki:** kullanıcı etkisi + teknik etki
- **Önerilen çözüm:** somut yaklaşım, hangi dosyalar değişir
- **Etkilenen diğer ekran/akış/job:** (konsolidasyon Bölüm 9'u kullan)
- **Nasıl geri alınır / kırılırsa nereden anlarız**
- **Efor:** S / M / L — **Risk:** düşük / orta / yüksek
- **Alternatifler ve neden bunu seçtin**

# ÇIKTI
1. Bulgular, etki × efor'a göre sıralı
2. QUICK WINS — S efor + düşük risk
3. YAPISAL DEĞİŞİKLİKLER — M/L efor, her biri için before/after Mermaid diyagramı
4. DAVRANIŞ KORUYAN (refactor) ve DAVRANIŞ DEĞİŞTİREN (fix/feature) önerileri
   AYRI listele
5. ÖNCE YAZILMASI GEREKEN TESTLER — karakterizasyon testi listesi, akış
   seviyesi (uçtan uca) ve ekran seviyesi ayrı
6. BİLİNÇLİ OLARAK ÖNERMEDİKLERİM — değerlendirip elediklerin ve nedeni

# KURALLAR
- "Yeniden yazalım", "modern framework'e taşıyalım", "mimariyi değiştirelim"
  türü öneriler YASAK. Her öneri mevcut yapı içinde, artımlı ve geri
  alınabilir olmalı.
- Kanıtı olmayan bulgu yazma. En fazla 15 bulgu — kaliteyi sayıyla takas etme.
- Bir davranışın NEDEN öyle olduğu belirsizse öneri üretme; "Açık Sorular"a ekle.
- Kod yazma. Onay verilince implementasyona geçilecek.
- Çıktıyı docs/entry-akis/99-iyilestirme.md dosyasına yaz.
```

---

## Tek ekran modu

Akış değil tek bir ekran analiz edilecekse:

- **Ön-tarama ve B0a/B0b/B0c atlanır.** Blok A'daki "ANALİZ KAPSAMI" bölümünü
  tek ekrana göre yeniden yaz.
- **B1 tek çalıştırılır**, `Derinlik: TAM`, `# BAĞLAM` satırındaki harita
  referansı silinir.
- **B2 atlanır**, yerine kartın kendisi Blok D'ye girdi olur.
- **C ve D** aynen kullanılır; D'de 1-5 arası akış seviyesi eksenler düşer.

## Çok büyük tek ekran

Bir PG_ ekranı tek başına 1500+ satırsa B1'i üç pasa böl, her pasta Blok A'yı
tekrar yapıştır:

| Pas | Yöntem adımları | Çıktı bölümleri |
|---|---|---|
| 1 | 1, 2, 7 | Künye, Akış Sözleşmesi, Yaşam Döngüsü, Event Haritası |
| 2 | 3, 4 | Servis Çağrıları, Veri Sözleşmesi |
| 3 | 5, 6 | Validasyon, Dialog, i18n, Ölü Kod |

Sonra dördüncü pasta üç çıktıyı `#file:` ile verip "İç Akışlar" bölümünü yazdır —
o bölüm diğer hepsine dayandığı için en sona bırakılmalı.
