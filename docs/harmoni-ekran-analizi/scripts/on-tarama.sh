#!/usr/bin/env bash
# Harmoni akış analizi — ön-tarama
#
# Kullanım (FE repo kökünde):
#   bash docs/harmoni-ekran-analizi/scripts/on-tarama.sh
#   bash docs/harmoni-ekran-analizi/scripts/on-tarama.sh <akis-yolu> <cikti-klasoru>
#
# Ortam: macOS, Linux, WSL veya Windows'ta Git Bash.
# PowerShell kullanıyorsan on-tarama.ps1 dosyasını çalıştır.

set -uo pipefail

ENTRY="${1:-cct/page/acq/entry}"
OUT="${2:-docs/entry-akis/_tarama}"

if [ ! -d "$ENTRY" ]; then
  echo "HATA: '$ENTRY' klasörü bulunamadı." >&2
  echo "FE repo kökünde çalıştırdığından emin ol, veya yolu parametre olarak ver:" >&2
  echo "  bash $0 <akis-yolu>" >&2
  exit 1
fi

ACQ="$(dirname "$ENTRY")"
mkdir -p "$OUT"

echo "Akış   : $ENTRY"
echo "Çıktı  : $OUT"
echo

# 1. Dosya envanteri + satır sayıları
find "$ENTRY" -type f \( -name "*.java" -o -name "*.html" -o -name "*.js" -o -name "*.json" \) \
  -exec wc -l {} + 2>/dev/null | grep -v ' total$' | sort -k2 > "$OUT/01-dosyalar.txt" || true

# 2. Navigasyon / dialog / event çağrıları
grep -rn "startNewProcess\|showCustomMessageBox\|fireEvent\|CCT\|openDialog\|closeDialog" \
  "$ENTRY" > "$OUT/02-gecisler.txt" 2>/dev/null || true

# 3. Servis (Intf) çağrıları
grep -rnE "HMN_[A-Za-z_]*Intf|[A-Za-z]+Intf[[:space:]]*\.|[A-Za-z]+Service[[:space:]]*\." \
  "$ENTRY" > "$OUT/03-servisler.txt" 2>/dev/null || true

# 4. Akışa DIŞARIDAN yapılan çağrılar (giriş noktaları)
# Klasör adını değil EKRAN ADLARINI arıyoruz — navigasyon sayfa sınıfını
# referanslıyor, klasörü değil.
NAMES=$(find "$ENTRY" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | paste -sd'|' -)
if [ -n "$NAMES" ]; then
  grep -rnE "$NAMES" "$ACQ" --include=*.java --include=*.js 2>/dev/null \
    | grep -v "/entry/" > "$OUT/04-giris-noktalari.txt" || true
else
  : > "$OUT/04-giris-noktalari.txt"
fi

# 5. Session / global state kullanımı
grep -rniE "session|getAttribute|setAttribute|processContext|globalMap" \
  "$ENTRY" > "$OUT/05-state.txt" 2>/dev/null || true

# 6. Ekran boyutları (toplam satır, büyükten küçüğe)
: > "$OUT/06-ekran-boyutlari.txt"
for d in "$ENTRY"/*/; do
  [ -d "$d" ] || continue
  n=$(find "$d" -type f -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
  echo "$n $(basename "$d")"
done | sort -rn >> "$OUT/06-ekran-boyutlari.txt"

# Özet
echo "Sonuç:"
for f in 01-dosyalar 02-gecisler 03-servisler 04-giris-noktalari 05-state 06-ekran-boyutlari; do
  n=$(wc -l < "$OUT/$f.txt" | tr -d ' ')
  if [ "$n" -eq 0 ]; then
    printf '  %-22s %5s satır   << BOŞ — deseni kontrol et\n' "$f.txt" "$n"
  else
    printf '  %-22s %5s satır\n' "$f.txt" "$n"
  fi
done

echo
echo "Ekran sayısı: $(find "$ENTRY" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
echo
echo "BOŞ dosya varsa: o mekanizma bu akışta kullanılmıyor olabilir, ya da isim"
echo "farklıdır. Koddan doğrulayıp script'teki grep desenini güncelle."
echo "Boş çıktıyı silme — modelin 'arandı, bulunamadı' ile 'hiç aranmadı'"
echo "arasındaki farkı bilmesi gerekiyor."
