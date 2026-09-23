# P2: epoll EEXIST 重注册 + net 致命发送 errno 锁存 — 归档文档

> **关联 PR**:[#58](https://github.com/jx-bit/bun/pull/58)（单 commit
> `69e4330296`，5 文件 +45/−4，base `ohos-aarch64` tip `96b1db1d0c`）
> **状态**：🔄 OPEN
> **来源**：[双分支采纳分析](../analys/20260922-two-branch-comparison-and-adoption.md)
> §2.1 候选 #1/#2（参照线 batch-2，含 springmin 原修复）。
> **一句话**：两个"用户只感到挂死/丢数据、看不到原因"的缺陷——fd 号复用
> 后事件永不交付（挂死）、对端 RST 时排队写静默丢失且 JS 被告知成功。

## 1. 问题与用户感知

### 1.1 epoll ADD-EEXIST（ recycled-fd 挂死）

OHOS 内核上 fd 的 epoll 注册可以**越过 close 存活**：fd 关闭时 DEL 缺失
或落空（我方 #32 起刻意 skip-CTL_DEL），内核里该 fd 号的陈旧注册仍在。
fd 号复用后，新 fd 的 CTL_ADD 撞 EEXIST——兴趣集还指向旧订阅，**新 fd
的事件永不交付**。

用户感知：服务器某条连接永远读不到数据 / spawn 管道输出永远不来 /
fetch 永不完成，只能等超时；与网络故障无法区分。fd 高频创建-关闭的
长跑负载统计上必然命中。

### 1.3 覆盖边界（重要——参照线的更深实验，2026-09-22 补）

A 侧（aarch64，`9ab94f22fbf`，2026-08-20/21）用两轮 CI 构建 + 真机
A/B 对同类问题做过严格假设检验，定案了**三个 HongMeng 内核 epoll CTL
怪癖**，其"死实例态"比本 PR 修复的场景**更深一层**：

- 死实例态形状：fd **在** epoll 表里（ADD=EEXIST、MOD=SUCCESS——MOD
  永远成功），但就绪投递永不触达，且 **CTL_DEL 也移除不了它（DEL 返回
  EEXIST，无标准语义可删）**——ADD/MOD/DEL 任何组合均无法救活或清除；
- watchdog 的 MOD 兜底对"晚到态"（#49/26286 那类）有效，对死实例态
  **结构性无效**（用户态不可修，内核态问题）。

**本 PR 的边界**：EEXIST→CTL_MOD 覆盖的是"关闭 fd 的陈旧注册阻塞新
ADD"的场景（springmin 线设备实证 tty 7/0）；A 的死实例态（注册项在活
跃期进入损坏态）**不在覆盖范围内**——该场景用户态无解，残余风险与
A 侧一致，待内核侧修复。两场景的关系假设：陈旧注册阻塞 ADD 时 MOD
覆写 userdata 即可复活（springmin 实证）；注册项在活跃期损坏后 MOD
虽成功但投递路径已断（A 实证）——修复窗口在"注册时"而非"损坏后"。

### 1.2 net 致命发送 errno 不锁存（RST 静默丢数据）

`internal_flush` 有 5 个调用者，只有 `on_writable` 读返回值,其余 4 个
`let _ =` 丢弃。对端 RST 且有排队写时：致命分支清掉缓冲、`return
fatal_errno`——但若驱动 flush 的恰好是丢弃返回值的调用者,错误随之消失,
socket 随后 dispatch `drain`（告知 JS 写完成）、发干净 FIN 关闭。A 侧
设备追踪（10MB 写入对端中途 RST）：1MB 送达、**9.4MB 丢弃、零报错、
写回调收到 null**;同设备 Node 报 EPIPE。OHOS 透明代理(vpn-tun)使 RST
比桌面 Linux 更频繁。

## 2. 修复

| 文件 | 内容 |
|---|---|
| `src/io/posix_event_loop.rs` | CTL_ADD 撞 EEXIST(OHOS-gated)→ 以 CTL_MOD 重发:内核条目重指向本 poll,不会丢弃活注册(DEL+ADD 会) |
| `src/sys/lib.rs` | `E` 新类型补 `EXIST` 常量(我们的 E 无前缀变体,参照实现的 `E::EEXIST` 需此适配) |
| `src/runtime/socket/socket_body.rs` | NewSocket 增 `pending_fatal_send_errno: Cell<i32>` 锁存;internal_flush 致命分支锁存;on_writable 自身 flush 无致命时消费锁存;post-open 延迟 flush 在锁存非零时**不 dispatch drain**(字节是被丢弃的,drain=对 JS 谎报成功) |
| `src/runtime/node/node_net_binding.rs` + `src/runtime/socket/Listener.rs` | 4+5 处构造点补字段初始化(含 TLSSocket 字面量) |

## 3. 与参照实现的对比

| 项 | 参照实现 | 本 PR | 证据 |
|---|---|---|---|
| EEXIST→CTL_MOD | A minimal b7cff72839(springmin d91b7c5487 原修) | 逐字同(仅 `E::EEXIST`→`E::EXIST` 适配) | 〔源码〕 |
| errno 锁存 | aarch64 519c8163c0b + 496fdb61ac9(两 commit 合一) | 逐字同(去掉其 T37 调试脚手架部分——我们树本来就没有) | 〔源码〕 |
| 字段初始化面 | A 树 1 处构造 | 我方 **4 处构造**(含 TLSSocket 字面量)——按我方结构补全 | 〔源码〕 |
| 非锁定差异 | 参照线另行移除了 usockets socket.c 的 22 行 T37 workaround | 我方无该 workaround,不涉及 | 〔源码〕 |

参照线 = social4hyq/ohos-bun(非官方);原始修复来自 springmin 线。

## 4. 验证

- 〔本机〕bun_io ohos-target clippy ✅、bun_runtime host clippy ✅
  (socket_body 非 cfg-gated,host 全 lint 集覆盖)、cargo check bun_runtime
  ohos-target ✅、rustfmt ✅、dead-code-escapes ✅。
- **未修复构建上必失败声明**:fd churn 下复用 fd 号静默无事件(挂死);
  对端 RST + 排队写 = JS 收到 drain 成功而字节未离进程。
- 〔设备·验收〕长跑 server fd churn 复现挂死消失;10MB 级写对 RST 对端:
  error 事件带 EPIPE(非 drain+clean FIN)。

## 5. 同批未采(见采纳分析文档)

cwd_is_deleted 截断(候选 #2,与 #57 同函数,趁热优先下一批)、
IN_ATTRIB 抑制、getgroups egid、net.connect AddressInfo。
