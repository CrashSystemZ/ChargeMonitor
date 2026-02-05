import AppKit
import SwiftUI

enum PopoverLayout {
	static let horizontalPadding: CGFloat = 16
	static let bodyFontSize: CGFloat = 12
	static let rowHeight: CGFloat = 22
	static let rowHorizontalPadding: CGFloat = 10
	static let rowVerticalPadding: CGFloat = 3
	static let sectionSpacing: CGFloat = 4
	static let rowCornerRadius: CGFloat = 8
}

struct PopoverMenuRow<Content: View>: View {
	private let title: String
	private let systemImageName: String?
	private let content: Content
	
	@State private var isHovering = false

	init(_ title: String, systemImageName: String? = nil, @ViewBuilder content: () -> Content) {
		self.title = title
		self.systemImageName = systemImageName
		self.content = content()
	}
	
	var body: some View {
		Menu {
			content
		} label: {
			HStack(spacing: 6) {
				if let systemImageName {
					Image(systemName: systemImageName)
				}
				Text(title)
					.font(.system(size: PopoverLayout.bodyFontSize, weight: .regular))
					.foregroundStyle(.primary)
			}
			.frame(maxWidth: .infinity, minHeight: PopoverLayout.rowHeight, alignment: .leading)
			.padding(.horizontal, PopoverLayout.rowHorizontalPadding)
			.contentShape(Rectangle())
		}
		.menuIndicator(.hidden)
		.menuStyle(.borderlessButton)
		.frame(maxWidth: .infinity, minHeight: PopoverLayout.rowHeight, alignment: .leading)
		.padding(.horizontal, PopoverLayout.rowHorizontalPadding - 3)
		.background(
			RoundedRectangle(cornerRadius: PopoverLayout.rowCornerRadius)
				.fill(isHovering ? Color(nsColor: .selectedContentBackgroundColor) : .clear)
		)
		.onHover { isHovering = $0 }
	}
}

struct PopoverInfoLine: View {
	private let text: String
	
	init(_ text: String) {
		self.text = text
	}
	
	var body: some View {
		Text(text)
			.font(.system(size: PopoverLayout.bodyFontSize, weight: .regular))
			.foregroundStyle(.secondary)
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(.vertical, PopoverLayout.rowVerticalPadding)
	}
}

struct PopoverActionRow: View {
	private let title: String
	private let icon: NSImage?
	private let action: () -> Void
	
	init(_ title: String, icon: NSImage? = nil, action: @escaping () -> Void) {
		self.title = title
		self.icon = icon
		self.action = action
	}
	
	var body: some View {
		Button(action: action) {
			HoverHighlightRow {
				HStack(spacing: 6) {
					if let icon {
						Image(nsImage: icon)
							.resizable()
							.scaledToFit()
							.frame(width: 20, height: 20)
							.cornerRadius(4)
					}
					Text(title)
						.font(.system(size: PopoverLayout.bodyFontSize, weight: .regular))
						.foregroundStyle(.primary)
				}
				.frame(maxWidth: .infinity, minHeight: PopoverLayout.rowHeight, alignment: .leading)
				.padding(.horizontal, PopoverLayout.rowHorizontalPadding)
				.contentShape(Rectangle())
			}
		}
		.buttonStyle(.plain)
	}
}

struct HoverHighlightRow<Content: View>: View {
	private let content: Content
	@State private var isHovering = false
	
	init(@ViewBuilder content: () -> Content) {
		self.content = content()
	}
	
	var body: some View {
		content
			.background(
				RoundedRectangle(cornerRadius: PopoverLayout.rowCornerRadius)
					.fill(isHovering ? Color(nsColor: .selectedContentBackgroundColor) : .clear)
			)
			.onHover { isHovering = $0 }
	}
}
