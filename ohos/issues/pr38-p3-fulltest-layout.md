# P3: ohos/fulltest 工具归位与索引补全 — 工作记录

> **关联 PR**：[#38](https://github.com/jx-bit/bun/pull/38)（claude 分支 → ohos-aarch64，单 commit `bcfa600f9a`，2 文件 +1/−1）
> **状态**：🔄 OPEN
> **定位**：工作流基础设施（纯文档/脚本归位）。配合 2026-09-11 的 ohos/ 目录
> 整理（134MB→5.2MB，垃圾目录/已合并分支/派生数据集清理，见
> `../fulltest-data/README.md` 轮次表（2026-09-11 时位于 analys/ 下，后归位））。

## 1. 内容

1. `install-bun-ohos.sh`（设备安装/签名）从 ohos 根部移入 `fulltest/`（rename
   100%），引用路径同步（全量测试指导 + tri-way 归档）
2. `fulltest/README.md` 补全 launcher/runner/deploy 脚本索引行

> junit 变体脚本（`run-all-official-junit.sh`）**暂不入库**：round C 用例级
> 升级机制待设备侧跑通后再定形态，当前移入 `ohos/_archive/` 本地暂存
> （未跟踪，不进 PR）。

## 2. 背景

- 用例级推断数据集（cases.sqlite/csv 58MB）已删除（推断精度不可靠 + junit
  轮将整体取代）；junit 脚本暂存 `_archive/`，待 round C 形态确定后再决定
  是否入库
- ohos/ 其余文档（issues/knowledge/analys 的 md）按惯例保持本地不入库；
  fulltest/ 脚本历来是跟踪的（设备测试交付物）

## 3. 验证

commit `bcfa600f9a`：install-bun-ohos.sh rename 100% + 指导路径修正 + README
索引行；junit 脚本不在 commit 内（本地 `_archive/` 暂存）。CI 纯文档变更。

## 4. 关联

- 同日整理：ohos/README.md（导航+硬性规则）、knowledge/README.md、
  analys/fulltest-data/README.md（三轮数据索引）
- 数据集删除记录：`analys/fulltest-data/`（per-case 管线已删；file-inventory-c4323a5d3 台账 2026-09-21 起归档于 fulltest-data/archive/）
