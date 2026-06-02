#!/usr/bin/env bash
# Build the static CVE dashboard from grype scan output.
#
# Usage:
#   tools/dashboard/build.sh <reports-dir> <output-dir> [options]
#
# Inputs in <reports-dir>:
#   grype-<image>.json   — grype scan output (required, one per image)
#   meta-<image>.json    — optional: { size_bytes, built_at, image_ref, digest }
#
# Output in <output-dir>:
#   index.html           — overview table with sort, filter, severity bars
#   <image>.html         — per-image detail page with full CVE list
#   assets/style.css     — extracted stylesheet
#   assets/app.js        — sort/filter JS
#
# Environment overrides (used by CI):
#   BUILD_DATE           — display "Updated" timestamp (default: now UTC)
#   COMMIT_SHA           — short SHA for the footer link (default: empty)
#   RUN_URL              — link target for the SHA (default: empty)

set -euo pipefail

REPORTS_DIR="${1:?reports directory required}"
SITE_DIR="${2:?output directory required}"
BUILD_DATE="${BUILD_DATE:-$(date -u +"%Y-%m-%d %H:%M UTC")}"
COMMIT_SHA="${COMMIT_SHA:-}"
RUN_URL="${RUN_URL:-}"

mkdir -p "$SITE_DIR/assets"

#--- helpers ------------------------------------------------------------------

# Format byte count → "54 MB" / "1.2 GB"
fmt_bytes() {
  local b="${1:-0}"
  awk -v b="$b" 'BEGIN {
    split("B KB MB GB TB", units)
    i = 1
    while (b >= 1024 && i < 5) { b /= 1024; i++ }
    printf "%.0f %s", b, units[i]
  }'
}

# Days between an ISO8601 timestamp and now (integer; 0 if blank/invalid)
days_since() {
  local ts="${1:-}"
  [ -n "$ts" ] || { echo 0; return; }
  local then_s now_s
  then_s=$(date -u -d "$ts" +%s 2>/dev/null) || { echo 0; return; }
  now_s=$(date -u +%s)
  echo $(( (now_s - then_s) / 86400 ))
}

# Inline a CSS class for a non-zero severity count, else "zero"
sev_class() {
  local count="${1:-0}" sev="${2:-low}"
  [ "$count" -gt 0 ] && echo "$sev" || echo "zero"
}

#--- stylesheet ---------------------------------------------------------------

cat > "$SITE_DIR/assets/style.css" <<'CSS'
:root {
  --bg: #ffffff;
  --fg: #1f2328;
  --muted: #656d76;
  --border: #d0d7de;
  --row-alt: #f6f8fa;
  --link: #0969da;
  --critical: #d1242f;
  --high: #bc4c00;
  --medium: #bf8700;
  --low: #6e7781;
  --zero: #1a7f37;
  --chip-bg: #f6f8fa;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0d1117;
    --fg: #e6edf3;
    --muted: #8d96a0;
    --border: #30363d;
    --row-alt: #161b22;
    --link: #58a6ff;
    --critical: #ff7b72;
    --high: #ffa657;
    --medium: #d2a8ff;
    --low: #8d96a0;
    --zero: #56d364;
    --chip-bg: #161b22;
  }
}

* { box-sizing: border-box; }
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  max-width: 1200px;
  margin: 32px auto;
  padding: 0 20px;
  background: var(--bg);
  color: var(--fg);
  line-height: 1.5;
}
h1 { font-size: 28px; margin: 0 0 4px; font-weight: 600; }
.subtitle { color: var(--muted); font-size: 14px; margin: 0 0 8px; }
.meta { color: var(--muted); font-size: 13px; margin: 0 0 24px; }
.meta a { color: var(--link); text-decoration: none; }
.meta a:hover { text-decoration: underline; }
.back { font-size: 14px; margin-bottom: 16px; }
.back a { color: var(--link); text-decoration: none; }

/* Top summary chips */
.summary {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  margin-bottom: 20px;
}
.chip {
  background: var(--chip-bg);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 8px 12px;
  font-size: 13px;
  min-width: 110px;
}
.chip .label { color: var(--muted); display: block; font-size: 11px; text-transform: uppercase; letter-spacing: 0.04em; }
.chip .value { font-size: 20px; font-weight: 600; display: block; margin-top: 2px; }
.chip.critical .value { color: var(--critical); }
.chip.high .value { color: var(--high); }
.chip.medium .value { color: var(--medium); }
.chip.low .value { color: var(--low); }
.chip.zero .value { color: var(--zero); }

/* Filter input */
.controls {
  display: flex;
  gap: 12px;
  margin-bottom: 12px;
  align-items: center;
}
input[type="search"] {
  flex: 1;
  padding: 8px 12px;
  border: 1px solid var(--border);
  border-radius: 6px;
  font-size: 14px;
  background: var(--bg);
  color: var(--fg);
}
input[type="search"]:focus { outline: 2px solid var(--link); outline-offset: -1px; }
.hint { color: var(--muted); font-size: 12px; }

/* Table */
table { width: 100%; border-collapse: collapse; font-size: 13px; }
th, td { padding: 10px 12px; border: 1px solid var(--border); text-align: left; vertical-align: middle; }
th { background: var(--row-alt); font-weight: 600; cursor: pointer; user-select: none; position: relative; }
th[data-sort]::after { content: ""; opacity: 0.3; margin-left: 6px; }
th[data-sort].asc::after { content: "▲"; opacity: 1; }
th[data-sort].desc::after { content: "▼"; opacity: 1; }
tr:nth-child(even):not(.totals) td { background: var(--row-alt); }
tr.totals td { border-top: 2px solid var(--border); font-weight: 600; }
tr.hidden { display: none; }

a { color: var(--link); text-decoration: none; }
a:hover { text-decoration: underline; }

.critical { color: var(--critical); }
.high { color: var(--high); }
.medium { color: var(--medium); }
.low { color: var(--low); }
.zero { color: var(--zero); }
.num { text-align: right; font-variant-numeric: tabular-nums; }

/* Severity bar — horizontal stacked CSS bar */
.sevbar {
  display: flex;
  height: 6px;
  border-radius: 3px;
  overflow: hidden;
  background: var(--border);
  min-width: 80px;
}
.sevbar > span { display: block; height: 100%; }
.sevbar > .b-critical { background: var(--critical); }
.sevbar > .b-high { background: var(--high); }
.sevbar > .b-medium { background: var(--medium); }
.sevbar > .b-low { background: var(--low); }

/* Mobile */
@media (max-width: 700px) {
  body { margin: 16px auto; }
  table { font-size: 12px; }
  th, td { padding: 6px 8px; }
  .chip { min-width: 90px; }
}
CSS

#--- per-image-table javascript -----------------------------------------------

cat > "$SITE_DIR/assets/app.js" <<'JS'
(function () {
  var input = document.getElementById('filter');
  var table = document.getElementById('imgtable');
  if (!table) return;
  var tbody = table.tBodies[0];
  if (!tbody) return;
  var rows = Array.prototype.slice.call(tbody.rows);

  // Filter
  if (input) {
    input.addEventListener('input', function () {
      var q = input.value.toLowerCase();
      rows.forEach(function (r) {
        if (r.classList.contains('totals')) return;
        var name = (r.dataset.name || '').toLowerCase();
        r.classList.toggle('hidden', q.length > 0 && name.indexOf(q) === -1);
      });
    });
  }

  // Sort
  var ths = table.tHead.querySelectorAll('th[data-sort]');
  ths.forEach(function (th, idx) {
    th.addEventListener('click', function () {
      var key = th.dataset.sort;
      var current = th.classList.contains('asc') ? 'desc' : 'asc';
      ths.forEach(function (t) { t.classList.remove('asc', 'desc'); });
      th.classList.add(current);
      var mult = current === 'asc' ? 1 : -1;

      var sortable = rows.filter(function (r) { return !r.classList.contains('totals'); });
      var totals = rows.filter(function (r) { return r.classList.contains('totals'); });

      sortable.sort(function (a, b) {
        var av = a.dataset[key];
        var bv = b.dataset[key];
        var an = parseFloat(av);
        var bn = parseFloat(bv);
        if (!isNaN(an) && !isNaN(bn)) return (an - bn) * mult;
        return String(av || '').localeCompare(String(bv || '')) * mult;
      });

      sortable.concat(totals).forEach(function (r) { tbody.appendChild(r); });
    });
  });
})();
JS

#--- per-image detail pages + index row data ---------------------------------

# Aggregate totals
TOTAL_CRIT=0; TOTAL_HIGH=0; TOTAL_MED=0; TOTAL_LOW=0
TOTAL_FIXABLE=0; TOTAL_IMAGES=0; CLEAN_IMAGES=0

# Build rows in a temp file (so the for-loop subshells don't lose state)
ROWS_FILE=$(mktemp)
trap 'rm -f "$ROWS_FILE"' EXIT

shopt -s nullglob
for f in "$REPORTS_DIR"/grype-*.json; do
  NAME=$(basename "$f" .json | sed 's/^grype-//')
  TOTAL_IMAGES=$((TOTAL_IMAGES + 1))

  # Severity counts
  C=$(jq '[.matches[] | select(.vulnerability.severity | ascii_upcase == "CRITICAL")] | length' "$f")
  H=$(jq '[.matches[] | select(.vulnerability.severity | ascii_upcase == "HIGH")] | length' "$f")
  M=$(jq '[.matches[] | select(.vulnerability.severity | ascii_upcase == "MEDIUM")] | length' "$f")
  L=$(jq '[.matches[] | select(.vulnerability.severity | ascii_upcase == "LOW")] | length' "$f")
  T=$((C + H + M + L))

  # Fixable count: CVEs where grype knows a fix version exists
  FIXABLE=$(jq '[.matches[] | select((.vulnerability.fix.versions // []) | length > 0)] | length' "$f")

  TOTAL_CRIT=$((TOTAL_CRIT + C))
  TOTAL_HIGH=$((TOTAL_HIGH + H))
  TOTAL_MED=$((TOTAL_MED + M))
  TOTAL_LOW=$((TOTAL_LOW + L))
  TOTAL_FIXABLE=$((TOTAL_FIXABLE + FIXABLE))
  [ "$T" -eq 0 ] && CLEAN_IMAGES=$((CLEAN_IMAGES + 1))

  # Optional meta
  META="$REPORTS_DIR/meta-$NAME.json"
  if [ -f "$META" ]; then
    SIZE_BYTES=$(jq -r '.size_bytes // 0' "$META")
    BUILT_AT=$(jq -r '.built_at // ""' "$META")
    DIGEST=$(jq -r '.digest // ""' "$META")
  else
    SIZE_BYTES=0
    BUILT_AT=""
    DIGEST=""
  fi
  SIZE_DISPLAY=$([ "$SIZE_BYTES" -gt 0 ] && fmt_bytes "$SIZE_BYTES" || echo "—")
  AGE_DAYS=$(days_since "$BUILT_AT")
  AGE_DISPLAY=$([ -n "$BUILT_AT" ] && echo "${AGE_DAYS}d" || echo "—")

  # Severity bar — width per band proportional to its share of T
  if [ "$T" -gt 0 ]; then
    CW=$(( C * 100 / T ))
    HW=$(( H * 100 / T ))
    MW=$(( M * 100 / T ))
    LW=$(( 100 - CW - HW - MW ))
    BAR="<div class=\"sevbar\" title=\"C:$C H:$H M:$M L:$L\"><span class=\"b-critical\" style=\"width:${CW}%\"></span><span class=\"b-high\" style=\"width:${HW}%\"></span><span class=\"b-medium\" style=\"width:${MW}%\"></span><span class=\"b-low\" style=\"width:${LW}%\"></span></div>"
  else
    BAR="<div class=\"sevbar\" title=\"clean\"></div>"
  fi

  CCLASS=$(sev_class "$C" critical)
  HCLASS=$(sev_class "$H" high)
  MCLASS=$(sev_class "$M" medium)
  LCLASS=$(sev_class "$L" low)

  # Index row
  printf '<tr data-name="%s" data-crit="%d" data-high="%d" data-med="%d" data-low="%d" data-total="%d" data-fixable="%d" data-size="%d" data-age="%d"><td><a href="%s.html">%s</a></td><td class="num %s">%d</td><td class="num %s">%d</td><td class="num %s">%d</td><td class="num %s">%d</td><td class="num">%d</td><td>%s</td><td class="num">%d</td><td class="num">%s</td><td>%s</td></tr>\n' \
    "$NAME" "$C" "$H" "$M" "$L" "$T" "$FIXABLE" "$SIZE_BYTES" "$AGE_DAYS" \
    "$NAME" "$NAME" \
    "$CCLASS" "$C" "$HCLASS" "$H" "$MCLASS" "$M" "$LCLASS" "$L" "$T" \
    "$BAR" "$FIXABLE" "$SIZE_DISPLAY" "$AGE_DISPLAY" >> "$ROWS_FILE"

  # Per-image detail page
  CVE_ROWS=$(jq -r '
    .matches
    | sort_by(if (.vulnerability.severity | ascii_upcase) == "CRITICAL" then 0
              elif (.vulnerability.severity | ascii_upcase) == "HIGH"    then 1
              elif (.vulnerability.severity | ascii_upcase) == "MEDIUM"  then 2
              else 3 end)
    | .[]
    | "<tr><td>\(.artifact.name)</td><td>\(.artifact.version)</td><td class=\"\(.vulnerability.severity | ascii_downcase)\">\(.vulnerability.severity | ascii_upcase)</td><td><a href=\"\(.vulnerability.dataSource // "")\" target=\"_blank\" rel=\"noopener\">\(.vulnerability.id)</a></td><td>\((.vulnerability.fix.versions // [])[0] // "—")</td><td>\(.vulnerability.description // "" | .[0:160] | @html)</td></tr>"
  ' "$f" 2>/dev/null || true)

  DIGEST_LINE=""
  if [ -n "$DIGEST" ]; then
    DIGEST_LINE="<p class=\"meta\">Image digest: <code>${DIGEST}</code></p>"
  fi

  cat > "$SITE_DIR/$NAME.html" <<DETAIL
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${NAME} — Vulnerability Report</title>
<link rel="stylesheet" href="assets/style.css">
</head>
<body>
<p class="back"><a href="index.html">← All images</a></p>
<h1>${NAME}</h1>
<p class="subtitle">${T} open finding$([ "$T" -eq 1 ] || echo s) · ${FIXABLE} with upstream fix available</p>
<p class="meta">Image: <code>ghcr.io/rtvkiz/minimal-${NAME}:latest</code> &nbsp;·&nbsp; Size: ${SIZE_DISPLAY} &nbsp;·&nbsp; Last rebuilt: ${AGE_DISPLAY} ago &nbsp;·&nbsp; Updated: ${BUILD_DATE}</p>
${DIGEST_LINE}
<table>
<thead><tr><th>Package</th><th>Version</th><th>Severity</th><th>CVE</th><th>Fix</th><th>Description</th></tr></thead>
<tbody>
${CVE_ROWS:-<tr><td colspan="6">No vulnerabilities found.</td></tr>}
</tbody>
</table>
</body>
</html>
DETAIL
done
shopt -u nullglob

TOTAL_ALL=$((TOTAL_CRIT + TOTAL_HIGH + TOTAL_MED + TOTAL_LOW))

# Totals row appended last
printf '<tr class="totals"><td>Total (%d images)</td><td class="num critical">%d</td><td class="num high">%d</td><td class="num medium">%d</td><td class="num low">%d</td><td class="num">%d</td><td></td><td class="num">%d</td><td></td><td></td></tr>\n' \
  "$TOTAL_IMAGES" "$TOTAL_CRIT" "$TOTAL_HIGH" "$TOTAL_MED" "$TOTAL_LOW" "$TOTAL_ALL" "$TOTAL_FIXABLE" >> "$ROWS_FILE"

#--- index page ---------------------------------------------------------------

COMMIT_LINK=""
if [ -n "$COMMIT_SHA" ]; then
  if [ -n "$RUN_URL" ]; then
    COMMIT_LINK="&nbsp;·&nbsp; Commit: <a href=\"${RUN_URL}\">${COMMIT_SHA}</a>"
  else
    COMMIT_LINK="&nbsp;·&nbsp; Commit: ${COMMIT_SHA}"
  fi
fi

cat > "$SITE_DIR/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Vulnerability Report — Minimal Images</title>
<link rel="stylesheet" href="assets/style.css">
</head>
<body>
<h1>Vulnerability Report</h1>
<p class="subtitle">Daily Grype scan across all production images. Click an image for the full CVE list.</p>
<p class="meta">Updated: ${BUILD_DATE}${COMMIT_LINK}</p>

<div class="summary">
  <div class="chip $([ "$TOTAL_CRIT" -gt 0 ] && echo critical || echo zero)">
    <span class="label">Critical</span><span class="value">${TOTAL_CRIT}</span>
  </div>
  <div class="chip $([ "$TOTAL_HIGH" -gt 0 ] && echo high || echo zero)">
    <span class="label">High</span><span class="value">${TOTAL_HIGH}</span>
  </div>
  <div class="chip $([ "$TOTAL_MED" -gt 0 ] && echo medium || echo zero)">
    <span class="label">Medium</span><span class="value">${TOTAL_MED}</span>
  </div>
  <div class="chip $([ "$TOTAL_LOW" -gt 0 ] && echo low || echo zero)">
    <span class="label">Low</span><span class="value">${TOTAL_LOW}</span>
  </div>
  <div class="chip"><span class="label">Fixable</span><span class="value">${TOTAL_FIXABLE}</span></div>
  <div class="chip zero"><span class="label">Clean images</span><span class="value">${CLEAN_IMAGES} / ${TOTAL_IMAGES}</span></div>
</div>

<div class="controls">
  <input id="filter" type="search" placeholder="Filter by image name…" autocomplete="off" autocorrect="off" autocapitalize="off" spellcheck="false">
  <span class="hint">Click a column header to sort</span>
</div>

<table id="imgtable">
<thead>
<tr>
  <th data-sort="name">Image</th>
  <th data-sort="crit" class="num">Crit</th>
  <th data-sort="high" class="num">High</th>
  <th data-sort="med" class="num">Med</th>
  <th data-sort="low" class="num">Low</th>
  <th data-sort="total" class="num">Total</th>
  <th>Severity mix</th>
  <th data-sort="fixable" class="num">Fixable</th>
  <th data-sort="size" class="num">Size</th>
  <th data-sort="age">Built</th>
</tr>
</thead>
<tbody>
$(cat "$ROWS_FILE")
</tbody>
</table>

<script src="assets/app.js"></script>
</body>
</html>
HTML

echo "Wrote $SITE_DIR/index.html ($TOTAL_IMAGES images, $TOTAL_ALL findings, $CLEAN_IMAGES clean)"
