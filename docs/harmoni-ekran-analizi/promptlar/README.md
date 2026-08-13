# Hazır Promptlar

Her dosya **kopyala-yapıştır hazır**: P0 sabit başlığı + o adımın gövdesi
birleştirilmiş. Ayrıca bir şey eklemene gerek yok.

Kullanım: dosyayı VS Code'da aç → `Ctrl+A` → `Ctrl+C` → Copilot chat'e yapıştır.
**Her adım yeni chat'te.**

| Dosya | Adım | Model | Çıktı |
|---|---|---|---|
| `07-envanter.txt` | Envanter + konvansiyon türetme | Sonnet | `00a-envanter.md` |
| `08-akis-yorum.txt` | Akış yorumu (grafik M1'den hazır) | Sonnet | `00b-akis.md` |
| `09-state-plan.txt` | State + servis + ikiz + grup planı | **Opus** | `00c-plan.md` |
| `10-dogrulama.txt` | Doğrulama | Sonnet | ilgili dosyaya düzeltme |
| `12-ekran-karti.txt` | Ekran kartı tamamlama | Sonnet | `ekranlar/*.hazir.md` |
| `13-konsolidasyon.txt` | Konsolidasyon | **Opus** | `90-konsolidasyon.md` |
| `16-iyilestirme.txt` | İyileştirme planı | **Opus** | `99-iyilestirme.md` |

## Elle doldurman gerekenler

- **`10-dogrulama.txt`** — `# GİRDİ` bölümündeki dosya listesi. Adım 10'da
  `00a`/`00b`/`00c`, Adım 14'te `90-konsolidasyon.md`.
- **`12-ekran-karti.txt`** — `# BU TURUN KAPSAMI` bölümü: grup adı, ekranlar,
  derinlik ve her ekranın kaynak dosyaları. Grup bilgisi `00c-plan.md`'deki
  "Derin Analiz Planı" tablosundan gelir. Bu prompt grup sayısı kadar
  çalıştırılır.
- **`13-konsolidasyon.txt`** — tüm ekran kartlarını `#file:` ile ekle.

## Sıra

Ayrıntı için [../RUNBOOK.md](../RUNBOOK.md) ve [../MEKANIZASYON.md](../MEKANIZASYON.md).

```
PowerShell: Adım 0-6  →  M0, M1, M2, M3
07  →  M4 (svcRx'i 00a'ya göre daralt)  →  08  →  09
10 + elle spot-check
12 × grup sayısı  →  13  →  14 + elle spot-check  →  16
```

## Yeniden üretme

Bu dosyalar RUNBOOK.md ve MEKANIZASYON.md'den türetildi. Kaynak dosyalarda
prompt değişirse buradakiler otomatik güncellenmez — elle eşitle.
