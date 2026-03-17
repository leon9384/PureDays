import SwiftUI

/// 纪念日卡片内容（与详情页统一风格）
///
/// - 只负责“卡片内部布局 + 样式”，不负责点击/左滑删除的容器与手势
/// - 数据驱动：
///   - `DateUtils.displayText(for:)`：倒计时（可选）与主文案（总天数/已过）
///   - `DateUtils.nextOccurrence(for:)`：下一次发生日期（可选）
/// - 视觉：
///   - 与 `EventDetailView` 的卡片一致：`secondarySystemBackground` + 柔和渐变叠加
///   - 圆角 20pt、轻阴影（0.06 / radius 10 / y 6）
/// - 排版：
///   - 采用更“产品级”的层级：标题行 → 关键数字 → 辅助信息
struct EventCard: View {
    let event: Event
    let isFutureSection: Bool
    
    // 动态字体适配：在用户调大字体时，卡片能按比例缩放而不溢出
    @ScaledMetric(relativeTo: .body) private var nameFontSize: CGFloat = 17
    @ScaledMetric(relativeTo: .title) private var primaryNumberSize: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var secondaryNumberSize: CGFloat = 24
    @ScaledMetric(relativeTo: .subheadline) private var metaFontSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 18

    var body: some View {
        let display = DateUtils.displayText(for: event)
        let next = DateUtils.nextOccurrence(for: event)
        let totalDays = DateUtils.totalDays(for: event)

        // 配色（与详情页一致）
        let coralPink = Color(hex: "#FF6B6B") ?? .pink
        let mintGreen = Color(hex: "#4ECDC4") ?? .green
        let primaryText = Color(hex: "#1C1C1E") ?? .primary
        let secondaryText = Color(hex: "#8E8E93") ?? .secondary
        let accent = isFutureSection ? coralPink : mintGreen
        // 分类色：用户自定义颜色（用于图标点缀，保持克制）
        let categoryTint = Color(hex: event.categoryColor) ?? accent

        // 主视觉：倒计时 or 总天数（一次性）
        let isOneTime = event.isOneTime || display.countdown == nil
        let mainValue: Int = {
            if isOneTime { return totalDays }
            // display.countdown 格式如 “倒计时 128天”，提取数字
            return Int(numberOnly(from: display.countdown ?? "")) ?? 0
        }()
        let mainText = formatFocusNumber(mainValue)

        VStack(alignment: .leading, spacing: 14) {
            // 标题区：避免“名称 + 日期”挤在一行导致换行
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: event.categoryIcon)
                        .font(.system(size: iconSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(categoryTint)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(categoryTint.opacity(0.14))
                        )

                    Text(event.name)
                        .font(.system(size: nameFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                }

                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: metaFontSize, weight: .regular, design: .rounded))
                        .foregroundStyle(secondaryText)

                    Text(formattedYMD(event.date))
                        .font(.system(size: metaFontSize, weight: .regular, design: .rounded))
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)

                    if event.isLunar {
                        Circle()
                            .fill(secondaryText.opacity(0.65))
                            .frame(width: 5, height: 5)
                            .accessibilityLabel("农历")
                    }
                }
            }

            // 关键数字区：让“数字”是唯一视觉焦点，其它信息下沉为小字
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(mainText)
                        .font(.system(size: primaryNumberSize, weight: .bold, design: .rounded))
                        .foregroundStyle(isOneTime ? mintGreen : coralPink)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .contentTransition(.numericText(value: Double(mainValue)))
                        .animation(.easeInOut(duration: 0.25), value: mainValue)
                        .layoutPriority(1)

                    Text("天")
                        .font(.system(size: metaFontSize, weight: .regular, design: .rounded))
                        .foregroundStyle(secondaryText)
                }

                Text(isOneTime ? "已过天数" : "倒计时")
                    .font(.system(size: metaFontSize, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // 辅助信息（两行内可读，不拥挤；值过长时截断）
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("总天数")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(formattedDecimal(totalDays)) 天")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                if let next, !isOneTime {
                    HStack {
                        Text("下次日期")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formattedYMD(next))
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                } else if isOneTime {
                    Text("已过 · 一次性")
                        .font(.system(size: metaFontSize, weight: .regular, design: .rounded))
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Color(.secondarySystemBackground)
                LinearGradient(
                    colors: [
                        categoryTint.opacity(0.14),
                        accent.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }

    private func formattedYMD(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func numberOnly(from text: String) -> String {
        let digits = text.filter { $0.isNumber }
        return digits.isEmpty ? "0" : digits
    }

    /// 按需求处理长数字：
    /// - 一般数字用千分位：12,073
    /// - 特别长数字压缩为“万”：1,000,000 -> 100万
    private func formatFocusNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return "\(value / 10_000)万"
        }
        if value >= 10_000 {
            let wan = Double(value) / 10_000.0
            let s = String(format: wan >= 100 ? "%.0f" : "%.1f", wan)
            return "\(s)万"
        }
        return formattedDecimal(value)
    }

    private func formattedDecimal(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Hex Color

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

