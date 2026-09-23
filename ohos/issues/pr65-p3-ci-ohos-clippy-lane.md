# P3: CI 增加 ohos-target clippy lane(防再发机制)— 归档文档

> **关联 PR**:[#65](https://github.com/jx-bit/bun/pull/65)（单 commit
> `420e70ff0e`，1 文件 +29，base `ohos-aarch64` tip）
> **状态**：🔄 OPEN
> **来源**:[pr63 §5](pr63-p3-runtime-clippy-final.md) 防再发建议。
> **一句话**:把 ohos-target clippy 检查面从"本机手动"升级为 **CI 强制
> lane**——堵住三车道盲区的最后一环。

## 1. 问题(三车道盲区,复述)

OHOS 门控代码(`cfg(target_env = "ohos")`)对三层检查全部不可见:
1. host clippy——门控代码被 cfg 整体剔除,linter 不存在
2. OHOS 容器构建——`cargo build`,clippy 规则不参与普通编译
3. 设备 fulltest——只测运行时行为

结果:37 处违规跨 4 个 crate 静默积累(#57/#60/#62/#63 清理前)。

## 2. 修复

`rust-lints.yml` 新增 `clippy-ohos-target` job(与 host clippy job 同
setup,`rust-lint-setup` action + clippy 组件 + codegen ninja targets):

```sh
rustup target add aarch64-unknown-linux-ohos
cargo clippy -p bun_runtime --lib --target=aarch64-unknown-linux-ohos
```

- `-p bun_runtime` 覆盖全部依赖链(OHOS 门控代码全在其中)
- 工作区 lint(Cargo.toml `disallowed_methods = "deny"` 等)自动生效,
  无需 -D warnings
- x64 runner 即可(target std 为架构无关下载;无需 OHOS SDK——check 模式
  不做链接)

## 3. 验证

- 起点即绿:四批清理后当前 tip 的同命令 **0 error**(本机已验证同一
  命令,与 lane 完全一致)。
- YAML 语法校验通过。
- 此后任何 PR 引入新的 OHOS 门控违规 → 本 job 红 → PR 不可绿。

## 4. 与参照实现的对比

**无参照实现**——参照线的 clippy 车道同样只有 host(其
`rust:clippy` 无 `--target`,其 ohos-minimal 的 OHOS 门控欠账仍在:
read_to_string/File/undocumented unsafe 等,见
[pr60 §5](pr60-p3-standalone-graph-clippy.md) 对比)。本 lane 为
我方独有的防再发机制。证据:〔源码〕A 树 grep + 其 package.json 实测。
