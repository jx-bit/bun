# release-docs

此分支只存放各 release 的详细说明文档。

- **结构**：`releases/<tag>/README.md` —— 每个 release 一个同名文件夹
- **生成**：发布流水线（ohos-release.yml）在每次 tag 发布时自动创建占位 README，
  已存在的文件绝不覆盖
- **编辑**：直接修改文件并 push 到本分支（无需 PR），release 页面的链接
  `blob/release-docs/releases/<tag>/README.md` 会自动显示最新内容
- **纪律**：只增改、不删挪 —— 已发布文档的路径是 release 页的永久链接
