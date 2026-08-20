# Çıktılar — Hangi Dosya Ne İşe Yarar

Analiz ~25 dosya üretti. Hepsini okumak gerekmiyor; çoğu ara ürün. Bu kılavuz
hangisinin kime, ne zaman lazım olduğunu söyler.

## Üç katman

```
_tarama/*.txt          HAM KANIT      script üretti, kimse baştan sona okumaz
_diyagram/*.md         ÇİZİM KAYNAĞI  M12 üretti, REHBER'e kopyalanır
00a / 00b / 00c*       ARA ÜRÜN       analiz sırasında kullanıldı
ekranlar/*.hazir.md    REFERANS       ekrana dokunacak kişi açar
90a / 90b / 90c        SİSTEMİK       akış seviyesi problemler
99-iyilestirme.md      KARAR          tek okunacak dosya
REHBER.md (+EK'ler)    ANLATIM        yeni gelene verilecek dosya
```

## Kime hangi dosya

| Kim / ne zaman | Ne okur |
|---|---|
| **Karar verecek olan** (lead, PO) — "ne yapalım?" | `99-iyilestirme.md`. Tek dosya. Bulgular etki × efor sıralı, quick win'ler ayrı, hangi testlerin önce yazılacağı yazılı |
| **Akışı öğrenecek olan** (yeni geliştirici) | `REHBER.md` — Adım 17 yazar, Adım 18 diyagramlar ve uçtan uca senaryolarla derinleştirir. Analiz çıktıları problem bulmaya göre yazıldı, bu ise anlatım |
| **Bir ekranı devralacak olan** | `REHBER-EK-<grup>.md` — Adım 19. Ekranın adım adım ne yaptığı, validasyon katmanları, hata yolları, "dokunacaksan şu 5 dosya" |
| **Bir ekrana dokunacak olan** | `ekranlar/<PG_X>.hazir.md`. O ekranın dosya ayak izi, CCT künyesi, olayları, servisleri, validasyonları, catch blokları, dil durumu — hepsi tek yerde |
| **Değişikliğin etkisini ölçecek olan** | `00c1-state.md` (hangi alan hangi ekranlar arası taşınıyor) + `90b` (servis envanteri, kapsam dışı bağımlılıklar) |
| **Test yazacak olan** | `99-iyilestirme.md`'nin "önce yazılması gereken karakterizasyon testleri" bölümü + `90a`'daki uçtan uca senaryolar |
| **Bir bulgudan şüphelenen** | `_tarama/` altındaki ilgili ham çıktı. Her bulgunun kanıtı orada, `dosya:satır` ile |

## Hangi soruya hangi dosya

| Soru | Dosya |
|---|---|
| Bu akış hangi ekranlardan geçiyor, hangi sırayla? | `REHBER.md` Bölüm 3 (D1 grafiği + anlatım). Ham hâli: `_diyagram/DIYAGRAMLAR.md` D1 |
| Bir başvuru baştan sona nasıl ilerliyor? | `REHBER.md` §3B — üç uçtan uca senaryo, sequenceDiagram |
| Bir ekran hangi dosyalardan oluşuyor? | `_diyagram/DIYAGRAMLAR.md` D5 |
| Şu ekran nereden açılıyor? | `00b-akis.md` §2-3, `_tarama/23-acik-sorular.txt` bölüm C |
| Bu alanı değiştirirsem nereler kırılır? | `00c1-state.md` §2 |
| Hangi servisler akışın omurgası? | `00c2-servis-dto.md` §1, `_tarama/25-servis-matrisi.txt` |
| Şu validasyon nerede uygulanıyor? | `90a` validasyon matrisi, `ekranlar/<PG_X>.hazir.md` |
| Aynı mantık kaç yerde tekrarlanmış? | `90c` tekrarlanan mantık haritası |
| Neden bu kadar ölü kod var? | `RUNBOOK.md` "Doğrulanmış bulgular" tablosu |

## Bunu nasıl kalıcı hâle getirirsin

**1. Repoya commit'le.** `docs/entry-akis/` klasörünü `hmnfe_acq_merchant`
reposuna al. Analiz kişisel bir çıktı değil, ekip belgesi — ve bir dahaki
akışta (annulment, branchopening, inquiry) komşu referans olarak kullanılıyor.

**2. `_tarama/` klasörünü `.gitignore`'a alabilirsin.** Ham çıktılar büyük ve
yeniden üretilebilir. Ama bulguların kanıtı orada; commit'lersen bir yıl sonra
"bu neden böyle demiştik" sorusunu cevaplayabilirsin.

**3. Bayatlama uyarısı.** Bu dosyalar kodun bir andaki fotoğrafı. Akışa
dokunulduğunda `00b`, `00c1` ve ilgili ekran kartı yanlışa döner. İki seçenek:
- Kod değişikliğiyle birlikte ilgili kartı güncelle (PR kuralı hâline getir)
- Ya da tarih damgası koy ve "şu tarihli fotoğraf" diye kullan

İkincisi daha gerçekçi. Mekanizasyon blokları (`M0`-`M12`) sayesinde tarama
katmanını yeniden üretmek yarım saat; asıl emek yorum katmanında.

Diyagramlarda bu daha da kolay: `REHBER.md`'deki Mermaid blokları M12'nin
ürettiği `_diyagram/DIYAGRAMLAR.md`'den kopyalanıyor. Akış değişince M0 + M12
koş, yeni blokları rehberdeki eskilerin üzerine yapıştır — anlatım metni
yerinde kalır. **Bu yüzden diyagramları rehberde elle düzeltme:** bir sonraki
koşuda kaybolur ve o arada kodla ayrışmış olur.

**4. Bir sonraki akış çok daha ucuz.** `annulment`, `branchopening`, `inquiry`
için `RUNBOOK.md`'deki kökleri ve `MEKANIZASYON.md`'deki `$gruplar`'ı
değiştirmen yeterli. Framework konvansiyonları (`00a`) zaten türetilmiş
durumda ve tekrar kullanılabilir — en pahalı adım oydu.

## İş katmanı eksikliği

Analizin tamamı koddan türetildi ve kod *niçin* sorusunu cevaplamıyor. Bu yüzden
`REHBER.md`'de iş gerekçesi gerektiren her yer `[İŞ BİRİMİNE SORULACAK]` diye
işaretlenir ve Bölüm 9'da toplanır. O listeyi iş birimiyle veya kıdemli bir
geliştiriciyle doldurmadan rehber yeni gelene verilmemeli — yarısı teknik
doğru, iş tarafı boş bir doküman yanıltıcıdır.

## Kalan açık sorular

`00c3-plan.md` §2'de kim cevaplayacak ataması yapılmış hâlde duruyorlar.
"insan" işaretli olanlar kodda cevabı olmayan sorulardır — commit geçmişi,
iş birimi bilgisi veya framework dokümantasyonu gerektirir. Bunları
iyileştirme planına girmeden önce netleştirmek gerekiyor, yoksa yanlış
varsayımla çözüm önerilir.
