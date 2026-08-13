# Hazır Promptlar

Her dosya **kopyala-yapıştır hazır**: P0 sabit başlığı + o adımın gövdesi
birleştirilmiş. Ayrıca bir şey eklemene gerek yok.

Kullanım: dosyayı VS Code'da aç → `Ctrl+A` → `Ctrl+C` → Copilot chat'e yapıştır.
**Her adım yeni chat'te.**

| Dosya | Adım | Model | Çıktı |
|---|---|---|---|
| `07-envanter.txt` | Envanter + konvansiyon türetme | Sonnet | `00a-envanter.md` |
| `08-akis-yorum.txt` | Akış yorumu (grafik M1'den hazır) | Sonnet | `00b-akis.md` |
| `09a-state.txt` | Paylaşılan state'i yorumla (M7 üretir) | Sonnet | `00c1-state.md` |
| `09b-servis-dto.txt` | Servis, DTO, auth, ikizler | Sonnet | `00c2-servis-dto.md` |
| `09c-plan.txt` | Grup planı + açık soru kapanışı | Sonnet | `00c3-plan.md` |
| `10-dogrulama.txt` | Doğrulama | Sonnet | ilgili dosyaya düzeltme |
| `12-ekran-karti.txt` | Ekran kartı tamamlama | Sonnet | `ekranlar/*.hazir.md` |
| `13-konsolidasyon.txt` | Konsolidasyon | Sonnet | `90-konsolidasyon.md` |
| `16-iyilestirme.txt` | İyileştirme planı | Sonnet | `99-iyilestirme.md` |

## Elle doldurman gerekenler

- **`10-dogrulama.txt`** — `# GİRDİ` bölümündeki dosya listesi. Adım 10'da
  `00a`/`00b`/`00c`, Adım 14'te `90-konsolidasyon.md`.
- **`12-ekran-karti.txt`** — `# BU TURUN KAPSAMI` bölümü: grup adı, ekranlar,
  derinlik ve her ekranın kaynak dosyaları. Grup bilgisi `00c-plan.md`'deki
  "Derin Analiz Planı" tablosundan gelir. Bu prompt grup sayısı kadar
  çalıştırılır.
- **`13-konsolidasyon.txt`** — tüm ekran kartlarını `#file:` ile ekle.

> **Model seçimi — ölçülmüş davranış.** Bu kurulumda denenen her Opus turu
> zaman aşımına uğradı (Adım 9, 9a ×2, 9c), denenen her Sonnet turu bitti
> (7, 8, 9a, 9b). Girdi kırpmak Opus'u kurtarmadı. Varsayılan **Sonnet**;
> Opus'u yalnızca çok küçük ve yargı yoğun bir tur için dene, bitmezse
> ısrar etme.
>
> **Zaman aşımı alırsan** üç sebep olabilir:
> 1. *Girdi büyük* → çıktı bölümlerine göre böl, frekans listelerini M6 ile kırp.
> 2. *Model keşif yapıyor* → prompt "kodda doğrula" diyorsa model onlarca
>    dosya açar. Çözüm bölmek değil, o keşfi script'e almak.
> 3. *Üretim uzun* → çıktı yüzlerce satır olacaksa tur bitmez. Çözüm
>    **yorumlanacak satır sayısını mekanik olarak azaltmak**. Adım 9a'da
>    ikisi de yaşandı: M7 sözlüğü üretti (2), sonra yerel alanlar elenip
>    yalnızca paylaşılanlar bırakıldı (3).

## Sıra

Ayrıntı için [../RUNBOOK.md](../RUNBOOK.md) ve [../MEKANIZASYON.md](../MEKANIZASYON.md).

```
PowerShell: Adım 0-6  →  M0, M1, M2, M3
07  →  M4  →  M6 (kırpma)  →  08  →  M7 (state)  →  09a  →  09b  →  09c
10 + elle spot-check
12 × grup sayısı  →  13  →  14 + elle spot-check  →  16
```

## Yeniden üretme

Bu dosyalar RUNBOOK.md ve MEKANIZASYON.md'den türetildi. Kaynak dosyalarda
prompt değişirse buradakiler otomatik güncellenmez — elle eşitle.
