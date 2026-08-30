import SwiftUI

struct PickerView: View {
  @ObservedObject var history: ClipboardHistory
  @ObservedObject var permission: AccessibilityPermission
  @ObservedObject var configuration: AppConfiguration
  @ObservedObject var state: PickerState

  let onSelect: (ClipboardItem) -> Void
  let onDelete: (ClipboardItem) -> Void
  let onClose: () -> Void

  @FocusState private var searchIsFocused: Bool

  private var filteredItems: [ClipboardItem] {
    state.filteredItems(from: history.items)
  }

  var body: some View {
    ZStack {
      VisualEffectView(material: .hudWindow)
      Color.black.opacity(0.18)

      VStack(spacing: 0) {
        header
        Divider().opacity(0.32)
        content
        Divider().opacity(0.32)
        footer
      }
    }
    .frame(width: 680, height: 500)
    .preferredColorScheme(.dark)
    .onAppear {
      DispatchQueue.main.async {
        searchIsFocused = true
      }
    }
    .onChange(of: state.query) { _ in
      state.selectedIndex = 0
    }
    .onChange(of: history.items.count) { newCount in
      state.normalizeSelection(itemCount: min(newCount, filteredItems.count))
    }
  }

  private var header: some View {
    VStack(spacing: 13) {
      HStack(spacing: 10) {
        Image(systemName: "doc.on.clipboard.fill")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.accentColor)
        Text("TorranceKit · 剪贴板")
          .font(.system(size: 16, weight: .semibold, design: .rounded))
        Spacer()
        ShortcutBadge(text: configuration.settings.hotKey.displayText)
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: 24, height: 24)
            .background(Color.white.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
        .help("关闭")
      }

      HStack(spacing: 10) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
        TextField("搜索剪贴板历史", text: $state.query)
          .textFieldStyle(.plain)
          .font(.system(size: 15))
          .focused($searchIsFocused)
        if !state.query.isEmpty {
          Button {
            state.query = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 13)
      .frame(height: 40)
      .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .stroke(Color.white.opacity(0.08), lineWidth: 1)
      }
    }
    .padding(.horizontal, 18)
    .padding(.top, 16)
    .padding(.bottom, 14)
  }

  @ViewBuilder
  private var content: some View {
    if filteredItems.isEmpty {
      emptyState
    } else {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 5) {
            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
              ClipboardRow(
                item: item,
                index: index,
                isSelected: index == state.selectedIndex,
                onSelect: { onSelect(item) },
                onDelete: { onDelete(item) },
                onHover: {
                  if $0 { state.selectedIndex = index }
                }
              )
              .id(item.id)
            }
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 9)
        }
        .onChange(of: state.selectedIndex) { newIndex in
          guard filteredItems.indices.contains(newIndex) else { return }
          withAnimation(.easeOut(duration: 0.12)) {
            proxy.scrollTo(filteredItems[newIndex].id, anchor: .center)
          }
        }
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Spacer()
      Image(systemName: state.query.isEmpty ? "clipboard" : "doc.text.magnifyingglass")
        .font(.system(size: 34, weight: .light))
        .foregroundStyle(.tertiary)
      Text(state.query.isEmpty ? "复制一段文字开始使用" : "没有匹配的内容")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.secondary)
      if state.query.isEmpty {
        Text("剪贴板模块会自动记录之后复制的文本")
          .font(.system(size: 12))
          .foregroundStyle(.tertiary)
      }
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var footer: some View {
    VStack(spacing: 0) {
      if configuration.settings.autoPaste && !permission.isTrusted {
        HStack(spacing: 8) {
          Image(systemName: "hand.raised.fill")
            .foregroundStyle(.orange)
          Text("开启辅助功能权限后，选择内容即可自动粘贴")
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
          Spacer()
          Button("开启") {
            permission.request()
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        Divider().opacity(0.25)
      }

      HStack(spacing: 15) {
        KeyHint(keys: "↑↓", action: "选择")
        KeyHint(
          keys: "↩",
          action: permission.isTrusted && configuration.settings.autoPaste
            ? "粘贴" : "复制"
        )
        KeyHint(keys: "⌘1…9", action: "快选")
        Spacer()
        Text("esc 关闭")
          .font(.system(size: 11))
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 16)
      .frame(height: 38)
    }
  }
}

private struct ClipboardRow: View {
  let item: ClipboardItem
  let index: Int
  let isSelected: Bool
  let onSelect: () -> Void
  let onDelete: () -> Void
  let onHover: (Bool) -> Void

  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 7)
          .fill(isSelected ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.055))
        Text(index < 9 ? "⌘\(index + 1)" : "\(index + 1)")
          .font(.system(size: 10, weight: .semibold, design: .rounded))
          .foregroundStyle(isSelected ? Color.accentColor : .secondary)
      }
      .frame(width: 38, height: 32)

      VStack(alignment: .leading, spacing: 5) {
        Text(item.text)
          .font(.system(size: 13.5))
          .foregroundStyle(.primary)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 7) {
          Text(relativeTime(item.createdAt))
          Text("·")
          Text("\(item.text.count) 字符")
          if item.copyCount > 1 {
            Text("·")
            Text("复制 \(item.copyCount) 次")
          }
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.tertiary)
      }

      Button(action: onDelete) {
        Image(systemName: "trash")
          .font(.system(size: 11, weight: .medium))
          .frame(width: 28, height: 28)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
      .help("删除这条记录")
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      isSelected ? Color.white.opacity(0.095) : Color.clear,
      in: RoundedRectangle(cornerRadius: 10)
    )
    .contentShape(Rectangle())
    .onTapGesture(perform: onSelect)
    .onHover(perform: onHover)
  }

  private func relativeTime(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}

private struct ShortcutBadge: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: 11, weight: .semibold, design: .rounded))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
      .overlay {
        RoundedRectangle(cornerRadius: 6)
          .stroke(Color.white.opacity(0.08), lineWidth: 1)
      }
  }
}

private struct KeyHint: View {
  let keys: String
  let action: String

  var body: some View {
    HStack(spacing: 4) {
      Text(keys)
        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
        .foregroundStyle(.secondary)
      Text(action)
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
    }
  }
}
