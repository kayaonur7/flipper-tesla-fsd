# Faith Tech Ürün Konsepti: ABD Pazarı İçin Uygulama Seçenekleri

> Bu doküman, `app-store-gelir-analizi.md` raporundaki bulgulara dayanarak inanç/faith tech
> kategorisinde geliştirilebilecek somut ürün seçeneklerini, önerilen konsepti, MVP kapsamını ve
> pazara giriş planını tanımlar. Hazırlanma tarihi: Temmuz 2026.

---

## 1. Rekabet Haritası ve Boşluklar

| Oyuncu | Konum | Gelir/Ölçek | Zayıf noktası |
|---|---|---|---|
| **Hallow** | Katolik dua & meditasyon | ~40M$/yıl net, 22M+ indirme, 105M$ yatırım | Sadece Katolik; Protestan pazarına hitap etmiyor |
| **Glorify** | Protestan "Calm'ı" | 2,5M+ kullanıcı, 84M$ yatırım (a16z) | Gelirle değil yatırımla büyüyor; AI katmanı zayıf |
| **Bible Chat** | AI + Kutsal Kitap sohbeti | ~750K$/ay tepe gelir, 30M+ indirme | Tek boyutlu (sohbet); içerik derinliği ve sesli deneyim yok |
| **Pray.com** | Sesli dua/İncil içeriği | 25M indirme | Yaşlı demografiye kayıyor; modern UX zayıf |
| **Abide** | İncil temelli uyku hikâyeleri | Niş lider | Uyku dışına genişleyemedi |
| **YouVersion** | Ücretsiz İncil okuma | En çok indirilen, kâr amaçsız | Para kazanmıyor — ama tüm pazarın huni girişi |
| **Bible App for Kids** | Çocuk segmenti | ~14,7M$/yıl tahmini | Az sayıda ciddi rakip var |

**Tespit edilen boşluklar:**
1. **AI + derin içerik birleşimi yok.** Bible Chat sadece sohbet; Hallow/Glorify sadece içerik. İkisini birleştiren ("bugünkü ruh haline göre kişiselleştirilmiş sesli dua + ayet + AI rehberlik") bir ürün yok.
2. **Protestan/evanjelik segmentte Hallow kalitesinde ürün yok.** ABD'de Protestanlar Katoliklerin ~2 katı (nüfusun ~%40'ı vs ~%20'si); Glorify bu boşluğu tam dolduramadı.
3. **İspanyolca konuşan ABD pazarı** (60M+ kişi, yüksek dindarlık oranı) için birinci sınıf ürün yok.
4. **Sezonluk ürünleşme** (Lent/Advent challenge'ları) Hallow dışında kimsede sistematik değil.

---

## 2. Ürün Seçenekleri

### Seçenek A — "AI Günlük Yoldaş" (ÖNERİLEN) ⭐
AI destekli, sesli-öncelikli günlük İncil arkadaşı. Kullanıcı sabah 2 dakikalık kişiselleştirilmiş
sesli devotional alır (ruh hali + yaşam durumu + takvim sezonuna göre); gün içinde AI'a soru
sorabilir (her cevap ayet referanslı); akşam uyku için İncil temelli sesli içerik.

- **Neden:** Bible Chat'in kanıtladığı AI talebini, Hallow'un kanıtladığı sesli içerik + sezonluk
  modeliyle birleştirir. İki kanıtlanmış gelir motoru tek üründe.
- **Hedef kitle:** 25–45 yaş ABD'li Protestan/evanjelik; kiliseye düzenli gitmeyen ama "inancını
  günlük hayata taşımak isteyen" segment (en büyük ve en az hizmet alan grup).
- **Farklılaştırıcı:** Teolojik güvenilirlik — her AI cevabı ayet kaynaklı ve denominasyon
  duyarlı; danışma kurulu (pastör onayı) pazarlamanın parçası.

### Seçenek B — "Uyku + Dinginlik" dikeyi
Abide'ın modern, daha iyi üretilmiş versiyonu: İncil temelli uyku hikâyeleri, akşam duaları,
sakinleştirici müzik. Calm'dan kaçan "amaçlı wellness" kullanıcısını hedefler.
- Daha düşük teknik risk (AI yok), ama içerik üretim maliyeti yüksek ve farklılaşma zor.

### Seçenek C — Model transferi: Müslüman pazarı
Aynı oyun kitabını (sesli içerik + AI rehberlik + Ramazan sezonluğu) Müslüman pazarına uygulama.
Muslim Pro (170M+ indirme) hakim ama AI katmanı zayıf; Türkçe/Arapça içerik üretiminde ekip avantajımız olur.
- ABD dışı gelir ağırlığı nedeniyle ARPU daha düşük; ama rekabet de daha az. İkinci ürün olarak bekletilebilir.

**Öneri: Seçenek A ile başla.** En yüksek gelir tavanı, iki kanıtlanmış modelin kesişimi ve
mevcut AI trend rüzgârı. B, A'nın içine "akşam modülü" olarak zaten girer; C ise A'nın motoru
kurulduktan sonra düşük maliyetli bir genişleme olur.

---

## 3. MVP Kapsamı (Seçenek A)

**v1.0 (3–4 ay):**
1. Onboarding: denominasyon, yaşam durumu, hedefler (kaygı/şükran/disiplin) → kişiselleştirme profili
2. Günlük sesli devotional (2–3 dk): ayet + kısa yorum + dua; TTS + insan sesi karışımı
3. AI sohbet: ayet referanslı cevaplar, denominasyon filtresi, "pastöre sor" yönlendirme sınırları
4. Akşam modülü: 5 uyku hikâyesi + 10 akşam duası (başlangıç kataloğu)
5. Streak/alışkanlık mekaniği (Duolingo modeli: seri, hatırlatıcılar, haftalık özet)
6. Hard paywall: 7 gün deneme → abonelik

**v1.1 (sezonluk):** Advent challenge (Aralık) — ilk büyük pazarlama anı.
**v1.2:** Lent challenge (Şubat–Mart) — Hallow'un tek ayda 10M$ kazandığı dönem.

**Teknik notlar:** Flutter veya React Native (tek kod tabanı); LLM API + RAG (ayet veritabanı
üzerinden kaynaklı cevap — halüsinasyon riskini içerik güvenilirliği için sıfıra yakın tutmak şart);
TTS için premium ses API'si; abonelik altyapısı RevenueCat.

---

## 4. Fiyatlandırma ve Gelir Modeli

| Plan | Fiyat | Not |
|---|---|---|
| Haftalık | 7,99 $ | Bible Chat'in kanıtladığı model; yüksek ARPU, yüksek churn |
| Yıllık | 59,99 $ | Ana plan — Hallow modeli; deneme sonrası varsayılan seçim |
| Ömür boyu | 149,99 $ | Sezonluk kampanyalarda indirimli |

- Hard paywall (RevenueCat verisi: freemium'a karşı ~8x erken gelir).
- Hedef metrikler: deneme→ücretli %30+ (sağlık/fitness benchmark'ı %35), yıl 1 sonunda 5–10K
  ödeyen abone (~400–700K$ ARR), yıl 2'de sezonluk kampanyalarla 2–3M$ ARR.

## 5. Pazara Giriş

- **ASO:** "daily devotional", "bible sleep stories", "AI bible", "prayer app" — Bible Chat'in
  büyümesi neredeyse tamamen ASO + Apple Search Ads'ten geldi; aynı kanal.
- **Sezonluk takvim:** Lansmanı Kasım'a (Advent öncesi) denk getir; en büyük bütçeyi Lent'e sakla.
- **Güven inşası:** Pastör/influencer ortaklıkları (mikro kilise toplulukları), teolojik danışma
  kurulu sayfası, "her cevap ayet kaynaklı" mesajı.
- **İçerik pazarlaması:** TikTok/Reels kısa devotional kesitleri — Hallow'un Mark Wahlberg
  kampanyası modelinin mikro versiyonu.

## 6. Riskler

| Risk | Azaltma |
|---|---|
| AI'ın teolojik hata yapması | RAG + ayet kaynaklı cevap zorunluluğu; hassas konularda (intihar, istismar) profesyonel yardım yönlendirmesi; insan denetimli içerik |
| Hallow/Glorify'ın AI eklemesi | Hız avantajı + niş segment (Protestan, sonra İspanyolca) odağı |
| Apple politikaları (dini içerik + AI) | İddialı "kutsal" iddialardan kaçın; "rehber/yoldaş" konumlandırması |
| İçerik üretim maliyeti | v1'de küçük katalog + AI destekli üretim, insan editör onayı |

## 7. Kaynaklar

- [Contrary Research — Hallow Business Breakdown](https://research.contrary.com/company/hallow)
- [Christianity Today — Venture Capitalists See Profit in Prayer](https://www.christianitytoday.com/2022/01/app-investment-prayer-bible-meditation-glorify-hallow/)
- [Warmpeach — Best Bible Apps in 2026](https://www.warmpeach.com/blog/best-bible-apps)
- [Appfigures — Bible Chat büyüme analizi](https://appfigures.com/resources/insights/20250418?f=5)
- [Appfigures — Hallow Lent sezonluk gelir analizi](https://appfigures.com/resources/insights/hallow-lent-surge-prayer-app-revenue)
- [faith.tools — Hristiyan uygulama dizini](https://faith.tools/)
