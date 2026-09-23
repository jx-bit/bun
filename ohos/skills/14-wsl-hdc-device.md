## Skill 14：WSL 直连鸿蒙真机（hdc 三条路径）

### 场景

WSL 里开发，鸿蒙设备插在 Windows 上（`hdc list targets` 在 PowerShell 可用）。
要在 WSL 里直接操控设备（部署 binary/测试树、跑 fulltest、收报告）。

### 路径 0（推荐）：WSLInterop 直调 hdc.exe —— 零配置

WSL 的 binfmt 已注册 `WSLInterop`，可直接执行 Windows exe：

```bash
# Windows hdc.exe 位置（各机器不同，两种找法）
# a. cmd 拿 Windows PATH 过滤
/mnt/c/Windows/System32/cmd.exe /c "where hdc"
# b. DevEco SDK 约定位置
ls /mnt/c/my_work/huawei/my_deveco/sdk/default/openharmony/toolchains/hdc.exe

# 直调（本仓库实测 OK）
H=/mnt/c/my_work/huawei/my_deveco/sdk/default/openharmony/toolchains/hdc.exe
$H list targets          # → 3QC0124905000311
$H shell "uname -a"      # → HongMeng Kernel 1.12.0 aarch64
```

**关键坑**：`hdc file send` 在 hdc.exe（Windows 进程）视角解析本地路径 ——
必须给 **Windows 路径**。WSL 文件先 cp 到 /mnt/c（= C:\）再发：

```bash
cp test-tree.tar /mnt/c/Users/DMMD/Desktop/
$H file send "C:\Users\DMMD\Desktop\test-tree.tar" "$DEVROOT/test-tree.tar"
```

### 路径 1：WSL 原生 Linux hdc + Windows 远程 server

本地 DevEco SDK 自带 Linux hdc：`/home/u22/DevEcoStudio/sdk/default/openharmony/toolchains/hdc`（Ver 3.1.0b）。
Windows 侧 server 默认只绑 127.0.0.1:8710，WSL2 不可达；让 Windows 重开：

```powershell
hdc kill; hdc -s 0.0.0.0:8710 start        # server 绑全网卡
netsh advfirewall firewall add rule name="hdc" dir=in action=allow protocol=tcp localport=8710
```

```bash
# WSL 侧（IP 用 `ip route | grep default` 的网关；WSL mirrored 模式可直接 127.0.0.1）
export OHOS_HDC_SERVER_PORT=8710
hdc -s <win-ip>:8710 list targets
```

### 路径 2：设备无线调试直连（绕过 Windows）

设备开"无线调试"拿 IP:port → WSL 直接 `hdc tconn <设备IP>:port`。
适合设备不便走 USB 时；传输速度看 WiFi。

### 路径对比

| 路径 | 配置成本 | 速度 | 适用 |
|---|---|---|---|
| 0 interop | 零 | USB 原速 | 日常（推荐） |
| 1 远程 server | Windows 两条命令 + 防火墙 | USB 原速 | 需要纯 Linux hdc 特性时 |
| 2 无线 tconn | 设备 UI 操作 | WiFi | 设备不在手边 |

---
