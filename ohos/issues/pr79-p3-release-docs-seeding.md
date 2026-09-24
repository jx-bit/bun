# P3: 发布文档自动占位——release-docs 专用分支 + 播种流水线
> **关联 PR**：[#79](https://github.com/jx-bit/bun/pull/79)

> 用户需求三轮迭代：(1) 每个 release 发布时自动在专用分支生成同名文件夹 +
> 占位 README，开发者事后直接编辑填充（"自动存在占位"）；(2) latest 的
> Products 表很好——所有 release 统一布局（tag 补 Products、latest/ohos-latest
> 补 Release Notes）；(3) 主页面需体现非商业独立性声明（与华为/OpenHarmony
> 社区无隶属、非附属软件非售后配套，可英文）与已知限制提示（细节指向详细文档）。

## 1. 背景：为什么是专用分支（三方案权衡记录）

| | dev | ohos-aarch64（+配套） | 专用分支（采纳） |
|---|---|---|---|
| 链接稳定性 | ✗ 工作区，文件会被清理/挪动 | ✓ | ✓ 单一用途无删除动机 |
| 编辑摩擦 | 零 | PR 仪式 | 零（直推） |
| CI 成本 | 零 | 零（需 paths-ignore 配套） | 零（天然，零配置） |
| 交付线改动 | 无 | 白名单 + 触发器 | 无 |

时序矛盾（描述 release 的文档不可能存在于它描述的 tag 的 commit 里）的解法：
文档住专用分支，release body 链接 `blob/release-docs/releases/<tag>/README.md`
（指向分支当前 HEAD，编辑后自动显示最新内容）。参考官方 oven-sh/bun 同构模式
（bun-v1.4.2 实测）：精简 body（安装命令内联 + 外部文档链接 + 贡献者），
不用 GitHub 自动 PR 笔记。

## 2. 实现（PR #79）

1. **release-docs 分支**：孤儿分支，仅含根 README（用途/结构/纪律说明）。
   纪律：只增改、不删挪——已发布文档路径是 release 页的永久链接。
2. **播种步骤**（ohos-release.yml，发布后、验证前）：python3 urllib（自托管
   runner 无 gh）+ contents API；幂等（GET 探查命中即跳过，绝不覆盖已有文件
   ——保护重跑与开发者内容）；瞬时 5xx 整体重试 3 次（先重探查再重创建，
   覆盖"500 但服务端实际已落盘"的歧义）；终态 404 时提示检查分支存在。
3. **body 瘦身**：删 Manual Download 清单（GitHub 自动列资产，原本重复）、
   关 `generate_release_notes`（官方也不用）、加 "Release Notes" 链接。
4. **门禁扩展**：Verify published releases 增加占位文档存在性断言——body
   链接的目标与资产同级验收，断链即红。
5. **统一页面布局**（所有 release，五段式）：Quick Install（内联自配对）→
   Products 表（tag 流新增，打包时动态生成含体积）→ Release Notes 链接 →
   Disclaimer → Known Limitations。latest 的 Quick Install 提到最前、标题
   层级统一为 ###；tag 流 body 改为动态生成（body_path，产物 /tmp/bun-release-body.md）。
6. **Disclaimer（英文）**：独立、非商业社区移植，as-is 无担保；非任何华为
   产品的附属软件或售后配套；与 OpenHarmony 社区及华为公司均无隶属。
7. **Known Limitations**：主页面提示鸿蒙系统限制（沙箱/签名/内核差异）导致
   部分功能缺失或降级，细节指向详细文档；三个占位模板均带"已知限制"骨架段
   供开发者填写。

## 3. 用户影响速览

| 需求 | 用户在做什么 | 感知结果 | 频率 | 严重度 |
|---|---|---|---|---|
| 占位 | push tag 发布（如 `1.4.0_1`） | release 页"详细说明"链接即刻有效（占位待补） | 每次发布 | —（满足） |
| 编辑 | 事后补充/修订文档 | 直推 release-docs 即生效，零仪式 | 随意 | —（满足） |
| 断链 | 发布异常/文档丢失 | CI 红（占位与资产同级门禁） | 异常时 | 中（可发现） |
| 合规 | 外部用户查看任意 release 页 | 页面明确非商业独立声明与已知限制提示，不会被误认为华为官方配套 | 每次浏览 | —（满足） |

## 4. 验证

- 实弹三路径（对真实分支）：创建（seeded，双文档）→ 幂等（already exists —
  untouched，双跳过）→ 5xx 重试（首跑 HTTP 500、重试成功——正是加重试的
  实证）；测试痕迹已还原，分支仅剩根 README。
- tag/latest 两处 body 生成器本地提取并端到端渲染，确认五段式统一布局
  （含 Disclaimer/Known Limitations 落版）。
- workflow YAML 解析 + 全部 run 块 `bash -n` 通过；播种 python `ast.parse`
  通过并经 contents API 端到端执行。
- check-pr.sh 全项 PASS（单 commit、message/body 无违禁引用、diff 白名单、
  基线新鲜）。

## 5. 使用约定

- 发布 = `git push origin <tag>` → CI 自动建 `releases/<tag>/README.md` 占位
- 编辑 = 直接改该文件、push release-docs；release 页链接自动显示最新
- 不删挪已发布的文档文件；可在仓库设置对该分支禁 force-push 加固

---
*立档：2026-09-24 | 分析者：Sisyphus | 依据：三方案权衡 + contents API 实弹测试*
