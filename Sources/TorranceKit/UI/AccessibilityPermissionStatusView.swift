import AppKit
import SwiftUI

struct AccessibilityPermissionStatusView: View {
  @ObservedObject var permission: AccessibilityPermission

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label(
          permission.isTrusted ? "辅助功能已授权" : "当前运行的 TorranceKit 尚未获得辅助功能权限",
          systemImage: permission.isTrusted ? "checkmark.circle.fill" : "hand.raised"
        )
        .font(.caption)
        .foregroundStyle(permission.isTrusted ? .green : .orange)
        Spacer()
        Button("重新检查") { permission.refresh() }
        if !permission.isTrusted {
          Button("开启权限…") { permission.request() }
        }
      }
      if !permission.isTrusted {
        Text("如果系统中已勾选，可能是更新前的旧授权：请关闭再打开该开关；仍未生效时移除旧条目，重新添加当前应用。")
          .font(.caption).foregroundStyle(.secondary)
        Button("在 Finder 中显示当前应用") {
          NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
        }
        .font(.caption)
      }
    }
    .onAppear { permission.refresh() }
  }
}
