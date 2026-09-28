# 1.4.0_1（OHOS 发布线）

> **适用版本**：1.4.0（发布标签 `1.4.0_1`）
> **平台**：OpenHarmony / HarmonyOS aarch64（标准系统设备）
> **版本性质**：预发布版本（canary）
> **质量基线**：文件通过率 95.33%；用例通过率 98.35%（执行用例 71,847 个）。
> 60 分钟持续负载运行稳定。

---

## 1. 概述

Bun 是集运行时、包管理器、打包器、测试运行器于一体的 JavaScript / TypeScript 工具链。
本版本为 Bun 1.4.0 在 OpenHarmony 平台（aarch64）的原生移植，在设备上直接运行，
无需容器或指令翻译层；TS / JSX / ESM 零配置执行、npm 兼容包管理、测试、打包、
HTTP 服务与 `node:` 核心模块均可用（接口级状态见第 6 章，已知限制见第 7 章）。

注意：`process.platform` 返回 `"openharmony"`（详见 7.1 节 P1）。

---

## 2. 获取与安装

### 2.1 方式一：预签名 tarball（推荐）

发布页提供预签名 tarball（42MB，包内 `bun` 已含系统签名），解压后可直接执行，无需签名步骤。

```sh
# 1. 下载（github 直连受限时，在链接前加 https://ghfast.top/ 前缀加速）
curl -fsSL -o bun.tar.gz \
  "https://github.com/jx-bit/bun/releases/download/1.4.0_1/bun-ohos-aarch64-1.4.0.tar.gz"

# 2. 解压（得到 bun-ohos-aarch64-1.4.0/ 目录，内含 bun 与 README）
tar xzf bun.tar.gz && cd bun-ohos-aarch64-1.4.0

# 3. 执行
chmod +x bun && ./bun --version

# 4.（可选）加入 PATH
export PATH="$PWD:$PATH"                                  # 当前会话立即生效
echo 'export PATH="安装目录:$PATH"' >> ~/.profile         # 持久化：默认 sh 登录会话
echo 'export PATH="安装目录:$PATH"' >> ~/.zshrc           # 持久化：zsh（harmonybrew 环境）
```

**故障诊断**：若 `chmod +x bun` 后执行仍报 `Permission denied`，表明压缩包下载损坏
（嵌入签名是内核 exec 校验的依据），重新下载即可。

### 2.2 方式二：裸二进制 + 设备端签名

若获取的是未签名裸二进制（发布页 `bun-ohos-aarch64-unsigned` 等资产），
需在设备上完成签名：

```sh
# 1. 下载
curl -fsSL -o bun-ohos-aarch64 \
  "https://github.com/jx-bit/bun/releases/download/1.4.0_1/bun-ohos-aarch64-unsigned"

# 2. 完整性校验（与发布页标注的 sha256 比对）
sha256sum bun-ohos-aarch64

# 3. 设备端签名（未签名无法执行）
/system/bin/binary-sign-tool sign -inFile bun-ohos-aarch64 \
        -outFile bun.signed -selfSign 1

# 4. 落位并加入 PATH
chmod +x bun.signed
mv bun.signed 目标目录/bun
export PATH="目标目录:$PATH"                              # 当前会话立即生效
echo 'export PATH="目标目录:$PATH"' >> ~/.profile         # 持久化：默认 sh 登录会话
echo 'export PATH="目标目录:$PATH"' >> ~/.zshrc           # 持久化：zsh（harmonybrew 环境）
```

### 2.3 安装说明

| 项 | 说明 |
|---|---|
| 完整性校验 | sha256 以未签名原件为准；签名会改变文件内容，签名副本哈希不同属正常现象 |
| 落位目录 | 需为可写目录；`/data/local/tmp` 对应用沙箱内进程不可写（EACCES），沙箱内请使用应用自身目录 |
| 磁盘占用 | 二进制约 105MB；首次使用包管理后家目录出现 `~/.bun` 缓存（约 98MB 量级，随使用增长） |
| 卸载 | 删除二进制与 `~/.bun` 即可完全清理 |
| PATH 持久化 | `~/.profile` 仅对默认 sh 的**登录会话**自动生效；zsh（harmonybrew 环境）写入 `~/.zshrc`；hdc shell 等非登录会话不自动读取任何配置，需执行 `source` 或用绝对路径调用 |
| 版本升级 | `bun upgrade` 在本平台不可用（见 7.1 节 P9）；从发布页下载新版本二进制替换 |
| 版本策略 | 本说明对应发布标签 `1.4.0_1`；发布页另有滚动标签 `latest` 供体验跟进。生产/复现场景建议锁定具体发布（记录标签与 sha256） |

---

## 3. 安装验证

```sh
bun --revision
# 输出版本串，与所下载版本一致

bun -e 'console.log(process.platform, Bun.version)'
# 输出：openharmony <版本号>
```

若版本串与所下载版本不一致，说明 PATH 上存在其他 bun，
可执行 `command -v bun` 检查解析优先级。

---

## 4. 运行环境要求

| 项 | 要求 |
|---|---|
| 存储 | 二进制 105MB；项目与缓存建议预留 1GB 以上 |
| 网络 | npm registry（registry.npmjs.org）可达为包管理必需；git 依赖需网络可达 github（受限时配置代理，见 7.1 节 P14） |
| 解释器 | 设备无 bash，系统 shell 为 toybox sh；脚本解释器一律使用 `#!/bin/sh` |
| 执行权限 | 二进制须含有效签名（tarball 已预签名；裸二进制需按 2.2 节自签） |
| 平台标识 | `process.platform = "openharmony"`、`os.arch() = "arm64"` |

---

## 5. 快速上手

```sh
bun run app.ts            # 运行 TS/JSX/ESM 文件，零配置
bun init && bun add express   # 初始化项目并安装依赖
bun test                  # 运行测试
bun build ./entry.ts --outfile out.js          # 打包
bun build --compile ./entry.ts --outfile app   # 生成单文件可执行程序
```

---

## 6. 接口支持矩阵

### 6.1 状态图例

| 标记 | 含义 |
|---|---|
| ✅ | 支持 |
| 🟡 | 部分支持，存在已知问题（详见行内说明与第 7 章对应条目） |
| ❌ | 不支持 |
| ❓ | 存在但未完成验证，可用性待确认 |
| 🔒 | 环境依赖项：能力存在于二进制（客户端面已验证），因缺少配套服务/环境未做真实场景验证，**非能力缺口** |

### 6.2 CLI 命令

| 接口 | 状态 | 说明 |
|---|---|---|
| `bun run` | ✅ | 支持 package.json scripts 与直接执行脚本文件 |
| `bun test` | ✅ | 测试运行器，兼容 node:test 用例 |
| `bun install / add / remove / update` | ✅ | registry 安装完整可用；git 依赖需配置代理（见 P14） |
| `bun add`（git 依赖，SSH/HTTPS） | ✅ | 经 git URL 重写代理后可用 |
| `bun pm pack / publish` | 🟡 | 可用；个别错误消息文本与上游存在差异 |
| `bun pm why` | ✅ | 正确输出依赖链 |
| `bun outdated` | ✅ | 输出 当前/可更新/最新 版本表（注意：`bun pm outdated` 子命令不存在） |
| `bun link` / `bun unlink` | ✅ | 本地包链接注册与解除（`bun pm link/unlink` 子命令不存在） |
| `bun pm patch` | ❌ | 该构建无此子命令 |
| `bun init / create` | ✅ | 高负载下偶发超时，单独重跑即可（见 P10） |
| `bun build`（bundle） | ✅ | 打包产物正确 |
| `bun build --compile`（本平台 target） | ✅ | 产物可直接在设备上运行 |
| `bun build --compile`（跨平台 target） | 🟡 | 仅支持本平台 target，其余报 Unknown compile target |
| `bun upgrade` | ❌ | 官方发布通道无本平台产物；从发布页下载替换 |
| `bunx` | 🟡 | 常规可用；经 bunx 安装 node-gyp 场景受设备限制（见 P5） |
| `bun repl` | ✅ | 求值与退出正常（管道非交互实测 1+1=2）；交互式多行/补全未深测 |
| `bun --watch / --hot` | ✅ | 文件变更触发重载/热更新（实测）；长时运行稳定性未系统验证 |
| `bun --print / -e` | ✅ | 支持表达式求值 |

### 6.3 运行时核心

| 接口 | 状态 | 说明 |
|---|---|---|
| TS / TSX / JSX / ESM / CJS 解析与执行 | ✅ | 零配置支持 |
| ESM ↔ CJS 互操作 | ✅ | — |
| top-level await / 装饰器 | ✅ | — |
| `import.meta`（dir / url / main） | ✅ | — |
| `process` 全局对象 | 🟡 | `process.platform` 返回 `"openharmony"`（平台特性，见 P1） |
| 退出码 / 信号处理 | ✅ | SIGTERM / SIGKILL 收割正常 |
| Ctrl+C（SIGINT）前台中断 | ✅ | 普通前台进程行为正常；向 dev server 类子进程的传播存在已知问题（见 P13） |
| `--inspect` 调试 | ✅ | 监听 ws://localhost:6499/<uuid> 并输出调试地址；完整调试会话未深测 |

### 6.4 Bun.* API

#### 6.4.1 文件 I/O

| 接口 | 状态 | 说明 |
|---|---|---|
| `Bun.file` / `Bun.write` | ✅ | — |
| `Bun.write`（slice 目标） | ✅ | — |
| `Bun.writev` | ❌ | 构建条件裁剪的存根（getter 存在，调用返回 undefined）；常规写由 `Bun.write` 完整覆盖 |
| `Bun.mmap`（文件只读映射） | ✅ | — |

#### 6.4.2 服务与网络

| 接口 | 状态 | 说明 |
|---|---|---|
| `Bun.serve`（HTTP / TLS / WebSocket） | ✅ | 监听仅支持 TCP |
| `Bun.serve` / `Bun.listen`（unix socket 模式） | ❌ | 设备存储面对 unix socket bind 的系统级限制，bind 全路径报 EPERM（见 P4） |
| `Bun.listen`（TCP） | ✅ | — |
| `Bun.connect` | ✅ | — |
| `Bun.udpSocket` | ✅ | — |
| `fetch`（出站请求） | ✅ | 可用性受设备网络环境约束（与二进制无关） |
| `Bun.dns` | 🟡 | 默认解析正常（localhost → 127.0.0.1）；system backend 的 AAAA 查询报 ENOTFOUND（见 P8） |

#### 6.4.3 进程与 shell

| 接口 | 状态 | 说明 |
|---|---|---|
| `Bun.spawn` / `Bun.spawnSync` | ✅ | 覆盖退出时序、并发、孤儿进程、IPC、大输出、信号场景 |
| `Bun.$`（shell） | ✅ | — |
| `Bun.which` | ✅ | — |
| `Bun.MainModule / main / cwd / argv / origin` | ✅ | — |

#### 6.4.4 哈希与编解码

| 接口 | 状态 | 说明 |
|---|---|---|
| `Bun.hash`（wyhash 等） | ✅ | — |
| `Bun.CryptoHasher` | ✅ | 支持 SHA1/224/256/384/512/512_256、MD5、MD4、keccak |
| `Bun.sha` / `SHA*` / `MD4` / `MD5` 速记 | ✅ | — |
| `Bun.password` | ✅ | 支持 bcrypt / argon2 |
| gzip / gunzip / deflate / inflate（Sync） | ✅ | — |
| brotli（Sync） | ✅ | — |
| `Bun.zstd*`（4 个） | ✅ | — |

#### 6.4.5 数据格式与解析

| 接口 | 状态 | 说明 |
|---|---|---|
| `Bun.TOML / YAML / JSON5` | ✅ | — |
| `Bun.JSONC` | ✅ | 支持带注释 JSON |
| `Bun.XML`（parse / stringify） | ✅ | 对象形态 |
| `Bun.markdown`（render / html / ansi / react） | ✅ | — |
| `Bun.file().jsonl()`（流式 JSONL） | ❌ | 方法不存在；替代：读全文后 split + JSON.parse |
| `Bun.JSONL` | 🟡 | parse / parseChunk 可用；流式 stream 方法不存在 |
| `Bun.semver` | ✅ | 支持 satisfies |
| `Bun.deepEquals` | ✅ | — |
| `Bun.deepMatch` | ✅ | 子集匹配语义：目标包含模式的全部键值即 true（与"全等"直觉不同，注意） |
| `Bun.Cookie / CookieMap / CSRF` | ✅ | CSRF 提供 generate / verify |
| `Bun.escapeHTML` | ✅ | — |
| `Bun.randomUUIDv5 / v7` | ✅ | — |
| `Bun.Transpiler` | ✅ | 需显式指定 loader（ts/tsx/jsx） |
| `Bun.build` | ✅ | 同 `bun build` |
| `Bun.plugin / registerMacro` | ✅ | — |
| `Bun.Glob` | ✅ | — |
| `Bun.FileSystemRouter` | ✅ | `style:"nextjs"` 下 match 正常：命中返回 {filePath, pathname, params, query, kind}，未命中返回 null |
| `Bun.Archive` | ✅ | 以 ArrayBuffer/Blob 构造（不接受路径字符串），extract 解包实测成功 |
| `Bun.Image` | 🟡 | 构造可用；width/height 懒加载，直接读取返回 -1，需先触发解码 |
| `Bun.WebView` | ❌ | 依赖系统 Chrome，设备上不可用 |

#### 6.4.6 凭据与外部服务

| 接口 | 状态 | 说明 |
|---|---|---|
| `Bun.secrets` | ❌ | 设备无 D-Bus/libsecret 服务（见 P7） |
| `Bun.sql` / `SQL`（Postgres） | 🟡 | 服务不可达时快速给出类型化错误（`ERR_POSTGRES_CONNECTION_REFUSED`）；真实连接需外部数据库 |
| `Bun.redis` / `RedisClient` | 🟡 | 服务不可达时挂起（>15s 不报错，见 P12）；真实连接需外部服务 |
| `Bun.s3` / `S3Client` | 🟡 | 服务不可达时快速给出类型化错误（`S3Error ConnectionRefused`）；真实对象存储操作未验证 |
| `Bun.postgres` | 🔒 | 环境依赖：需可达 Postgres 服务端；客户端错误路径已验证（不可达时快速类型化报错） |

#### 6.4.7 工具与其他

| 接口 | 状态 | 说明 |
|---|---|---|
| `Bun.gc` | ✅ | gc(true) 返回释放的字节数 |
| `Bun.peek` | ✅ | 已决 promise 返回其值且不消费；未决返回空对象 `{}`（与上游文档"返回 undefined"有偏差，判断是否完成勿用真值判断） |
| `Bun.stringWidth`（CJK 宽度）/ `sliceAnsi / wrapAnsi / stripANSI / color / enableANSIColors` | ✅ | 中文宽度按 2 计，ANSI 剥离与彩色开关正常 |
| `Bun.indexOfLine` | ✅ | 行号语义与常规预期不同，使用前先验证具体行为 |
| `Bun.readableStreamTo*`（6 个） | ✅ | — |
| `Bun.concatArrayBuffers` | ✅ | 参数为数组形态 |
| `Bun.env / stderr / stdin / stdout` | ✅ | — |
| `Bun.version / revision / isMainThread / isStandaloneExecutable / embeddedFiles / main` | ✅ | — |
| `Bun.jest / test` | ✅ | 测试运行器接口 |
| `Bun.unsafe`（gcAggressionLevel 等） | ✅ | — |
| `Bun.shrink` | ✅ | 将 JSC 堆的空闲页归还操作系统（调用 VM shrinkFootprint，返回 undefined）。实测：制造 80×1MB 内存 churn 后 126.1MB → gc(true) 不变 → shrink 后 29.9MB。内存敏感的长运行服务建议在大批量对象释放后与 `Bun.gc(true)` 配合使用 |

### 6.5 node: 内置模块（50/50 可加载）

#### 完全可用

| 模块 | 备注 |
|---|---|
| `node:fs` | mode 位断言类在 /storage 路径存在设备面限制（见 6.5 部分支持表与 P6） |
| `node:path`（含 posix / win32） | — |
| `node:crypto` | — |
| `node:buffer` | — |
| `node:events` | — |
| `node:util` | — |
| `node:stream`（含 promises / web / consumers） | `pipeline` + async generator 组合存在已知问题（见下表） |
| `node:child_process` | — |
| `node:worker_threads` | — |
| `node:zlib` | — |
| `node:vm` / `node:v8` | — |
| `node:os` | tmpdir 跟随 TMPDIR 环境变量 |
| `node:http` / `node:https` | 仅 TCP |
| `node:net` / `node:dgram` | TCP / UDP 正常 |
| `node:tls` | 仅 TCP |
| `node:cluster` | — |
| `node:module` / `node:querystring` / `node:string_decoder` / `node:punycode` / `node:url` / `node:sys` / `node:constants` / `node:assert` | — |
| `node:test` | `expect` 不从 node:test 导出，与 Node 标准一致 |
| `node:sqlite` | — |
| `node:timers`（含 promises） | — |
| `node:readline`（含 promises） | PTY 变体存在已知问题（见下表） |
| `node:domain` / `node:wasi` / `node:inspector` / `node:tty` / `node:console` / `node:perf_hooks` / `node:async_hooks` / `node:diagnostics_channel` | 基础面实测通过（domain 错误捕获、inspector Session+Runtime.enable、wasi 构造、tty isatty/setRawMode），更深层行为未全部验证 |

#### 部分支持

| 模块 | 已知问题 | 规避 |
|---|---|---|
| `node:fs`（chmod / stat mode 类） | /storage 路径权限位不保持（hmdfs） | mode 敏感操作避开 /storage（见 P6） |
| `node:http` / `node:net` / `node:tls`（unix socket 模式） | bind 报 EPERM | 使用 TCP 替代（见 P4） |
| `node:dns`（system backend，AAAA / localhost） | `getaddrinfo ENOTFOUND` | 用 127.0.0.1 直连或补充 /etc/hosts（见 P8） |
| `node:process`（platform 值） | 返回 `"openharmony"` | 生态包需兼容该值（见 P1） |
| `node:http2`（部分） | 个别 pipe / stream 用例存在已知问题 | 优先 HTTP/1.1 或 TCP 面 |
| `node:trace_events`（fs-sync / fs-async） | 2 个 trace 场景失败（见 7.3） | — |
| `node:stream`（pipeline + async generator） | 中间级收不到数据、两参形式被拒 | 中间处理级使用 `Transform` 实例 |
| `node:readline`（stdin-pause-pty 变体） | PTY 关联用例存在已知问题 | — |
| `node:repl` | 求值链路实测可用（内存流 6*7=42）；交互式 TTY 深度未验证 | — |

### 6.6 Web 标准 API

| 接口 | 状态 | 说明 |
|---|---|---|
| `fetch` / `Request` / `Response` / `Headers` / `FormData` | ✅ | — |
| `URL` / `URLSearchParams` | ✅ | — |
| Streams（Readable / Writable / Transform） | ✅ | compression 一项偶发（负载敏感） |
| WebSocket（客户端 / 服务端） | ✅ | — |
| `crypto`（subtle / getRandomValues） | ✅ | — |
| `AbortController` / `Event` / `EventTarget` | ✅ | — |
| `structuredClone` | ✅ | 覆盖基础类型、Date、Map、循环引用 |
| `Blob` / `File` / `TextEncoder` / `TextDecoder` | ✅ | — |
| `performance` / `queueMicrotask` / `setImmediate` / `setTimeout` | ✅ | — |
| `Worker` / `WebAssembly` / `navigator` / `location` | ✅ | — |
| `HTMLRewriter` | 🟡 | `rw.transform(response)` 形态全功能可用（元素/属性/文本捕获与改写）；`pipeThrough` Streams 形态不支持；`#comment` / `#doctype` 处理器注册后不触发（见 P11） |

### 6.7 N-API / FFI / 原生 addon

| 接口 | 状态 | 说明 |
|---|---|---|
| 加载预编译 `.node` / `.so`（dlopen） | ✅ | — |
| `Bun.FFI`（CFunction / View / dlsym） | ✅ | — |
| 设备上构建 addon（node-gyp / cc） | ❌ | 双重阻塞：设备无 C 编译器 + bunx 缓存目录属主检查受 FUSE uid 映射阻断（见 P5） |
| node-gyp 经 bunx 安装 | ❌ | 同上 |

### 6.8 包管理

| 特性 | 状态 | 说明 |
|---|---|---|
| registry 安装（含 scoped / proxy） | ✅ | — |
| lockfile（文本 / 二进制读写往返） | ✅ | — |
| workspaces / catalogs | ✅ | — |
| lifecycle scripts（pre / postinstall） | ✅ | node-gyp 类脚本受 6.7 节限制 |
| git 依赖（SSH / HTTPS） | ✅ | 需配置 git URL 重写代理（见 P14） |
| tarball 依赖 / file: 依赖 | ✅ | — |
| isolated linker（`--linker isolated`） | ✅ | — |
| overrides | ✅ | 强制覆盖依赖版本，实测生效 |
| trustedDependencies | ✅ | trust / untrusted / default-trusted 命令面完整，默认信任名单（367 包）生效 |
| patch | ❌ | `bun pm patch` 子命令不存在 |
| security scanner | 🟡 | 无 TTY 下交互提示流行为有差异 |
| optionalDependencies 的 os 过滤 | ✅ | — |
| `bun publish / pack` | 🟡 | 可用；个别消息文本与上游存在差异 |

### 6.9 测试运行器

| 特性 | 状态 | 说明 |
|---|---|---|
| describe / it / test / expect（matchers 全集） | ✅ | — |
| mock / spyOn / mock.module | ✅ | — |
| snapshot（含 `--update-snapshots`） | ✅ | — |
| concurrent / timeout / done 回调 | ✅ | — |
| `--filter`（文件级）/ `--changed` | ✅ | 均实测生效 |
| `--coverage` | ❌ | 测试照常运行但不输出覆盖率报告 |
| node:test 兼容 | ✅ | — |

### 6.10 打包器

| 特性 | 状态 | 说明 |
|---|---|---|
| loaders（ts / tsx / jsx / json / toml 等） | ✅ | — |
| plugins / 宏 | ✅ | — |
| target（browser / node / bun） | ✅ | — |
| external / splitting / minify / sourcemap | ✅ | — |
| HTML 入口 | ✅ | — |
| `--compile`（本平台 target） | ✅ | 产物可直接运行 |
| `--compile`（跨平台 target） | 🟡 | 仅本平台可用 |
| asset / bunfs 嵌入 | ✅ | — |

### 6.11 bake

| 特性 | 状态 | 说明 |
|---|---|---|
| bake dev（dev server） | 🟡 | 高负载下偶发失败，单独重跑通过；属设备态负载敏感，持续观察 |
| bake build | ✅ | — |

### 6.12 汇总

| 状态 | 数量（约） |
|---|---|
| ✅ 完全支持 | 175+（本轮实测新增确认：pm why、bun outdated、bun link/unlink、overrides、trustedDependencies、--filter/--changed、--watch、--hot、repl、--inspect、FileSystemRouter、Archive、deepMatch、node:inspector/domain/wasi/tty 等） |
| 🟡 部分支持（存在已知问题） | 23（新增：Bun.JSONL 缺流式方法） |
| ❌ 不支持 | 8（Bun.secrets、unix socket bind、设备上 addon 构建、bun upgrade、Bun.WebView、Bun.writev、bun pm patch、--coverage 无报告） |
| ❓ 未完成验证 | 0（Bun.shrink 已通过"源码确认 + 实测"闭环，其余 ❓ 此前已全部收敛） |
| 🔒 环境依赖项（非能力缺口） | 5（Bun.postgres / Bun.sql / Bun.redis / Bun.s3 的真实服务端交互，REPL 交互式深度需 PTY——客户端错误路径与求值链路均已实测） |

---

## 7. 已知限制与规避

> 以下条目按"现象 → 原因 → 规避"描述；编号 P1–P15 在全文统一使用，
> 便于问题反馈时准确指代。

### 7.1 平台与环境限制（P1–P15）

#### P1 · `process.platform` 返回 `"openharmony"`

- **现象**：按平台分支的代码得到 `openharmony`（常见预期值为 `linux`）；
  个别按平台白名单过滤原生依赖的 npm 包识别失败。
- **原因**：本移植版本的平台识别特性，用于让生态正确识别运行环境。
- **规避**：优先选择带纯 JS fallback 的包；需要平台判断的代码兼容
  `platform === "openharmony"`。

#### P2 · 设备无 bash

- **现象**：执行 `#!/bin/bash` 脚本、`child_process.spawn("bash", ...)` 或部分包的
  lifecycle 脚本时，报 `Executable not found in $PATH: "bash"`。
- **原因**：系统仅提供 toybox sh，无 bash 解释器。
- **规避**：脚本解释器一律使用 `#!/bin/sh`；`Bun.$` 与 `spawn("sh", ...)` 不受影响。

#### P3 · 含原生二进制的 npm 包无法加载

- **现象**：`bun add sharp` 安装成功，但 `require("sharp")` 报
  `Could not load the "sharp" module using the openharmony-arm64 runtime /
  No native build was found for platform=openharmony arch=arm64`。
  同类包：rollup（原生模式）、@next/swc、vite turbo、canvas、datadog agent。
- **原因**：这些包未发布 openharmony-arm64 平台的原生产物。
- **规避**：优先使用 wasm / 纯 JS 实现路径（rollup 走 wasm、vite 关闭 turbo），
  或使用提供本平台产物的新版本。替代方案见附录 A。

#### P4 · unix domain socket 不可用

- **现象**：`net.Server.listen(path)`、`Bun.serve({unix})`、http/tls 的 socket 路径
  模式及默认使用 unix socket 的开发服务器，bind 任意路径均报
  `EPERM: operation not permitted, listen '/任意路径.sock'`。
- **原因**：设备存储面（hmdfs / EL2 沙箱）对 unix socket bind 的系统级限制。
- **规避**：统一改用 TCP + 端口。TCP（127.0.0.1 与局域网）完全可用。

#### P5 · 设备上无法构建原生 addon

- **现象**：`bun install` 触发 node-gyp 或 napi 构建场景时，先后出现
  `Executable not found in $PATH: "cc"`（无 C 编译器）与
  `refusing to use bunx cache directory ... not a directory owned by the current user`
  （bunx 缓存目录属主检查失败）；`/data/local/tmp` 对应用也不可写（EACCES），
  设备内构建的所有路径均被阻断。
- **原因**：设备无 C 工具链；应用沙箱的 FUSE uid 映射使 bunx 的目录属主检查必然失败。
- **规避**：在 linux aarch64 主机上交叉预编译，`.node` / `.so` 随项目分发，
  运行时直接加载（见 6.7 节）。

#### P6 · /storage 路径的 chmod 权限位不保持

- **现象**：`chmod 0o444 file` 后 `stat` 仍为 `660`；`bun pm diff` 的 mode 变更显示异常。
- **原因**：hmdfs 对权限位的存储策略（实验值：444→660，700→2771 setgid）。
- **规避**：权限位敏感的操作放在非 /storage 路径执行。
  常规文件操作（读/写/重命名/删除）不受影响。

#### P7 · `Bun.secrets` 不可用

- **现象**：调用报 `libsecret not available`。
- **原因**：设备无 D-Bus / libsecret 服务。
- **规避**：凭据使用文件存储（可配合 `Bun.password` 校验）或其他存储方案。

#### P8 · 显式 IPv6 的 localhost 解析失败

- **现象**：仅 `dns.lookup("localhost", {family:6})` 等显式 AAAA 查询报
  `getaddrinfo ENOTFOUND`；默认解析与日常用法无感知。
- **原因**：`/etc/hosts` 无 `::1 localhost` 条目（现有 `::1 ip6-localhost`）。
- **规避**：需要 IPv6 时用 `::1` 直连；有 root 权限时在 `/etc/hosts` 补充
  `::1 localhost`。`fetch("http://localhost:port/")` 等默认解析不受影响。

#### P9 · `bun upgrade` 不可用

- **现象**：报 `Bun v1.4.0 is out, but not for this platform (linux-aarch64) yet.`。
- **原因**：官方升级通道无本平台产物，属预期行为。
- **规避**：从发布页下载新版本二进制替换（见第 2 章）。

#### P10 · 高并发/长时间负载下的偶发失败

- **现象**：install / serve 类操作在多任务并发时偶发超时或失败，单独重跑即通过。
- **原因**：设备资源竞争，非功能缺陷。
- **规避**：降低并发度；偶发失败优先重跑再定性。

#### P11 · HTMLRewriter 使用形态限制

- **现象**：`response.body.pipeThrough(new HTMLRewriter()...)` 报
  `The transform's 'readable' property must be a ReadableStream`；
  `#comment` / `#doctype` 处理器注册后不触发（0 事件）。
- **原因**：pipeThrough Streams 形态未支持；注释 / doctype 事件派发存在缺口。
- **规避**：使用 Bun 形态 `rw.transform(response)`（元素/属性/文本捕获与改写
  全功能可用）；注释 / doctype 处理需求暂缓。

#### P12 · `Bun.redis` 对不可达服务挂起

- **现象**：redis 服务未启动或地址错误时，`Bun.redis.set/get` 等调用长时间无响应
  （超过 15 秒不抛错）。
- **原因**：redis 客户端缺少对不可达服务的快速失败路径
  （`Bun.sql` 与 S3 客户端均会快速给出类型化错误）。
- **规避**：调用前确认服务可达；为 redis 调用增加超时护栏。

#### P13 · Ctrl+C 对 dev server 类子进程的信号传播

- **现象**：在 `bun run dev`（vite / next 类 dev server）场景按 Ctrl+C 后，
  子进程 `signalCode` 为 `null` 而非 `"SIGINT"`。
- **原因**：SIGINT 向该类子进程的传播存在缺口（见 7.3）。
- **规避**：依赖子进程 signalCode 的脚本改为检查退出码。
  普通前台进程的中断行为与 SIGTERM / SIGKILL 收割不受影响。

#### P14 · git 依赖安装失败（网络前提）

- **现象**：`bun add github:user/repo` 或 git 协议依赖报
  `fatal: unable to access 'https://github.com/...': OpenSSL SSL_read: ... unexpected eof`
  或 `git@github.com: Permission denied (publickey)`。
- **原因**：设备网络对 github 直连的干扰；npm registry 不受影响。
- **规避**：为 git 配置代理，或将 github URL 重写到可达镜像
  （`git config --global url.<镜像地址>.insteadOf <原始地址>`）。
  npm registry 安装不经过 github，不受影响。

#### P15 · 透明代理环境下的网络行为（诊断须知）

- **现象**：设备网络经透明代理（vpn-tun）转发时，出站 `connect` 几乎不会失败
  （对不可达地址也表现为连接成功）；读路径上对端 RST 被内核呈现为干净的 EOF
  而非连接错误。
- **原因**：系统网络栈环境事实，非 Bun 行为。
- **规避**：网络诊断不要以 `connect` 失败为判定依据，为连接与请求设置显式超时；
  服务端与客户端代码需将"提前 EOF"视为可能的连接异常处理。

### 7.2 环境依赖与未完成验证面

以下各项**不是二进制能力缺口**：前四项因缺少配套服务端（Postgres/redis/S3）未做真实场景验证；REPL 交互深度需 PTY 驱动。使用前建议先小范围试运行：

| 能力 | 当前认知 | 待验证项 |
|---|---|---|
| REPL 交互式深度（多行/历史/补全） | 管道求值实测正常，交互 TTY 深度未测 | 交互式多行、历史、补全 |
| Bun.s3 | 需要 S3 服务端，本环境不可测 | 真实对象存储操作 |
| Bun.sql / Bun.redis 外连 | 需可达服务端，本环境不可测 | 连接池 / 断线重连行为 |
| `--inspect` 完整调试会话 | 监听与 inspector Session 实测通过 | 完整调试器链路 |
| bake dev | 高负载下偶发失败（见 P10） | 长运行稳定性 |

### 7.3 已知缺陷（修复中）

以下 4 项为已确认的缺陷，修复进行中：

| # | 失败面 | 使用者影响 |
|---|---|---|
| 1 | ctrl-c：SIGINT 未传播到 `bun vite` / `bun dev` 子进程 | 见 P13；另有 4 用例为 rollup 原生包缺失连带（P3） |
| 2 | cwd-enoent 改进错误消息断言 | 极边缘：工作目录被删除场景的错误消息文本 |
| 3 | expo 集成测试面 | 使用 expo 工具链的场景 |
| 4 | child_process IPC handle 面 | 依赖 IPC handle 深度行为的场景 |

> 其余测试失败均为设备环境面所致（unix socket、无工具链、无 bash、权限位、
> 生态包缺产物等，即 7.1 节条目所列），非功能缺陷。

### 7.4 上游继承问题（Bun 1.4.0）

本版本基于 Bun 1.4.0 上游代码构建：官方 1.4.0 存在、且在其后续版本中才修复或
仍未修复的问题，本版本同样存在。此类问题**与本平台移植无关**，随上游版本演进
自然收敛。已识别项如下：

**① node:stream 的 `pipeline` + async generator 组合缺口**（Bun 上游共性，见 6.5 节）

**② Worker 生命周期内存泄漏（当前存在；上游 1.4.1 起修复）**

- **问题**：Worker 的创建/销毁周期存在内存滞留——**强制垃圾回收后仍驻留，
  线性不收敛**。当前交付构建实测约 0.75MB/Worker（含 8MB JS 堆分配的
  Worker、close 与 terminate 退出路径行为一致，120 轮无平台期）；
  空 Worker 同样触发，MessagePort 非必要条件。
- **问题程度**：长运行进程反复新建 Worker 即持续增长，数千个 Worker 累计
  滞留 GB 级内存；"每请求新建 Worker"类场景影响显著。上游历史口径约
  1.4–1.8MB/Worker（因负载形态而异）。
- **归属**：上游缺陷——WebKit 分配器中 JSC/JIT 数据结构未随 Worker 虚拟机
  拆解释放。与本平台移植无关；官方 1.4.0 源码构建以同速率复现，可排除
  移植因素。
- **当前状态**：上游 1.4.1 起（JSC 分配器切换至 mimalloc）修复；当前交付
  构建基于 1.4.0 代码，**仍存在**。
- **规避**：长运行进程复用 Worker（池化），避免反复新建；观察到 RSS 随
  Worker 创建线性增长时按第 8 章反馈。

**③ `Bun.$` 高频重复调用的内存滞留（当前存在）**

- **问题**：长运行进程中反复执行 `Bun.$` shell 模板（如 await $`echo hello`），
  内存持续增长不释放。
- **问题程度**：本平台每万次调用 RSS 增长约 69MB，线性不收敛；50 万次累计
  约 3.5GB——常见 3GB 进程限制下约 43 万次触发 OOM。多个 1.4.0 基础的构建
  行为一致，属于版本级问题而非个例。
- **归属**：上游缺陷面——该版本 Bun 每次执行 `$` 都会创建并销毁一个专用
  分配器堆，而其内置的 mimalloc 版本在销毁堆时会永久滞留其他线程释放的
  内存页（该 mimalloc 缺陷在上游有明确记载并已修复）；OHOS 的线程调度
  必然触发该跨线程路径，因此问题在本平台明显显形。与本平台移植代码无关；
  含新版 mimalloc 的构建（1.4.2 起）实测不受影响。
- **当前状态**：当前交付构建存在；修复将随上游同步（mimalloc 版本升级）
  落地后续构建。
- **规避**：长运行循环中避免高频（万次级）调用 `$`；确需长时子进程调用的
  场景分批执行并周期性重启进程；采用替代方式（如 `Bun.spawn`）前先做
  等量压力验证。

---

## 8. 问题反馈

反馈请附以下三项，便于定位：

1. `bun --revision` 输出
2. 最小复现脚本
3. 完整 stderr

属第 7 章所列已知限制的，请先对照规避方案确认；偶发失败请先单独重跑
（负载敏感类见 P10）。

---

## 附录 A · 常见原生生态包替代方案

| 包 | 问题 | 替代方案 |
|---|---|---|
| sharp | 无 openharmony-arm64 原生产物 | 纯 JS 图像库（如 jimp）或服务端预处理 |
| rollup | 原生模式缺产物 | `@rollup/wasm-node`（wasm 版） |
| vite（turbo 引擎） | 缺产物 | 关闭 turbo（回退 esbuild wasm 路径） |
| @next/swc | 缺产物 | SWC wasm 版；或改用 Bun 内置打包/转译 |
| canvas | 缺产物 | 纯 JS 方案或预编译链路 |
| 通用原生 addon | 设备上不可构建 | linux aarch64 交叉预编译后随项目分发 `.node`，运行时直接加载 |

---

*本说明随版本更新。*

