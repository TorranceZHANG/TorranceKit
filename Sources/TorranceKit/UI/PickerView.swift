import AppKit
import SwiftUI

struct PickerView: View {
  @ObservedObject var history: ClipboardHistory
  @ObservedObject var permission: AccessibilityPermission
  @ObservedObject var configuration: AppConfiguration
  @ObservedObject var state: PickerState

  let onSelect: (ClipboardItem) -> Void
  let onDelete: (ClipboardItem) -> Void
  let onOpenSettings: () -> Void
  let onClose: () -> Void

  @FocusState private var searchIsFocused: Bool

  private var filteredItems: [ClipboardItem] {
    state.filteredItems(from: history.items)
  }

  private var selectedItem: ClipboardItem? {
    guard filteredItems.indices.contains(state.selectedIndex) else { return nil }
    return filteredItems[state.selectedIndex]
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
    .frame(width: 1_000, height: 620)
    .preferredColorScheme(.dark)
    .onAppear {
      DispatchQueue.main.async {
        searchIsFocused = true
      }
    }
    .onChange(of: state.query) { _ in
      state.selectFirstAndRequestScroll()
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
        TextField("搜索文本或图片", text: $state.query)
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

  private var content: some View {
    HStack(spacing: 0) {
      historyList
        .frame(width: 410)

      Divider().opacity(0.32)

      preview
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  @ViewBuilder
  private var historyList: some View {
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
                onSelect: {
                  state.select(index: index, itemCount: filteredItems.count)
                },
                onActivate: { onSelect(item) },
                onDelete: { onDelete(item) }
              )
              .id(item.id)
            }
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 9)
        }
        .onChange(of: state.selectionScrollRequest) { _ in
          let newIndex = state.selectedIndex
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
      Text(state.query.isEmpty ? "复制文本或图片开始使用" : "没有匹配的内容")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.secondary)
      if state.query.isEmpty {
        Text("剪贴板模块会自动记录之后复制的内容")
          .font(.system(size: 12))
          .foregroundStyle(.tertiary)
      }
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var preview: some View {
    if let selectedItem {
      VStack(spacing: 0) {
        HStack(spacing: 10) {
          Image(systemName: selectedItem.kind == .text ? "doc.text" : "photo")
            .foregroundStyle(Color.accentColor)
          VStack(alignment: .leading, spacing: 3) {
            Text(selectedItem.kind == .text ? "文本预览" : "图片预览")
              .font(.system(size: 13, weight: .semibold))
            Text(previewMetadata(for: selectedItem))
              .font(.system(size: 10.5))
              .foregroundStyle(.tertiary)
          }
          Spacer()
        }
        .padding(.horizontal, 18)
        .frame(height: 54)

        Divider().opacity(0.25)

        switch selectedItem.kind {
        case .text:
          ClipboardTextPreview(item: selectedItem)
        case .image:
          ClipboardImagePreview(item: selectedItem, history: history)
        }
      }
    } else {
      VStack(spacing: 10) {
        Image(systemName: "rectangle.on.rectangle.slash")
          .font(.system(size: 30, weight: .light))
          .foregroundStyle(.tertiary)
        Text("选择左侧条目查看预览")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
      }
    }
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
          keys: "↩ / 双击",
          action: permission.isTrusted && configuration.settings.autoPaste
            ? "粘贴" : "复制"
        )
        KeyHint(keys: "⌘1…9", action: "快选")
        Spacer()
        Button(action: onOpenSettings) {
          Label("设置", systemImage: "gearshape")
            .font(.system(size: 11))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help("打开设置（⌘,）")
        Text("esc 关闭")
          .font(.system(size: 11))
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 16)
      .frame(height: 38)
    }
  }

  private func previewMetadata(for item: ClipboardItem) -> String {
    let usage = item.copyCount > 1 ? " · 复制 \(item.copyCount) 次" : ""
    switch item.kind {
    case .text:
      return "\(item.text.count) 字符 · \(relativeTime(item.createdAt))\(usage)"
    case .image:
      let size = item.imageByteCount.map(formattedByteCount) ?? "未知大小"
      return "\(item.imageDimensionsText) · \(size) · \(relativeTime(item.createdAt))\(usage)"
    }
  }
}

private struct ClipboardRow: View {
  let item: ClipboardItem
  let index: Int
  let isSelected: Bool
  let onSelect: () -> Void
  let onActivate: () -> Void
  let onDelete: () -> Void

  @State private var isHovered = false

  var body: some View {
    HStack(spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 7)
          .fill(isSelected ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.055))
        if index < 9 {
          Text("⌘\(index + 1)")
            .font(.system(size: 10, weight: .semibold, design: .rounded))
        } else {
          Image(systemName: item.kind == .text ? "doc.text" : "photo")
            .font(.system(size: 11, weight: .medium))
        }
      }
      .foregroundStyle(isSelected ? Color.accentColor : .secondary)
      .frame(width: 38, height: 34)

      VStack(alignment: .leading, spacing: 5) {
        Text(item.summaryText)
          .font(.system(size: 13.5))
          .foregroundStyle(.primary)
          .lineLimit(2)
          .truncationMode(.tail)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 6) {
          Text(item.kind == .text ? "文本" : "图片")
          Text("·")
          if item.kind == .text {
            Text("\(item.text.count) 字符")
          } else {
            Text(item.imageDimensionsText)
          }
          Text("·")
          Text(relativeTime(item.createdAt))
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.tertiary)
        .lineLimit(1)
      }

      Button(action: onDelete) {
        Image(systemName: "trash")
          .font(.system(size: 11, weight: .medium))
          .frame(width: 26, height: 26)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
      .opacity(isHovered || isSelected ? 1 : 0)
      .help("删除这条记录")
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 8)
    .background(
      isSelected
        ? Color.white.opacity(0.095)
        : (isHovered ? Color.white.opacity(0.045) : Color.clear),
      in: RoundedRectangle(cornerRadius: 10)
    )
    .contentShape(Rectangle())
    .onTapGesture(count: 2, perform: onActivate)
    .onTapGesture(count: 1, perform: onSelect)
    .onHover { isHovered = $0 }
  }
}

private struct ClipboardTextPreview: View {
  let item: ClipboardItem

  private var content: ClipboardTextPreviewContent {
    ClipboardPreviewLoader.textPreview(for: item.text)
  }

  var body: some View {
    VStack(spacing: 0) {
      AppKitScrollableTextView(
        itemID: item.id,
        text: content.text
      )

      if content.isTruncated {
        Divider().opacity(0.25)
        HStack(spacing: 7) {
          Image(systemName: "text.badge.ellipsis")
          Text("内容过长，仅预览前 20 万字符；复制和粘贴仍使用完整内容")
          Spacer()
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(Color.white.opacity(0.025))
      }
    }
  }
}

private struct AppKitScrollableTextView: NSViewRepresentable {
  let itemID: UUID
  let text: String

  final class Coordinator {
    var itemID: UUID?
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true
    scrollView.borderType = .noBorder

    let contentSize = scrollView.contentSize
    let textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize))
    textView.minSize = NSSize(width: 0, height: contentSize.height)
    textView.maxSize = NSSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    )
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]
    textView.textContainer?.containerSize = NSSize(
      width: contentSize.width,
      height: CGFloat.greatestFiniteMagnitude
    )
    textView.textContainer?.widthTracksTextView = true
    textView.textContainerInset = NSSize(width: 18, height: 18)
    textView.isEditable = false
    textView.isSelectable = true
    textView.isRichText = false
    textView.allowsUndo = false
    textView.drawsBackground = false
    textView.textColor = .labelColor
    textView.font = .systemFont(ofSize: 13.5)
    textView.string = text

    scrollView.documentView = textView
    context.coordinator.itemID = itemID
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard context.coordinator.itemID != itemID,
      let textView = scrollView.documentView as? NSTextView
    else {
      return
    }
    textView.string = text
    textView.scrollToBeginningOfDocument(nil)
    context.coordinator.itemID = itemID
  }
}

private struct ClipboardImagePreview: View {
  let item: ClipboardItem
  @ObservedObject var history: ClipboardHistory

  @State private var image: NSImage?
  @State private var isLoading = true

  var body: some View {
    ZStack {
      Color.white.opacity(0.025)

      if isLoading {
        VStack(spacing: 10) {
          ProgressView()
            .controlSize(.small)
          Text("正在生成图片预览…")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
      } else if let image {
        Image(nsImage: image)
          .resizable()
          .interpolation(.high)
          .scaledToFit()
          .padding(22)
      } else {
        VStack(spacing: 10) {
          Image(systemName: "photo.badge.exclamationmark")
            .font(.system(size: 32, weight: .light))
            .foregroundStyle(.orange)
          Text("无法读取本地图片")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
      }
    }
    .task(id: item.id) {
      image = nil
      isLoading = true
      guard let url = history.imageFileURL(for: item) else {
        isLoading = false
        return
      }
      let thumbnail = await ClipboardPreviewLoader.imageThumbnail(at: url)
      guard !Task.isCancelled else { return }
      image = thumbnail
      isLoading = false
    }
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

private func relativeTime(_ date: Date) -> String {
  let formatter = RelativeDateTimeFormatter()
  formatter.unitsStyle = .short
  return formatter.localizedString(for: date, relativeTo: Date())
}

private func formattedByteCount(_ byteCount: Int) -> String {
  let formatter = ByteCountFormatter()
  formatter.countStyle = .file
  return formatter.string(fromByteCount: Int64(byteCount))
}
