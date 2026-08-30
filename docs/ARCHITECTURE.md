# 架构设计

## 产品边界

TorranceKit 是单进程、无服务端的 macOS 菜单栏工具库。应用壳负责生命周期、菜单栏入口和通用本地路径；具体能力以模块形式接入。

当前唯一的功能模块是剪贴板历史。它处理纯文本和位图图片，不读取文件列表或保留富文本格式，也不做云同步。图片统一规范化为 PNG 并在本机独立存储。

## 工具库分层

```text
TorranceKitApp
    │
    ├─ 应用壳：菜单栏、生命周期、AppPaths
    │
    └─ 功能模块
         └─ Clipboard
              ├─ 监听与历史
              ├─ 搜索与选择器
              └─ 粘贴与权限
```

当前代码仍在单一 SwiftPM executable target 中，以避免在只有一个模块时过度拆分。当新增第二个模块时，再将共享能力抽到 `Core` target，各模块使用独立 target，应用 target 只做组合。

## 数据流

```text
NSPasteboard
    │ 按配置间隔检查 changeCount
    ▼
ClipboardMonitor ──敏感类型/应用/大小过滤──▶ ClipboardHistory
                                                  │
                                                  ├─ 去重、淘汰
                                                  ├─ Clipboard/history.json 原子写入
                                                  └─ Clipboard/images/*.png 私有文件

组合快捷键 / 双击修饰键 ─▶ GlobalHotKey ─▶ PickerPanelController ─▶ PickerView
                                                        │ 选中
                                                        ▼
                                   PasteController ─▶ 原应用 + ⌘V
```

## 组件职责

- `AppModel`：应用组合根，连接监控、历史、配置、权限和选择器。
- `ClipboardMonitor`：观察系统剪贴板，并以前台应用作为来源推断；识别 PNG/TIFF，校验尺寸与大小后统一转换为 PNG，不负责持久化。
- `ClipboardHistory`：历史记录的唯一写入口，负责文本/图片去重、数量限制、时间限制、JSON 元数据和图片文件落盘，以及删除时的文件清理。
- `AppConfiguration`：创建、校验和重新读取用户配置。
- `GlobalHotKey`：组合快捷键通过 Carbon 注册；双击修饰键通过全局与本地 `flagsChanged` 监听，并用可测试的状态机限制时间窗口、要求中间松开且禁止其他修饰键混入。
- `PickerPanelController`：保存唤起前的前台应用、管理浮层生命周期和快捷键。
- `ClipboardPreviewLoader`：限制超长文本的界面预览规模，并在后台从私有 PNG 生成有界缩略图。
- `PasteController`：把文本或 PNG/TIFF 图片写回剪贴板，恢复原应用；有权限时注入 `⌘V`。

选择器使用 `moveToActiveSpace` 而非 `canJoinAllSpaces`，只进入呼出时的当前桌面；切换应用或桌面时控制器主动隐藏窗口。安装器通过 `--background-launch` 启动菜单栏进程，避免安装完成后自动弹出选择器，用户手动打开 App 时仍会进入选择器。

## 新模块接入约定

- 为模块定义独立的状态对象，由 `AppModel` 或后续的组合根创建，不使用隐式全局单例。
- 持久化数据放入 `~/Library/Application Support/TorranceKit/<Module>/`，文件和目录继续使用最小权限。
- 全局配置保留在 `config.json`，新模块配置应使用命名分区，并为缺失字段提供向后兼容的默认值。
- 每个新权限、网络请求或外部数据交互都必须单独说明并更新 `SECURITY.md`。
- 全局呼出方式之间必须做冲突检测；新配置注册失败时保留原有可用配置。

## 配置生效

用户默认通过 SwiftUI 可视化设置编辑 `SettingsDraft`，保存时转换为 `AppSettings`。应用先完整校验候选配置，再尝试注册新呼出方式，最后原子写入 JSON 并更新运行状态。文件写入失败时会回滚到原呼出方式。

高级用户仍可直接修改 JSON，并从设置窗口重新载入。手工配置与可视化配置共用解码、校验和快捷键冲突处理；失败时当前运行配置保持不变。

`maxItems` 和 `retentionDays` 都是可空值，对文本和图片统一生效。两者同时存在时取更严格的结果；一条记录重新复制或被选择使用后会刷新其有效时间。配置重新加载、写入新记录和打开选择器时都会执行清理，图片记录被清理时同步删除 PNG 文件。

## 兼容性与数据迁移

TorranceKit 使用新的应用名、Bundle ID 和数据根目录。首次启动会在目标文件缺失时，将 PasteNook 的 `config.json` 和 `history.json` 复制到新路径；源文件保留，已有的 TorranceKit 文件不被覆盖。旧记录缺少 `kind` 字段时按文本解码。暂停记录偏好从旧 UserDefaults domain 单独迁移。

## 发布模型

普通 CI 做单元测试和 ad-hoc 签名构建。正式 GitHub Release 导入 Developer ID 证书，启用 Hardened Runtime，提交 Apple 公证并把票据装订到应用后再归档。
