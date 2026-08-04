# Harmoni Legacy Ekran Analizi — Prompt Seti

Harmoni (kuruma özel, kapalı kaynak) legacy ekranlarının uçtan uca analizi ve
iyileştirme planı için hazırlanmış prompt seti. GitHub Copilot **agent mode** +
**Opus** ile kullanılmak üzere yazıldı.

Çalıştırma adımları için: [README.md](./README.md)

| Blok | Amaç | Ne zaman |
|---|---|---|
| [A](#blok-a--framework-primer) | Framework primer | Her prompt'un başına yapıştırılır |
| [B](#blok-b--aşama-1-uçtan-uca-analiz) | Uçtan uca analiz | İlk çalıştırma |
| [C](#blok-c--doğrulama-pası) | Doğrulama pası | Analizden hemen sonra |
| [D](#blok-d--aşama-2-iyileştirme-planı) | İyileştirme planı | Analiz doğrulandıktan sonra |

---

## Blok A — Framework Primer

> Bu blok tek başına çalıştırılmaz. B, C ve D bloklarının **her birinin başına**
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
Bir ekran şu dosya grubundan oluşur:
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

## Domain
ACQ = Acquiring / Merchant (üye işyeri) — kartlı ödeme kabul tarafı.
```

---

## Blok B — Aşama 1: Uçtan Uca Analiz

> Başına Blok A'yı yapıştır. `<...>` alanlarını doldur.

```
[BLOK A BURAYA]

# ROL
Kıdemli yazılım mimarısın. Kod yazmayacaksın; bir ekranı uçtan uca tersine
mühendislikle belgeleyeceksin.

# HEDEF EKRAN
Ekran      : <EKRAN ADI>
Controller : #file:PG_<...>.java
Template   : #file:<...>.html
Script     : #file:<...>.js
İş tanımı  : <kullanıcı bu ekranda ne yapıyor — 1-2 cümle>
Bildiğim ilişkili servisler/DTO'lar : <varsa yaz, yoksa "yok">
Bu liste EKSİK — buradan başlayıp genişlet.

# YÖNTEM (sırayla uygula, adım atlama)
1. DOSYA GRUBU: Dörtlüyü tamamla (PG_ / html / js / lang). Adlandırma birebir
   uymuyorsa yakın eşleşmeleri listele; hangisinin doğru olduğunu html ve js
   içindeki referanslarla doğrula.

2. YAŞAM DÖNGÜSÜ: PG_ sınıfında hangi metotlar framework tarafından çağrılıyor
   (init / load / prepare vb.), hangileri event handler? Komşu PG_ sınıflarıyla
   karşılaştırarak türet ve kaynağını belirt.

3. EVENT ZİNCİRİ — en kritik adım:
   - .js ve .java içindeki TÜM fireEvent çağrılarını bul, event adlarını çıkar
   - Her event adını STRING olarak her iki repoda ara: kim tetikliyor, kim dinliyor
   - Dinleyicisi bulunamayanı "DİNLEYİCİSİ BULUNAMADI" diye işaretle
   - Tetikleyicisi bulunamayan handler'ı "ÖLÜ HANDLER ŞÜPHESİ" diye işaretle

4. SERVİS ÇAĞRILARI: FE'den çağrılan her HMN_*_Intf metodunu listele. Her biri
   için BE'deki HMN_ACQ_Merchant_Internal implementasyonunu bul.
   BE'ye erişemiyorsan arayüz imzası + Model DTO'sunu çıkar ve
   "BE TARAFI ANALİZ EDİLMEDİ" notu düş — implementasyonu TAHMİN ETME.

5. DTO AKIŞI: HMN_ACQ_Merchant_Model içinde bu ekranın kullandığı sınıflar.
   Alan bazlı Jackson anotasyonlarını (@JsonProperty, @JsonIgnore, @JsonFormat,
   @JsonInclude) not et — serialization davranışı orada belirleniyor.

6. i18n: Ekranda kullanılan tüm lang key'lerini çıkar. Dört listeyi ayrı ver:
   (a) tr'de olup en'de olmayan
   (b) en'de olup tr'de olmayan
   (c) tanımlı ama hiç kullanılmayan
   (d) kodda hardcoded, lang dosyasına hiç girmemiş metin

7. NAVİGASYON: startNewProcess / CCT / dialog çağrıları — bu ekran nereye
   gidiyor, buraya nereden geliniyor.

8. RAPOR: HopeReportGenerator kullanımı varsa reportId'yi, sunucu tarafındaki
   şablonu ve rapora giren alanları çıkar.

9. Her iddia için dosya:satır referansı ver. Kodda göremediğini YAZMA;
   "DOĞRULANAMADI: <neden>" kullan.

# ÇIKTI FORMATI

## 1. Ekran Künyesi
Giriş noktaları, yetki/rol koşulları, üst akıştaki yeri, ön koşullar

## 2. Dosya Grubu ve Sorumluluklar
Tablo: Dosya | Rol | Sorumluluk | Neyi çağırıyor

## 3. Sayfa Yaşam Döngüsü
PG_ sınıfının framework tarafından çağrılan metotları, çağrılma sırası,
her adımda ne olduğu

## 4. Event Haritası
Tablo: Event adı | Tetikleyen (dosya:satır) | Dinleyen (dosya:satır) |
Taşıdığı veri | Durum (eşleşti / dinleyicisi yok / tetikleyicisi yok)

## 5. Uçtan Uca Akışlar
Her senaryo ayrı bölüm — mutlu yol, alternatif yollar ve hata yolları ayrı ayrı.
Her akış için:
- Tetikleyici (kullanıcı aksiyonu / lifecycle / event)
- Adım adım çağrı zinciri (dosya:satır referanslı)
- Mermaid sequence diagram
- Yan etkiler: dialog, navigasyon, log, rapor, state değişimi

## 6. Servis / Entegrasyon Envanteri
Tablo: Intf metodu | Impl sınıfı | Girdi DTO | Çıktı DTO | Tetikleyen akış |
Hata davranışı | Timeout/retry var mı | Kod referansı
Ayrıca: DB, dış sistem, dosya/FTP, batch job, rapor motoru temasları

## 7. Veri Sözleşmesi
Her DTO için alan tablosu: Alan | Tip | Zorunlu mu | Jackson anotasyonu |
Null davranışı | Enum değerleri | UI'daki karşılığı (html alan adı)

## 8. Validasyon Matrisi
Tablo: Alan | Kural | Nerede uygulanıyor (js / PG_ controller / Intf /
Internal / DB) | Hata mesajı | Lang key'i var mı | Kod referansı
Ayrıca açıkça listele:
- Sadece .js'te olan, sunucuda karşılığı olmayan kurallar
- Sadece BE'de olup UI'da karşılığı olmayan (kullanıcıya kör gelen) hatalar
- Aynı kuralın FE ile BE arasında ÇELİŞEN versiyonları

## 9. Dialog ve Kullanıcı Geri Bildirimi
showCustomMessageBox ve diğer dialog çağrıları: nerede, bloklayıcı mı,
mesaj lokalize mi, kullanıcı iptal ederse ne oluyor

## 10. i18n Durumu
Yöntem adım 6'daki dört listenin çıktısı

## 11. Gizli Bağımlılıklar
- Bu ekranın yazdığı veriyi okuyan başka ekran / job / rapor
- Session veya global state, static/singleton kullanımı
- Paylaşılan utility'ler — değişirse başka nerelerin kırılacağı
- Zamanlanmış işler ile örtük sözleşmeler

## 12. Ölü ve Şüpheli Kod
Ulaşılamaz bloklar, dinleyicisi olmayan event'ler, kullanılmayan parametreler,
varyant/kopya dosyalar. Her biri için "neden ölü olduğunu düşünüyorum" kanıtı.

## 13. Açık Sorular
Kodda cevabı olmayan, iş birimine veya ekibe sorulması gerekenler

# KURALLAR
- Türkçe yaz, teknik terimleri İngilizce bırak.
- Her iddianın yanında dosya:satır referansı olsun.
- Kod bloğu yapıştırma; sadece kritik 5-10 satırı alıntıla, gerisine referans ver.
- Bu aşamada İYİLEŞTİRME ÖNERİSİ YAZMA. Sadece mevcut durumu belgele.
- Çıktıyı docs/<ekran-adi>-analiz.md dosyasına yaz.
```

---

## Blok C — Doğrulama Pası

> Aşama 1 biter bitmez, **yeni bir chat'te** çalıştır. Aynı sohbette çalıştırırsan
> model kendi çıktısını savunma eğilimine giriyor.

```
[BLOK A BURAYA]

# GÖREV
#file:docs/<ekran-adi>-analiz.md dosyası bir önceki turda üretildi.
Bu dosyayı ÜRETEN sen değilsin — eleştirel bir denetçisin.

Dokümandaki her dosya:satır referansını tek tek koda karşı doğrula.

# ÇIKTI
## Yanlış Referanslar
Tablo: İddia | Verilen referans | Kodda gerçekte ne var | Durum

## Uydurulmuş İçerik
Kodda hiç karşılığı olmayan, tamamen üretilmiş iddialar

## Eksikler
Kodda var olup dokümanda hiç geçmeyen: event, servis çağrısı, validasyon,
dialog, hata yolu

## Şüpheli Genellemeler
"Muhtemelen", "genellikle", "standart olarak" gibi ifadelerle geçiştirilmiş,
kanıtsız yerler

# KURALLAR
- Doğru olan maddeleri tek tek onaylama, sadece PROBLEMLİ olanları listele.
- Hiç problem bulamazsan bunu açıkça söyle; uydurma bulgu üretme.
- Düzeltmeleri doğrudan analiz dosyasına uygula ve neyi değiştirdiğini özetle.
```

---

## Blok D — Aşama 2: İyileştirme Planı

> Analiz doğrulanıp elle gözden geçirildikten sonra çalıştırılır.

```
[BLOK A BURAYA]

# BAĞLAM
#file:docs/<ekran-adi>-analiz.md
Bu doküman gerçek koddan çıkarıldı, doğrulama pasından geçti ve tarafımdan
onaylandı. Başlangıç noktası olarak al — ama iddia ettiğin her problemi
kodda TEKRAR doğrula.

# GÖREV
Bu ekran için iyileştirme alanlarını çıkar. Kod yazma, plan üret.

# İNCELEME EKSENLERİ
1. EVENT HİJYENİ
   Dinleyicisi olmayan event'ler; aynı event'in birden çok dinleyicisi
   arasında örtük sıra bağımlılığı; event üzerinden taşınan implicit state;
   event zincirinin izlenemez hale geldiği noktalar

2. VALİDASYON BOŞLUĞU
   Sadece .js'te olup Intf/Internal tarafında karşılığı olmayan kurallar
   (istemci atlatılabilir); BE'de olup UI'a yansımayan hatalar; FE ile BE
   arasında çelişen kurallar — hangisi doğru davranış

3. SÖZLEŞME SAĞLIĞI
   DTO ile UI alanları arasındaki uyuşmazlıklar; Jackson anotasyon eksikleri
   (bilinmeyen alan davranışı, tarih formatı, null serialization);
   tip güvenliği kaybedilen dönüşüm noktaları

4. KULLANICI GERİ BİLDİRİMİ
   showCustomMessageBox'ın bloklayıcı kullanımı ve alternatifleri; sessizce
   yutulan hatalar; kullanıcıya anlamsız gelen teknik mesajlar; loading /
   empty / kısmi veri durumlarının eksikliği

5. i18n
   Eksik dil key'leri, hardcoded metinler, lang dosyasında olup kullanılmayan
   ölü key'ler

6. DAYANIKLILIK
   Timeout / retry / geri alma eksikleri; HopeReportGenerator senkron rapor
   üretiminin bloklama ve zaman aşımı riski; exception yutan catch blokları;
   yarım kalan işlem durumunda veri tutarlılığı

7. PERFORMANS
   Sayfa açılışında gereksiz servis çağrısı; N+1 çağrı; paralelleştirilebilir
   seri çağrılar; over-fetching; gereksiz yeniden yükleme

8. NAVİGASYON VE AKIŞ
   startNewProcess / CCT geçişlerinde kaybolan bağlam; geri dönüşte state
   kaybı; kullanıcının kurtulamadığı çıkmaz durumlar; gereksiz adımlar

9. BAKIM YAPILABİLİRLİK
   PG_ controller içine sızmış iş mantığı; kopyala-yapıştır tekrarlar;
   test edilemez yapılar; sorumluluk sızıntısı

10. GÜVENLİK / YETKİ
    Sadece istemci tarafında yapılan yetki kontrolü; loglara düşen PII veya
    kart/işyeri hassas verisi; bağımlılık sürümlerinin güvenlik durumu
    (Jackson 2.9.6 dahil — sürümü doğrula ve bilinen risk varsa NOT olarak yaz,
    kesin iddia etme)

11. DEĞİŞİM RİSKİ
    Bu ekrana dokunmadan önce hangi karakterizasyon testleri (characterization
    test) yazılmalı — mevcut davranışı dondurup sonra güvenle değiştirebilmek için

12. İZOLASYON FIRSATLARI
    Strangler fig ile parça parça çıkarılabilecek, net sınırı olan alt-akışlar

# HER BULGU İÇİN FORMAT
### [B-01] <Kısa başlık>
- **Eksen:** <yukarıdaki 12'den biri>
- **Kanıt:** <dosya:satır> — kodda tam olarak ne var
- **Neden problem:** somut başarısızlık senaryosu (hangi input/durum → hangi
  yanlış sonuç). "Best practice değil" gibi soyut gerekçe KABUL EDİLMEZ.
- **Etki:** kullanıcı etkisi + teknik etki
- **Önerilen çözüm:** somut yaklaşım, hangi dosyalar değişir
- **Etkilenen diğer ekran/job/rapor:** (analiz Bölüm 11'i kullan)
- **Nasıl geri alınır / kırılırsa nereden anlarız**
- **Efor:** S / M / L — **Risk:** düşük / orta / yüksek
- **Alternatifler ve neden bunu seçtin**

# ÇIKTI
1. Bulgular, etki × efor'a göre sıralı
2. QUICK WINS — S efor + düşük risk olanlar ayrı bölüm
3. YAPISAL DEĞİŞİKLİKLER — M/L efor olanlar ayrı bölüm, her biri için
   before/after Mermaid akış diyagramı
4. DAVRANIŞ KORUYAN (refactor) ve DAVRANIŞ DEĞİŞTİREN (fix/feature)
   önerileri AYRI listele — karıştırma
5. ÖNCE YAZILMASI GEREKEN TESTLER — karakterizasyon testi listesi
6. BİLİNÇLİ OLARAK ÖNERMEDİKLERİM — değerlendirip elediğin şeyler ve nedeni

# KURALLAR
- "Yeniden yazalım", "modern framework'e taşıyalım", "mimariyi değiştirelim"
  türü öneriler YASAK. Her öneri mevcut yapı içinde, artımlı ve geri
  alınabilir olmalı.
- Kanıtı olmayan bulgu yazma. En fazla 12 bulgu — kaliteyi sayıyla takas etme.
- Bir davranışın NEDEN öyle olduğu belirsizse öneri üretme; analizin
  "Açık Sorular" bölümüne ekle.
- Kod yazma. Onay verilince implementasyona geçilecek.
- Çıktıyı docs/<ekran-adi>-iyilestirme.md dosyasına yaz.
```

---

## Büyük ekranlar için bölme stratejisi

Ekran 1500+ satırsa Blok B'yi tek seferde çalıştırma — son bölümler gözle
görülür şekilde sığlaşıyor. Üç pasa böl, her pasta Blok A'yı tekrar yapıştır:

| Pas | Yöntem adımları | Çıktı bölümleri | Çıktı dosyası |
|---|---|---|---|
| B1 | 1, 2, 3, 7 | 1, 2, 3, 4, 9 | `<ekran>-analiz-ui.md` |
| B2 | 4, 5, 8 | 6, 7, 11 | `<ekran>-analiz-servis.md` |
| B3 | 6 + validasyon taraması | 8, 10, 12, 13 | `<ekran>-analiz-validasyon.md` |

Sonra dördüncü bir pasla üç dosyayı `#file:` ile verip "Bölüm 5 (Uçtan Uca
Akışlar)'ı bu üç dokümanı birleştirerek yaz" de. Akış bölümü diğer hepsine
dayandığı için en sona bırakılmalı.
