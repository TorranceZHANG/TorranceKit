# TorranceKit

TorranceKit 是一款面向 Apple Silicon Mac 的开源原生效率工具库。它以菜单栏应用为统一入口，便于持续增加新的本地工具模块。当前第一个模块是剪贴板历史：记录用户连续复制的文本，通过可配置的全局快捷键呼出类似 Alfred 的浮动选择器，然后搜索、选择并粘贴任意一条历史内容。

项目完全使用 SwiftUI / AppKit 实现，无第三方运行时依赖。App 运行时无网络请求、无遥测，用户数据只保存在本机；安装和更新脚本仅在用户主动执行时访问 GitHub。

## 当前模块：剪贴板历史

- 默认 `⌥V` 呼出，可切换为其他组合快捷键或“双击 Ctrl / Option / Command / Shift”
- 自动记录纯文本，重复内容去重并移动到顶部
- 输入即搜索，支持 `↑` / `↓`、回车、`⌘1…9` 和鼠标操作
- 获得辅助功能权限后，选中即粘贴；未授权时安全降级为“选中即复制”
- 常驻菜单栏，可暂停记录、清空历史和退出
- 不占用程序坞；从“应用程序”中再次打开 App 可直接呼出剪贴板
- 保留条数、保留时间、单条大小、监听频率和粘贴行为均可配置
- 可按 Bundle ID 跳过前台应用中的复制内容
- 跳过密码管理器常用的临时、机密剪贴板类型

## 安装

要求 macOS 13 或更新版本，以及 Apple Silicon（M 系列）。

### 一键安装（无需 clone）

```bash
curl -fsSL https://raw.githubusercontent.com/TorranceZHANG/TorranceKit/main/install.sh | zsh
```

脚本会优先下载并校验最新 GitHub Release，安装到 `~/Applications/TorranceKit.app`。尚无 Release 时，会自动下载 `main` 源码快照并本地构建，该降级路径需要完整 Xcode，但同样不使用 `git clone`。

安装到系统的 `/Applications`：

```bash
curl -fsSL https://raw.githubusercontent.com/TorranceZHANG/TorranceKit/main/install.sh | zsh -s -- --system
```

如需先审阅脚本，可单独下载后再执行：

```bash
curl -fSLO https://raw.githubusercontent.com/TorranceZHANG/TorranceKit/main/install.sh
zsh install.sh
```

## 更新

检查并安装最新正式版本，无需 clone：

```bash
curl -fsSL https://raw.githubusercontent.com/TorranceZHANG/TorranceKit/main/update.sh | zsh
```

只检查、不安装：

```bash
curl -fsSL https://raw.githubusercontent.com/TorranceZHANG/TorranceKit/main/update.sh | zsh -s -- --check
```

更新脚本会自动查找 `~/Applications` 或 `/Applications` 中已安装的 TorranceKit，比较语义化版本号，只下载更新的 GitHub Release，并继续校验 SHA-256、Bundle ID、arm64 架构和代码签名。相同版本不会重复安装；需要修复安装时可追加 `--force`。更新只使用正式 Release，不会退回到 `main` 源码构建。

如果两个位置都安装了 TorranceKit，默认更新用户目录中的版本；追加 `--system` 可明确更新 `/Applications` 中的版本。

### 从源码一键安装

先安装完整 Xcode，或版本匹配的 Xcode Command Line Tools。克隆仓库后执行：

```bash
make install
```

默认安装到 `~/Applications/TorranceKit.app` 并立即启动，不需要管理员权限。若希望安装到所有用户可见的 `/Applications`：

```bash
make install-system
```

只构建、不安装：

```bash
make build
open dist/TorranceKit.app
```

### 从 GitHub Release 安装

正式发布后，下载 `TorranceKit-<版本>-macOS-arm64.zip`，解压后把 `TorranceKit.app` 拖入“应用程序”。Release 工作流已预留 Developer ID 签名和 Apple 公证，详见 [发布指南](docs/RELEASING.md)。

### 辅助功能权限

首次选择内容时，如果尚未授权，TorranceKit 只会把内容放回系统剪贴板。点击浮层底部或菜单栏里的“开启自动粘贴权限”，在“系统设置 → 隐私与安全性 → 辅助功能”中启用 TorranceKit，即可自动完成 `⌘V`。

如果重新构建后 macOS 未沿用辅助功能权限，先在系统设置中删除旧的 TorranceKit 条目，再重新添加 `dist/TorranceKit.app`。正式发布时应使用稳定的 Apple Developer 签名替代脚本默认的 ad-hoc 签名：

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build_app.sh
```

## 使用方式

1. 正常使用 `⌘C` 复制多段文字（终端中任何能写入系统剪贴板的 `Ctrl+C` 映射同样支持）。
2. 在要输入文字的位置按 `⌥V`。
3. 输入关键词过滤，使用方向键选择后按回车，或直接按 `⌘1…9`。

列表支持触控板和鼠标滚轮自然滚动。滚动时鼠标经过条目只更新悬停高亮，不会把页面自动拉回；使用 `↑` / `↓` 键选择时才会自动滚动到选中项。

### 菜单栏图标被刘海挡住时

macOS 会在菜单栏空间不足时隐藏部分状态项，应用本身无法强制占据最右侧位置。TorranceKit 不常驻程序坞，可以直接在“应用程序”中再次打开 `TorranceKit.app`，或者执行下面的命令呼出剪贴板：

```bash
open "$HOME/Applications/TorranceKit.app"
```

剪贴板浮层底部保留“设置”入口，也可以按 `⌘,` 打开设置。全局快捷键不依赖菜单栏图标是否可见；菜单栏图标当前可见时，还可以按住 `⌘` 将它向右拖动，降低被刘海或其他状态项挤出的概率。

## 本地数据

历史和配置分别保存在：

```text
~/Library/Application Support/TorranceKit/config.json
~/Library/Application Support/TorranceKit/Clipboard/history.json
```

TorranceKit App 运行时不联网、不上传内容。暂停记录期间产生的剪贴板内容不会在恢复时补录。

### 从 PasteNook 升级

第一次启动 TorranceKit 时，如果新路径中还没有数据，应用会自动复制 PasteNook 的配置、剪贴板历史和“是否暂停记录”偏好。旧数据不会被删除，新数据也不会被覆盖。

`make install` 会将同一安装位置中的 `PasteNook.app` 移到废纸篓。由于应用名和 Bundle ID 已更改，macOS 会把 TorranceKit 视为新应用，自动粘贴功能需要重新授予辅助功能权限。

## 配置

点击菜单栏的 TorranceKit 图标，选择“设置…”即可打开可视化设置窗口。日常使用无需接触 JSON，可直接配置：

- 全局呼出快捷键及修饰键组合
- 双击 Ctrl、Option、Command 或 Shift 呼出，以及双击识别间隔
- 历史保留条数和保留时间，两者均可单独关闭限制
- 自动粘贴、粘贴延迟、监听间隔和单条文本上限
- 不记录剪贴板的排除应用 Bundle ID

点击“保存并应用”后无需重启。如果新快捷键被其他应用占用或数值越界，窗口会显示错误，原有运行配置保持不变。

### 高级：JSON 配置

可视化设置与 `~/Library/Application Support/TorranceKit/config.json` 使用同一份数据。在设置窗口的“高级”页中，仍可在 Finder 中定位、使用默认编辑器打开，或将手工修改的 JSON 重新载入并应用。完整默认配置为：

```json
{
  "autoPaste": true,
  "excludedBundleIdentifiers": [],
  "hotKey": {
    "doubleTapIntervalMilliseconds": 400,
    "doubleTapModifier": "control",
    "key": "V",
    "mode": "keyCombination",
    "modifiers": ["option"]
  },
  "maxItems": 1000,
  "maxTextBytes": 1048576,
  "pasteDelayMilliseconds": 160,
  "pollIntervalMilliseconds": 450,
  "retentionDays": 30
}
```

| 配置项 | 类型 / 范围 | 作用 |
| --- | --- | --- |
| `hotKey.mode` | `keyCombination` 或 `doubleTapModifier` | 选择组合快捷键或双击修饰键 |
| `hotKey.key` | `A-Z`、`0-9`、`SPACE`、`RETURN`、`TAB` | 呼出选择器的主按键 |
| `hotKey.modifiers` | `command`、`control`、`option`、`shift`，至少一个 | 可组合多个修饰键，例如 `["command", "shift"]` |
| `hotKey.doubleTapModifier` | `command`、`control`、`option`、`shift` | 双击模式下监听的修饰键 |
| `hotKey.doubleTapIntervalMilliseconds` | `200...800` | 两次按下之间允许的最长毫秒数 |
| `maxItems` | 正整数或 `null` | 最大历史条数；`null` 表示不限条数 |
| `retentionDays` | 正整数或 `null` | 最近复制或使用后保留天数；`null` 表示不限时间 |
| `maxTextBytes` | `1024...10485760` | 单条文本最大 UTF-8 字节数 |
| `pollIntervalMilliseconds` | `100...5000` | 检查剪贴板变化的间隔 |
| `autoPaste` | 布尔值 | 是否在选择后自动向原应用发送 `⌘V` |
| `pasteDelayMilliseconds` | `50...2000` | 恢复原应用后等待多久再粘贴 |
| `excludedBundleIdentifiers` | 字符串数组 | 当前台应用匹配时跳过记录，例如 `com.example.SecretApp` |

`maxItems` 和 `retentionDays` 同时设置时，两项约束同时生效。两项都设为 `null` 会永久累计历史，请结合磁盘和隐私风险谨慎使用。

组合快捷键示例：

```json
{
  "hotKey": {
    "key": "K",
    "mode": "keyCombination",
    "modifiers": ["command", "shift"]
  }
}
```

双击 Ctrl 示例：

```json
{
  "hotKey": {
    "mode": "doubleTapModifier",
    "doubleTapModifier": "control",
    "doubleTapIntervalMilliseconds": 400
  }
}
```

双击修饰键需要 macOS 辅助功能权限才能全局监听。组合快捷键仍使用 Carbon Hot Key，不依赖该权限。

配置可以只写需要覆盖的字段，缺失字段沿用默认值；显式写 `null` 才会关闭条数或时间限制。配置格式错误、越界或新组合快捷键被其他应用占用时，当前配置和呼出方式保持不变。

## 卸载

默认只把应用移到废纸篓，保留历史和配置：

```bash
./scripts/uninstall.sh
```

同时永久清理本地数据：

```bash
./scripts/uninstall.sh --purge-data
```

## 开发验证

```bash
make test
make build
```

当前版本记录在根目录的 `VERSION` 文件中，构建后的应用会在菜单栏和“设置 → 高级 → 关于”中显示版本号。发布标签必须与该文件一致，例如 `VERSION` 为 `0.1.0` 时使用 `v0.1.0`。

工程使用 SwiftUI、AppKit、Carbon Hot Key 和 CoreGraphics，不依赖第三方库。`make test` 会同时运行核心独立测试和 SwiftPM XCTest，并在新版 Xcode 中显式选用 XCTest 运行器。

当前剪贴板模块的核心分层如下：

- `ClipboardMonitor`：监听系统剪贴板变化并过滤敏感类型
- `ClipboardHistory`：去重、限量、持久化
- `AppConfiguration`：解析、补默认值并校验 `config.json`
- `GlobalHotKey`：注册和热切换组合快捷键或双击修饰键触发器
- `PickerPanelController`：管理 Alfred 风格浮层与键盘路由
- `PasteController`：恢复原应用并注入 `⌘V`

新模块应保持独立的状态、配置分区、数据目录和权限边界，再由应用组合根接入菜单栏与全局快捷键。更完整的数据流和扩展约定见 [架构设计](docs/ARCHITECTURE.md)。参与开发前请阅读 [贡献指南](CONTRIBUTING.md) 与 [安全说明](SECURITY.md)。

## 许可证

[MIT](LICENSE)
