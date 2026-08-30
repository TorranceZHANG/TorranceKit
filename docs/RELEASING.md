# GitHub 发布指南

## 前置条件

公开分发的 macOS 应用应使用 Apple Developer Program 的 `Developer ID Application` 证书签名并通过 Apple 公证，否则 Gatekeeper 会阻止普通用户直接启动。

在 GitHub 仓库 Settings → Secrets and variables → Actions 中配置：

| Secret | 内容 |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | 导出的 Developer ID `.p12` 文件的 Base64 内容 |
| `P12_PASSWORD` | `.p12` 导出密码 |
| `KEYCHAIN_PASSWORD` | CI 临时钥匙串密码，可使用单独生成的随机值 |
| `DEVELOPER_ID_APPLICATION` | 完整签名身份，例如 `Developer ID Application: Name (TEAMID)` |
| `APPLE_ID` | 用于公证的 Apple ID |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APP_SPECIFIC_PASSWORD` | Apple ID 的 app-specific password |

Secret 只能通过 GitHub 界面或受控的仓库管理流程录入，不要写入代码、Issue、Actions 日志或提交历史。

## 发版步骤

1. 更新 `CHANGELOG.md`，把 Unreleased 内容归入目标版本。
2. 确认 `Resources/Info.plist` 的默认版本与目标版本一致；工作流还会用标签版本覆盖它。
3. 在干净工作区执行 `make test && make build`。
4. 创建并推送语义化版本标签，例如 `v0.1.0`。
5. `Release` 工作流会测试、构建、Developer ID 签名、公证、装订票据，并创建带 zip 和 SHA-256 校验文件的 GitHub Release。
6. 下载 Release 产物，在另一台未安装开发证书的 Apple Silicon Mac 上验证安装、权限、快捷键和粘贴。

本地仅打包 ad-hoc 签名版本可执行：

```bash
./scripts/package_release.sh 0.1.0
```

ad-hoc 产物适合本地测试，不适合作为面向普通用户的公开下载。
