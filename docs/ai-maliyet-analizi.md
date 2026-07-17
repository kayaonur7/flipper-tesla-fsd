# AI Maliyet Analizi — "AI Günlük Yoldaş" (Seçenek A)

> Bu doküman, uygulamanın AI özelliklerinin (kişiselleştirilmiş devotional üretimi + ayet kaynaklı
> AI sohbet) işletme maliyetini modeller. Fiyatlar Anthropic Claude API güncel liste fiyatlarıdır
> (Temmuz 2026). Hazırlanma tarihi: Temmuz 2026.

---

## 1. Model Fiyatları (Claude API, 1M token başına)

| Model | Girdi (input) | Çıktı (output) | Not |
|---|---|---|---|
| Claude Opus 4.8 | 5,00 $ | 25,00 $ | En yüksek kalite; varsayılan öneri |
| Claude Sonnet 5 | 3,00 $ (31 Ağu 2026'ya kadar tanıtım: 2,00 $) | 15,00 $ (tanıtım: 10,00 $) | Kalite/maliyet dengesi çok iyi |
| Claude Haiku 4.5 | 1,00 $ | 5,00 $ | Basit görevler için en ucuz |

**Kritik indirimler:**
- **Prompt caching:** Önbellekten okunan girdi tokenleri ~%90 indirimli (0,1×). Sistem promptu +
  ayet veritabanı bağlamı her mesajda tekrarlandığı için sohbet maliyetini ciddi düşürür.
  (Önbelleğe yazma 1,25× — ilk istekte küçük bir prim.)
- **Batch API:** Gecikmeye duyarsız işler (ör. günlük devotional'ların gece toplu üretimi)
  **%50 indirimli**.

---

## 2. Kullanım Varsayımları (aktif kullanıcı / ay)

| Özellik | Varsayım | Token/istek |
|---|---|---|
| Günlük devotional | 30 üretim/ay (gece Batch API ile) | ~2.000 girdi (profil + şablon + ayetler), ~500 çıktı |
| AI sohbet | ~20 mesaj/ay (5 oturum × 4 mesaj) | ~3.000 girdi (sistem + RAG ayet bağlamı + geçmiş; ~2.000'i önbellekten), ~300 çıktı |
| Uyku içeriği | Önceden üretilmiş katalog | LLM maliyeti yok (tek seferlik TTS) |

RAG mimarisi notu: Ayet veritabanı embedding tabanlı aramayla seçilip prompta eklenir; sabit sistem
promptu + ayet formatı önbelleklenebilir şekilde en başa yerleştirilmelidir (bkz. prompt caching).

## 3. Aktif Kullanıcı Başına Aylık AI Maliyeti

Hesap: sohbet (önbellekli) + devotional (Batch %50):

| Model | Sohbet | Devotional (Batch) | **Toplam / aktif kullanıcı / ay** |
|---|---|---|---|
| Opus 4.8 | ~0,27 $ | ~0,34 $ | **~0,60 $** |
| Sonnet 5 (liste) | ~0,16 $ | ~0,20 $ | **~0,36 $** (tanıtım fiyatıyla ~0,25 $) |
| Haiku 4.5 | ~0,06 $ | ~0,07 $ | **~0,13 $** |

Örnek hesap (Opus 4.8, sohbet): mesaj başına 1.000 önbelleksiz girdi × 5 $/M + 2.000 önbellek
okuma × 0,5 $/M + 300 çıktı × 25 $/M ≈ 0,0135 $ → 20 mesaj ≈ 0,27 $.

**Ücretsiz/deneme kullanıcıları:** Hard paywall sayesinde deneme süresi 7 gün ve AI sohbet
denemede günde ~3 mesajla sınırlandırılırsa, deneme kullanıcısı başına maliyet ~0,03–0,08 $
seviyesinde kalır.

## 4. Ölçek Senaryoları (aylık)

Varsayım: MAU'nun %8'i ödeyen (tam kullanım), kalanı sınırlı deneme/ücretsiz kullanım (~0,05 $/kullanıcı).
Gelir: yıllık 59,99 $ plan ≈ 5 $/ay brüt; Apple komisyonu sonrası (%15 Small Business Program*) ≈ 4,25 $/ay net.

| MAU | Ödeyen | Aylık net gelir | AI maliyeti (Opus 4.8) | AI maliyeti (Sonnet 5) | AI / gelir oranı (Sonnet) |
|---|---|---|---|---|---|
| 1.000 | 80 | ~340 $ | ~94 $ | ~75 $ | ~%22 |
| 10.000 | 800 | ~3.400 $ | ~940 $ | ~750 $ | ~%22 |
| 50.000 | 4.000 | ~17.000 $ | ~4.700 $ | ~3.700 $ | ~%22 |

\* İlk 1M $/yıl gelire kadar Apple komisyonu %15 (Small Business Program); üzeri %30.

**Sonuç:** AI maliyeti, net gelirin ~%15–25'i bandında tutulabilir — abonelik fiyatlaması bunu
rahatça taşır. Maliyetin ölçekle doğrusal büyüdüğüne ve gelirle aynı oranda arttığına dikkat:
birim ekonomi ölçekte bozulmaz.

## 5. Maliyet Kontrol Kolları (önem sırasıyla)

1. **Hard paywall + deneme sınırı:** En büyük risk ödemeyen kullanıcının AI tüketimi. Denemede
   günlük mesaj limiti (ör. 3), ödeyende makul bir adil kullanım limiti (ör. 30 mesaj/gün) koy.
2. **Prompt caching:** Sabit sistem promptu + RAG şablonunu önbellek kırılmayacak şekilde tasarla
   (değişken içerik en sona). Sohbet maliyetini ~%50-60 düşürür.
3. **Batch API:** Devotional üretimini gece toplu çalıştır → %50 indirim. Ek avantaj: aynı gün
   içeriği segment bazında (ör. "kaygı" profili) üretilip binlerce kullanıcıya kişiselleştirilmiş
   varyant olarak dağıtılabilir — kullanıcı başına üretim yerine segment başına üretim maliyeti
   10× düşürebilir.
4. **Model seçimi / yönlendirme:** Teolojik hassasiyeti yüksek sohbet için güçlü model; selamlaşma,
   ayet arama gibi basit istekler için Haiku 4.5'e yönlendirme (router) eklenebilir. Bu bir
   kalite/maliyet kararı — lansmanda tek modelle başlayıp veriyle karar vermek daha sağlıklı.
5. **Çıktı uzunluğu disiplini:** Çıktı tokeni girdiden 5× pahalı. Devotional ve sohbet cevaplarını
   ürün gereği kısa tut (zaten UX bunu istiyor: 2-3 dk'lık içerik).

## 6. AI Dışı Değişken Maliyetler (hatırlatma)

| Kalem | Tahmini | Not |
|---|---|---|
| TTS (premium ses) | Devotional başına ~0,01–0,05 $ (sağlayıcıya göre) | Segment bazlı üretimle paylaşılır; katalog içeriği tek seferlik |
| Embedding/RAG altyapısı | İhmal edilebilir (~binde birler) | Ayet DB küçük ve statik; embeddingler tek seferlik |
| RevenueCat | 2,5K $/ay gelire kadar ücretsiz, sonrası gelirin ~%1'i | |
| Apple komisyonu | %15 (SBP) / %30 | Gelir hesabına dahil edildi |

## 7. Öneri

- **Lansman modeli: Claude Opus 4.8** — teolojik güvenilirlik ürünün ana vaadi; kullanıcı başına
  ~0,60 $/ay maliyet, 4,25 $/ay net gelirin %14'ü. Kalite riskini alma.
- İlk 3 ayın gerçek kullanım verisiyle **Sonnet 5'e geçişi A/B testiyle değerlendir**
  (maliyeti ~%40 düşürür; tanıtım fiyatı döneminde fark daha da büyük).
- Mimaride ilk günden: prompt caching uyumlu prompt yapısı, Batch API ile devotional üretimi,
  kullanıcı başına kullanım sayaçları (rate limit + maliyet telemetrisi).
- Refusal/hassas konu yönetimi: hassas konularda (kriz, intihar) modele değil, sabit
  yönlendirme akışına düş — hem güvenlik hem maliyet açısından doğru.
