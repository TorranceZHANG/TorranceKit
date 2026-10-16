import SwiftUI

struct LauncherSettingsView: View {
  @ObservedObject var model: SettingsViewModel
  @ObservedObject var permission: AccessibilityPermission

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        GroupBox {
          VStack(alignment: .leading, spacing: 12) {
            Text("双击 Command 打开搜索和计算器，双击 Control 打开剪贴板。")
            Button("使用双击 Command / Control 预设") { model.draft.useDoubleTapPreset() }
            Text("只修改两个入口；点击下方“保存并应用”生效。旧版配置会保留原剪贴板快捷键。")
              .font(.caption).foregroundStyle(.secondary)
            AccessibilityPermissionStatusView(permission: permission)
          }.frame(maxWidth: .infinity, alignment: .leading)
        } label: { Label("统一入口", systemImage: "square.grid.2x2").font(.headline) }

        GroupBox {
          HotKeySettingsEditor(configuration: $model.draft.launcher.hotKey)
        } label: { Label("搜索与计算的呼出方式", systemImage: "keyboard").font(.headline) }

        GroupBox {
          VStack(alignment: .leading, spacing: 14) {
            Toggle("搜索并打开本机应用", isOn: $model.draft.launcher.searchesApplications)
            Toggle("启用计算器（回车复制结果）", isOn: $model.draft.launcher.calculatorEnabled)
            Toggle("显示网页搜索", isOn: $model.draft.launcher.webSearchEnabled)
            Picker("默认搜索引擎", selection: $model.draft.launcher.searchEngine) {
              ForEach(WebSearchEngine.allCases, id: \.self) { engine in
                Text(engine.displayName).tag(engine)
              }
            }.disabled(!model.draft.launcher.webSearchEnabled)
            Stepper("最多显示 \(model.draft.launcher.maxResults) 个结果",
                    value: $model.draft.launcher.maxResults, in: 3...20)
            Text("输入期间在本机处理。只有执行网页搜索或打开网址时才交给浏览器。")
              .font(.caption).foregroundStyle(.secondary)
          }.frame(maxWidth: .infinity, alignment: .leading)
        } label: { Label("功能", systemImage: "slider.horizontal.3").font(.headline) }
      }.padding(20)
    }
  }
}

private struct HotKeySettingsEditor: View {
  @Binding var configuration: HotKeyConfiguration
  private let modifierNames = ["command", "control", "option", "shift"]
  private let names = ["command": "⌘ Command", "control": "⌃ Control", "option": "⌥ Option", "shift": "⇧ Shift"]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Picker("触发方式", selection: $configuration.mode) {
        Text("双击修饰键").tag(HotKeyTriggerMode.doubleTapModifier)
        Text("组合快捷键").tag(HotKeyTriggerMode.keyCombination)
      }.pickerStyle(.segmented)
      if configuration.mode == .doubleTapModifier {
        Picker("双击按键", selection: $configuration.doubleTapModifier) {
          ForEach(modifierNames, id: \.self) { name in Text(names[name] ?? name).tag(name) }
        }
        Stepper("双击间隔 \(configuration.doubleTapIntervalMilliseconds) 毫秒",
                value: $configuration.doubleTapIntervalMilliseconds, in: 200...800, step: 50)
        Text("两次独立按下并松开才触发；中间按字母、鼠标或其他修饰键会取消。")
          .font(.caption).foregroundStyle(.secondary)
      } else {
        Picker("主按键", selection: $configuration.key) {
          ForEach(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789").map(String.init) + ["SPACE", "RETURN", "TAB"], id: \.self) { key in
            Text(key == "SPACE" ? "空格" : key).tag(key)
          }
        }
        HStack {
          ForEach(modifierNames, id: \.self) { name in
            Toggle(names[name] ?? name, isOn: Binding(
              get: { configuration.modifiers.contains(name) },
              set: { enabled in
                configuration.modifiers.removeAll { $0 == name }
                if enabled { configuration.modifiers.append(name) }
              }
            ))
          }
        }.toggleStyle(.checkbox)
        Text("例如 Option + 空格；组合快捷键无需辅助功能权限。")
          .font(.caption).foregroundStyle(.secondary)
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
}
