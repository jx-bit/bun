# P2: runner 导入名与 utils 导出名不匹配（getHomedir）— 工作记录

> **关联 PR**：[#24](https://github.com/jx-bit/bun/pull/24)
> **状态**：🔄 OPEN（checks 验证中）
> **定位**：openharmony 对齐的跟进修复 —— RUNNER=node 链路的最后一个断点。
> 机制背景见 [`../knowledge/codesign-and-spawn-primer.md`](../knowledge/codesign-and-spawn-primer.md)。

## 1. 问题一句话

runner.node.mjs 从 utils.mjs 导入 `getHomedir`，而 utils.mjs 导出的函数名
是 `homedir` —— 名字对不上 → 模块加载即失败 → 容器测试通道 0 个测试执行。

## 2. 实锤（run 34202615606，#21/#22/#23 合并后首跑）

```
SyntaxError: The requested module './utils.mjs'
  does not provide an export named 'getHomedir'
runner exit code: 1
```

## 3. 修复（1 行）

runner 的导入别名对齐参考通道写法（其 runner.node.mjs:59 同款）：

```diff
-  getHomedir,
+  homedir as getHomedir,
```

## 4. 验证

- 定向 dispatch run 34208461267（ref=dev @ 修复后）：in progress ——
  RUNNER=node 下 runner 正常启动 + 测试执行 = 修复闭环
- 本 PR 的 build 门禁：zlib + lld@21 在 merge ref 上复验

## 5. 关联

- openharmony 对齐的完整映射：[pr21-p2-container-lanes-bringup.md](pr21-p2-container-lanes-bringup.md) §5.3/§5.4
- shebang 悬垂修复：[pr22-p1-shebang-arg-dangling.md](pr22-p1-shebang-arg-dangling.md)
