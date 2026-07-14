# 爱记账 (aijz)

一个记账 / 个人财务管理项目。

## 项目简介

> 在这里用一两句话描述你的项目目标、受众与核心功能。

## 功能特性

- [ ] 待补充

## 快速开始

```bash
git clone https://github.com/yq2580/aijz.git
cd aijz
# 后续根据你选择的技术栈补充安装与运行步骤
```

## 目录结构

（待补充）

## 贡献

欢迎提交 Issue 和 Pull Request。

## License

[MIT](LICENSE)

## 本地开发与发布

- 更新清单页面 `update.html` 顶部 `const REPO = "yq2580/aijz";` 改成你的 `owner/repo` 即可复用（GitHub Pages 版本在 `docs/index.html`）。
- 一键发布新版本：执行 `./release.sh <版本tag> [说明文件]`
  - 需先 `export GITHUB_TOKEN=你的Token`（需要 repo 权限）
  - 会自动创建 Release、上传 `update.html` / `update.json`、并同步 `docs/` 供 GitHub Pages 使用
- 更新清单页面实时读取 GitHub Releases（`/releases/latest`），展示版本号、发布说明与下载资源。