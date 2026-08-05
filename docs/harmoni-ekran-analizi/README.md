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

**2. Akış seviyesi ile ekran seviyesi ayrı.** 14 ekranı tek pasta analiz etmek
context'e sığmıyor; model ilk 3-4 ekranı düzgün, gerisini yüzeysel işliyor.
Ayrıca bir başvuru akışında asıl karmaşıklık ekranların *içinde* değil
*arasında* — adımlar arası taşınan state, tekrarlanan validasyonlar, ikiz
ekranlar. Bunların hiçbiri tekil ekran analizinde görünmüyor, o yüzden ayrı bir
konsolidasyon pası var.

**3. Doğrulama pası zorunlu.** Harmoni eğitim verisinde olmadığı için model
boşlukları tanıdığı framework'lerin konvansiyonlarıyla dolduruyor — ve bunu
söylemeden yapıyor.

---

## Akış şeması

```
Adım 0  Ön hazırlık (bir kez)
   ↓
Adım 1  Blok A primer'ını kontrol et
   ↓
Adım 2  Blok B0 → 00-akis-haritasi.md
   ↓
Adım 3  Blok C (harita doğrulama)  ─┐
Adım 4  Elle spot-check             ─┴→ harita güvenilir
   ↓
Adım 5  Blok B1 × grup sayısı → ekranlar/<grup>.md
   ↓
Adım 6  Blok B2 → 90-konsolidasyon.md
   ↓
Adım 7  Blok C (konsolidasyon doğrulama) + elle spot-check
   ↓
Adım 8  Blok D → 99-iyilestirme.md
   ↓
Adım 9  Bulgu bulgu implementasyon
```

Beklenen toplam: **11-14 Copilot çalıştırması.**

Üretilecek dosya yapısı:

```
docs/entry-akis/
  00-akis-haritasi.md
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
- Analiz uzun sürer; chat'i ortasında kesme.

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

## Adım 2 — Akış haritası (Blok B0)

1. Yeni Copilot chat aç
2. [Blok B0](./PROMPTS.md#blok-b0--akış-envanteri-ve-haritası)'ı kopyala
3. Başındaki `[BLOK A BURAYA]` yerine Blok A'yı yapıştır
4. Gönder

**Çıktı:** `docs/entry-akis/00-akis-haritasi.md`

Bu turda ekranların iç mantığına girilmez. Çıktının en önemli iki bölümü:

- **Bölüm 4 — Paylaşılan State Sözlüğü:** akışın gerçek karmaşıklığı burada
- **Bölüm 7 — Derin Analiz Planı:** 14 ekranı 6-8 gruba indirir, Adım 5'in girdisi

---

## Adım 3 — Harita doğrulama (Blok C)

**Yeni chat aç.** Aynı sohbette çalıştırırsan model kendi çıktısını savunur.

[Blok C](./PROMPTS.md#blok-c--doğrulama-pası)'yi kopyala, başına Blok A'yı ekle,
`#file:` satırına `docs/entry-akis/00-akis-haritasi.md` yaz.

---

## Adım 4 — Elle spot-check (atlama)

Harita sonraki her adımın temeli. Yanlışsa 6-8 ekran kartı da yanlış çıkar.

Kendin kontrol et:

- **Ekran envanteri eksiksiz mi** — 14 ekranın hepsi var mı, klasörle karşılaştır
- **Geçiş grafiğinden 3 ok seç**, kod referanslarını aç, gerçekten o geçiş var mı
- **Paylaşılan state sözlüğünden 2 satır seç**, "yazan ekran" gerçekten yazıyor mu
- **Derin analiz planındaki gruplama mantıklı mı** — sen daha iyi biliyorsun,
  gerekirse elle düzelt

Bir hata bulursan düzelt ve Adım 3'ü tekrarla.

---

## Adım 5 — Ekran kartları (Blok B1 × grup sayısı)

Haritadaki **Derin Analiz Planı**'ndaki her grup için bir kez:

1. Yeni chat aç (her grup için ayrı — aynı chat'te devam etme, context dolar)
2. [Blok B1](./PROMPTS.md#blok-b1--ekran-kartı)'i kopyala, başına Blok A'yı ekle
3. `# BU TURUN KAPSAMI` bölümünü doldur:
   - Grup adı ve ekranlar (haritadan al)
   - Derinlik: TAM veya ÖZET (haritadan al)
   - Her ekranın `.java`, `.html`, `.js` dosya yolları — **`#file:` ile tek tek**
4. Gönder

> **Dosya yollarını mutlaka `#file:` ile ver.** Sadece `#codebase` yeterli değil —
> Harmoni'de modüler yapı ve tip grafiği zayıf olduğu için semantik arama ekran
> ağacının derinlerine (servis katmanı, DTO'lar) çoğu zaman inemiyor.

**Çıktı:** `docs/entry-akis/ekranlar/<grup-adi>.md`

Her kartın **Akış Sözleşmesi** bölümü (ekran neyi okuyor / neyi yazıyor) Adım
6'nın hammaddesi. Boş veya yüzeysel çıktıysa o grubu tekrar çalıştır — o bölüm
olmadan konsolidasyon yapılamıyor.

Bir PG_ ekranı tek başına 1500+ satırsa PROMPTS.md sonundaki
[bölme tablosunu](./PROMPTS.md#çok-büyük-tek-ekran) uygula.

---

## Adım 6 — Konsolidasyon (Blok B2)

1. Yeni chat aç
2. [Blok B2](./PROMPTS.md#blok-b2--konsolidasyon)'yi kopyala, başına Blok A'yı ekle
3. `# BAĞLAM` bölümüne haritayı ve **tüm** kartları `#file:` ile ekle
4. Gönder

**Çıktı:** `docs/entry-akis/90-konsolidasyon.md`

Akışın asıl bulguları burada çıkıyor: adımlar arası validasyon çelişkileri,
kopya mantık, yazılıp okunmayan state, geri dönüşte temizlenmeyen artıklar.

---

## Adım 7 — Konsolidasyon doğrulama + spot-check

Adım 3 ve 4'ün aynısı, hedef dosya `90-konsolidasyon.md`.

Bu sefer spot-check'te özellikle şuna bak: **Validasyon Tutarlılık
Matrisi**'nden 3 satır seç ve kod referanslarını aç. En sık görülen hata,
var olmayan bir validasyonun veya retry mekanizmasının raporlanması — bu yanlış
Blok D'ye taşınırsa tüm iyileştirme planı çürük temele oturur.

---

## Adım 8 — İyileştirme planı (Blok D)

1. Yeni chat aç
2. [Blok D](./PROMPTS.md#blok-d--iyileştirme-planı)'yi kopyala, başına Blok A'yı ekle
3. Haritayı ve konsolidasyonu `#file:` ile ver (gerekirse ilgili kartları da)
4. Gönder

**Çıktı:** `docs/entry-akis/99-iyilestirme.md` — bulgular, quick win'ler,
yapısal değişiklikler, önce yazılması gereken karakterizasyon testleri.

---

## Adım 9 — Uygulama

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
| BE tarafı hiç analiz edilmemiş, "BE TARAFI ANALİZ EDİLMEDİ" notları var | İkinci repo workspace'te değil veya indekslenmemiş | Adım 0.1'i tekrarla, doğrulama komutunu çalıştır |
| B0 çıktısı 14 ekranın hepsini kapsamıyor | Model klasörleri listelemek yerine tahmin etmiş | Prompt'a ekle: "Önce entry altındaki klasörleri listele, sayısını yaz, sonra devam et" |
| Geçiş grafiği boş veya çok kısa | `startNewProcess` / `fireEvent` string araması yapılmamış, import takip edilmeye çalışılmış | Prompt'a ekle: "Önce her string'i tüm repoda ara ve eşleşme sayısını yaz, sonra devam et" |
| Ekran kartlarında Akış Sözleşmesi boş | Model haritayı okumadan karta girmiş | Haritayı `#file:` ile verdiğinden emin ol; o grubu tekrar çalıştır |
| Konsolidasyon kartları tekrar ediyor, yeni bilgi yok | "Sadece birleştirince ortaya çıkanı yaz" kuralı silinmiş | Blok B2 `# KURALLAR` bölümünü aynen koru |
| Çıktı yarıda kesiliyor | Grup çok büyük | Grubu ikiye böl, veya derinliği ÖZET'e çek |
| Framework mekanizmaları Spring/JSF terimleriyle anlatılmış | Blok A yapıştırılmamış veya zayıf | Blok A'yı yapıştırdığından emin ol; eksik mekanizmaları primer'a ekle |
| Sonraki blok önceki çıktıyı "hatırlamıyor" | Chat geçmişi context penceresinden düşmüş | Her çıktıyı dosyaya yazdır, `#file:` ile geri ver — chat geçmişine güvenme |
| Model kendi hatasını kabul etmiyor | Doğrulama aynı sohbette çalıştırılmış | Blok C'yi mutlaka yeni chat'te çalıştır |
| Öneriler "yeniden yazalım / modern framework'e geçelim" diyor | Blok D'deki yasak kural silinmiş | `# KURALLAR` bölümünü aynen koru |

---

## Notlar

- Promptlar Türkçe çıktı üretecek şekilde yazıldı; teknik terimler İngilizce
  kalıyor.
- Üretilen dokümanları repoya commit'lemek faydalı — bir sonraki akışta
  (annulment, application, branchopening, inquiry) komşu referans olarak
  kullanılabiliyor ve model konvansiyonu oradan türetiyor.
- Aynı set diğer `cct/page/acq/*` akışları için de kullanılabilir: Blok A'daki
  "ANALİZ KAPSAMI" bölümündeki klasör ve ekran listesini değiştirmek yeterli.
- Tek ekranlık analiz için PROMPTS.md'deki
  [Tek ekran modu](./PROMPTS.md#tek-ekran-modu) bölümüne bak.
