import SwiftUI

/// 分类颜色选择器（可复用）
///
/// - 用法：
///   ```swift
///   @State private var selectedColor = "FF6B6B"
///   CategoryColorPicker(selectedHex: $selectedColor)
///   ```
/// - 约定：
///   - `selectedHex` 支持 "FF6B6B" 或 "#FF6B6B"
///   - 回传时默认写入 **不带 #** 的 6 位 Hex（更适合存储/比较）
struct CategoryColorPicker: View {
    @Binding var selectedHex: String

    /// 预设 12 色（不带 #）
    private let palette: [String] = [
        "FF6B6B", // 珊瑚粉
        "4ECDC4", // 薄荷绿
        "45B7D1", // 天空蓝
        "96CEB4", // 浅绿
        "FFEEAD", // 奶油黄
        "D4A5A5", // 玫瑰粉
        "9B59B6", // 紫色
        "3498DB", // 蓝色
        "E67E22", // 橙色
        "2ECC71", // 绿色
        "F1C40F", // 黄色
        "E74C3C"  // 红色
    ]

    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(palette, id: \.self) { hex in
                colorCell(hex: hex)
            }
        }
        .padding(.vertical, 4)
    }

    private func colorCell(hex: String) -> some View {
        let isSelected = normalize(hex) == normalize(selectedHex)
        let fill = Color(hex: "#" + hex) ?? .clear

        return Button {
            // 回传不带 # 的 Hex
            selectedHex = hex
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fill)
                    .frame(height: 40)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.9 : 0.35), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("颜色 \(hex)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
    }
}

private extension Color {
    /// 解析 `#RRGGBB` 或 `RRGGBB` 为 Color
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let rgb = Int(s, radix: 16) else { return nil }
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}

#Preview {
    struct Demo: View {
        @State var selected = "FF6B6B"
        var body: some View {
            Form {
                CategoryColorPicker(selectedHex: $selected)
                Text("Selected: \(selected)")
            }
        }
    }

    return Demo()
}

