# TorranceKit

TorranceKit 是一款面向 Apple Silicon Mac 的开源原生效率工具集合：双击 **Command** 进入搜索与计算启动器，双击 **Control** 进入文本和图片剪贴板。两个入口和功能选项都能在可视化设置中配置。

项目使用 SwiftUI / AppKit，无第三方运行时依赖。搜索和计算在本机执行，无遥测；只有用户执行网页搜索或打开网址时交给默认浏览器。安装和更新脚本在用户主动执行时访问 GitHub。

当前版本为 0.3.1，可通过下面的一键安装或更新命令获取；旧用户升级后保留原有剪贴板快捷键。

## 搜索与计算

从“应用程序”打开 TorranceKit，或双击 Command 显示输入框，输入后用上下键选择、回车执行、Esc 关闭。

| 输入 | 行为 |
| --- | --- |
| `Safari`、`Chrome`、`gc` | 搜索并打开应用，支持名称包含匹配和大写首字母缩写 |
| `1+2*3`、`(120+80)*10%` | 实时计算，回车复制结果 |
| `=sqrt(16)+2^3` | 指定计算，支持括号、幂、函数、pi/e |
| `web 北京天气`、`bing macOS` | 用默认或指定引擎在浏览器中搜索 |
| `example.com`、`https://example.com` | 打开网址 |
| `clipboard` / `剪贴板` | 进入原有剪贴板界面 |
| `settings` / `设置` | 打开可视化设置 |

应用扫描范围是 `/Applications`、`/System/Applications` 和 `~/Applications`，每次打开启动器后台刷新。网页关键词包括 `web`、`search`、`google`、`bing`、`ddg`、`baidu`。默认搜索引擎可选 Google、Bing、DuckDuckGo、百度。

计算器支持 `+ - * / ^`、后缀 `%`（百分数）、`sqrt/abs/round/floor/ceil/sin/cos/tan/log/ln`；三角函数为弧度，`log` 为以 10 为底。使用浮点数，最多 16 位有效数字；除零、无效输入和非有限结果会报错。输入上限 1024 字符、递归上限 64 层，不执行脚本或系统命令。

设计参考 Alfred 的 [默认搜索](https://www.alfredapp.com/help/features/default-results/)、[计算器](https://www.alfredapp.com/help/features/calculator/) 和 [网页搜索](https://www.alfredapp.com/help/features/web-search/) 的交互；详细边界和后续扩展见 [启动器设计](docs/LAUNCHER.md)。

## 当前模块：剪贴板历史

- 新配置默认双击 Control 呼出；旧用户保留原有快捷键，可在设置中一键切换双击预设
- 自动记录文本和图片，重复内容去重并移动到顶部
- 左侧显示省略后的内容列表，右侧完整预览长文本或图片
- 输入即搜索，支持 `↑` / `↓`、回车、双击、`⌘1…9` 和鼠标操作
- 获得辅助功能权限后，确认条目即粘贴；未授权时安全降级为“确认即复制”
- 常驻菜单栏，可暂停记录、清空历史和退出
- 不占用程序坞；从“应用程序”中再次打开 App 显示搜索与计算，可从中进入剪贴板
- 保留条数、保留时间、文本/图片大小、监听频率和粘贴行为均可配置
- 可按 Bundle ID 跳过前台应用中的复制内容
- 跳过密码管理器常用的临时、机密剪贴板类型

## 安装

要求 macOS 13 或更新版本，以及 Apple Silicon（M 系列）。

### 一键安装（无需 clone）

```bash
curl -fL --connect-timeout 15 --max-time 60 \
  https://raw.githubusercontent.com/TorranceZHANG/TorranceKit/main/install.sh | zsh
```

脚本会优先下载并校验最新 GitHub Release，安装到 `~/Applications/TorranceKit.app`，完成后在后台启动菜单栏进程但不主动弹出选择器。尚无 Release 时，会自动下载 `main` 源码快照并本地构建，该降级路径需要完整 Xcode，但同样不使用 `git clone`。

安装到系统的 `/Applications`：

```bash
curl -fL --connect-timeout 15 --max-time 60 \
  https://raw.githubusercontent.com/TorranceZHANG/TorranceKit/main/install.sh | zsh -s -- --system
```

如需先审阅脚本，可单独下载后再执行：

```bash
curl -fSLO https://raw.githubusercontent.com/TorranceZHANG/TorranceKit/main/install.sh
zsh install.sh
```

## 更新

检查并安装最新正式版本，无需 clone：

```bash
curl -fL --connect-timeout 15 --max-time 60 \
  https://raw.githubusercontent.com/TorranceZHANG/TorranceKit/main/update.sh | zsh
```

只检查、不安装：

```bash
curl -fL --connect-timeout 15 --max-time 60 \
  https://raw.githubusercontent.com/TorranceZHANG/TorranceKit/main/update.sh | zsh -s -- --check
```

更新脚本会自动查找 `~/Applications` 或 `/Applications` 中已安装的 TorranceKit，比较语义化版本号，只下载更新的 GitHub Release，并继续校验 SHA-256、Bundle ID、arm64 架构和代码签名。下载过程会显示进度并设置超时；相同版本不会重复安装，需要修复安装时可追加 `--force`。更新只使用正式 Release，不会退回到 `main` 源码构建。

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

正式发布后，下载 `TorranceKit-<版本>-macOS-arm64.zip`，解压后把 `TorranceKit.app` 拖入“应用程序”。当前 Release 使用 ad-hoc 签名且未经过 Apple 公证，首次打开时可能需要在“系统设置 → 隐私与安全性”中选择“仍要打开”，详见 [发布指南](docs/RELEASING.md)。

### 辅助功能权限

首次选择内容时，如果尚未授权，TorranceKit 只会把内容放回系统剪贴板。点击浮层底部或菜单栏里的“开启自动粘贴权限”，在“系统设置 → 隐私与安全性 → 辅助功能”中启用 TorranceKit，即可自动完成 `⌘V`。

设置页会在打开时、从系统设置返回时和后台定时检查当前进程的权限，授权后显示“辅助功能已授权”，并重建双击监听，无需重新保存快捷键。点击“开启权限”会先隐藏启动器、剪贴板和设置窗口，再打开系统授权页面，避免遮挡。

当前本地构建和 GitHub Release 都使用 ad-hoc 签名，更新或重新构建后，系统设置中的旧开关可能仍开启，但不再匹配新应用。此时先关闭再打开 TorranceKit 开关；若仍未生效，删除旧条目，通过应用设置中的“在 Finder 中显示当前应用”定位并重新添加实际运行的副本（默认是 `~/Applications/TorranceKit.app`）。以后加入 Apple Developer Program 后，可以改用稳定的 Developer ID 签名：

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build_app.sh
```

## 使用方式

1. 正常使用 `⌘C` 复制多段文字或图片（终端中任何能写入系统剪贴板的 `Ctrl+C` 映射同样支持）。
2. 在要输入文字的位置双击 Control（旧用户使用原配置的快捷键）。
3. 左侧单击条目，右侧查看完整文本或图片预览。
4. 按回车、双击条目，或直接按 `⌘1…9` 完成复制/粘贴。

列表支持触控板和鼠标滚轮自然滚动。滚动时鼠标经过条目只更新悬停高亮，不会把页面自动拉回；使用 `↑` / `↓` 键选择时才会自动滚动到选中项。切换到其他应用或桌面时选择器会自动隐藏，也可以使用 `Esc` 或右上角关闭按钮隐藏。

为防止异常大的内容阻塞界面，超过 20 万字符的文本只在右侧预览前 20 万字符，复制和粘贴仍使用完整内容；图片预览会在后台生成最长边不超过 1600 像素的缩略图，原图保存和粘贴不受影响。

### 菜单栏图标被刘海挡住时

macOS 会在菜单栏空间不足时隐藏部分状态项。可在“应用程序”中再次打开 `TorranceKit.app`，或执行下面的命令呼出启动器，再输入 `clipboard` 进入剪贴板：

```bash
open "$HOME/Applications/TorranceKit.app"
```

剪贴板浮层底部保留“设置”入口，也可以按 `⌘,` 打开设置。全局快捷键不依赖菜单栏图标是否可见；菜单栏图标当前可见时，还可以按住 `⌘` 将它向右拖动，降低被刘海或其他状态项挤出的概率。

## 本地数据

历史和配置分别保存在：

```text
~/Library/Application Support/TorranceKit/config.json
~/Library/Application Support/TorranceKit/Clipboard/history.json
~/Library/Application Support/TorranceKit/Clipboard/images/*.png
```

文本和图片元数据保存在 `history.json`，图片二进制单独保存为私有 PNG 文件。删除、过期淘汰或清空图片记录时，对应文件也会同步删除。

剪贴板历史和搜索输入不上传。用户主动执行网页搜索时，搜索词会传递给浏览器和所选搜索引擎。暂停记录期间产生的剪贴板内容不会在恢复时补录。

### 从 PasteNook 升级

第一次启动 TorranceKit 时，如果新路径中还没有数据，应用会自动复制 PasteNook 的配置、剪贴板历史和“是否暂停记录”偏好。旧数据不会被删除，新数据也不会被覆盖。

`make install` 会将同一安装位置中的 `PasteNook.app` 移到废纸篓。由于应用名和 Bundle ID 已更改，macOS 会把 TorranceKit 视为新应用，自动粘贴功能需要重新授予辅助功能权限。

## 配置

点击菜单栏的 TorranceKit 图标，选择“设置…”即可打开可视化设置窗口。日常使用无需接触 JSON，可直接配置：

- 全局呼出快捷键及修饰键组合
- 启动器独立呼出方式、应用搜索/计算器/网页搜索开关、默认搜索引擎、结果数量
- 双击 Ctrl、Option、Command 或 Shift 呼出，以及双击识别间隔
- 历史保留条数和保留时间，两者均可单独关闭限制
- 是否记录图片、自动粘贴、粘贴延迟、监听间隔和文本/图片大小上限
- 不记录剪贴板的排除应用 Bundle ID

旧版升级后，打开“设置 → 启动器 → 使用双击 Command / Control 预设”，再点击“保存并应用”即可切换两个入口，不重置其他选项。双击功能需要辅助功能权限；未授权时仍可从菜单栏或直接打开 App 进入，并可配置组合快捷键。

保存时完整校验两组快捷键，并一起注册后写入文件；重复绑定或被其他应用占用会报错，恢复原配置。极端情况下原绑定也无法重新注册时，会明确显示恢复失败。

### 高级：JSON 配置

可视化设置与 `~/Library/Application Support/TorranceKit/config.json` 使用同一份数据。在设置窗口的“高级”页中，仍可在 Finder 中定位、使用默认编辑器打开，或将手工修改的 JSON 重新载入并应用。完整默认配置为：

```json
{
  "autoPaste": true,
  "capturesImages": true,
  "excludedBundleIdentifiers": [],
  "hotKey": {
    "doubleTapIntervalMilliseconds": 400,
    "doubleTapModifier": "control",
    "key": "V",
    "mode": "doubleTapModifier",
    "modifiers": ["option"]
  },
  "maxImageBytes": 20971520,
  "launcher": {
    "hotKey": {
      "mode": "doubleTapModifier",
      "doubleTapModifier": "command",
      "doubleTapIntervalMilliseconds": 400,
      "key": "SPACE",
      "modifiers": ["option"]
    },
    "searchesApplications": true,
    "calculatorEnabled": true,
    "webSearchEnabled": true,
    "searchEngine": "google",
    "maxResults": 8
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
| `launcher.hotKey` | 同 `hotKey` 格式 | 搜索与计算的独立入口，不能与剪贴板重复 |
| `launcher.searchesApplications` / `calculatorEnabled` / `webSearchEnabled` | 布尔值 | 对应功能开关 |
| `launcher.searchEngine` | `google` / `bing` / `duckduckgo` / `baidu` | 默认网页搜索引擎 |
| `launcher.maxResults` | `3...20` | 可见结果数上限 |
| `hotKey.key` | `A-Z`、`0-9`、`SPACE`、`RETURN`、`TAB` | 呼出选择器的主按键 |
| `hotKey.modifiers` | `command`、`control`、`option`、`shift`，至少一个 | 可组合多个修饰键，例如 `["command", "shift"]` |
| `hotKey.doubleTapModifier` | `command`、`control`、`option`、`shift` | 双击模式下监听的修饰键 |
| `hotKey.doubleTapIntervalMilliseconds` | `200...800` | 两次完整轻点的时间窗口；长按或夹杂其他键会取消 |
| `maxItems` | 正整数或 `null` | 最大历史条数；`null` 表示不限条数 |
| `retentionDays` | 正整数或 `null` | 最近复制或使用后保留天数；`null` 表示不限时间 |
| `capturesImages` | 布尔值 | 是否记录系统剪贴板中的图片 |
| `maxTextBytes` | `1024...10485760` | 单条文本最大 UTF-8 字节数 |
| `maxImageBytes` | `65536...52428800` | 单张图片转为 PNG 后允许保存的最大字节数 |
| `pollIntervalMilliseconds` | `100...5000` | 检查剪贴板变化的间隔 |
| `autoPaste` | 布尔值 | 是否在选择后自动向原应用发送 `⌘V` |
| `pasteDelayMilliseconds` | `50...2000` | 恢复原应用后等待多久再粘贴 |
| `excludedBundleIdentifiers` | 字符串数组 | 当前台应用匹配时跳过记录，例如 `com.example.SecretApp` |

`maxItems` 和 `retentionDays` 对文本、图片统一计数；同时设置时两项约束同时生效。两项都设为 `null` 会永久累计历史，请结合磁盘和隐私风险谨慎使用。

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

配置可以只写需要覆盖的字段；显式写 `null` 才会关闭条数或时间限制。为兼容旧版，JSON 缺少顶层 `hotKey` 时保留旧默认 Option+V；新生成的配置使用 Control 双击。缺少 `launcher` 时补 Command 双击；如果旧剪贴板已经使用 Command 双击，新启动器回退到 Control+Option+Space。

## 卸载

默认会停止 TorranceKit/PasteNook，注销它们在两个“应用程序”目录中的全部副本并移到废纸篓，同时移除可能遗留的启动项；历史和配置仍会保留：

```bash
./scripts/uninstall.sh
```

同时永久清理 TorranceKit 和旧版 PasteNook 的历史、图片、配置、偏好、缓存、保存状态与隐私权限记录：

```bash
./scripts/uninstall.sh --purge-data
```

在真正卸载前，可以预览本机将执行的操作：

```bash
./scripts/uninstall.sh --purge-data --dry-run
```

应用会移到废纸篓以便恢复；`--purge-data` 清理的用户数据无法恢复。自动化运行时可追加 `--yes` 跳过永久删除确认。

## 开发验证

```bash
make test
make build
```

当前版本记录在根目录的 `VERSION` 文件中，构建后的应用会在菜单栏和“设置 → 高级 → 关于”中显示版本号。发布标签必须与该文件一致，例如 `VERSION` 为 `0.1.0` 时使用 `v0.1.0`。

工程使用 SwiftUI、AppKit、Carbon Hot Key 和 CoreGraphics，不依赖第三方库。`make test` 会同时运行核心独立测试和 SwiftPM XCTest，并在新版 Xcode 中显式选用 XCTest 运行器。

当前剪贴板模块的核心分层如下：

- `ClipboardMonitor`：监听系统剪贴板变化，过滤敏感类型并将图片规范化为 PNG
- `ClipboardHistory`：统一管理文本/图片去重、限量、元数据与图片文件持久化
- `AppConfiguration`：解析、补默认值并校验 `config.json`
- `GlobalHotKey`：注册和热切换组合快捷键或双击修饰键触发器
- `PickerPanelController`：管理 Alfred 风格浮层与键盘路由
- `PasteController`：恢复原应用并注入 `⌘V`

新模块应保持独立的状态、配置分区、数据目录和权限边界，再由应用组合根接入菜单栏与全局快捷键。更完整的数据流和扩展约定见 [架构设计](docs/ARCHITECTURE.md)。参与开发前请阅读 [贡献指南](CONTRIBUTING.md) 与 [安全说明](SECURITY.md)。

## 许可证

[MIT](LICENSE)
