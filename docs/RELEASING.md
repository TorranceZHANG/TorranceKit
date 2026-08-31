# GitHub 发布指南

## 当前发布方式

TorranceKit 当前通过 GitHub Actions 自动制作 ad-hoc 签名的 Release，不需要 Apple Developer Program、Developer ID 证书或仓库 Secret。

推送与根目录 `VERSION` 一致的 `v*` 标签后，`Release` 工作流会自动：

1. 运行完整测试。
2. 构建 Apple Silicon `arm64` 应用。
3. 使用 ad-hoc 签名并验证应用包完整性。
4. 生成 zip 和 SHA-256 校验文件。
5. 创建 GitHub Release 并上传两个文件。

ad-hoc 签名不能证明开发者身份，应用也未经过 Apple 公证。用户首次打开时可能需要进入“系统设置 → 隐私与安全性”，确认“仍要打开”。不要建议用户全局关闭 Gatekeeper。

## 发版步骤

1. 更新根目录的 `VERSION` 和 `CHANGELOG.md`；`VERSION` 使用不带 `v` 的语义化版本号，例如 `0.2.0`。
2. 构建脚本会把 `VERSION` 写入 App 的 `Info.plist`，发布工作流会拒绝版本不一致的标签。
3. 在干净的 macOS 工作区执行：

   ```bash
   make test
   make build
   ```

4. 提交版本变更并推送 `main`。
5. 创建并推送对应的版本标签：

   ```bash
   git tag -a v0.2.0 -m "TorranceKit v0.2.0"
   git push origin v0.2.0
   ```

6. 在 GitHub 的 `Actions → Release` 中等待工作流完成。
7. 确认 Release 包含以下资产：

   ```text
   TorranceKit-0.2.0-macOS-arm64.zip
   TorranceKit-0.2.0-macOS-arm64.zip.sha256
   ```

8. 在另一台 Apple Silicon Mac 上验证下载、首次放行、安装、权限、快捷键、粘贴和更新。

已存在的版本标签不要覆盖；应增加版本号并创建新标签。

## 本地打包

本地制作同类 ad-hoc 安装包：

```bash
./scripts/package_release.sh
```

产物位于 `dist` 目录，仅适合测试或明确接受“无法验证开发者”提示的分发场景。

## 后续升级 Developer ID

加入 Apple Developer Program 后，可以恢复 Developer ID Application 签名、Hardened Runtime、`notarytool` 公证和 `stapler` 票据装订。升级前应继续保留当前版本校验、测试、SHA-256 和 Release 资产命名规则。
