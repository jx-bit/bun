# autofix.ci 格式化流水线 — 机制详解

> 讲清楚 PR9 引入的这套 Format CI 的完整执行链路：谁触发、用什么版本跑了什么命令、
> 变更怎么被推回 PR、为什么会失败、失败时怎么排查。
> 依据源文件：`.github/workflows/format.yml`、`scripts/run-clang-format.sh`、
> `rustfmt.toml`、`.prettierrc`、`package.json`（2026-09-02 时点）。

---

## TL;DR

```
PR push / reopen / 手动触发
  └→ GitHub Actions: workflow "autofix.ci"（ubuntu-latest 云端机器）
       ├→ 四个格式化任务并行：string-maps 代码生成 + Prettier + clang-format-21 + rustfmt
       │    → 直接修改工作区文件（不是 check，是 --write / -i 就地改）
       └→ autofix-ci/action@v1.3.4
            → 把工作区 diff 用 GitHub App 身份 commit + push 回 PR 分支
            → commit 名固定 "[autofix.ci] apply automated fixes"
            → push 自动触发新一轮全部 checks
```

一句话：**CI 用钉死的工具版本就地改文件，然后用 bot 身份推回来**。
前提是仓库装了 [autofix.ci GitHub App](https://github.com/apps/autofix-ci)，
没装则 action 必失败（这是刻意设计，见 §5）。

---

## 1. 背景知识

### 1.1 为什么需要 format CI

Bun 仓库有四种代码形态，各有各的格式化工具：

| 代码形态 | 工具 | 配置来源 |
|---|---|---|
| TS/JS/JSON/MD | Prettier | `.prettierrc` |
| C/C++（.h/.hpp/.cpp） | clang-format | 就近的 `.clang-format` 文件 |
| Rust | rustfmt | `rustfmt.toml`（几乎全默认） |
| 生成的字符串表 | codegen | `*.string-map.ts`（源头是真源） |

如果只让 CI "检查不通过就打回"，开发者要本地装齐三套正确版本的工具、
跑一遍、再提交 —— 摩擦很大。autofix.ci 的思路反过来：
**CI 直接修，修完推给你**。开发者可以完全不关心格式化。

### 1.2 为什么 action 需要装 App

GitHub 的 workflow 默认 token（`GITHUB_TOKEN`）推 commit 会**绕过分支保护、
且不触发新 checks**（防递归机制）。要让 push 产生合法的 bot commit 并触发
新一轮 CI，必须用 GitHub App 的 installation token。
autofix.ci 是一个第三方服务：后端持有你仓库安装的 App，action 运行时
向后端换 token 完成推送。所以 **App 未安装 = action 必失败**。

---

## 2. format.yml 逐 step 详解

源文件：`.github/workflows/format.yml`（workflow 名就叫 `autofix.ci`，job 名 `Format`）。

### 2.1 触发与运行环境

```yaml
on: [workflow_call, workflow_dispatch, pull_request, merge_group]
runs-on: ubuntu-latest          # GitHub 云端，与 OHOS 自托管构建无关
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true      # 同一 PR 只保留最新一轮
```

钉死的版本（workflow 级 env）：

| env | 值 | 用途 |
|---|---|---|
| `BUN_VERSION` | `1.3.14` | 跑 prettier / glob-sources / codegen |
| `LLVM_VERSION` | `21.1.8` | 记录用 |
| `LLVM_VERSION_MAJOR` | `21` | 决定装 `clang-format-21` |
| `RUSTUP_TOOLCHAIN`（step 级） | `nightly-2026-07-20` | 让 rustup **忽略 rust-toolchain.toml** |

> `RUSTUP_TOOLCHAIN` 设在 step 级是刻意优化：rust-toolchain.toml 声明了 11 个
> 交叉编译 target 的 std（约 450 MB），而 rustfmt 只需要 host 工具链 + rustfmt 组件。
> workflow 里用 `--profile minimal --component rustfmt` 安装。

### 2.2 准备步骤

1. **Checkout**（`actions/checkout@v7.0.1`，SHA 钉死）—— 关键参数
   `persist-credentials: false`：**job 里没有 git 推送凭证**。
   这保证了最后只有 autofix App 能推（安全设计，见 §5.3）。
2. **Configure Git**：`core.autocrlf true`、`core.ignorecase true`、
   `core.precomposeUnicode true`（跨平台行为对齐，避免假 diff）。
3. **Setup Bun** 1.3.14。
4. **`bun install`** —— 装出 node_modules，prettier 从这里来。

### 2.3 Format Code step：四个任务并行

入口先 `set -o pipefail`——因为每个任务的输出都接了
`| sed 's/^/[prefix] /'`，没有 pipefail 的话 sed 的退出码会掩盖任务失败。

#### 任务 ①：string-maps 代码生成（串行，最先跑）

```bash
bun run codegen:string-maps
# 展开为：for f in src/**/*.string-map.ts; do
#   bun src/codegen/generate-string-map.ts "$f" "${f%.string-map.ts}.generated.rs"; done
```

- 重新生成所有 `*.generated.rs`。真源是 `.string-map.ts`，
  生成文件若过期 → 产生 diff → 和格式化变更一起被推回。
- 必须在 prettier 之前跑：否则 prettier 会边格式化边和生成器抢写文件。

#### 任务 ②：Prettier（后台）

```bash
bun --bun ./node_modules/.bin/prettier \
  --plugin=prettier-plugin-organize-imports \
  --config .prettierrc \
  --write \
  scripts packages src docs \
  'test/**/*.{test,spec}.{ts,tsx,js,jsx,mts,mjs,cjs,cts}' \
  '!test/**/*fixture*.*'
```

- 版本（package.json devDependencies）：prettier `^3.6.2`、
  prettier-plugin-organize-imports `^4.3.0`。
- `.prettierrc` 要点：`printWidth: 120`、`trailingComma: all`、
  `arrowParens: avoid`、markdown 放宽到 80、bindgen 相关收窄到 100。
- glob 只覆盖 `test/**/*.{test,spec}.*` —— 普通 test 目录下的非测试文件
  （fixture 除外）不在 prettier 范围内。

#### 任务 ③：clang-format（后台）

```bash
# 先从 apt.llvm.org 装（版本钉死 21，无 fallback）
wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | sudo tee ...asc
sudo apt-get install clang-format-21
# 再跑脚本
./scripts/run-clang-format.sh format
```

`scripts/run-clang-format.sh` 的文件收集逻辑：

1. `find src packages -type f \( -name "*.h" -o -name "*.hpp" \)`，
   排除 `vendor/ third_party/ thirdparty/ generated/`，
   再排除 `src/runtime/napi/`、`src/jsc/bindings/{libuv,sqlite}/`、
   `src/runtime/ffi/ffi-*`、llhttp、usockets/libuv（第三方头不动）。
2. `bun scripts/glob-sources.ts cxx` 拿 .cpp 清单（与构建同一份源清单）。
3. 去重后逐文件 `clang-format-21 -i`（就地修改）。

> 这就是它改 `src/jsc/bindings/{bun-spawn,c-bindings,workaround-missing-symbols}.cpp`
> 的原因 —— 那三个文件是 OHOS port 时提交的，格式不符合 clang-format-21。

#### 任务 ④：rustfmt（后台）

```bash
rustup toolchain install nightly-2026-07-20 --profile minimal --component rustfmt
cargo fmt --all
```

- 与 CI 其他 Rust job、本地开发用的 toolchain 完全同版本
  （rust-toolchain.toml 的 `channel`），格式结果可复现。
- 仓库根 `rustfmt.toml` **只有 ignore 列表**，无任何样式覆盖：

```toml
ignore = ["/vendor", "/test", "/build"]
```

  即：除 vendor/test/build 外全部使用 pinned nightly 的**默认规则**
  （`max_width=100`、`reorder_modules=true`、链式调用折行等）。

#### 收口

```bash
wait $PRETTIER_PID || FAILED=1   # 三个后台任务依次 wait
...
[ $FAILED -eq 1 ] && exit 1      # 任一失败 → step 红
```

典型失败：某个 .rs 语法错误导致 rustfmt 解析失败（PR9 之前的
unclosed delimiter 就是这个模式）—— `cargo fmt failed`。

### 2.4 最后一步：autofix-ci/action@v1.3.4

```yaml
- uses: autofix-ci/action@c5b2d67aa2274e7b5a18224e8171550871fc7e4a # v1.3.4
```

SHA 钉死（不用浮动 tag），保证行为不可变。

---

## 3. autofix-ci/action 的工作原理

action 自身只做四件事：

1. **扫描 diff**：对工作区跑 `git status` / `git diff`，
   收集前面格式化产生的全部变更。
2. **无变更 → 直接成功退出**（绿色，什么都不推）。
3. **有变更 → 向 autofix.ci 后端换取 App installation token**：
   - action 本身不带凭证（checkout 时 `persist-credentials: false`）；
   - 后端校验"这个仓库装了 App 吗"，没装 → 抛
     `BuildError: autofix.ci app is not installed for this repository`（我们踩过的坑）。
4. **用 App 身份 commit + push**：
   - commit message 固定：`[autofix.ci] apply automated fixes`
   - 作者：`autofix-ci[bot] <114827586+autofix-ci[bot]@users.noreply.github.com>`
   - push 到 PR 的 **head 分支**（我们这里是 `dev`）
   - push 自动触发新一轮全部 checks（Rust lints、OHOS Build 等都会重跑）

### 3.1 安全模型

- workflow token 被显式拿掉，job 内任何代码都推不了 commit；
- 唯一的 push 通道是 autofix App 的短时 token；
- App 只会推" checkout 里产生的 diff "，不接受任意指令；
- 这套设计防止恶意 PR 伪造 bot commit 或泄露 GITHUB_TOKEN。

### 3.2 与分支保护的配合

autofix 推的 commit 属于 bot 用户，如果分支保护设置了
"require signed commits / 限制 push 名单"，需要把 autofix-ci[bot]
加入豁免名单，否则 push 会被拒。

---

## 4. 版本与配置速查表

| 项 | 版本/路径 | 说明 |
|---|---|---|
| Bun | 1.3.14 | setup-bun action 安装 |
| Prettier | ^3.6.2 | node_modules（bun install） |
| organize-imports | ^4.3.0 | prettier 插件，自动排序 import |
| prettier 配置 | `.prettierrc` | printWidth 120 / trailingComma all |
| clang-format | 21.1.8（装 21） | apt.llvm.org，脚本钉死无 fallback |
| clang-format 配置 | 就近 `.clang-format` | 逐文件向上查找 |
| rustfmt | nightly-2026-07-20 | `--profile minimal` 只装 host+rustfmt |
| rustfmt 配置 | 根 `rustfmt.toml` | 仅 ignore = /vendor /test /build |
| autofix action | v1.3.4（SHA 钉死） | `.github/workflows/format.yml` 末行 |
| 覆盖范围 | scripts packages src docs + test/{test,spec}.* | fixture 文件除外 |

---

## 5. 失败模式与排查

| 现象 | 原因 | 处理 |
|---|---|---|
| `autofix.ci app is not installed for this repository` | App 未装，或**刚装完还没传播生效** | 等 3-5 分钟再跑新 run（重跑旧 run 可能仍用旧上下文，直接推个空 commit 触发新 run 更稳） |
| `cargo fmt failed` | 有 .rs 文件 rustfmt 解析不了（语法错误/截断） | 先修语法，格式问题自然消失。PR9 的 unclosed delimiter 即此模式 |
| Prettier/clang-format failed | 工具本身崩了（极少） | 看 log 对应前缀段落 |
| action 成功但 PR 没多 commit | 本来就没有 diff（格式干净） | 正常，绿就是绿 |
| autofix push 被拒 | 分支保护没豁免 autofix-ci[bot] | Settings → Branches 里加豁免 |
| 形成无限循环（autofix 推的 commit 又触发 autofix） | 理论上不会：格式化是幂等的。若某个 formatter 非幂等会抖动 | 检查该 formatter 版本是否被改过 |

### 5.1 为什么"重跑"旧 run 经常没意义

重跑复用旧 run 的上下文（同 commit、同 token 发放路径）。App 刚安装时
授权传播有延迟，重跑会继续失败。正确姿势：
**触发一个全新的 run**（推空 commit 或 close/reopen PR，见 handbook Skill 11）。

### 5.2 判断 Format job 健康的最快方法

```bash
gh run list --repo jx-bit/bun --branch dev --limit 5 | grep -i autofix
gh run view <run_id> --repo jx-bit/bun --log-failed | grep -E '::error::|autofix'
```

---

## 6. PR9 实战案例时间线（2026-09-01 ~ 09-02）

```
09-01 12:44  Format FAIL — cargo fmt 解析不了 ohos_sign/lib.rs:61
             （unclosed delimiter，sign_selfsign_inplace_with_strip 函数体被截断）
09-01 12:46  bot 留言：autofix.ci App 未安装
09-02 01:03  修复后重推（2981f40a93）— Format FAIL：
             ① rustfmt 解析通过后暴露 workspace ~25 个存量格式违规
                （.rs 7 个 + .cpp 3 个 + test 若干，均为 OHOS port 期间带入）
             ② App 仍未装，autofix 无法推送修复
09-02 01:22  推 bin clippy 修复（b70c1cfa3d）→ Format 仍红（同上）
09-02 01:50  用户安装 autofix-ci App → 手动重跑旧 run → 仍失败
             （App 授权传播延迟，见 §5）
09-02 01:55  新 run 自动触发 → Format SUCCESS
             → push b2c4342892 "[autofix.ci] apply automated fixes"
             → 一次性修完全部 25 个存量违规（prettier+clang-format+rustfmt 各司其职）
09-02 02:0x  新 commit 的 Rust lints ✅ / source-lints ✅ / Lint ✅ / autofix ✅
             OHOS Build 跑中（上一轮 30m32s 已 SUCCESS）
```

### 6.1 本案例的教训

1. **Format job 挂了先看两层**：formatter 本身（语法错误）→ autofix（App/权限）。
   第一层不修，第二层永远轮不到。
2. **存量违规会一次性爆炸**：OHOS port 期间的 25 个违规一直没人发现，
   因为之前的 run 都死在更早的解析错误上。解析一通过，全部翻出来。
3. **本地修格式要版本对齐**：prettier 要 node_modules、clang-format 要 21，
   版本不对修了也白修（CI 会再改一遍）。而 autofix 装好后，这事交给 CI 即可。

---

## 7. 对日常开发的实际影响

装好 App 后的日常姿势：

1. **可以完全不本地跑 formatter**：直接 push，autofix 会修好并推
   `[autofix.ci] apply automated fixes`，Format job 绿。
2. **注意 autofix commit 会重跑全部 checks**：OHOS Build 30 分钟一轮，
   如果 push 前本地格式明显不干净，等于多烧一轮 CI。洁癖一点还是本地过一下：
   ```bash
   cargo fmt --all                      # Rust（同版本 toolchain 本地就有）
   bun run prettier                     # 需要 node_modules
   bunx clang-format-21 -i <files>      # 或装 clang-format-21
   ```
3. **autofix commit 不要手改**：它就是 CI 的产物，rebase 时当普通 commit 处理即可。
4. **若某文件必须保持手工格式**：要么进对应工具的 ignore 配置
   （rustfmt.toml / .prettierignore / clang-format 脚本排除表），
   要么加 `// clang-format off` 之类的局部指令 —— 不要和 autofix 对抗。

---

## 8. 术语速查

| 术语 | 含义 |
|---|---|
| autofix.ci | 第三方服务：App（授权）+ action（推 commit）的组合 |
| GitHub App installation token | App 安装后颁发的短时凭证，能 push 且触发 CI |
| `persist-credentials: false` | checkout 不留 GITHUB_TOKEN，封死 job 内的推送通道 |
| `[autofix.ci] apply automated fixes` | autofix bot 的固定 commit message |
| `--write` / `-i` | prettier / clang-format 的"就地修改"模式（区别于 --check / --dry-run） |
| pipefail | bash 选项：管道的退出码取第一个失败者，防止 sed 掩盖 formatter 失败 |
| string-map | `src/**/*.string-map.ts` → `*.generated.rs` 的确定性代码生成 |
| Profile minimal | rustup 只装 host 工具链，跳过 rust-toolchain.toml 的 11 个交叉 target |

---

*文档日期：2026-09-02 | 作者：Sisyphus | 依据 PR9 修复过程实测整理*
