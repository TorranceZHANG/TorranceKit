import AppKit
import Combine

@MainActor
final class AppModel: ObservableObject {
  static let shared = AppModel()

  let history: ClipboardHistory
  let permission: AccessibilityPermission
  let configuration: AppConfiguration

  @Published var isCaptureEnabled: Bool {
    didSet {
      monitor.isPaused = !isCaptureEnabled
      UserDefaults.standard.set(isCaptureEnabled, forKey: Self.captureEnabledKey)
    }
  }

  private let monitor: ClipboardMonitor
  private let hotKey: GlobalHotKey
  private static let captureEnabledKey = "captureEnabled"
  private static let legacyBundleIdentifier = "com.torrance.PasteNook"
  private var hasStarted = false

  private lazy var panelController = PickerPanelController(
    history: history,
    permission: permission,
    configuration: configuration
  ) { [weak self] item, targetApplication in
    self?.select(item, targetApplication: targetApplication)
  }

  private lazy var settingsWindowController = SettingsWindowController(appModel: self)

  private init() {
    AppPaths.migrateLegacyDataIfNeeded()
    Self.migrateLegacyPreferencesIfNeeded()

    let configuration = AppConfiguration()
    let settings = configuration.settings
    let policy = settings.retentionPolicy
    let history = ClipboardHistory(
      maxItems: policy.maxItems,
      retentionDays: policy.retentionDays
    )
    let permission = AccessibilityPermission()
    self.configuration = configuration
    self.history = history
    self.permission = permission
    monitor = ClipboardMonitor(history: history)
    hotKey = GlobalHotKey(configuration: settings.hotKey)

    if UserDefaults.standard.object(forKey: Self.captureEnabledKey) == nil {
      isCaptureEnabled = true
    } else {
      isCaptureEnabled = UserDefaults.standard.bool(forKey: Self.captureEnabledKey)
    }
    monitor.apply(settings: settings)
    monitor.isPaused = !isCaptureEnabled

    hotKey.onPressed = { [weak self] in
      self?.togglePicker()
    }
  }

  private static func migrateLegacyPreferencesIfNeeded() {
    let defaults = UserDefaults.standard
    guard defaults.object(forKey: captureEnabledKey) == nil,
      let legacyDefaults = UserDefaults(suiteName: legacyBundleIdentifier),
      let captureEnabled = legacyDefaults.object(forKey: captureEnabledKey) as? Bool
    else {
      return
    }
    defaults.set(captureEnabled, forKey: captureEnabledKey)
  }

  func start() {
    guard !hasStarted else { return }
    hasStarted = true
    // Start tracking the current external application before making the Dock icon visible.
    // Otherwise the first Dock click would lose the application that should receive the paste.
    _ = panelController
    applyDockIconVisibility(configuration.settings.showDockIcon)
    monitor.start()
  }

  func stop() {
    monitor.stop()
  }

  func showPicker() {
    history.prune()
    panelController.show()
  }

  func togglePicker() {
    history.prune()
    panelController.toggle()
  }

  func confirmAndClearHistory() {
    let alert = NSAlert()
    alert.messageText = "清空剪贴板历史？"
    alert.informativeText = "这会永久删除保存在本机的全部文本记录。"
    alert.alertStyle = .warning
    alert.addButton(withTitle: "清空")
    alert.addButton(withTitle: "取消")
    guard alert.runModal() == .alertFirstButtonReturn else { return }
    history.clear()
  }

  func showSettings() {
    settingsWindowController.show()
  }

  func setDockIconVisible(_ isVisible: Bool) {
    guard configuration.settings.showDockIcon != isVisible else { return }
    var settings = configuration.settings
    settings.showDockIcon = isVisible
    do {
      try saveConfiguration(settings)
    } catch {
      showAlert(
        title: "无法更新程序坞设置",
        message: error.localizedDescription,
        style: .warning
      )
    }
  }

  func openConfiguration() {
    configuration.openInDefaultEditor()
  }

  func revealConfiguration() {
    configuration.revealInFinder()
  }

  @discardableResult
  func saveConfiguration(_ candidate: AppSettings) throws -> AppSettings {
    let newSettings = try candidate.validated()
    let oldSettings = configuration.settings
    try hotKey.update(configuration: newSettings.hotKey)

    do {
      try configuration.writeToDisk(newSettings)
    } catch {
      try? hotKey.update(configuration: oldSettings.hotKey)
      throw error
    }

    applyConfiguration(newSettings)
    return newSettings
  }

  @discardableResult
  func reloadConfigurationFromDisk() throws -> AppSettings {
    let newSettings = try configuration.readFromDisk()
    try hotKey.update(configuration: newSettings.hotKey)
    applyConfiguration(newSettings)
    return newSettings
  }

  func reloadConfiguration() {
    do {
      let newSettings = try reloadConfigurationFromDisk()
      let countText = newSettings.maxItems.map(String.init) ?? "不限"
      let daysText = newSettings.retentionDays.map { "\($0) 天" } ?? "不限"
      showAlert(
        title: "配置已生效",
        message: "呼出方式：\(newSettings.hotKey.displayText)；保留条数：\(countText)；保留时间：\(daysText)。"
      )
    } catch {
      showAlert(
        title: "配置未生效",
        message: error.localizedDescription,
        style: .warning
      )
    }
  }

  private func applyConfiguration(_ newSettings: AppSettings) {
    configuration.apply(newSettings)
    applyDockIconVisibility(newSettings.showDockIcon)
    history.applyRetentionPolicy(newSettings.retentionPolicy)
    monitor.apply(settings: newSettings)
  }

  private func applyDockIconVisibility(_ isVisible: Bool) {
    let policy: NSApplication.ActivationPolicy = isVisible ? .regular : .accessory
    guard NSApp.activationPolicy() != policy else { return }
    if !NSApp.setActivationPolicy(policy) {
      NSLog("TorranceKit: failed to change activation policy")
    }
  }

  private func select(
    _ item: ClipboardItem,
    targetApplication: NSRunningApplication?
  ) {
    history.markUsed(item)
    permission.refresh()
    monitor.ignoreNextChange(containing: item.text)
    PasteController.copyAndPaste(
      text: item.text,
      into: targetApplication,
      automatically: permission.isTrusted && configuration.settings.autoPaste,
      delayMilliseconds: configuration.settings.pasteDelayMilliseconds
    )
  }

  private func showAlert(
    title: String,
    message: String,
    style: NSAlert.Style = .informational
  ) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = style
    alert.addButton(withTitle: "好")
    alert.runModal()
  }
}
