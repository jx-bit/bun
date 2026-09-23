#!/usr/bin/env bash
# file-inventory 再生脚本 —— A(brew sys-release 1.4.0_80 固定基线) × B(最新轮) 文件级台账
#
# 用法（下一轮 fulltest log 回来后）:
#   ./update-inventory.sh <谱系csv> <最新轮log> <最新轮名>
# 下轮实际调用（谱系 = 上一轮产出的台账 csv）:
#   ./update-inventory.sh ohos-bun全量测试报告.csv <新轮目录>/fulltest-<新轮>.log <新轮名>
# 再生完成后: ./archive-round.sh <上一轮目录> <代号> 归档旧轮（保留策略见 README）。
#
# 谱系首轮曾用 file-inventory-c4323a5d3.csv（round B 22 列快照，2026-09-21 已归档至
# archive/round-B-file-inventory-c4323a5d3.tar.gz——round B 唯一存活逐文件记录）。
# 两种表头按列名自动识别，A 轮数据原样滚动携带、永不改变。
# 产出：全量测试报告.md（人类可读）+ 全量测试报告.csv（机器可读，可作下轮谱系）。
set -euo pipefail
cd "$(dirname "$0")"

GENE=$1; LATEST_LOG=$2; LATEST_NAME=$3
OUT_CSV=ohos-bun全量测试报告.csv; OUT_MD=ohos-bun全量测试报告.md
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

perfile() { grep -E "(✅|❌|⏰) \[" "$1" | sed 's/^[[:space:]]*//' | awk '{
  status=$1; dur=$4; path=$5; plus=0; minus=0;
  if (match($0, /\(cases: \+([0-9]+)\/-([0-9]+)\)/, m)) { plus=m[1]+0; minus=m[2]+0 }
  else if (match($0, /\(cases: \+-([0-9]+)\/--([0-9]+)\)/, m)) { plus="-1"; minus="-1" }
  print path"\t"status"\t"dur"\t"plus"\t"minus }'; }

perfile "$LATEST_LOG" | sort > "$TMP/latest.tsv"

# 谱系 csv → 规范 TSV（列名定位，兼容 22 列旧谱系 / 17 列新谱系；无内嵌逗号已验证）
awk -F, -v OFS='\t' '
  FNR == 1 {
    for (i = 1; i <= NF; i++) h[$i] = i
    so = h["官方树skip门控数"]; if (!so) so = h["skip官方"]
    sf = h["fork树skip门控数"]; if (!sf) sf = h["skipfork"]
    cl = h["根因簇"];          if (!cl) cl = h["根因簇谱系"]
    next
  }
  { print $h["file"], $h["类别"], $h["修改状态"], $h["改动类别"], $so, $sf, $cl,
          $h["A_结果"], $h["A_通过"], $h["A_失败"], $h["A_耗时s"] }
' "$GENE" > "$TMP/gene.tsv"

# ---- 合并：规范谱系 × 最新轮 → 带排序键的中间表 ----
awk -F'\t' -v OFS='\t' -v gene="$TMP/gene.tsv" -v latest="$TMP/latest.tsv" '
  BEGIN {
    n = split("Bun.sql,CLI 命令,bake/SSR,打包器,回归测试(issue),Bun API,Node 兼容,Web 标准 API,第三方库兼容,端到端集成,构建系统/内部,N-API,V8 C++ 兼容,其他", cats, ",")
    for (i = 1; i <= n; i++) cord[cats[i]] = i
  }
  FILENAME == gene {
    f = $1; gf[f] = $2; mod[f] = $3; chg[f] = $4; so[f] = $5; sf[f] = $6
    clg[f] = $7; ar[f] = $8; ap[f] = $9; af_[f] = $10; ad[f] = $11
    NF0++; files[NF0] = f; next
  }
  { bs[$1] = $2; bd[$1] = $3; bp[$1] = $4; bf[$1] = $5; next }
  END {
    for (i = 1; i <= NF0; i++) {
      f = files[i]
      bfail = (bs[f] != "✅")
      afail = (ar[f] != "PASS")
      if (bfail && afail)       { cls = "both-fail";   co = 2 }
      else if (bfail)           { cls = "B-only-fail"; co = 1 }
      else if (afail)           { cls = "A-only-fail"; co = 3 }
      else                      { cls = "both-pass";   co = 4 }
      # 最新根因簇（谱系簇优先；env-baseline 若 A 轮实际通过则标签失效，重算）
      c = ""
      if (bfail) {
        cl = clg[f]
        if (cl == "env-baseline" && !afail) cl = ""
        if (cl != "") c = cl
        else if (f ~ /terminal|\/tty\.test\.ts|\/repl\.test\.ts/) c = "platform-tty-boundary"
        else if (bs[f] == "⏰") c = "chronic-timeout"
        else if (f ~ /bun-audit|bun-update\.|frozen-lockfile-pruned|bun-add-catalog/) c = "verdaccio-rotation"
        else if (f ~ /bun-write/) c = "parked-data-correctness"
        else if (f ~ /child-process-exec/) c = "rotation-single-case"
        else if (f ~ /node-http-connect/) c = "af-unix-hmdfs"
        else if (afail) c = (f ~ /bake\//) ? "bake-dev-server" : "env-baseline"
        else c = "jxbit-pending"
      }
      print cord[gf[f]] + 0, gf[f], co, cls, f, mod[f], chg[f], so[f] + 0, sf[f] + 0, clg[f], \
            ar[f], ap[f], af_[f], ad[f], bs[f], bd[f], bp[f], bf[f], c
    }
  }' "$TMP/gene.tsv" "$TMP/latest.tsv" | \
  sort -t$'\t' -k1,1n -k3,3n -k5,5 > "$TMP/merged.tsv"

FTOT=$(awk -F'\t' '$15 != "✅"' "$TMP/merged.tsv" | wc -l)

# 汇总统计：共同失败 / 各自独有 / 双轮通过 / 文件与用例通过率
read -r BF BONLY AONLY BPASSF CPASS CFAIL <<EOF
$(awk -F'\t' '
  { c[$4]++
    if ($15 != "⏰") { cp += $17; cf += $18 } }
  END { printf "%d %d %d %d %d %d", c["both-fail"], c["B-only-fail"], c["A-only-fail"], c["both-pass"], cp, cf }
' "$TMP/merged.tsv")
EOF
BTOT=$((BF + BONLY)); ATOT=$((BF + AONLY))
FRATE=$(awk "BEGIN{printf \"%.1f\", (2001-$BTOT)*100/2001}")
CRATE=$(awk "BEGIN{printf \"%.2f\", $CPASS*100/($CPASS+$CFAIL)}")

# ---- 产出 CSV（17 列，A 列原样携带，可作下轮谱系）----
awk -F'\t' -v OFS=, -v ln="$LATEST_NAME" 'BEGIN {
  print "file,类别,修改状态,改动类别,skip官方,skipfork,根因簇谱系," \
        "A_结果,A_通过,A_失败,A_耗时s," ln "_结果," ln "_通过," ln "_失败," ln "_耗时s,失败集合,根因簇"
}
{ print $5,$2,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$17,$18,$16,$4,$19 }' \
  "$TMP/merged.tsv" > "$OUT_CSV"

# ---- 产出 MD ----
awk -F'\t' '
  NR == FNR { cnt[$2]++; if ($15 != "✅") fcnt[$2]++; next }
  {
    if ($2 != cat) {
      if (cat != "") { print ""; print "" }
      cat = $2
      print "## " cat "（" cnt[cat] " 文件 / " fcnt[cat] " 失败）"
      print ""
      print "| 文件 | 改动 | A 轮 | " LN " 轮 | 失败集合 | 根因簇 |"
      print "|---|---|---|---|---|---|"
    }
    chg = ($7 != "") ? "🔧" $7 : (($6 != "unchanged" && $6 != "") ? "🔧" : "")
    if ($8 + $9 > 0) chg = chg " ⊘" $8 "+" $9
    acell = ($11 == "PASS") ? "✅" $12 "/" $13 : (($11 == "FAIL") ? "❌" $12 "/" $13 : "⏰" $14)
    bcell = ($15 == "⏰") ? "⏰" $16 : $15 $17 "/" $18
    print "| `" $5 "` | " chg " | " acell " | " bcell " | " $4 " | " $19 " |"
  }
' LN="$LATEST_NAME" "$TMP/merged.tsv" "$TMP/merged.tsv" > "$TMP/body.md"

{
  echo "# ohos-bun 全量测试报告"
  echo ""
  echo "> - 2001 个测试文件 × A / B 两轮真机结果"
  echo "> - **A 轮 = brew bun 1.4.0_80**（固定参考基线，185 失败，不随轮滚动）"
  echo "> - **B 轮 = jx-bit \`${LATEST_NAME}\`**（最新轮，当前 ${FTOT}/2001 文件失败）"
  echo "> - **结果汇总**：A∩B 共同失败 **${BF}**；仅 B 失败 **${BONLY}**；仅 A 失败 **${AONLY}**；双轮通过 **${BPASSF}**；B 轮文件通过率 ${FRATE}%、用例通过率 ${CRATE}%"
  echo "> - 图例：✅通过 ❌失败 ⏰超时（数字=用例 pass/fail，⏰附耗时）· 🔧=源码有改动（ohos 适配等）· ⊘a+b=上游树+fork树 skip 门控数"
  echo "> - 失败集合：B-only-fail=仅 B 轮失败 · both-fail=A、B 两轮共同失败 · A-only-fail=仅 A 轮失败 · both-pass"
  echo "> - 排序：每类内 B 独有失败 → 两轮都失败 → A 独有失败 → 通过"
  echo ""
} > "$OUT_MD"
cat "$TMP/body.md" >> "$OUT_MD"

# ---- 产出 log 口径三张清单（消除设备侧 lists/ 的超时漏报 + 嵌套 EXIT_CODE 假阳性）----
# 与 runner log 逐文件行（地面真相）严格同源；写入 <轮目录>/lists-log/，
# 设备侧 lists/ 保留作对照，验收一律以 lists-log/ 为准。
LOGDIR=$(dirname "$LATEST_LOG"); LISTS="$LOGDIR/lists-log"; mkdir -p "$LISTS"
awk -F'\t' -v ln="$LATEST_NAME" '
  $15 != "✅"            { print $5 > sprintf("%s/fail_%s.txt",        D, ln) }
  $4 == "B-only-fail"    { print $5 > sprintf("%s/fail_%s_only.txt",   D, ln) }
  $4 == "both-fail"      { print $5 > sprintf("%s/fail_overlap_both.txt", D) }
' D="$LISTS" "$TMP/merged.tsv"

echo "OK: $OUT_CSV ($(( $(wc -l < "$OUT_CSV") - 1 )) 文件) / $OUT_MD ($(wc -l < "$OUT_MD") 行) / B 轮失败 ${FTOT}/2001"
echo "    log 口径清单: $LISTS/fail_${LATEST_NAME}.txt / fail_${LATEST_NAME}_only.txt / fail_overlap_both.txt"
