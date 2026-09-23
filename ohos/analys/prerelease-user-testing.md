# OHOS Bun 发布前用户视角测试清单（v1.4.0-canary.1+交付线）

> 视角：一个 OHOS 开发者拿到 bun 后实际会做什么。按使用场景组织，
> 每项标注：✅ 官方套件已覆盖 / ⚠️ 已知薄弱（复测数据）/ ❓ 套件未覆盖需专项。
> 基于：交付线 `0eafc2a105`（#34-#48 + 维护方 #49-#56 全部集成）+ 八轮复测归因。

## 一、安装与首次接触

| # | 用户动作 | 验证命令 | 覆盖 |
|---|---|---|---|
| 1.1 | 版本查询 | `bun --version` → `1.4.0-canary.1+<sha>` | ✅ |
| 1.2 | 帮助完整 | `bun --help` / `bun run --help` 各子命令 | ❓ |
| 1.3 | 平台报告 | `bun -e 'console.log(process.platform, os.platform(), os.arch(), os.machine())'` → 全部 openharmony/arm64 | ✅ #30/#53 |
| 1.4 | REPL 启动与求值 | `bun` 交互式 → 表达式/多行/退出 | ⚠️ repl 面有历史失败 |
| 1.5 | shebang 直执行 | `chmod +x script.ts && ./script.ts` | ✅ #17 |
| 1.6 | 签名 | ohos-selfsign 后 .so/.node 可加载 | ✅ #14/#16 |

## 二、运行代码（核心路径）

| # | 用户动作 | 验证命令 | 覆盖 |
|---|---|---|---|
| 2.1 | TS/JSX/ESM 零配置 | `bun run app.tsx`（含装饰器/top-level await） | ✅ |
| 2.2 | ESM+CJS 互操作 | CJS require ESM / ESM import CJS | ✅ |
| 2.3 | `bun -e` 求值 | `bun -e 'console.log(1+1)'` | ✅ |
| 2.4 | NPM 包零配置运行 | `bun add is-odd && bun -e 'require("is-odd")'` | ✅ |
| 2.5 | `bun run` package.json 脚本 | `bun run dev` / `bun run --parallel a b` | ⚠️ #41 修后待复测确认 |
| 2.6 | watch 模式 | `bun --watch run app.ts`（改动后重跑） | ❓ |
| 2.7 | 热重载 | `bun --hot run server.ts`（HTTP 不中断） | ❓ |
| 2.8 | 中文/长路径 | 项目放中文路径/深层目录下运行 | ❓ |

## 三、包管理

| # | 用户动作 | 验证命令 | 覆盖 |
|---|---|---|---|
| 3.1 | 全量安装 | `bun install`（package.json 多依赖） | ✅ |
| 3.2 | 增删改 | `bun add`/`remove`/`update` 各一次 | ✅ |
| 3.3 | 文本 lockfile 往返 | `bun install` ×2 → `bun.lock` 无 `os: "!openharmony"` 污染 | ⚠️ **#48 刚修，本轮必验** |
| 3.4 | 二进制 lockfile 往返 | 旧 lockb → 新 binary install → 无 os 字段损坏 | ⚠️ **#48 刚修，同上** |
| 3.5 | os 包过滤 | optionalDependencies 含 @esbuild/openharmony-arm64 → 正常安装 | ⚠️ #44 修后待复测 |
| 3.6 | workspace | monorepo `bun install` + `bun run --filter` | ⚠️ #41 修后待复测 |
| 3.7 | 生命周期脚本 | preinstall/postinstall（含 native 包 node-gyp 类） | ⚠️ #50 修后待复测 |
| 3.8 | 私有 registry | .npmrc/token/内网域名解析 | ⚠️ #40 netsys 后待复测 |
| 3.9 | git/tarball 依赖 | `bun add github:user/repo` | ❓ |
| 3.10 | isolated installs | `bun install --linker isolated` | ⚠️ Hardlinker 面有 A 差量 |
| 3.11 | 大型项目安装 | express/next 等真实项目 `bun install`（耗时/成功率） | ❓ **F4 忙旋面** |

## 四、测试运行器

| # | 用户动作 | 验证命令 | 覆盖 |
|---|---|---|---|
| 4.1 | 基础测试 | `bun test`（describe/it/expect/beforeEach） | ✅ |
| 4.2 | mock | `mock.module`/`jest.fn`/`spyOn` | ✅ |
| 4.3 | snapshot | `bun test --update-snapshots` | ✅ |
| 4.4 | 过滤 | `bun test --filter x` / `--changed` | ⚠️ #41 修后待复测 |
| 4.5 | 超时与 done 回调 | async done/nextTick 异常不挂 | ⚠️ #41 修后待复测 |

## 五、Bun.serve（HTTP 服务器）

| # | 用户动作 | 验证命令 | 覆盖 |
|---|---|---|---|
| 5.1 | HTTP 服务 + fetch | `Bun.serve({fetch})` → `fetch localhost` | ✅ |
| 5.2 | 静态文件路由 | `routes: {"/*": {dir}}` → 200×3 + 404 | ⚠️ **#43 修后待复测** |
| 5.3 | WebSocket | serve.websocket → 收发消息 | ✅ |
| 5.4 | TLS | `Bun.serve({tls})` → https fetch | ✅ |
| 5.5 | 错误处理 | fetch 回调 throw → 500 + 错误日志 | ✅ |
| 5.6 | 热重载不中断 | --hot 下 HTTP 持续可用 | ❓ |

## 六、Bun API（运行时内置）

| # | 用户动作 | 验证命令 | 覆盖 |
|---|---|---|---|
| 6.1 | Bun.file 读写 | 大文件/小文件/追加/删除 | ✅ |
| 6.2 | Bun.write 切片目标 | `Bun.write(file.slice(0,N), src)` | ⚠️ **bun-write 未修** |
| 6.3 | Bun.sql (Postgres) | 连接 → 查询 → 关闭 | ✅ |
| 6.4 | bun:sqlite | DatabaseSync/StatementSync 全生命周期 | ⚠️ 本轮 sqlite 文件级失败待定性 |
| 6.5 | Bun.redis | 连接 → get/set | ✅ |
| 6.6 | Bun.password | argon2i hash/verify | ✅ |
| 6.7 | Bun.hash | sha256/blake2b/crc32 | ✅ |
| 6.8 | Bun.Glob | 匹配/扫描 | ✅ |
| 6.9 | Bun.Transpiler | TS→JS 转换 | ✅ |
| 6.10 | Bun.ffi | dlopen + C 函数调用（OHOS .so） | ⚠️ 签名关联面 |
| 6.11 | Bun.dns | lookup（含 OHOS 无 v6 网络） | ⚠️ #40 修后待复测 |
| 6.12 | Bun.s3 | 需 S3 环境 | ❓ |

## 七、Web 标准 API

| # | 用户动作 | 验证命令 | 覆盖 |
|---|---|---|---|
| 7.1 | fetch/Response/Headers | 全组合 | ✅ |
| 7.2 | Streams | ReadableStream/WritableStream/TransformStream | ✅ |
| 7.3 | structuredClone | 含 CryptoKey/File 等复杂对象 | ⚠️ structured-clone 修后待复测 |
| 7.4 | crypto.subtle | digest/sign/verify | ✅ |
| 7.5 | AbortController | fetch 中断 | ✅ |
| 7.6 | URL/URLSearchParams | 解析/序列化 | ✅ |
| 7.7 | Event/EventTarget | DOM 事件模型 | ✅ |

## 八、Node 兼容层（node: 模块）

| # | 用户动作 | 验证命令 | 覆盖 |
|---|---|---|---|
| 8.1 | node:fs 全 API | read/write/stat/watch/rename | ✅ |
| 8.2 | node:path | posix/win32/parse/format | ✅ |
| 8.3 | node:crypto | createHash/cipher/decipher | ✅ |
| 8.4 | node:http createServer | listen → request → response | ✅ |
| 8.5 | node:child_process | spawn/exec/execFile/fork | ⚠️ #41 修后待复测 |
| 8.6 | node:stream | Readable/Writable/.pipeline | ✅ |
| 8.7 | node:os userInfo | `os.userInfo()` 不 throw | ⚠️ **#52 修后待复测** |
| 8.8 | node:zlib | gzip/deflate 全格式 | ✅ |
| 8.9 | node:worker_threads | Worker 通信/终止 | ✅ |
| 8.10 | node:cluster | 多进程 | ⚠️ 历史失败 |
| 8.11 | node:v8/vm | serialize/Script | ✅ |
| 8.12 | node:tls | TLS 客户端/服务端 | ⚠️ TLS/QUIC 面历史失败 |

## 九、进程与系统交互（OHOS 关键面）

| # | 用户动作 | 验证命令 | 覆盖 |
|---|---|---|---|
| 9.1 | Ctrl+C 中断 | 运行中服务器 → SIGINT 优雅退出 | ⚠️ ctrl-c 面历史失败 |
| 9.2 | SIGTERM 优雅退出 | kill → 清理回调执行 | ⚠️ |
| 9.3 | fd 预算 | `ulimit -Sn 256 && bun install` 不 EMFILE | ⚠️ **#42 修后待复测** |
| 9.4 | 删除 cwd 传播 | cwd 删除后 bun → 干净报错（非 $HOME 静默替换） | ⚠️ **#42 修后待复测** |
| 9.5 | Unix socket bind | AF_UNIX listen 在 hmdfs/EL2 路径 | ⚠️ EPERM 本轮新现 |
| 9.6 | 中文文件名/环境变量 | 含中文的项目/包名/脚本参数 | ❓ |
| 9.7 | 长跑稳定性 | 1h+ 服务器运行：RSS/fd/CPU 稳定 | ❓ **F4 忙旋面** |

## 十、打包与构建

| # | 用户动作 | 验证命令 | 覆盖 |
|---|---|---|---|
| 10.1 | bun build（bundler） | TS/JSX → JS bundle + sourcemap | ✅ |
| 10.2 | bun build --compile | 单文件可执行 → 设备运行 | ⚠️ 签名关联 |
| 10.3 | HTML 入口 | fullstack 构建 | ✅ |
| 10.4 | 宏 | 宏展开 | ✅ |
| 10.5 | 代码分割/minify | splitting + minify | ✅ |

## 优先级建议（发布前必过的 12 项）

| 优先 | 项 | 理由 |
|---|---|---|
| **P0** | 3.3/3.4 lockfile 往返 | 每次安装都触发——损坏即数据丢失 |
| **P0** | 2.5/3.6/4.4 `bun run` + shell 面 | 核心工作流（#41 修后首验）|
| **P0** | 3.5 os 包过滤 | OHOS 生态包能否安装 |
| **P1** | 3.7/3.11 生命周期+大型安装 | 真实项目可用性 |
| **P1** | 5.2 目录路由 / 6.2 bun-write 切片 | 功能缺失（#43 修/未修）|
| **P1** | 8.7 os.userInfo / 9.5 unix socket | Node 兼容完整性 |
| **P2** | 9.7 长跑 / 1.4 repl / 2.6-2.7 watch/hot | 体验面 |
