#!/usr/bin/env bash
# RGU DPWH Pull Script
# Purpose: Mirror high-value DPWH references into the RGU BlueBook folder structure.
# Author: ChatGPT (for DJ Capili)
# Date: 2025-09-17 09:23 PST
set -euo pipefail

# ====== Configuration ======
BLUEBOOK_DIR="${BLUEBOOK_DIR:-RGU BlueBook/DPWH References}"
UA="${UA:-RGU-DPWH-Puller/1.0 (+rgu.marketing)}"
WGET_COMMON=(wget -e robots=off -U "$UA" -w 1 --random-wait -N -nd)

# Create folder map
mkdir -p "${BLUEBOOK_DIR}/01_Issuances/Department Orders (DO)"
mkdir -p "${BLUEBOOK_DIR}/01_Issuances/Department Memorandum Circulars (DMC)"
mkdir -p "${BLUEBOOK_DIR}/01_Issuances/Special Orders (SO)"
mkdir -p "${BLUEBOOK_DIR}/02_Guidelines & Manuals"
mkdir -p "${BLUEBOOK_DIR}/03_Standard Specifications (Blue Book)"
mkdir -p "${BLUEBOOK_DIR}/04_Standard Design Drawings"
mkdir -p "${BLUEBOOK_DIR}/05_Citizens Charter"
mkdir -p "${BLUEBOOK_DIR}/06_Safety, Environment & QA"
mkdir -p "${BLUEBOOK_DIR}/07_Other Technical References"

# Helper: fetch with recursion (for listing pages that link to PDFs)
fetch_recursive() {
  local dest="$1"
  local depth="$2"
  local url="$3"

  printf '>> Fetch (recursive l%s): %s -> %s\n' "$depth" "$url" "$dest"
  ( cd "$dest" && "${WGET_COMMON[@]}" -r -l "$depth" -np -A pdf "$url" )
}

# Helper: fetch direct PDF(s)
fetch_direct() {
  local dest="$1"
  shift || true
  local urls=("$@")

  [[ ${#urls[@]} -gt 0 ]] || return 0
  printf '>> Fetch (direct): %s -> %s\n' "${urls[*]}" "$dest"
  ( cd "$dest" && "${WGET_COMMON[@]}" "${urls[@]}" )
}

# ====== 01_Issuances ======
fetch_recursive "${BLUEBOOK_DIR}/01_Issuances/Department Orders (DO)" 2 \
  "https://www.dpwh.gov.ph/dpwh/references/issuances/department_order"

fetch_recursive "${BLUEBOOK_DIR}/01_Issuances/Special Orders (SO)" 2 \
  "https://www.dpwh.gov.ph/dpwh/references/issuances/special_order"

fetch_recursive "${BLUEBOOK_DIR}/01_Issuances/Department Memorandum Circulars (DMC)" 2 \
  "https://www.dpwh.gov.ph/dpwh/references/issuances/department_memorandum_circulars"

# ====== 02_Guidelines & Manuals ======
fetch_recursive "${BLUEBOOK_DIR}/02_Guidelines & Manuals" 3 \
  "https://www.dpwh.gov.ph/dpwh/references/guidelines_manuals"
fetch_recursive "${BLUEBOOK_DIR}/02_Guidelines & Manuals" 2 \
  "https://www.dpwh.gov.ph/dpwh/references/guidelines_manuals/highway_safety_design_standards_manual"

# ====== 03_Standard Specifications (Blue Book) ======
fetch_direct "${BLUEBOOK_DIR}/03_Standard Specifications (Blue Book)" \
  "https://www.dpwh.gov.ph/dpwh/sites/default/files/issuances/do_032_s2025.pdf" \
  "https://www.dpwh.gov.ph/DPWH/sites/default/files/webform/civil_works/advertisement/volume_iv_final_draft_march._2024.pdf"

# Example of DO that amends specific items (e.g., Item 500)
fetch_recursive "${BLUEBOOK_DIR}/03_Standard Specifications (Blue Book)" 1 \
  "https://www.dpwh.gov.ph/dpwh/issuances/department-order/33136"

# ====== 04_Standard Design Drawings ======
fetch_recursive "${BLUEBOOK_DIR}/04_Standard Design Drawings" 3 \
  "https://www.dpwh.gov.ph/dpwh/references/standard_design"
fetch_direct "${BLUEBOOK_DIR}/04_Standard Design Drawings" \
  "https://www.dpwh.gov.ph/dpwh/sites/default/files/issuances/DO_062_S2013.pdf"

# ====== 05_Citizens Charter ======
fetch_direct "${BLUEBOOK_DIR}/05_Citizens Charter" \
  "https://www.dpwh.gov.ph/dpwh/sites/default/files/citizens%20charter.pdf" \
  "https://www.dpwh.gov.ph/dpwh/sites/default/files/DPWH_Citizens%20Charter_2021_V2.pdf" \
  "https://www.dpwh.gov.ph/dpwh/sites/default/files/preliminaries_11202023_.pdf"

# ====== 06_Safety, Environment & QA ======
fetch_direct "${BLUEBOOK_DIR}/06_Safety, Environment & QA" \
  "https://www.dpwh.gov.ph/dpwh/sites/default/files/DPWH%20SEMS%202021.pdf" \
  "https://www.dpwh.gov.ph/dpwh/sites/default/files/BSDS%20Design%20Standard%20Guide%20Manual.pdf" \
  "https://www.dpwh.gov.ph/dpwh/sites/default/files/Simplified%20Construction%20Handbook.pdf"


# ====== 08_Procurement (Region IX ▸ Zamboanga del Norte 3rd & 4th DEOs) ======
# Tunables (env vars with sensible defaults):
CW_CUR_START="${CW_CUR_START:-0}";   CW_CUR_END="${CW_CUR_END:-30}"
CW_ARC_START="${CW_ARC_START:-0}";   CW_ARC_END="${CW_ARC_END:-800}"
GS_CUR_START="${GS_CUR_START:-0}";   GS_CUR_END="${GS_CUR_END:-50}"
GS_ARC_START="${GS_ARC_START:-0}";   GS_ARC_END="${GS_ARC_END:-800}"
YEAR_MIN="${YEAR_MIN:-2021}"   # keep items mentioned in pages/URLs with year >= YEAR_MIN when detectable

year_ok() {
  # returns 0 if URL or context likely >= YEAR_MIN
  local url="$1"
  local y

  y=$(printf '%s' "$url" | grep -Eo '20[0-9]{2}' | tail -n1)
  if [[ -n "$y" ]]; then
    if [[ "$y" -ge "$YEAR_MIN" ]]; then
      return 0
    else
      return 1
    fi
  fi

  # Fallback: allow if unknown
  return 0
}

mkdir -p "${BLUEBOOK_DIR}/08_Procurement/Civil Works/Region IX - ZN 3rd DEO (JD)"
mkdir -p "${BLUEBOOK_DIR}/08_Procurement/Civil Works/Region IX - ZN 4th DEO (JJ)"
mkdir -p "${BLUEBOOK_DIR}/08_Procurement/Goods & Services/Region IX - ZN 3rd DEO"
mkdir -p "${BLUEBOOK_DIR}/08_Procurement/Goods & Services/Region IX - ZN 4th DEO"

# Helpers for procurement scraping
fetch_pages() {
  # $1 dest; $2 base_url; $3 start_page; $4 end_page
  local dest="$1"
  local base="$2"
  local start_page="$3"
  local end_page="$4"

  mkdir -p "$dest/html"
  for p in $(seq "$start_page" "$end_page"); do
    local url="${base}${p}"
    printf '>> Fetch list page: %s\n' "$url"
    if ! curl -A "$UA" -sS "$url" -o "$dest/html/page_${p}.html"; then
      printf '!! Failed to download %s\n' "$url" >&2
    fi
  done
}

extract_pdf_links() {
  # $1 html_dir; $2 grep_office (regex); $3 grep_code (regex like '(jd|jj)')
  local html_dir="$1"
  local office_rx="$2"
  local code_rx="$3"
  local page

  grep -Ei "$office_rx" -r "$html_dir" -n | cut -d: -f1 | sort -u | while read -r page; do
    grep -Eo 'href="[^"]+\.pdf"' "$page" | sed -E 's/^href="(.*)"/\1/' |
      grep -E '/webform/(civil_works|gs)/advertisement/.*\.pdf|/sites/default/files/.*\.pdf' |
      grep -Ei "$code_rx" |
      sed -E 's#^//#https://#' |
      sed -E 's#^/+#https://www.dpwh.gov.ph/#' |
      sed -E 's#^http://#https://#'
  done | sort -u
}

download_pdfs() {
  # $1 dest; reads URLs from stdin
  local dest="$1"

  mkdir -p "$dest"
  while IFS= read -r url; do
    [[ -n "$url" ]] || continue
    if ! year_ok "$url"; then
      printf '>> Skip (year<%s): %s\n' "$YEAR_MIN" "$url"
      continue
    fi
    printf '>> PDF: %s\n' "$url"
    ( cd "$dest" && "${WGET_COMMON[@]}" "$url" )
  done
}

# CIVIL WORKS: current + archive pages (bounded window)
CW_BASE_CUR="https://www.dpwh.gov.ph/dpwh/business/procurement/cw/advertisement?page="
CW_BASE_ARC="https://www.dpwh.gov.ph/dpwh/business/procurement/cw/current_archive/advertisements?page="
CW_TMP="${BLUEBOOK_DIR}/08_Procurement/_tmp_cw"
rm -rf "$CW_TMP"
mkdir -p "$CW_TMP"
fetch_pages "$CW_TMP" "$CW_BASE_CUR" "$CW_CUR_START" "$CW_CUR_END"
fetch_pages "$CW_TMP" "$CW_BASE_ARC" "$CW_ARC_START" "$CW_ARC_END"

# Extract & download for 3rd DEO (JD) and 4th DEO (JJ)
extract_pdf_links "$CW_TMP/html" "Zamboanga[[:space:]]+del[[:space:]]+Norte[[:space:]]+3rd|25jd" "(jd)" \
  | download_pdfs "${BLUEBOOK_DIR}/08_Procurement/Civil Works/Region IX - ZN 3rd DEO (JD)"
extract_pdf_links "$CW_TMP/html" "Zamboanga[[:space:]]+del[[:space:]]+Norte[[:space:]]+4th|25jj" "(jj)" \
  | download_pdfs "${BLUEBOOK_DIR}/08_Procurement/Civil Works/Region IX - ZN 4th DEO (JJ)"

# GOODS & SERVICES: current + archive pages (bounded window)
GS_BASE_CUR="https://www.dpwh.gov.ph/dpwh/business/procurement/gs/advertisement?page="
GS_BASE_ARC="https://www.dpwh.gov.ph/dpwh/business/procurement/gs/archive/advertisement?page="
GS_TMP="${BLUEBOOK_DIR}/08_Procurement/_tmp_gs"
rm -rf "$GS_TMP"
mkdir -p "$GS_TMP"
fetch_pages "$GS_TMP" "$GS_BASE_CUR" "$GS_CUR_START" "$GS_CUR_END"
fetch_pages "$GS_TMP" "$GS_BASE_ARC" "$GS_ARC_START" "$GS_ARC_END"

# For GS, filter by office text on pages, then pull linked PDFs (usually RFQ/ITB)
extract_pdf_links "$GS_TMP/html" "Zamboanga[[:space:]]+del[[:space:]]+Norte[[:space:]]+3rd" "(jj|jd|g)" \
  | download_pdfs "${BLUEBOOK_DIR}/08_Procurement/Goods & Services/Region IX - ZN 3rd DEO"
extract_pdf_links "$GS_TMP/html" "Zamboanga[[:space:]]+del[[:space:]]+Norte[[:space:]]+4th" "(jj|jd|g)" \
  | download_pdfs "${BLUEBOOK_DIR}/08_Procurement/Goods & Services/Region IX - ZN 4th DEO"

# Clean temp html (keep if DEBUG=1)
if [[ "${DEBUG:-0}" != "1" ]]; then
  rm -rf "$CW_TMP" "$GS_TMP"
fi

# ====== Post-process: checksums and inventory ======
checksum_folder() {
  local d="$1"

  printf '>> Checksums: %s\n' "$d"
  ( cd "$d" && {
      find . -maxdepth 1 -type f -name '*.pdf' -print0 \
        | sort -z \
        | xargs -0 -r sha256sum \
        | sort -k2,2 || true
    } > checksums.sha256 )
}

inventory_folder() {
  local d="$1"

  printf '>> Inventory: %s\n' "$d"
  ( cd "$d" && {
      echo "file,size_bytes,mtime_iso"
      find . -maxdepth 1 -type f -name '*.pdf' -print0 | sort -z | while IFS= read -r -d '' file; do
        local base="${file#./}"
        local size
        local mtime
        size=$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file")
        mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file")
        if [[ -n "$mtime" ]]; then
          mtime=$(date -u -d "@$mtime" '+%Y-%m-%dT%H:%M:%SZ')
        else
          mtime=""
        fi
        printf '%s,%s,%s\n' "$base" "$size" "$mtime"
      done
    } > index.csv )
}

for d in \
  "${BLUEBOOK_DIR}/01_Issuances/Department Orders (DO)" \
  "${BLUEBOOK_DIR}/01_Issuances/Department Memorandum Circulars (DMC)" \
  "${BLUEBOOK_DIR}/01_Issuances/Special Orders (SO)" \
  "${BLUEBOOK_DIR}/02_Guidelines & Manuals" \
  "${BLUEBOOK_DIR}/03_Standard Specifications (Blue Book)" \
  "${BLUEBOOK_DIR}/04_Standard Design Drawings" \
  "${BLUEBOOK_DIR}/05_Citizens Charter" \
  "${BLUEBOOK_DIR}/06_Safety, Environment & QA"; do
  checksum_folder "$d"
  inventory_folder "$d"
done

# ====== Summary tree ======
printf '>> Summary (top-level PDFs):\n'
( cd "${BLUEBOOK_DIR}" && find . -maxdepth 2 -type f -name '*.pdf' | sort )
printf 'DONE.\n'
