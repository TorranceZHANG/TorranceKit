# 参与贡献

感谢你帮助改进 TorranceKit。提交改动前，请先搜索现有 Issue；较大的功能建议先开 Issue 对齐交互和安全边界。

## 本地开发

要求 macOS 13+、Apple Silicon，以及完整 Xcode 或版本匹配的 Xcode Command Line Tools。

```bash
git clone <your-fork-url>
cd TorranceKit
make test
make build
open dist/TorranceKit.app
```

## Pull Request 要求

- 一个 PR 只解决一个主题。
- 用户可见文案优先使用清晰自然的中文。
- 修改历史淘汰、配置、去重或持久化逻辑时必须补测试。
- 修改剪贴板读取范围、权限或数据路径时，必须同步更新 `SECURITY.md` 和 README。
- 提交前运行 `make test` 和 `make build`。

## 设计原则

- 本地优先：剪贴板内容默认不离开设备。
- 键盘优先：核心流程不依赖鼠标。
- 权限最小化：没有辅助功能权限时仍能完成“选中即复制”。
- 可恢复：安装覆盖和卸载默认把旧应用移到废纸篓；只有显式传入 `--purge-data` 才删除历史。
- 模块自治：新工具拥有独立的状态、配置分区、数据目录和权限说明。
