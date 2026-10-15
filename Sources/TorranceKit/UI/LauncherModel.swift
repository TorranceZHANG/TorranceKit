import Combine
import Foundation

@MainActor
final class LauncherModel: ObservableObject {
  @Published var query = "" { didSet { recompute() } }
  @Published private(set) var results: [LauncherResult] = []
  @Published var selectedIndex = 0
  @Published private(set) var isLoadingApplications = false
  @Published var presentationID = UUID()
  private var applications: [ApplicationEntry] = []
  private var settings: LauncherSettings = .default
  private var catalogTask: Task<Void, Never>?
  private var catalogGeneration = UUID()
  private let applicationLoader: @Sendable () async -> [ApplicationEntry]

  init(applicationLoader: @escaping @Sendable () async -> [ApplicationEntry] = {
    let worker = Task.detached(priority: .userInitiated) { ApplicationCatalog.load() }
    return await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
  }) {
    self.applicationLoader = applicationLoader
  }

  func show(settings: LauncherSettings) {
    self.settings = settings
    query = ""
    presentationID = UUID()
    refreshApplications()
  }

  func update(settings: LauncherSettings) {
    self.settings = settings
    recompute()
  }

  func hide() {
    catalogTask?.cancel()
    catalogTask = nil
    catalogGeneration = UUID()
    isLoadingApplications = false
  }

  func moveSelection(by offset: Int) {
    selectedIndex = max(0, min(results.count - 1, selectedIndex + offset))
  }

  var selectedResult: LauncherResult? {
    results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
  }

  private func recompute() {
    results = LauncherQueryEngine.results(query: query, applications: applications, settings: settings)
    selectedIndex = 0
  }

  private func refreshApplications() {
    hide()
    guard settings.searchesApplications else { return }
    isLoadingApplications = true
    let generation = UUID()
    catalogGeneration = generation
    catalogTask = Task { [weak self] in
      guard let loader = self?.applicationLoader else { return }
      let entries = await loader()
      guard !Task.isCancelled, let self, self.catalogGeneration == generation else { return }
      self.applications = entries
      self.isLoadingApplications = false
      self.recompute()
    }
  }
}
