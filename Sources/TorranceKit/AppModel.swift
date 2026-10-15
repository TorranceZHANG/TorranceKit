import AppKit
import Combine

@MainActor
final class AppModel: ObservableObject {
  static let shared = AppModel()

  let history: ClipboardHistory
  let permission: AccessibilityPermission
  let configuration: AppConfiguration
  @Published private(set) var shortcutError: String?

  @Published var isCaptureEnabled: Bool {
    didSet {
      monitor.isPaused = !isCaptureEnabled
      UserDefaults.standard.set(isCaptureEnabled, forKey: Self.captureEnabledKey)
    }
  }

  private let monitor: ClipboardMonitor
  private let hotKey: GlobalHotKey
  private let launcherHotKey: GlobalHotKey
  private var permissionSubscription: AnyCancellable?
  private static let captureEnabledKey = "captureEnabled"
  private static let legacyBundleIdentifier = "com.torrance.PasteNook"
  private var hasStarted = false

  private lazy var panelController = PickerPanelController(
    history: history,
    permission: permission,
    configuration: configuration,
    onInput: { [weak self] in self?.cancelDoubleTapSequences() },
    onOpenSettings: { [weak self] in
      self?.showSettings()
    }
  ) { [weak self] item, targetApplication in
    self?.select(item, targetApplication: targetApplication)
  }

  private lazy var settingsWindowController = SettingsWindowController(appModel: self)
  private lazy var launcherController = LauncherPanelController(
    configuration: configuration, permission: permission,
    onInput: { [weak self] in self?.cancelDoubleTapSequences() },
    onSettings: { [weak self] in self?.showSettings() },
    onExecute: { [weak self] action in self?.execute(action) }
  )

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
    hotKey = GlobalHotKey(identifier: 1, configuration: settings.hotKey)
    launcherHotKey = GlobalHotKey(identifier: 2, configuration: settings.launcher.hotKey)

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
    launcherHotKey.onPressed = { [weak self] in self?.toggleLauncher() }
    if !hotKey.isRegistered || !launcherHotKey.isRegistered {
      shortcutError = "部分快捷键注册失败，请在设置中调整呼出方式。"
    }
    permissionSubscription = permission.$isTrusted.removeDuplicates().dropFirst().sink { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        do { try self.replaceHotKeys(with: self.configuration.settings) }
        catch { self.shortcutError = error.localizedDescription }
      }
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
    // Capture the current external application before the launch picker activates TorranceKit.
    _ = panelController
    monitor.start()
  }

  func stop() {
    monitor.stop()
    hotKey.unregisterTrigger()
    launcherHotKey.unregisterTrigger()
    panelController.hide()
    launcherController.hide()
    PasteController.cancelPendingPaste()
  }

  func showPicker() {
    PasteController.cancelPendingPaste()
    launcherController.hide()
    history.prune()
    panelController.show()
  }

  func togglePicker() {
    panelController.isVisible ? panelController.hide() : showPicker()
  }

  func showLauncher() {
    PasteController.cancelPendingPaste()
    panelController.hide()
    launcherController.show()
  }

  func toggleLauncher() {
    launcherController.isVisible ? launcherController.hide() : showLauncher()
  }

  func confirmAndClearHistory() {
    let alert = NSAlert()
    alert.messageText = "清空剪贴板历史？"
    alert.informativeText = "这会永久删除保存在本机的全部文本和图片记录。"
    alert.alertStyle = .warning
    alert.addButton(withTitle: "清空")
    alert.addButton(withTitle: "取消")
    guard alert.runModal() == .alertFirstButtonReturn else { return }
    history.clear()
  }

  func showSettings() {
    PasteController.cancelPendingPaste()
    panelController.hide()
    launcherController.hide()
    settingsWindowController.show()
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
    try replaceHotKeys(with: newSettings, previous: oldSettings) {
      try configuration.writeToDisk(newSettings)
    }

    applyConfiguration(newSettings)
    return newSettings
  }

  @discardableResult
  func reloadConfigurationFromDisk() throws -> AppSettings {
    let newSettings = try configuration.readFromDisk()
    try replaceHotKeys(with: newSettings)
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
    history.applyRetentionPolicy(newSettings.retentionPolicy)
    monitor.apply(settings: newSettings)
    launcherController.model.update(settings: newSettings.launcher)
  }

  private func replaceHotKeys(
    with candidate: AppSettings, previous: AppSettings? = nil, persist: () throws -> Void = {}
  ) throws {
    do {
      try HotKeyTransaction.apply(
        previous: previous ?? configuration.settings, candidate: candidate,
        unregister: {
          self.hotKey.unregisterTrigger()
          self.launcherHotKey.unregisterTrigger()
        },
        register: { settings in
          try self.hotKey.registerTrigger(configuration: settings.hotKey)
          try self.launcherHotKey.registerTrigger(configuration: settings.launcher.hotKey)
        }, persist: persist
      )
      shortcutError = nil
    } catch {
      if !hotKey.isRegistered || !launcherHotKey.isRegistered {
        shortcutError = error.localizedDescription
      }
      throw error
    }
  }

  private func execute(_ action: LauncherAction) {
    switch action {
    case .clipboard: showPicker()
    case .settings: showSettings()
    case .copy(let text):
      monitor.ignoreNextChange(containing: .text(text))
      if !PasteController.write(.text(text), to: .general) {
        showAlert(title: "复制失败", message: "无法写入系统剪贴板，请重试。", style: .warning)
      }
    case .openApplication(let url), .openURL(let url):
      if !NSWorkspace.shared.open(url) {
        showAlert(title: "无法打开", message: "请检查应用或网址是否可用。", style: .warning)
      }
    case .none: break
    }
  }

  private func cancelDoubleTapSequences() {
    hotKey.cancelDoubleTapSequence()
    launcherHotKey.cancelDoubleTapSequence()
  }

  private func select(
    _ item: ClipboardItem,
    targetApplication: NSRunningApplication?
  ) {
    guard let payload = history.payload(for: item) else {
      history.remove(item)
      showAlert(
        title: "无法读取剪贴板内容",
        message: "对应的本地图片文件可能已被删除，这条历史记录已清理。",
        style: .warning
      )
      return
    }
    history.markUsed(item)
    permission.refresh()
    monitor.ignoreNextChange(containing: payload)
    PasteController.copyAndPaste(
      payload: payload,
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
