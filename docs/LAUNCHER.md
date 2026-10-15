# 从剪贴板应用到工具集合

## 两个入口

| 入口 | 新配置默认 | 用途 |
| --- | --- | --- |
| 启动器 | 双击 Command | 一个输入框：应用搜索、计算、网页搜索、网址、工具命令 |
| 剪贴板 | 双击 Control | 保留现有左右两列文本和图片历史、预览、粘贴 |

两个快捷键独立配置，可以改成组合键。双击需辅助功能授权，组合键和菜单入口可用于未授权时进入设置。直接打开 App 显示启动器，不占程序坞；安装脚本仍后台启动。

双击是两次干净的按下和松开，默认必须在 400ms 内完成；中间按字母、鼠标或其他修饰键会取消。这样连续 ⌘C / ⌘V、Command 点击多选不会唤起启动器。

## Alfred 参考与本版边界

参考 Alfred 官方的 [Default Results](https://www.alfredapp.com/help/features/default-results/)、[Calculator](https://www.alfredapp.com/help/features/calculator/)、[Web Search](https://www.alfredapp.com/help/features/web-search/) 和 [Clipboard History](https://www.alfredapp.com/help/features/clipboard/)：默认结果适合高频应用，计算在输入框完成，搜索用关键词，剪贴板使用独立快捷键。

0.3.0 实现本机应用打开、数学计算、网页搜索、网址打开、剪贴板与设置命令。不是完整 Alfred 克隆：本版没有文件全文搜索、联系人、工作流、自动化脚本、片段扩展或 AI 功能。

应用目录每次展示后在后台扫描；名称优先精确匹配、前缀匹配、首字母，再包含匹配。查询变化即计算结果，目录回调使用当前查询。浮层关闭或重新展示会取消旧扫描，generation 校验防止过期回调。

网页搜索是用户明确执行的浏览器动作，不会边输入边联网。网址仅识别 HTTP/HTTPS，禁止把 file/javascript 等协议当成网址打开；搜索词由 URLComponents 编码。计算器使用手写语法，不接受任意代码或脚本。

## 接入新的本地工具

1. 为工具写无界面副作用的解析/计算服务。
2. 增加 LauncherAction 类型和对应 LauncherResult；扩展 LauncherQueryEngine 的关键词路由。
3. AppModel.execute 执行动作，先关闭当前浮层；涉及系统权限时在设置中解释并引导授权。
4. 工具设置放在独立命名分区，提供缺省字段兼容和可视化编辑。
5. 后台服务必须有取消、结果身份校验和明确失败反馈。

后续候选：`open/find` 文件搜索（Spotlight 及可配置范围）、固定文本片段、单位/时间戳/JSON 转换、自定义网站搜索；工作流插件接口等公共契约稳定后再设计。

## 升级兼容

已有的 Option+V 或其他剪贴板绑定继续有效；设置中的“双击 Command / Control 预设”才会切换两个入口。配置保存会同时释放两组绑定再注册候选，保证交换快捷键可行。任何注册或写盘失败都尝试恢复原两组绑定，恢复失败会显示错误。

切换浮层不覆盖最后一个外部应用。显示启动器、剪贴板或设置会取消上一条待执行的自动粘贴，避免延迟的 ⌘V 落进新输入框。
