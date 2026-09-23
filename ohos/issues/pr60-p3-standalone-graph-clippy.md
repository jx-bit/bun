# P3: ohos-target clippy 欠账第二批——StandaloneModuleGraph 迁移 — 归档文档

> **关联 PR**:[#60](https://github.com/jx-bit/bun/pull/60)（单 commit
> `fc31790a7c`，1 文件 +60/−37，base `ohos-aarch64` tip `586d8a1784`）
> **状态**：✅ 合并（5d8820bcdc）
> **来源**：[#57](https://github.com/jx-bit/bun/pull/57) 第一批清理后
> `--keep-going` 全量枚举出的下一批；承接
> [pr57 文档](pr57-p3-ohos-target-clippy-debt.md)。
> **一句话**：OHOS 独立可执行文件的模块图加载器（定位 /proc/self/exe 的
> `.bun` section 并 mmap）整体迁移出禁用的 std::fs/str API——12 错清零。

## 1. 欠账明细（12 处,单文件单区域）

`src/standalone_graph/StandaloneModuleGraph.rs:501-622`（cfg(target_env =
"ohos") 区域,host lane 不可见）：

| 类型 | 数量 | 位点 |
|---|---|---|
| `std::fs::read_to_string` | 1 | ohos_pie_load_base(:503) |
| `str::lines` / `str::split` | 2 | 同上(:504/:514) |
| `std::fs::File` | 4 | get_data(:526/:529)、locate_bun_section(:554)、read_at(:608) |
| undocumented unsafe | 3 | mmap(:537)、ptr add(:550)、pread(:610) |
| ptr `as` 强转 | 2 | :550/:613 |

## 2. 迁移内容

1. **ohos_pie_load_base**:`/proc/self/maps` 改字节级读取解析
   (`openat_a` + read 循环 + `bun_core::strings::split`)。**顺带修复一个
   潜伏缺陷**:mapped 路径可含非 UTF-8 字节,原 read_to_string 会失败 →
   PIE base 检测静默失效;字节级解析不再有此问题。
2. **File → bun_sys 全家桶**:`openat_a`(收 `&[u8]`)+ `File::from_fd`
   (Drop 保证所有路径关闭)+ `bun_sys::pread`(EINTR 重试,原裸
   libc::pread64 不重试);mmap 块补 SAFETY;指针转换 `.cast::<u8>()`。
3. `locate_bun_section(fd: bun_sys::Fd)` 签名随迁;`AlignedBuf` 未涉及
   (无独立欠账)。

## 3. 本仓 lint 更严的适配

- `bun_paths::strings` 与 `bun_core::strings` 同名遮蔽——解析代码用
  `bun_core::strings::` 全限定
- 嵌套 mod 作用域无 `Syscall` 别名——`bun_sys::` 全限定
- `Fd::native()` 在本文件 :1649 有 c_int FFI 先例,mmap 沿用

## 4. 验证

- 〔本机〕bun_standalone_graph ohos-target clippy **0 error**(修复前
  12 error);host clippy ✅;rustfmt ✅;cargo check bun_runtime
  ohos-target ✅。
- **未修复构建上必失败声明**:同命令 12 error。
- 〔行为变化〕仅 non-UTF-8 maps 路径(原 PIE 检测静默失效 → 现正常),
  其余语义不变。

## 5. 剩余欠账(第三批,已枚举)

~~`bun_install` 7 错~~ **✅ 已清:[#62](pr62-p3-bun-install-clippy.md)**
(env::var → getenv_z 等)。其后续枚举:**bun_runtime 自身 OHOS 门控
7 错**(第四批,见 pr62 文档 §4)。枚举命令:
`cargo clippy --workspace --lib --target=aarch64-unknown-linux-ohos --keep-going`。
