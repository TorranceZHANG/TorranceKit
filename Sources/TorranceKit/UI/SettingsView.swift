import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsDraft: Equatable {
  var triggerMode: HotKeyTriggerMode
  var hotKeyKey: String
  var usesCommand: Bool
  var usesControl: Bool
  var usesOption: Bool
  var usesShift: Bool
  var doubleTapModifier: String
  var doubleTapIntervalMilliseconds: Int

  var limitsItemCount: Bool
  var maxItems: Int
  var limitsRetentionTime: Bool
  var retentionDays: Int

  var autoPaste: Bool
  var pasteDelayMilliseconds: Int
  var pollIntervalMilliseconds: Int
  var maxTextBytes: Int
  var excludedBundleIdentifiersText: String

  init(settings: AppSettings) {
    triggerMode = settings.hotKey.mode
    hotKeyKey = settings.hotKey.key
    usesCommand = settings.hotKey.modifiers.contains("command")
    usesControl = settings.hotKey.modifiers.contains("control")
    usesOption = settings.hotKey.modifiers.contains("option")
    usesShift = settings.hotKey.modifiers.contains("shift")
    doubleTapModifier = settings.hotKey.doubleTapModifier
    doubleTapIntervalMilliseconds = settings.hotKey.doubleTapIntervalMilliseconds
    limitsItemCount = settings.maxItems != nil
    maxItems = settings.maxItems ?? AppSettings.default.maxItems ?? 1_000
    limitsRetentionTime = settings.retentionDays != nil
    retentionDays = settings.retentionDays ?? AppSettings.default.retentionDays ?? 30
    autoPaste = settings.autoPaste
    pasteDelayMilliseconds = settings.pasteDelayMilliseconds
    pollIntervalMilliseconds = settings.pollIntervalMilliseconds
    maxTextBytes = settings.maxTextBytes
    excludedBundleIdentifiersText = settings.excludedBundleIdentifiers.joined(separator: "\n")
  }

  func makeSettings() throws -> AppSettings {
    var modifiers: [String] = []
    if usesControl { modifiers.append("control") }
    if usesOption { modifiers.append("option") }
    if usesShift { modifiers.append("shift") }
    if usesCommand { modifiers.append("command") }

    let excludedBundleIdentifiers =
      excludedBundleIdentifiersText
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    return try AppSettings(
      maxItems: limitsItemCount ? maxItems : nil,
      retentionDays: limitsRetentionTime ? retentionDays : nil,
      hotKey: HotKeyConfiguration(
        mode: triggerMode,
        key: hotKeyKey,
        modifiers: modifiers,
        doubleTapModifier: doubleTapModifier,
        doubleTapIntervalMilliseconds: doubleTapIntervalMilliseconds
      ),
      maxTextBytes: maxTextBytes,
      pollIntervalMilliseconds: pollIntervalMilliseconds,
      autoPaste: autoPaste,
      pasteDelayMilliseconds: pasteDelayMilliseconds,
      excludedBundleIdentifiers: excludedBundleIdentifiers
    ).validated()
  }
}

@MainActor
final class SettingsViewModel: ObservableObject {
  struct Status {
    enum Kind {
      case success
      case information
      case error
    }

    let kind: Kind
    let message: String
  }

  typealias SaveHandler = (AppSettings) throws -> AppSettings
  typealias ReloadHandler = () throws -> AppSettings

  @Published var draft: SettingsDraft
  @Published private(set) var status: Status?

  private let saveHandler: SaveHandler
  private let reloadHandler: ReloadHandler
  private let openJSONHandler: () -> Void
  private let revealJSONHandler: () -> Void

  init(
    settings: AppSettings,
    saveHandler: @escaping SaveHandler,
    reloadHandler: @escaping ReloadHandler,
    openJSONHandler: @escaping () -> Void,
    revealJSONHandler: @escaping () -> Void
  ) {
    draft = SettingsDraft(settings: settings)
    self.saveHandler = saveHandler
    self.reloadHandler = reloadHandler
    self.openJSONHandler = openJSONHandler
    self.revealJSONHandler = revealJSONHandler
  }

  func load(_ settings: AppSettings) {
    draft = SettingsDraft(settings: settings)
    status = nil
  }

  func restoreDefaults() {
    draft = SettingsDraft(settings: .default)
    status = Status(kind: .information, message: "已载入默认值，点击“保存并应用”后生效。")
  }

  func save() {
    do {
      let settings = try draft.makeSettings()
      let savedSettings = try saveHandler(settings)
      draft = SettingsDraft(settings: savedSettings)
      status = Status(
        kind: .success,
        message: "设置已保存，呼出方式 \(savedSettings.hotKey.displayText) 已生效。"
      )
    } catch {
      status = Status(kind: .error, message: error.localizedDescription)
    }
  }

  func reloadJSON() {
    do {
      let settings = try reloadHandler()
      draft = SettingsDraft(settings: settings)
      status = Status(kind: .success, message: "已从 JSON 配置文件重新载入并应用。")
    } catch {
      status = Status(kind: .error, message: error.localizedDescription)
    }
  }

  func openJSON() {
    openJSONHandler()
  }

  func revealJSON() {
    revealJSONHandler()
  }

  func chooseExcludedApplications() {
    let panel = NSOpenPanel()
    panel.title = "选择不记录剪贴板的应用"
    panel.prompt = "添加"
    panel.allowedContentTypes = [.applicationBundle]
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.canChooseFiles = true

    guard panel.runModal() == .OK else { return }
    let selectedIdentifiers = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
    guard !selectedIdentifiers.isEmpty else {
      status = Status(kind: .error, message: "无法读取所选应用的 Bundle ID。")
      return
    }

    let existingIdentifiers = draft.excludedBundleIdentifiersText
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    draft.excludedBundleIdentifiersText = Array(
      Set(existingIdentifiers + selectedIdentifiers)
    ).sorted().joined(separator: "\n")
    status = Status(kind: .information, message: "已添加所选应用，点击“保存并应用”后生效。")
  }
}

struct SettingsView: View {
  @ObservedObject var model: SettingsViewModel
  @ObservedObject var permission: AccessibilityPermission

  var body: some View {
    VStack(spacing: 0) {
      TabView {
        ClipboardSettingsView(model: model, permission: permission)
          .tabItem {
            Label("剪贴板", systemImage: "doc.on.clipboard")
          }

        AdvancedSettingsView(model: model)
          .tabItem {
            Label("高级", systemImage: "gearshape.2")
          }
      }
      .padding(.top, 8)

      Divider()

      HStack(spacing: 12) {
        if let status = model.status {
          Label(status.message, systemImage: statusIcon(status.kind))
            .font(.caption)
            .foregroundStyle(statusColor(status.kind))
            .lineLimit(2)
        }

        Spacer()

        Button("恢复默认值") {
          model.restoreDefaults()
        }

        Button("保存并应用") {
          model.save()
        }
        .keyboardShortcut(.defaultAction)
      }
      .padding(16)
    }
    .frame(minWidth: 660, idealWidth: 720, minHeight: 600, idealHeight: 680)
  }

  private func statusIcon(_ kind: SettingsViewModel.Status.Kind) -> String {
    switch kind {
    case .success: return "checkmark.circle.fill"
    case .information: return "info.circle.fill"
    case .error: return "exclamationmark.triangle.fill"
    }
  }

  private func statusColor(_ kind: SettingsViewModel.Status.Kind) -> Color {
    switch kind {
    case .success: return .green
    case .information: return .secondary
    case .error: return .red
    }
  }
}

private struct ClipboardSettingsView: View {
  @ObservedObject var model: SettingsViewModel
  @ObservedObject var permission: AccessibilityPermission

  private static let hotKeyChoices: [String] = {
    let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map { String($0) }
    let numbers = Array(0...9).map { String($0) }
    return letters + numbers + ["SPACE", "RETURN", "TAB"]
  }()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        GroupBox {
          VStack(alignment: .leading, spacing: 12) {
            Picker("触发方式", selection: $model.draft.triggerMode) {
              Text("组合快捷键").tag(HotKeyTriggerMode.keyCombination)
              Text("双击修饰键").tag(HotKeyTriggerMode.doubleTapModifier)
            }
            .pickerStyle(.segmented)

            Divider()

            if model.draft.triggerMode == .keyCombination {
              HStack {
                Text("主按键")
                Spacer()
                Picker("", selection: $model.draft.hotKeyKey) {
                  ForEach(Self.hotKeyChoices, id: \.self) { key in
                    Text(displayName(for: key)).tag(key)
                  }
                }
                .labelsHidden()
                .frame(width: 150)
              }

              Divider()

              Text("修饰键（至少选一个）")
                .font(.caption)
                .foregroundStyle(.secondary)

              HStack(spacing: 18) {
                Toggle("⌘ Command", isOn: $model.draft.usesCommand)
                Toggle("⌥ Option", isOn: $model.draft.usesOption)
                Toggle("⌃ Control", isOn: $model.draft.usesControl)
                Toggle("⇧ Shift", isOn: $model.draft.usesShift)
              }
              .toggleStyle(.checkbox)
            } else {
              HStack {
                Text("双击按键")
                Spacer()
                Picker("", selection: $model.draft.doubleTapModifier) {
                  Text("⌃ Control").tag("control")
                  Text("⌥ Option").tag("option")
                  Text("⌘ Command").tag("command")
                  Text("⇧ Shift").tag("shift")
                }
                .labelsHidden()
                .frame(width: 150)
              }

              HStack {
                Text("最长双击间隔")
                Spacer()
                Picker("", selection: $model.draft.doubleTapIntervalMilliseconds) {
                  ForEach(doubleTapIntervalChoices, id: \.self) { interval in
                    Text("\(interval) 毫秒").tag(interval)
                  }
                }
                .labelsHidden()
                .frame(width: 150)
              }

              Text("只有独立完成两次快速按下和松开才会触发；长按或同时按下其他修饰键不会触发。")
                .font(.caption)
                .foregroundStyle(.secondary)

              if !permission.isTrusted {
                HStack {
                  Label("双击修饰键需要辅助功能权限。", systemImage: "lock.trianglebadge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.orange)
                  Spacer()
                  Button("开启权限…") {
                    permission.request()
                  }
                }
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
          Label("呼出方式", systemImage: "keyboard")
            .font(.headline)
        }

        GroupBox {
          VStack(alignment: .leading, spacing: 14) {
            HStack {
              Toggle("限制历史条数", isOn: $model.draft.limitsItemCount)
              Spacer()
              NumberField(value: $model.draft.maxItems, suffix: "条")
                .disabled(!model.draft.limitsItemCount)
            }

            HStack {
              Toggle("限制保留时间", isOn: $model.draft.limitsRetentionTime)
              Spacer()
              NumberField(value: $model.draft.retentionDays, suffix: "天")
                .disabled(!model.draft.limitsRetentionTime)
            }

            Text("两项都开启时同时生效；关闭某项即表示该维度不限制。")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
          Label("保留策略", systemImage: "archivebox")
            .font(.headline)
        }

        GroupBox {
          VStack(alignment: .leading, spacing: 14) {
            Toggle("选择历史后自动粘贴", isOn: $model.draft.autoPaste)

            HStack {
              Text("恢复原应用后的粘贴延迟")
              Spacer()
              NumberField(value: $model.draft.pasteDelayMilliseconds, suffix: "毫秒")
            }
            .disabled(!model.draft.autoPaste)

            HStack {
              Text("剪贴板检查间隔")
              Spacer()
              NumberField(value: $model.draft.pollIntervalMilliseconds, suffix: "毫秒")
            }

            HStack {
              Text("单条文本上限")
              Spacer()
              Picker("", selection: $model.draft.maxTextBytes) {
                ForEach(textSizeChoices, id: \.self) { byteCount in
                  Text(byteCountDescription(byteCount)).tag(byteCount)
                }
              }
              .labelsHidden()
              .frame(width: 150)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
          Label("记录与粘贴", systemImage: "slider.horizontal.3")
            .font(.headline)
        }

        GroupBox {
          VStack(alignment: .leading, spacing: 8) {
            Text("当以下应用位于前台时，不记录新的剪贴板内容。每行填写一个 Bundle ID。")
              .font(.caption)
              .foregroundStyle(.secondary)

            TextEditor(text: $model.draft.excludedBundleIdentifiersText)
              .font(.system(.body, design: .monospaced))
              .frame(minHeight: 84)
              .padding(4)
              .overlay {
                RoundedRectangle(cornerRadius: 6)
                  .stroke(Color.secondary.opacity(0.3))
              }

            Text("例如：com.example.SecretApp")
              .font(.caption)
              .foregroundStyle(.secondary)

            Button("选择应用…") {
              model.chooseExcludedApplications()
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
          Label("排除应用", systemImage: "eye.slash")
            .font(.headline)
        }
      }
      .padding(20)
    }
  }

  private func displayName(for key: String) -> String {
    switch key {
    case "SPACE": return "空格"
    case "RETURN": return "回车"
    case "TAB": return "Tab"
    default: return key
    }
  }

  private var textSizeChoices: [Int] {
    let presets = [65_536, 262_144, 1_048_576, 5_242_880, 10_485_760]
    guard !presets.contains(model.draft.maxTextBytes) else { return presets }
    return (presets + [model.draft.maxTextBytes]).sorted()
  }

  private var doubleTapIntervalChoices: [Int] {
    let presets = [250, 300, 400, 500, 600, 800]
    guard !presets.contains(model.draft.doubleTapIntervalMilliseconds) else { return presets }
    return (presets + [model.draft.doubleTapIntervalMilliseconds]).sorted()
  }

  private func byteCountDescription(_ byteCount: Int) -> String {
    if byteCount.isMultiple(of: 1_048_576) {
      return "\(byteCount / 1_048_576) MB"
    }
    if byteCount.isMultiple(of: 1_024) {
      return "\(byteCount / 1_024) KB"
    }
    return "\(byteCount) 字节（自定义）"
  }
}

private struct AdvancedSettingsView: View {
  @ObservedObject var model: SettingsViewModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        GroupBox {
          VStack(alignment: .leading, spacing: 12) {
            Text("可视化设置与 JSON 使用同一份配置。通常不需要直接编辑文件；高级用户可用它做版本管理或批量修改。")
              .foregroundStyle(.secondary)

            Text(AppConfiguration.defaultURL.path)
              .font(.system(.caption, design: .monospaced))
              .textSelection(.enabled)
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))

            HStack {
              Button("在 Finder 中显示") {
                model.revealJSON()
              }

              Button("使用默认编辑器打开") {
                model.openJSON()
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
          Label("JSON 配置文件", systemImage: "curlybraces")
            .font(.headline)
        }

        GroupBox {
          VStack(alignment: .leading, spacing: 12) {
            Text("在外部编辑器中保存 JSON 后，点击下方按钮。TorranceKit 会先校验所有字段并尝试注册新呼出方式；失败时当前运行配置保持不变。")
              .foregroundStyle(.secondary)

            Button("从 JSON 重新载入并应用") {
              model.reloadJSON()
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
          Label("手工配置", systemImage: "arrow.clockwise")
            .font(.headline)
        }

        GroupBox {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("TorranceKit")
                .font(.headline)
              Text(AppVersion.displayText)
                .foregroundStyle(.secondary)
            }
            Spacer()
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
          Label("关于", systemImage: "info.circle")
            .font(.headline)
        }
      }
      .padding(20)
    }
  }
}

private struct NumberField: View {
  @Binding var value: Int
  let suffix: String
  var width: CGFloat = 90

  var body: some View {
    HStack(spacing: 6) {
      TextField("", value: $value, format: .number)
        .multilineTextAlignment(.trailing)
        .frame(width: width)
      Text(suffix)
        .foregroundStyle(.secondary)
        .frame(minWidth: 28, alignment: .leading)
    }
  }
}
