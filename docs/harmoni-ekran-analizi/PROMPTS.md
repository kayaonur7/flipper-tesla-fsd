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
| [B0](#blok-b0--akış-envanteri-ve-haritası) | Akış haritası, ekran envanteri, önceliklendirme | 1 |
| [B1](#blok-b1--ekran-kartı) | Tek ekran/grup derin analizi | Grup sayısı kadar (~6-7) |
| [B2](#blok-b2--konsolidasyon) | Ekranlar arası birleşik görünüm | 1 |
| [C](#blok-c--doğrulama-pası) | Doğrulama | B0 ve B2'den sonra |
| [D](#blok-d--iyileştirme-planı) | İyileştirme planı | 1 |

**Neden bu sırayla:** B0 olmadan hangi ekranın çekirdek hangisinin yardımcı
olduğu bilinmiyor ve 14 ekrana eşit efor harcanıyor. B2 olmadan akışın asıl
problemleri — adımlar arası tutarsızlıklar — hiç görünmüyor, çünkü hiçbiri tek
ekranın içinde durmuyor.

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

## Blok B0 — Akış Envanteri ve Haritası

> İlk çalıştırılan blok. Tek ekranın içine girmez; akışın iskeletini çıkarır ve
> sonraki adımların önceliğini belirler.

```
[BLOK A BURAYA]

# ROL
Kıdemli yazılım mimarısın. Kod yazmayacaksın.

# GÖREV
cct/page/acq/entry akışının HARİTASINI çıkar. Bu turda hiçbir ekranın iç
mantığına derinlemesine girme — akışın iskeletini, ekranlar arası ilişkileri
ve paylaşılan state'i belgele.

# YÖNTEM (sırayla, atlama)
1. ENVANTER: entry altındaki her PG_* klasörünü aç. Her biri için dosya
   dörtlüsünü (java / html / js / lang) ve her dosyanın SATIR SAYISINI çıkar.
   Eksik dosyası olan ekranları işaretle.

2. SINIFLANDIRMA: Her ekranı şu tiplerden birine ata ve gerekçesini yaz:
   adım sayfası / modal popup / yardımcı görünüm / arama-sorgu ekranı
   Kanıt: nasıl açıldığı (startNewProcess mi, dialog mu, CCT mi).

3. GEÇİŞ GRAFİĞİ: Tüm entry altında şu string'leri ara ve her eşleşmeyi incele:
   startNewProcess, CCT, dialog, showCustomMessageBox, fireEvent
   Kim kimi açıyor, hangi koşulla, hangi parametreyi taşıyarak?
   Geri dönüş (parent'a dönüş) nasıl oluyor?

4. GİRİŞ VE ÇIKIŞ NOKTALARI: Bu akışa dışarıdan nereden giriliyor? Kardeş
   klasörlerde (annulment / application / branchopening / inquiry) entry
   ekranlarına yapılan çağrıları ara. Akış tamamlanınca nereye gidiliyor?

5. PAYLAŞILAN STATE — bu turun en kritik adımı:
   Adımlar arası taşınan her veri parçası için: nerede saklanıyor (session /
   process context / CCT parametresi / gizli form alanı / servis üzerinden
   yeniden okuma), hangi ekranda YAZILIYOR, hangi ekranda OKUNUYOR.

6. SERVİS KESİŞİMİ: Tüm entry altındaki HMN_*_Intf çağrılarını topla.
   Hangi arayüz metodu kaç farklı ekrandan çağrılıyor?

7. İKİZ / VARYANT TARAMASI: Primer'da işaretlenen ikizleri (Account/AccountEdit,
   Pricing/PricingTrio, TagInquiry/TagOperation) ve tespit ettiğin diğer
   benzerleri karşılaştır. Dosya boyutları, ortak metot adları, ortak DTO'lar.
   Bu turda yüzeysel bak — "kopya şüphesi VAR / YOK / İNCELENMELİ" düzeyinde.

8. Kodda göremediğini yazma. "DOĞRULANAMADI: <neden>" kullan.

# ÇIKTI FORMATI

## 1. Ekran Envanteri
Tablo: Ekran | Tip | java satır | html satır | js satır | lang key sayısı |
Eksik dosya | Bir cümlelik rol

## 2. Geçiş Grafiği
Mermaid flowchart — düğümler ekranlar, oklar geçişler. Ok etiketi = tetikleyici
(buton/event) + taşınan parametre. Modal'ları farklı şekille göster.
Altına tablo: Kaynak | Hedef | Mekanizma (startNewProcess/CCT/dialog) |
Koşul | Taşınan parametre | Dönüş değeri | Kod referansı

## 3. Giriş ve Çıkış Noktaları
Akışa nereden giriliyor (kardeş akışlar dahil), hangi ön koşullarla,
tamamlanınca / iptal edilince nereye gidiliyor

## 4. Paylaşılan State Sözlüğü
Tablo: Veri | Saklandığı yer | Yazan ekran(lar) | Okuyan ekran(lar) |
Tip | Akış sonunda ne oluyor
Ayrıca açıkça listele:
- Yazılıp hiç okunmayan veriler
- Okunup hiç yazılmayan (dışarıdan gelmesi beklenen) veriler

## 5. Servis Paylaşım Matrisi
Tablo: Intf metodu | Çağıran ekranlar | Çağrı sayısı | Aynı parametrelerle mi

## 6. İkiz / Varyant Adayları
Tablo: Ekran A | Ekran B | Benzerlik kanıtı | Kopya şüphesi (VAR/YOK/İNCELENMELİ)

## 7. DERİN ANALİZ PLANI
Ekranları önem sırasına diz ve gruplandır. Her grup için:
- Grup adı ve içindeki ekranlar
- Neden birlikte analiz edilmeli (ortak state / ikiz / ardışık adım)
- Derinlik: TAM (çekirdek adım) veya ÖZET (yardımcı/popup)
Amaç: 14 ekranı 6-8 gruba indirmek. Bu plan Blok B1 çalıştırmalarının
girdisi olacak.

## 8. Açık Sorular
Haritadan çözülemeyen, koda derin bakmadan cevaplanamayacak sorular

# KURALLAR
- Türkçe yaz, teknik terimleri İngilizce bırak.
- Her iddianın yanında dosya:satır referansı olsun.
- Bu turda ekranların İÇ mantığına girme (validasyon detayı, DTO alan listesi
  vb. YOK). Sadece iskelet ve ilişkiler.
- İYİLEŞTİRME ÖNERİSİ YAZMA.
- Çıktıyı docs/entry-akis/00-akis-haritasi.md dosyasına yaz.
```

---

## Blok B1 — Ekran Kartı

> B0'ın ürettiği **Derin Analiz Planı**'ndaki her grup için bir kez çalıştırılır
> (~6-8 çalıştırma). Her seferinde yeni chat aç.

```
[BLOK A BURAYA]

# BAĞLAM
#file:docs/entry-akis/00-akis-haritasi.md
Akış haritası doğrulandı. Bu turda haritadaki tek bir gruba derinlemesine
bakacaksın.

# BU TURUN KAPSAMI
Grup      : <B0'daki grup adı>
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
#file:docs/entry-akis/00-akis-haritasi.md
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

> İki kez çalıştırılır: B0'dan sonra (harita için) ve B2'den sonra
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
#file:docs/entry-akis/00-akis-haritasi.md
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

- **B0 atlanır.** Blok A'daki "ANALİZ KAPSAMI" bölümünü tek ekrana göre yeniden yaz.
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
