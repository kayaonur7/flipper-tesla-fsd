# Harmoni Legacy Akış Analizi — Çalıştırma Kılavuzu

Bu klasör, Harmoni legacy akışlarının uçtan uca analizi ve iyileştirme planı
için hazırlanmış prompt setini içerir. Promptlar: [PROMPTS.md](./PROMPTS.md)

**Hedef akış:** `cct/page/acq/entry` — 14 alt ekrandan oluşan üye işyeri başvuru
akışı.

**Amaç:** Akışın uçtan uca hangi adımlardan geçtiğini, nerelerde entegrasyon
yaptığını, hangi veri tiplerini ve validasyonları kullandığını koda dayalı
belgelemek; ardından iyileştirme alanlarını çıkarmak.

---

## Neden bu yapı

Üç tasarım kararı, çıktı kalitesinin tamamını belirliyor:

**1. Analiz ile öneri ayrı.** Tek prompt'ta istendiğinde model analizin
yarısında değerlendirmeye kayıyor ve envanter eksik kalıyor.

**2. Keşif shell'e, yorum modele.** Copilot'un 14 klasörü tarayarak envanter
çıkarması hem yavaş hem eksik — uzun turlar tool-call limitine ve istek zaman
aşımına takılıyor, ayrıca model bazı klasörleri sessizce atlıyor. `grep`/`find`
atlamaz. Ön-tarama script'i çıktıları workspace'e dosya olarak yazıyor, prompt'a
`#file:` ile veriliyor; model arama yapmıyor, hazır çıktıyı yorumluyor.

**3. Akış seviyesi ile ekran seviyesi ayrı.** 14 ekranı tek pasta analiz etmek
context'e sığmıyor; model ilk 3-4 ekranı düzgün, gerisini yüzeysel işliyor.
Ayrıca bir başvuru akışında asıl karmaşıklık ekranların *içinde* değil
*arasında* — adımlar arası taşınan state, tekrarlanan validasyonlar, ikiz
ekranlar. Bunların hiçbiri tekil ekran analizinde görünmüyor, o yüzden ayrı bir
konsolidasyon pası var.

**4. Doğrulama pası zorunlu.** Harmoni eğitim verisinde olmadığı için model
boşlukları tanıdığı framework'lerin konvansiyonlarıyla dolduruyor — ve bunu
söylemeden yapıyor.

---

## Akış şeması

```
Adım 0  Ön hazırlık (bir kez)
   ↓
Adım 1  Blok A primer'ını kontrol et
   ↓
Adım 2  Ön-tarama shell komutları → _tarama/*.txt      (Copilot'suz)
   ↓
Adım 3  B0a → 00a-envanter.md
        B0b → 00b-gecis-grafigi.md
        B0c → 00c-state-ve-plan.md
   ↓
Adım 4  Blok C (harita doğrulama)  ─┐
Adım 5  Elle spot-check             ─┴→ harita güvenilir
   ↓
Adım 6  Blok B1 × grup sayısı → ekranlar/<grup>.md
   ↓
Adım 7  Blok B2 → 90-konsolidasyon.md
   ↓
Adım 8  Blok C (konsolidasyon doğrulama) + elle spot-check
   ↓
Adım 9  Blok D → 99-iyilestirme.md
   ↓
Adım 10 Bulgu bulgu implementasyon
```

Beklenen toplam: **13-16 Copilot çalıştırması**, her biri kısa.

Üretilecek dosya yapısı:

```
docs/entry-akis/
  _tarama/                  ← shell çıktıları, Adım 2
    01-dosyalar.txt
    02-gecisler.txt
    03-servisler.txt
    04-giris-noktalari.txt
    05-state.txt
    06-ekran-boyutlari.txt
  00a-envanter.md
  00b-gecis-grafigi.md
  00c-state-ve-plan.md
  ekranlar/
    <grup-1>.md
    <grup-2>.md
    ...
  90-konsolidasyon.md
  99-iyilestirme.md
```

---

## Adım 0 — Ön hazırlık (bir kez)

### 0.1 İki repoyu tek workspace'e al

FE ve BE ayrı repolarda. Copilot repo sınırını tek başına geçemez; BE tarafı
sessizce analiz dışı kalır ve model FE'deki arayüz çağrısına bakıp
implementasyonu uydurur.

VS Code'da:

1. `hmnfe_acq_merchant` klasörünü aç
2. `File > Add Folder to Workspace…` → `hmn_acq_merchant` klasörünü ekle
3. `File > Save Workspace As…` → örn. `harmoni-acq.code-workspace`

Doğrulama: Copilot chat'e `#codebase HMN_ACQ_Merchant_Internal modülündeki
sınıfları listele` yaz. Sınıflar geliyorsa iki repo da indekslenmiş demektir.

### 0.2 Copilot ayarları

- **Agent mode** kullan, ask mode değil. Ask mode dosya gezinemez; sadece açık
  sekmelerden cevap üretir ve analizin çoğunu uydurur.
- Model olarak **Opus** seç.
- Analiz uzun sürer; chat'i ortasında kesme. "Continue to iterate?" çıkarsa devam et.

---

## Adım 1 — Blok A primer'ını kontrol et

[Blok A](./PROMPTS.md#blok-a--framework--akış-primer) içindeki primer, eldeki
stack ve klasör yapısı bilgisinden yazıldı. Kontrol et:

- Alt ekran listesi klasör yapısıyla birebir mi
- Farklı bir mekanizma var mı (başka dialog fonksiyonu, ek rapor yolu, farklı
  navigasyon çağrısı) — varsa "Mekanizmalar" bölümüne ekle
- İkiz aday listesine ekleyeceğin çift var mı

Primer ne kadar doğruysa analiz o kadar doğru çıkıyor. Bu blok tek başına
çalıştırılmaz — diğer blokların **her birinin başına** yapıştırılır.

---

## Adım 2 — Ön-tarama (terminalde, Copilot'suz)

Tek komut. **FE repo kökünde** çalıştır:

```bash
# macOS / Linux / WSL / Windows'ta Git Bash
bash docs/harmoni-ekran-analizi/scripts/on-tarama.sh
```

```powershell
# Windows PowerShell — VS Code'un varsayılan terminali
powershell -ExecutionPolicy Bypass -File docs\harmoni-ekran-analizi\scripts\on-tarama.ps1
```

Akış yolun farklıysa parametre ver: `... on-tarama.sh cct/page/acq/application`
(PowerShell'de `-Entry cct\page\acq\application`).

Script `docs/entry-akis/_tarama/` altına altı dosya yazar ve sonunda özet basar.
Bu çıktılar sonraki adımlarda `#file:` ile veriliyor; model klasör taramıyor,
hazır çıktıyı yorumluyor. **B0'ın uzun sürüp zaman aşımına düşmesinin temel
sebebi buydu.**

Özette kontrol et:

- **Ekran sayısı** beklediğin gibi mi (entry için 14) — değilse yol yanlış
- **`<< BOŞ` uyarısı** var mı — o mekanizma kullanılmıyor olabilir ya da isim
  farklıdır. Koddan doğrulayıp script içindeki deseni güncelle, tekrar çalıştır
- Boş çıktıyı **silme**. Modelin "arandı, bulunamadı" ile "hiç aranmadı"
  arasındaki farkı bilmesi gerekiyor

Desenleri değiştirmen gerekirse script'in içinde numaralı bloklar halinde
duruyor — `02-gecisler` bloğu navigasyon/dialog, `05-state` bloğu session
kullanımı için.

> **Script çalıştırma izni yoksa** (kurumsal execution policy): PROMPTS.md'deki
> [Script çalıştırılamıyorsa](./PROMPTS.md#script-çalıştırılamıyorsa) bölümünde
> dört alternatif var — Git Bash, komutları terminale doğrudan yapıştırma,
> VS Code arama arayüzü (hiç terminal gerektirmez) ve Copilot agent mode'a
> çalıştırtma.

---

## Adım 3 — Akış haritası (B0a → B0b → B0c)

Üç kısa tur, **her biri ayrı chat'te**, sırayla:

| Tur | Prompt | Girdi | Çıktı |
|---|---|---|---|
| 3.1 | [B0a](./PROMPTS.md#b0a--envanter-ve-sınıflandırma) | `_tarama/01`, `_tarama/06` | `00a-envanter.md` |
| 3.2 | [B0b](./PROMPTS.md#b0b--geçiş-grafiği-ve-girişçıkış) | `00a` + `_tarama/02`, `_tarama/04` | `00b-gecis-grafigi.md` |
| 3.3 | [B0c](./PROMPTS.md#b0c--state-servis-ikizler-ve-plan) | `00a`, `00b` + `_tarama/03`, `05`, `06` | `00c-state-ve-plan.md` |

Her prompt için:

1. Yeni chat aç
2. Bloğu kopyala, `[BLOK A BURAYA]` yerine Blok A'yı yapıştır
3. `# KURALLAR` içindeki `[ÇALIŞMA DİSİPLİNİ BLOĞUNU BURAYA EKLE]` yerine
   [Çalışma Disiplini](./PROMPTS.md#çalışma-disiplini) bloğunu yapıştır
4. Gönder

Çıktının en değerli iki bölümü `00c` içinde:

- **Paylaşılan State Sözlüğü** — akışın gerçek karmaşıklığı burada
- **Derin Analiz Planı** — 14 ekranı 6-8 gruba indirir, Adım 6'nın girdisi

> Bir tur yine de yarıda kesilirse: aynı prompt'u yeni chat'te tekrar gönder.
> Çalışma Disiplini bloğu modele "hedef dosyayı oku, kaldığın yerden devam et"
> dediği için baştan başlamaz.

---

## Adım 4 — Harita doğrulama (Blok C)

**Yeni chat aç.** Aynı sohbette çalıştırırsan model kendi çıktısını savunur.

[Blok C](./PROMPTS.md#blok-c--doğrulama-pası)'yi kopyala, başına Blok A'yı ekle,
`#file:` satırlarına üç harita dosyasını da yaz (`00a`, `00b`, `00c`).

---

## Adım 5 — Elle spot-check (atlama)

Harita sonraki her adımın temeli. Yanlışsa 6-8 ekran kartı da yanlış çıkar.

Kendin kontrol et:

- **Envanter eksiksiz mi** — 14 ekranın hepsi var mı, klasörle karşılaştır
- **Geçiş grafiğinden 3 ok seç**, kod referanslarını aç, gerçekten o geçiş var mı
- **Paylaşılan state sözlüğünden 2 satır seç**, "yazan ekran" gerçekten yazıyor mu
- **Derin analiz planındaki gruplama mantıklı mı** — sen daha iyi biliyorsun,
  gerekirse elle düzelt

Bir hata bulursan düzelt ve Adım 4'ü tekrarla.

---

## Adım 6 — Ekran kartları (Blok B1 × grup sayısı)

`00c` içindeki **Derin Analiz Planı**'ndaki her grup için bir kez:

1. Yeni chat aç (her grup için ayrı — aynı chat'te devam etme, context dolar)
2. [Blok B1](./PROMPTS.md#blok-b1--ekran-kartı)'i kopyala, başına Blok A'yı ekle
3. `# KURALLAR` içine Çalışma Disiplini bloğunu yapıştır
4. `# BU TURUN KAPSAMI` bölümünü doldur:
   - Grup adı ve ekranlar (plandan al)
   - Derinlik: TAM veya ÖZET (plandan al)
   - Her ekranın `.java`, `.html`, `.js` dosya yolları — **`#file:` ile tek tek**
5. Gönder

> **Dosya yollarını mutlaka `#file:` ile ver.** Sadece `#codebase` yeterli değil —
> Harmoni'de modüler yapı ve tip grafiği zayıf olduğu için semantik arama ekran
> ağacının derinlerine (servis katmanı, DTO'lar) çoğu zaman inemiyor.

**Çıktı:** `docs/entry-akis/ekranlar/<grup-adi>.md`

Her kartın **Akış Sözleşmesi** bölümü (ekran neyi okuyor / neyi yazıyor) Adım
7'nin hammaddesi. Boş veya yüzeysel çıktıysa o grubu tekrar çalıştır — o bölüm
olmadan konsolidasyon yapılamıyor.

Grup 2000 satırı aşıyorsa ikiye böl. Tek bir PG_ ekranı 1500+ satırsa
PROMPTS.md sonundaki [bölme tablosunu](./PROMPTS.md#çok-büyük-tek-ekran) uygula.

---

## Adım 7 — Konsolidasyon (Blok B2)

1. Yeni chat aç
2. [Blok B2](./PROMPTS.md#blok-b2--konsolidasyon)'yi kopyala, başına Blok A'yı ekle
3. `# KURALLAR` içine Çalışma Disiplini bloğunu yapıştır
4. `# BAĞLAM` bölümüne `00b`, `00c` ve **tüm** kartları `#file:` ile ekle
5. Gönder

**Çıktı:** `docs/entry-akis/90-konsolidasyon.md`

Akışın asıl bulguları burada çıkıyor: adımlar arası validasyon çelişkileri,
kopya mantık, yazılıp okunmayan state, geri dönüşte temizlenmeyen artıklar.

Kart sayısı fazlaysa bu tur da uzayabilir. Kesilirse çıktı bölümlerini ikiye
böl: önce Bölüm 1-5, sonra ayrı bir turda Bölüm 6-10 (ilk turun çıktısını
`#file:` ile vererek).

---

## Adım 8 — Konsolidasyon doğrulama + spot-check

Adım 4 ve 5'in aynısı, hedef dosya `90-konsolidasyon.md`.

Bu sefer spot-check'te özellikle şuna bak: **Validasyon Tutarlılık
Matrisi**'nden 3 satır seç ve kod referanslarını aç. En sık görülen hata,
var olmayan bir validasyonun veya retry mekanizmasının raporlanması — bu yanlış
Blok D'ye taşınırsa tüm iyileştirme planı çürük temele oturur.

---

## Adım 9 — İyileştirme planı (Blok D)

1. Yeni chat aç
2. [Blok D](./PROMPTS.md#blok-d--iyileştirme-planı)'yi kopyala, başına Blok A'yı ekle
3. `00b`, `00c` ve konsolidasyonu `#file:` ile ver (gerekirse ilgili kartları da)
4. Gönder

**Çıktı:** `docs/entry-akis/99-iyilestirme.md` — bulgular, quick win'ler,
yapısal değişiklikler, önce yazılması gereken karakterizasyon testleri.

---

## Adım 10 — Uygulama

Blok D kod yazmaz, bilinçli olarak. Planı gözden geçirip hangi bulguların
yapılacağına karar ver, sonra bulgu bulgu implementasyon iste:

```
#file:docs/entry-akis/99-iyilestirme.md
[B-03] numaralı bulguyu uygula. Plandaki "Önerilen çözüm" bölümüne sadık kal.
Önce bulgudaki karakterizasyon testini yaz, testin mevcut davranışta geçtiğini
doğrula, sonra değişikliği yap.
```

Bulguları teker teker uygula — toplu istendiğinde model plandan sapıyor.

---

## Sorun giderme

| Belirti | Sebep | Çözüm |
|---|---|---|
| **Tur uzun sürüp network / timeout hatası veriyor** | Tek turda çok fazla dosya okuma ve arama | Ön-tarama script'ini çalıştırdığından emin ol; Çalışma Disiplini bloğunu prompt'a ekle; turu daha küçük parçaya böl |
| Bir tarama dosyası hiç oluşmadı (PowerShell) | Sıfır eşleşme — boş pipeline `Set-Content`'e ulaşmıyor | Desen bu kod tabanına uymuyor: [Desen tutmadıysa](./PROMPTS.md#desen-tutmadıysa-gerçek-desenleri-koddan-çıkar) bölümündeki K1-K5 keşif komutlarıyla gerçek deseni bul |
| `04-giris-noktalari` boş | Literal klasör adı aranmış; navigasyon sayfa sınıfını referanslıyor | Script güncellendi (ekran adlarını arıyor); elle çalıştırıyorsan K5 komutunu kullan |
| `grep: command not found` / `find` beklenmedik çalışıyor | PowerShell'de bash komutu | `on-tarama.ps1` kullan, veya terminali Git Bash'e çevir (VS Code: terminal panelinde `+` yanındaki ok → Git Bash) |
| PowerShell "execution policy" hatası, script çalıştırılamıyor | Kurumsal politika `.ps1` dosyalarını engelliyor | [Script çalıştırılamıyorsa](./PROMPTS.md#script-çalıştırılamıyorsa) — Git Bash, komutları doğrudan yapıştırma, veya VS Code arama arayüzü |
| Tur yarıda kesildi, kısmi çıktı var | İstek zaman aşımı | Aynı prompt'u yeni chat'te tekrar gönder — Çalışma Disiplini bloğu "kaldığın yerden devam et" der |
| "Continue to iterate?" çıkıyor | Agent mode tool-call limiti | Devam et; sık oluyorsa ön-tarama çıktılarının verildiğini kontrol et (model hâlâ kendi arama yapıyor olabilir) |
| BE tarafı hiç analiz edilmemiş, "BE TARAFI ANALİZ EDİLMEDİ" notları var | İkinci repo workspace'te değil veya indekslenmemiş | Adım 0.1'i tekrarla, doğrulama komutunu çalıştır |
| Envanter 14 ekranın hepsini kapsamıyor | Model tarama çıktısını okumak yerine tahmin etmiş | `_tarama/01-dosyalar.txt` dosyasını `#file:` ile verdiğinden emin ol |
| Geçiş grafiği boş veya çok kısa | `02-gecisler.txt` boş — grep deseni tutmamış | Mekanizma adlarını koddan doğrula, grep desenini düzelt, taramayı tekrarla |
| Ekran kartlarında Akış Sözleşmesi boş | Model haritayı okumadan karta girmiş | `00c`'yi `#file:` ile verdiğinden emin ol; o grubu tekrar çalıştır |
| Konsolidasyon kartları tekrar ediyor, yeni bilgi yok | "Sadece birleştirince ortaya çıkanı yaz" kuralı silinmiş | Blok B2 `# KURALLAR` bölümünü aynen koru |
| Framework mekanizmaları Spring/JSF terimleriyle anlatılmış | Blok A yapıştırılmamış veya zayıf | Blok A'yı yapıştırdığından emin ol; eksik mekanizmaları primer'a ekle |
| Sonraki blok önceki çıktıyı "hatırlamıyor" | Chat geçmişi context penceresinden düşmüş | Her çıktıyı dosyaya yazdır, `#file:` ile geri ver — chat geçmişine güvenme |
| Model kendi hatasını kabul etmiyor | Doğrulama aynı sohbette çalıştırılmış | Blok C'yi mutlaka yeni chat'te çalıştır |
| Öneriler "yeniden yazalım / modern framework'e geçelim" diyor | Blok D'deki yasak kural silinmiş | `# KURALLAR` bölümünü aynen koru |

---

## Notlar

- Promptlar Türkçe çıktı üretecek şekilde yazıldı; teknik terimler İngilizce
  kalıyor.
- `_tarama/` çıktıları büyük olabilir; repoya commit'lemek istemezsen
  `.gitignore`'a ekle. Analiz dokümanlarını commit'lemek ise faydalı — bir
  sonraki akışta (annulment, application, branchopening, inquiry) komşu referans
  olarak kullanılabiliyor ve model konvansiyonu oradan türetiyor.
- Aynı set diğer `cct/page/acq/*` akışları için de kullanılabilir: Blok A'daki
  "ANALİZ KAPSAMI" bölümündeki klasör ve ekran listesini, ön-tarama
  komutlarındaki `E=` değişkenini değiştirmek yeterli.
- Tek ekranlık analiz için PROMPTS.md'deki
  [Tek ekran modu](./PROMPTS.md#tek-ekran-modu) bölümüne bak.
