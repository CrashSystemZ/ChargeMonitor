import AppKit
import SwiftUI

enum AppleMetrics {
    static let popoverPadH: CGFloat = 16
    static let popoverPadV: CGFloat = 16
    
    static let bodySize: CGFloat = 12
    
    static let sectionRadius: CGFloat = 12
    static let rowHeight: CGFloat = 22
    static let rowPadH: CGFloat = 7
    static let rowPadV: CGFloat = 3
    
    static let sectionGap: CGFloat = 4
}

struct AppleSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.55))
            .frame(height: 1)
            .padding(.horizontal, AppleMetrics.rowPadH)
    }
}

struct AppleInfoLine: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: AppleMetrics.bodySize, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, AppleMetrics.rowPadV)
    }
}

struct AppleRowButton: View {
    let title: String
    let icon: NSImage?
    let action: () -> Void
    
    @State private var hover = false
    
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = nil
        self.action = action
    }
    
    init(_ title: String, icon: NSImage?, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .cornerRadius(4)
                }
                
                Text(title)
                    .font(.system(size: AppleMetrics.bodySize, weight: .regular))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: AppleMetrics.rowHeight, alignment: .leading)
            .padding(.horizontal, AppleMetrics.rowPadH + 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Rectangle()
                .fill(hover ? Color(nsColor: .selectedContentBackgroundColor) : .clear)
                .cornerRadius(8)
        )
        .onHover { hover = $0 }
    }
}
