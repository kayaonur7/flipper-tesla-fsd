# Harmoni Legacy Ekran Analizi — Çalıştırma Kılavuzu

Bu klasör, Harmoni legacy ekranlarının uçtan uca analizi ve iyileştirme planı
için hazırlanmış prompt setini içerir. Promptlar: [PROMPTS.md](./PROMPTS.md)

**Amaç:** Bir ekranın hangi akışlara sahip olduğunu, nerelerde entegrasyon
yaptığını, hangi veri tiplerini ve validasyonları kullandığını koda dayalı
olarak belgelemek; ardından iyileştirme alanlarını çıkarmak.

**Neden 4 blok var:** Analiz ile öneri tek prompt'ta istendiğinde model
analizin yarısında değerlendirmeye kayıyor ve envanter eksik kalıyor. Ayrıca
Harmoni eğitim verisinde olmadığı için model boşlukları tanıdığı framework'lerin
konvansiyonlarıyla dolduruyor — doğrulama pası (Blok C) bunun için var.

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

## Adım 1 — Blok A'yı kendine göre kontrol et

[PROMPTS.md > Blok A](./PROMPTS.md#blok-a--framework-primer) içindeki primer,
elimizdeki stack bilgisinden yazıldı. Kendi ekranında farklı bir mekanizma
varsa (başka bir dialog fonksiyonu, farklı rapor motoru, ek modül) primer'a
ekle. Primer ne kadar doğruysa analiz o kadar doğru çıkıyor.

Bu blok tek başına çalıştırılmaz — B, C ve D bloklarının **her birinin başına**
yapıştırılır.

---

## Adım 2 — Analizi çalıştır (Blok B)

1. Yeni bir Copilot chat aç
2. [Blok B](./PROMPTS.md#blok-b--aşama-1-uçtan-uca-analiz)'yi kopyala
3. Başındaki `[BLOK A BURAYA]` yerine Blok A'yı yapıştır
4. `# HEDEF EKRAN` bölümündeki alanları doldur:
   - Ekran adı
   - `PG_<...>.java`, `<...>.html`, `<...>.js` dosya yolları — `#file:` ile
   - İş tanımı: kullanıcı bu ekranda ne yapıyor (1-2 cümle)
   - Bildiğin ilişkili servis/DTO adları (bilmiyorsan "yok" yaz)
5. Gönder

> **Dosya yollarını mutlaka `#file:` ile ver.** Sadece `#codebase` yeterli
> değil — Harmoni'de modüler yapı ve tip grafiği zayıf olduğu için semantik
> arama ekran ağacının derinlerine (servis katmanı, DTO'lar) çoğu zaman inemiyor.

**Çıktı:** `docs/<ekran-adi>-analiz.md`

Ekran 1500+ satırsa tek pasta çalıştırma — PROMPTS.md sonundaki
[bölme stratejisini](./PROMPTS.md#büyük-ekranlar-için-bölme-stratejisi) uygula.

---

## Adım 3 — Doğrulama pası (Blok C)

**Yeni bir chat aç.** Aynı sohbette çalıştırırsan model kendi çıktısını savunur.

1. [Blok C](./PROMPTS.md#blok-c--doğrulama-pası)'yi kopyala, başına Blok A'yı ekle
2. `<ekran-adi>` yerine analiz dosyanın adını yaz
3. Gönder

Model yanlış referansları, uydurulmuş içeriği ve eksikleri listeleyip analiz
dosyasını düzeltir.

---

## Adım 4 — Elle spot-check (atlama)

Doğrulama pası her şeyi yakalamaz. Analiz dosyasından **rastgele 5 madde** seç
ve `dosya:satır` referanslarını kendin aç:

- 2 tanesi Validasyon Matrisi'nden
- 2 tanesi Servis/Entegrasyon Envanteri'nden
- 1 tanesi Event Haritası'ndan

En sık görülen hata: var olmayan bir validasyonun veya retry mekanizmasının
raporlanması. Bu yanlış Aşama 2'ye taşınırsa tüm iyileştirme planı çürük
temele oturur.

Bir hata bulursan düzelt ve Adım 3'ü tekrarla.

---

## Adım 5 — İyileştirme planı (Blok D)

1. Yeni chat aç
2. [Blok D](./PROMPTS.md#blok-d--aşama-2-iyileştirme-planı)'yi kopyala, başına
   Blok A'yı ekle
3. Analiz dosyasını `#file:` ile referansla
4. Gönder

**Çıktı:** `docs/<ekran-adi>-iyilestirme.md` — bulgular, quick win'ler, yapısal
değişiklikler, önce yazılması gereken karakterizasyon testleri.

---

## Adım 6 — Uygulama

Blok D kod yazmaz, bilinçli olarak. Planı gözden geçirip hangi bulguların
yapılacağına karar ver, sonra bulgu bulgu implementasyon iste:

```
#file:docs/<ekran-adi>-iyilestirme.md
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
| Event haritası boş veya çok kısa | Model `fireEvent` çağrılarını grep'lemek yerine import takip etmeye çalışmış | Prompt'a ekle: "Önce tüm repoda `fireEvent` string'ini ara, sonuç sayısını yaz, sonra devam et" |
| Çıktı yarıda kesiliyor | Ekran çok büyük | Bölme stratejisini uygula |
| Framework mekanizmaları Spring/JSF terimleriyle anlatılmış | Blok A yapıştırılmamış veya zayıf kalmış | Blok A'yı yapıştırdığından emin ol; eksik mekanizmaları primer'a ekle |
| Sonraki aşama önceki analizi "hatırlamıyor" | Chat geçmişi context penceresinden düşmüş | Analizi her zaman dosyaya yazdır ve `#file:` ile geri ver — chat geçmişine güvenme |
| Öneriler "yeniden yazalım / modern framework'e geçelim" diyor | Blok D'deki yasak kural silinmiş | `# KURALLAR` bölümünü aynen koru |
| Model kendi hatasını kabul etmiyor | Doğrulama aynı sohbette çalıştırılmış | Blok C'yi mutlaka yeni chat'te çalıştır |

---

## Notlar

- Promptlar Türkçe çıktı üretecek şekilde yazıldı; teknik terimler İngilizce
  kalıyor.
- Analiz ve iyileştirme dosyalarını repoya commit'lemek faydalı — bir sonraki
  ekranda komşu ekran referansı olarak kullanılabiliyor ve model konvansiyonu
  oradan türetiyor.
- Aynı set başka bir Harmoni modülü için de kullanılabilir; Blok A'daki repo
  ve modül adlarını değiştirmek yeterli.
