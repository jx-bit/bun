# P1: DNS 双栈 AAAA 超时（OHOS 系统 backend + 无全局 IPv6 强制 Inet）— 工作记录

> **关联 PR**：[#40](https://github.com/jx-bit/bun/pull/40)（claude 分支 → ohos-aarch64，
> 单 commit `38371c22b4`，2 文件 +53/−2，OHOS 构建与 A 逐字节一致）
> **状态**：🔄 OPEN
> **定位**：node-dns 三轮 flap（PASS → FAIL → PASS）的根因 + OHOS 上全部
> AF_UNSPEC 解析的隐性超时面。

## 1. 现象

`test/js/node/dns/node-dns.test.js` 中 `dns.lookup` 对随机垃圾域名
（`qedjp3….com`，预期快速 ENOTFOUND）的断言：

| 轮 | binary | 结果 | 耗时 |
|---|---|---|---|
| 0e0fd1559 | #32 后 | PASS | — |
| 14fdf0d56 | #34 后 | **FAIL** | **2081.83ms**（≈2s DNS 超时形态）|
| 007d7a07e | #37+#39 后 | PASS | — |

**Flap 实锤**：同测试树、同设备、非 verdaccio 签名——波动源在 DNS 查询
本身：垃圾域名的 AAAA 查询在设备网络上的行为不稳定（多数时候超时挂起
2s，偶发快速应答），而 A 断言的是"快速 ENOTFOUND"。

## 2. 机制链（为什么是 AAAA）

`dns.lookup` 默认 family = AF_UNSPEC → 解析器**并发发出 A 与 AAAA 两个
查询**，整体延迟 = max(A, AAAA)：

1. OHOS 设备**没有可路由的全局 IPv6**：`/proc/net/if_inet6` 只含
   `fe80::/10` link-local 与 `::1`（wlan0/vpn-tun 常另报一个 ULA
   `fc00::/7`，同样不可路由）
2. 对无 v6 路由的网络，AAAA 查询的应答行为取决于解析链路：部分网络
   （netsys 代理、运营商 DNS）对 AAAA **静默丢弃而非回空应答** → 客户端
   等到超时（EAI_AGAIN / 2s 形态）；偶发网络状态不同则快速回空 → flap
3. 无论 AAAA 结果如何，设备上 AAAA 的答案都不可用（无 v6 路由）——
   这 2s 是纯浪费，且把"快速失败"测试拖成超时

上游 Linux 从未暴露：开发/CI 网络有真实全局 IPv6，AAAA 要么可用要么
被 AI_ADDRCONFIG/应答过滤正确处理。

## 3. 实现选型（两个独立修复点，各有备选）

### 3.1 backend 默认值：c-ares → System

| 候选 | 结论 | 理由 |
|---|---|---|
| **Backend::System**（OHOS） | ✅ 采用（A 同款） | 系统 getaddrinfo 走 **netsys IPC** 私有通道——能解析内网域名、拿到设备真实解析器；c-ares 只读 `/etc/resolv.conf`，在 OHOS 上看不到 netsys 的解析配置 |
| c-ares + 注入 resolv.conf | ❌ | 需在运行时从 netsys 拉取解析器再手写 resolv.conf——依赖私有 IPC 细节，且 netsys 行为随网络切换变化，追不上 |
| c-ares + netsys 集成 | ❌ | 要改 c-ares 内部（ares_init 的 channel 配置），侵入第三方库，A 未做、无设备验证 |

### 3.2 family 强制：`has_global_ipv6()` 门控

| 候选 | 结论 | 理由 |
|---|---|---|
| **无全局 v6 时强制 Inet**（A 同款） | ✅ 采用 | 精确：仅当 family 未指定且设备无可路由 v6 时跳过 AAAA；显式请求 v6 的调用方不受影响；有真实全局 v6 的网络保留双栈 |
| OHOS 上无条件强制 Inet | ❌ | 有真实 v6 路由的网络（少数但存在）被错误降级 |
| 依赖 getaddrinfo 的 AI_ADDRCONFIG | ❌ | A 实测 OHOS 解析链路未按预期过滤 AAAA（这正是超时发生的现状）；依赖平台行为等于不修 |
| 修 c-ares 的 AAAA 超时参数 | ❌ | c-ares 已非 OHOS 默认 backend（3.1）；调参治标 |

`has_global_ipv6()` 的判定细节（A 二次迭代教训〔源码注释自证〕）：
读 `/proc/net/if_inet6`，仅 `2000::/3`（首 nibble '2'/'3'）计为全局——
**第一版把 ULA 也当全局，结果 `dns.lookup({all:true})` 在不可路由的
wlan0/vpn ULA 网络上仍然返回 AAAA**，二次修正排除 `fc00::/7`。

## 4. 修复内容（2 文件 +53/−2）

- `src/runtime/dns_jsc/dns.rs`：`has_global_ipv6()`（OHOS）+ `do_lookup`
  挂钩（family 未指定 && 无全局 v6 → `Family::Inet`）
- `src/dns/lib.rs`：`Backend::default()` 的 cfg 门控加 OHOS
- 规范适配一处：非 OHOS 的恒真 stub 整体 cfg 掉（调用点本就 cfg(ohos)，
  非 OHOS 构建零死代码；A 只编 OHOS 面故携带 stub 无此差异）

## 5. 与 social4hyq 实现的对比（逐字核验）

证据类型：〔源码〕两树 diff 逐字核验；〔实测〕A 轮设备行为。

| 维度 | social4hyq（61dbc3a9d，A 轮） | 我方（c2459c8442）→ 本 PR |
|---|---|---|
| DNS backend 默认 | 〔源码〕OHOS=System（netsys IPC 注释） | c-ares ❌ → 同 A |
| 双栈 family | 〔源码+实测〕`has_global_ipv6` 门控（含 ULA 二次迭代） | 无 ❌ → 同 A |
| node-dns | 〔实测〕A 轮通过（A-only=21 不含 node-dns） | flap ❌ → 预期稳定转绿 |

规范适配偏差声明：非 OHOS stub 的 cfg 差异一处（非 OHOS 构建行为等价——
A 侧该 stub 亦不可达语义）。

## 6. 影响面与风险

- **全部 OHOS `dns.lookup` 受益**：默认路径不再有 AAAA 空等；显式
  `family: 6` 仍尝试 AAAA（调用方自主选择）
- backend 换 System 的行为差异：/etc/hosts 语义、应答排序（RFC 6724
  由系统处理）随系统 getaddrinfo——与 A 轮设备行为一致，已验证
- 非 OHOS 平台零影响（两处改动均 cfg 门控）

## 7. 验证

- `cargo check -p bun_dns -p bun_runtime` ✓；dead-code-escapes lint
  0 fail（无新 allow，无需再生账本）
- 设备复测预期：node-dns 稳定转绿（消除 flap 源）；dns.lookup 垃圾域名
  快速 ENOTFOUND；潜在连带：fetch.tls（若含 DNS 超时成分）

## 8. 关联

- 全树 A 侧 OHOS 补丁分诊（30 文件清单）见 `20260914-round-report.md`
  附录与对话记录——本 PR 为 DNS 簇；c-bindings `is_executable_file`
  （which/26207 族）、install 簇（PackageManager/resolver_hooks）待后续
- flap 数据来源：0e0fd1559 / 14fdf0d56 / 007d7a07e 三轮 result 逐行比对
