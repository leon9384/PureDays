import SwiftUI

/// 分类图标选择器（可复用）
///
/// - 用法：
///   ```swift
///   @State private var selectedIcon = "star.fill"
///   CategoryIconPicker(selectedIcon: $selectedIcon)
///   ```
struct CategoryIconPicker: View {
    @Binding var selectedIcon: String

    private let icons: [String] = [
        "star.fill", "heart.fill", "crown.fill", "gift.fill", "cake.fill",
        "balloon.fill", "sparkles", "sun.max.fill", "moon.fill", "leaf.fill",
        "flame.fill", "drop.fill", "bolt.fill", "bell.fill", "bookmark.fill",
        "flag.fill", "tag.fill", "bag.fill", "cart.fill", "creditcard.fill"
    ]

    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(icons, id: \.self) { icon in
                iconCell(name: icon)
            }
        }
        .padding(.vertical, 4)
    }

    private func iconCell(name: String) -> some View {
        let isSelected = (name == selectedIcon)

        return Button {
            selectedIcon = name
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.14) : Color(.secondarySystemBackground))
                    .frame(height: 44)

                Image(systemName: name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.blue : Color.primary.opacity(0.85))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.blue.opacity(0.9) : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("图标 \(name)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    struct Demo: View {
        @State var icon = "star.fill"
        var body: some View {
            Form {
                CategoryIconPicker(selectedIcon: $icon)
                Text("Selected: \(icon)")
            }
        }
    }

    return Demo()
}

