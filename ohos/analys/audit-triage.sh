#!/bin/bash
# 机械分诊：对每个修改文件的每个 hunk，提取最近的门控线索
# 输出 TSV: file, hunk起始行, 该hunk上方最近的cfg/#if行, hunk新增行内的门控标记
cd /home/u22/oh_rust/bun/src/bun
BASE=bun-v1.4.0
printf 'FILE\tHUNK\tPRECEDING_GATE\tHUNK_MARKERS\n'
git diff --diff-filter=M --name-only $BASE..HEAD -- src/ | while read -r f; do
  [ -f "$f" ] || continue
  # 每个 hunk 的新文件起始行
  for s in $(git diff -U0 $BASE..HEAD -- "$f" | grep -E '^\@\@' | sed -E 's/^\@\@ -[0-9]+(,[0-9]+)? \+([0-9]+).*/\2/'); do
    prec=$(awk -v s="$s" 'NR<s { if ($0 ~ /#\[cfg|cfg!\(|__OHOS__|#[ \t]*if|[ \t]#if|#ifdef/) last=NR"|"substr($0,1,90) } END { if (last) print last; else print "-" }' "$f" | tr '\t' ' ')
    mk=$(git diff -U0 $BASE..HEAD -- "$f" | awk -v target="$s" '
      /^\@\@/ { match($0, /\+[0-9]+/); hs=substr($0, RSTART+1, RLENGTH-1)+0; inh=(hs==target) }
      inh && /^\+/ && !/^\+\+\+/ { print }' | grep -oE 'target_env = "ohos"|target_env="ohos"|target_os = "linux"|target_os="linux"|not\(windows\)|\(unix\)|unix,|IS_OHOS|__OHOS__|cfg!\(|#if|#ifdef' | sort -u | tr '\n' ',' )
    printf '%s\t%s\t%s\t%s\n' "$f" "$s" "$prec" "$mk"
  done
done
