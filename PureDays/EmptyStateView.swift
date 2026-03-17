import SwiftUI

/// 首页空状态视图（无数据时展示）
///
/// 设计目标：
/// - 与当前 Bento Grid / 苹果风卡片语言一致
/// - 使用 SF Symbol 组合做“温馨插图”
/// - 珊瑚粉作为点缀色（#FF6B6B）
struct EmptyStateView: View {
    private let coralPink = Color(red: 1.0, green: 0.42, blue: 0.42) // #FF6B6B
    
    let onAdd: (() -> Void)?
    
    init(onAdd: (() -> Void)? = nil) {
        self.onAdd = onAdd
    }

    var body: some View {
        VStack(spacing: 22) {
            illustration

            VStack(spacing: 8) {
                Text("还没有纪念日")
                    .font(.system(.title3, design: .rounded).weight(.semibold))

                Text("点击右上角+号添加第一个纪念日")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            if let onAdd {
                Button {
                    onAdd()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                        Text("添加第一个纪念日")
                    }
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 260)
                    .padding(.vertical, 12)
                    .background(coralPink)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    private var illustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(coralPink.opacity(0.14))
                .frame(width: 220, height: 170)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(coralPink.opacity(0.18), lineWidth: 1)
                )

            // 组合插图：主图标 + 小点缀
            ZStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 54, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(coralPink, Color.primary.opacity(0.85))

                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(coralPink.opacity(0.9))
                    .offset(x: 54, y: -46)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("空状态插图")
    }
}

#Preview {
    EmptyStateView()
}

