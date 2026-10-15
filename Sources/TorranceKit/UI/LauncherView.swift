import SwiftUI

struct LauncherView: View {
  @ObservedObject var model: LauncherModel
  @ObservedObject var configuration: AppConfiguration
  @ObservedObject var permission: AccessibilityPermission
  let onExecute: (LauncherResult) -> Void
  let onClose: () -> Void
  let onSettings: () -> Void
  @FocusState private var inputFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Label("TorranceKit", systemImage: "square.grid.2x2.fill")
          .font(.system(size: 15, weight: .semibold))
        Spacer()
        Text(configuration.settings.launcher.hotKey.displayText)
          .font(.caption).foregroundStyle(.secondary)
        Button(action: onClose) { Image(systemName: "xmark.circle.fill") }
          .buttonStyle(.plain).help("关闭")
      }
      .padding(.horizontal, 22).padding(.top, 18)
      HStack(spacing: 14) {
        Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(.secondary)
        TextField("搜索应用、输入算式或网址…", text: $model.query)
          .font(.system(size: 24, weight: .medium)).textFieldStyle(.plain)
          .focused($inputFocused)
          .accessibilityLabel("搜索应用、计算或网址")
        if model.isLoadingApplications { ProgressView().controlSize(.small) }
      }
      .padding(22)
      Divider()
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 4) {
            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
              Button { onExecute(result) } label: {
                HStack(spacing: 14) {
                  Image(systemName: result.symbol)
                    .font(.system(size: 25, weight: .light)).foregroundStyle(Color.accentColor)
                    .frame(width: 40)
                  VStack(alignment: .leading, spacing: 5) {
                    Text(result.title).font(.system(size: 16, weight: .medium)).lineLimit(1)
                    Text(result.subtitle).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                  }
                  Spacer()
                  if index == model.selectedIndex { Image(systemName: "return").foregroundStyle(.secondary) }
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .background(index == model.selectedIndex ? Color.accentColor.opacity(0.15) : .clear,
                            in: RoundedRectangle(cornerRadius: 10))
              }
              .buttonStyle(.plain).disabled(result.action == .none).id(result.id)
            }
            if model.results.isEmpty {
              Text("没有匹配结果，试试应用名称、1+2 或 web 关键词")
                .foregroundStyle(.secondary).padding(30)
            }
            if model.query.isEmpty {
              VStack(alignment: .leading, spacing: 10) {
                Text("应用名称 → 打开应用    1+2*3 → 计算并复制")
                Text("web 关键词 → 网页搜索    example.com → 打开网址")
                Text("clipboard → 剪贴板    settings → 设置")
              }
              .font(.caption).foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            }
          }.padding(10)
        }
        .onChange(of: model.selectedIndex) { index in
          guard model.results.indices.contains(index) else { return }
          proxy.scrollTo(model.results[index].id)
        }
      }
      Spacer(minLength: 0)
      Divider()
      if !permission.isTrusted {
        HStack {
          Text("双击快捷键需要辅助功能权限")
            .font(.caption).foregroundStyle(.orange)
          Spacer()
          Button("开启权限…") { permission.request() }.controlSize(.small)
        }.padding(.horizontal, 20).padding(.vertical, 8)
      }
      HStack {
        Text("↑↓ 选择    ↩ 执行    esc 关闭").font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button(action: onSettings) { Label("设置", systemImage: "gearshape") }
          .buttonStyle(.plain).font(.caption)
      }.padding(.horizontal, 20).padding(.vertical, 12)
    }
    .frame(width: 760, height: 540)
    .background(VisualEffectView(material: .hudWindow))
    .clipShape(RoundedRectangle(cornerRadius: 18))
    .preferredColorScheme(.dark)
    .onAppear { inputFocused = true }
    .onChange(of: model.presentationID) { _ in
      inputFocused = false
      DispatchQueue.main.async { inputFocused = true }
    }
  }
}
