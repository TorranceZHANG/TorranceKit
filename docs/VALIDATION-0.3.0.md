# 0.3.0 开发版验证记录

本记录对应 2026-10-12 的本地验证，后续分支提交和 CI 状态以 PR 页面为准。

## 快照与产物

- 基线：TorranceKit `v0.2.1`，commit `7c2d6077c43fcb96ca923bb52733e7232e181cda`。
- 开发副本：`/Users/torrance/workspace/copy_paste_tool/TorranceKit-next`。
- 版本：0.3.0 开发版；本轮不创建发布标签或 GitHub Release。
- 工具链：Apple Swift 6.2.4；生产构建 `-swift-version 5 -target arm64-apple-macosx13.0 -O -whole-module-optimization`。
- 应用：`dist/TorranceKit.app`；实际二进制来自该副本的 `.build/torrancekit/release/TorranceKit`。
- 测试：该副本 `.build/arm64-apple-macosx/debug/TorranceKitPackageTests.xctest`，SwiftPM debug 模式。

## 实际执行与结果

| 检查 | 命令 | 结果 |
| --- | --- | --- |
| 编译全部测试 | `swift build --build-tests --disable-sandbox`，缓存路径均设为副本内 `.build` | exit 0，无新增编译警告 |
| 核心独立测试 | `./scripts/test_core.sh` | exit 0 |
| 安装/卸载隔离测试 | `./scripts/test_installer.sh` | exit 0 |
| 完整 XCTest | `xcrun xctest .build/arm64-apple-macosx/debug/TorranceKitPackageTests.xctest` | exit 1：76 个测试，74 个通过，两项剪贴板测试共六个断言失败 |
| 新增与受影响 suite 单独复跑 | `xcrun xctest -XCTest TorranceKitTests.<suite> <测试包>` | 七个 suite 共 38 个测试全部通过，其中 34 个为新增测试 |
| Release 构建 | `./scripts/build_app.sh`，module cache 指向副本 `.build/module-cache` | exit 0 |
| 应用校验 | `plutil -lint`、`codesign --verify --deep --strict --verbose=2`、`file` | exit 0，版本 0.3.0、arm64、签名有效 |

新增测试涵盖计算器优先级/溢出/恶意输入、数学和网址路由、中文搜索编码、功能开关、旧 JSON、快捷键冲突、真实 Carbon 双 ID 路由、注册/写盘回滚以及取消后的过期扫描结果。Lead 亲自复跑了这些 suite。

完整测试失败的是 `testMonitorCapturesAndCanIgnorePNG` 和 `testPasteControllerWritesTextAndImagePayloads`。直接运行原仓库未修改的基线测试二进制，也在同两个测试、相同六个断言失败，表现为命名 NSPasteboard 无法写入/读取；结合当前受限执行环境，判断是系统剪贴板服务访问限制。没有跳过、削弱或改写这些断言，完整失败日志保留。

日志位于副本 `.build/build-tests.log`、`.build/xctest.log`、`.build/baseline-pasteboard.log`、`.build/release-build.log`，七个定向 suite 日志也在 `.build/<suite>.log`。

## 独立审查

Expert 检查了双全局快捷键、配置事务、窗口生命周期和延迟粘贴的设计。Reviewer 检查生产代码及测试；提出的 URL/科学计数/函数错误/常量路由、鼠标取消、隐藏修饰键校验问题均已修正并增量复核。最终未发现已知的阻断代码问题。

Lead 额外扫描了事件监听、浮层入口、延迟任务和键盘注入的同类调用：窗口独立失焦只隐藏自身；AppModel 入口切换先隐藏另一个浮层；待粘贴任务有 generation 和目标前台 PID 校验；扫描回调有取消和 generation；普通输入/鼠标事件取消双击候选，事件本身继续交付。

## 尚未执行的真实桌面验收

当前沙箱不能完成系统剪贴板/辅助功能/键鼠/桌面切换端到端验证，不能把构建和单测通过当成这些功能已验证。

在普通终端或另一台测试 Mac 上：

1. 退出旧 TorranceKit，执行 `open dist/TorranceKit.app`。
2. 打开设置的“启动器”页，选择双击 Command / Control 预设并保存；已有用户的原快捷键不会自动改写。
3. 在“隐私与安全性 → 辅助功能”添加实际测试的 App 并授权，重新打开。
4. 双击 Command：验证输入框焦点、应用名称搜索、回车打开、1+2*3、2.0e-3、sqrt(-1)、pi*2、C++ 网页搜索、关闭与重新打开。
5. 复制两段文本及图片，双击 Control：验证历史、双栏预览、回车/双击复制粘贴；连续 ⌘C 两次不得唤起启动器。
6. 在两个入口间切换，验证只有一个浮层、中文输入法候选正常、Esc 关闭、点击外部和切换桌面时隐藏。
7. 将两组组合快捷键互换；占用第二组或模拟配置写盘失败，确认恢复原绑定并显示错误。

本地验证时发布仓库为只读，因此在独立副本开发并导出补丁；补丁在干净的基线源码中通过检查和应用验证，包含复用的原图标。后续通过 zhr 推送独立分支并提交 PR；正式发布前仍需完成上面的真实桌面验收。
