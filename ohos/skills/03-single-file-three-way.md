## Skill 3：三方对比单个文件

### 目的

对同一个文件，对比「我们 vs 上游 v1.4.0」和「我们 vs social4hyq」的差异。

### 操作

```bash
# 1. 我们的版本 vs 上游版本（看 OHOS 改了什么）
git diff HEAD bun-v1.4.0 -- <file>

# 2. social4hyq 的版本（通过 GitHub raw URL）
curl -s "https://raw.githubusercontent.com/social4hyq/ohos-bun/ohos-aarch64/<file>"

# 3. social4hyq 的版本（通过 gh api，大文件用这个）
gh api repos/social4hyq/ohos-bun/contents/<file>?ref=ohos-aarch64 --jq '.content' | base64 -d

# 4. social4hyq 版本里的 OHOS 标记
curl -s "https://raw.githubusercontent.com/social4hyq/ohos-bun/ohos-aarch64/<file>" | \
  grep -c 'ohos|__OHOS__|target_env.*ohos'

# 5. 示例：对比 Highway 文件
for f in highway_sourcemap highway_json highway_xml; do
  echo "--- $f.cpp ---"
  echo "我们:"
  grep -c 'HWY_DISABLED\|BUN_BFM' "src/jsc/bindings/$f.cpp" 2>/dev/null
  echo "social4hyq:"
  curl -s "https://raw.githubusercontent.com/social4hyq/ohos-bun/ohos-aarch64/src/jsc/bindings/$f.cpp" | \
    grep -c 'HWY_DISABLED\|BUN_BFM\|highway_dispatch'
done
```

---
