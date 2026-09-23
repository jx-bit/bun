# P3: ohos-target clippy 第四批(末批)——bun_runtime 自身的 7 处规则违规 — 归档文档

> **关联 PR**:[#63](https://github.com/jx-bit/bun/pull/63)（单 commit
> `68fd86d669`，3 文件 +17/−8，base `ohos-aarch64` tip `67f7784eb8`）
> **状态**：🔄 OPEN
> **一句话**：清掉 bun_runtime **自己**（不是依赖 crate）的 7 处 OHOS 门控
> 代码规则违规——**本批没有任何用户可感的行为变化**（与 #57/#60/#62 含
> 真 bug 不同），价值是规则一致 + 把隐式安全契约升为签名 + 为
> ohos-target clippy 全绿收尾。

## 1. 这批是什么、和前三批的区别

前三批（#57 spawn 路径 11 处、#60 standalone_graph 12 处、#62
bun_install 7 处）修的是**真缺陷**：UB、静默失效、编码规则违规。
本批修的是 **bun_runtime 自己**（不是依赖 crate）的 7 处同类违规——
全部产生自我方近期 PR（#52 的 userinfo、#40 系的 dns、#54 系的
run_command），清完它，ohos-target clippy 全链路首次全绿。

**为什么用户无感**：7 处全部是形式化修复——补 SAFETY 注释、签名加
unsafe、等价 API 替换。没有任何一行改变运行结果（详见 §2 逐条）。

**为什么还要做**：①工作区规则对**所有**编译的代码一视同仁，欠着就是
欠着；②`is_managed_key` 的 unsafe 形式化把"调用方必须保证指针有效"
从注释升为签名——这是真实的安全契约强化；③全绿是防再发机制的前提
（新增门控代码一旦违规立刻可见，参照 #57 复盘的"三车道盲区"）。

## 2. 用户影响速览（诚实版：本批无直接用户影响）

| # | 代码在做什么 | 用户感知 | 修复后 |
|---|---|---|---|
| 4.1 | `bun run` 解析根目录时读 HOME | **无变化**（等价 API;仅非 UTF-8 HOME 的极端场景从"退回 /"变为"正常使用"） | 同左（微小健壮性） |
| 4.2 | node-userinfo 的 getpwuid_r 身份查询 | **无变化**（纯 SAFETY 注释） | 同左 |
| 4.3 | node-userinfo 判断 env 条目是否属于注入 | **无变化**（unsafe 形式化——契约从注释升为签名，调用方本就满足） | 同左 |
| 4.4 | node-userinfo 检查 `--require` 旗标是否已注入 | **无变化**（子串搜索换 highway SIMD，结果相同、大输入微快） | 同左 |
| 4.5 | DNS 的 IPv6 可路由性检测 open/read/close | **无变化**（纯 SAFETY 注释） | 同左 |

## 3. 七处位点逐条（大白话）

### 4.1 run_command.rs:694 —— HOME 读取换正规 API
`bun run` 在解析根目录时读 `$HOME`。原写法 `std::env::var("HOME")`
是工作区禁用的 API（env 读取必须走 `env_var::HOME::get()`）。唯一
行为差异：HOME 含非 UTF-8 字节的极端场景下,原写法退回 "/"（把家目录
当根）,新写法正常使用。日常零影响。

### 4.2 ohos_node_userinfo.rs:149 —— getpwuid_r 补 SAFETY
身份查询的 unsafe 块没写 SAFETY 注释（规则：unsafe 必须写）。补上
"pw/result/buf 有效、ERANGE 已处理"三条理由。零行为变化。

### 4.3 ohos_node_userinfo.rs:390 —— is_managed_key 形式化为 unsafe fn
该函数解引用调用方传入的裸指针（env 数组条目）。规则要求：解引用裸
指针的公开函数必须标 `unsafe`,把"指针必须 NUL 终止且存活"的契约写进
签名。两处调用方（spawn 绑定 + shell subproc）本就持有该不变量
（cstr_storage / arena 所有权）,补 unsafe 包裹即可。零行为变化。

### 4.4 ohos_node_userinfo.rs:433 —— 子串搜索换 highway
`contains_subslice` 用 `slice::windows` 逐窗口比对——工作区规定子串
搜索走 `strings::index_of`（highway memmem,SIMD 加速）。结果相同,
大缓冲微快。零语义变化。

### 4.5-4.7 dns.rs:5156/:5166/:5167 —— IPv6 检测补 SAFETY
`has_global_ipv6`（#40 系:检测设备有无可路由 IPv6,决定 DNS 是否跳过
AAAA）的 open/read/close 三个 unsafe 块补 SAFETY 注释。零行为变化。

## 4. 与参照实现的对比

**无参照实现**——这 7 处全在我方自有代码里（#52/#40/#54 系）,参照线
没有对应物可对齐（其 clippy 车道连 host 都跑不出这些——同样的违规在
其线也存在,只是无人检查）。本批是纯自查收尾,证据为 clippy 输出逐条
消号〔实测〕。

## 5. 验证

- 〔本机〕bun_runtime ohos-target clippy **0 error**（修复前 7）;host
  clippy ✅;rustfmt ✅;dead-code-escapes + byte-search ✅。
- **未修复构建上必失败声明**:同命令 7 error。
- 〔用户影响〕零——本批全部为注释/签名/等价 API,见速览表。

## 6. 里程碑与防再发

四批总账:#57（11 处）→ #60（12 处）→ #62（7 处）→ #63（7 处）=
**37 处清零,ohos-target clippy 全链路首次全绿**（依赖到 bun_runtime）。

**防再发建议**:CI 增加一条 `--target=ohos` 的 clippy lane（容器内已有
OHOS SDK）——否则新的 cfg(ohos) 代码仍会积累同款欠账（本批前的状态,
参照线至今同样欠着）。
