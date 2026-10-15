# 架构设计

## 产品边界

TorranceKit 是单进程、无服务端的 macOS 菜单栏工具库。应用壳负责生命周期、菜单栏入口和通用本地路径；具体能力以模块形式接入。

当前模块包括搜索与计算启动器、剪贴板历史。启动器扫描本机应用、解析算式和网页动作；剪贴板处理纯文本和位图图片，不保留富文本，也不做云同步。

## 工具库分层

```text
TorranceKitApp
    │
    ├─ 应用壳：菜单栏、生命周期、AppPaths
    │
    └─ 功能模块
         ├─ Launcher
         │    ├─ ApplicationCatalog：后台应用目录扫描
         │    ├─ CalculatorEngine：有界表达式解析
         │    └─ LauncherQueryEngine / LauncherModel / LauncherPanelController
         └─ Clipboard
              ├─ 监听与历史
              ├─ 搜索与选择器
              └─ 粘贴与权限
```

目前保留单一 SwiftPM executable target，通过独立状态对象、服务和 action 类型分离模块。AppModel 统一窗口互斥、入口和配置事务；等模块形成稳定公共接口后再拆独立 target。

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
- `GlobalHotKey`：每个入口独立 Carbon ID，未知事件返回未处理；双击修饰键监听 flagsChanged、keyDown 和鼠标按下，两次完整轻点才触发。普通组合键和鼠标操作会取消候选，不吞输入。
- `HotKeyTransaction`：同步替换两组快捷键，先释放两者再注册候选，支持绑定互换；注册或写盘失败时恢复原绑定，恢复失败会明确报错。
- `LauncherModel`：同步解析当前查询、后台刷新应用目录；取消任务并用 generation 阻止旧窗口的扫描结果覆盖新窗口。
- `LauncherQueryEngine`：根据输入返回明确的 LauncherAction。网页关键词和网址只产生动作，用户执行前不会访问网络。
- `CalculatorEngine`：手写递归下降解析器，字符、UTF-8 字节和递归深度有界，拒绝无效和非有限数值。
- `PickerPanelController`：保存唤起前的前台应用、管理浮层生命周期和快捷键。
- `ClipboardPreviewLoader`：限制超长文本的界面预览规模，并在后台从私有 PNG 生成有界缩略图。
- `PasteController`：写回剪贴板、恢复原应用，延迟后确认目标仍在前台才注入 `⌘V`。打开任一入口/设置或开始另一次粘贴时取消旧任务。

两个浮层均进入当前桌面，失焦或切换桌面时隐藏。AppModel 的展示入口先隐藏另一个窗口，保证最多一个浮层。剪贴板控制器在应用启动时就记录最后一个外部应用，因此从启动器切换到剪贴板仍能找回原粘贴目标。安装仍后台启动，用户手动打开 App 则显示启动器。

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

0.3.0 保留顶层 hotKey（剪贴板），新增 launcher 配置分区。HotKeyConfiguration.default 继续表示旧 Option+V 解码默认；新建文件的 AppSettings.default 则使用 Control/Command 双击。旧用户已有绑定不被改写；缺少 launcher 且剪贴板已用 Command 双击时，启动器默认采用 Control+Option+Space。预设只改两个快捷键。

## 发布模型

普通 CI 和 GitHub Release 都会执行单元测试及 ad-hoc 签名构建。Release 额外校验版本、Info.plist、arm64 架构和代码签名完整性，并生成 zip 与 SHA-256 校验文件；当前不导入 Developer ID 证书，也不提交 Apple 公证。
