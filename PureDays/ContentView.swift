import SwiftUI
import SwiftData

/// 纪念日首页（Bento Grid 卡片布局）
///
/// - 苹果风 Bento Grid：自适应网格 + 圆角卡片 + 柔和阴影
/// - 视觉区分：
///   - 未来事件：浅粉色渐变背景 + 主色 #FF6B6B
///   - 已过事件：浅灰色卡片
/// - 微交互：
///   - 卡片按压时 scaleEffect 缩放
///   - 倒计时/已过天数字符串变化时使用隐式动画
struct ContentView: View {
    // SwiftData：持久化上下文 & 查询
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.date, order: .forward) private var events: [Event]

    // UI 状态
    @State private var isPresentingAddSheet = false

    // Bento Grid：自适应列数，让卡片在不同尺寸下自动排布
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
    ]

    // 色彩（根据需求固定主辅色）
    private let coralPink = Color(red: 1.0, green: 0.42, blue: 0.42)      // #FF6B6B
    private let mintGreen = Color(red: 0.31, green: 0.80, blue: 0.77)     // #4ECDC4

    // MARK: - 分组：未来 / 已过
    private var todayStart: Date {
        DateUtils.startOfToday()
    }

    private var futureItems: [Event] {
        events
            .filter { DateUtils.startOfDay($0.date) >= todayStart }
            .sorted { $0.date < $1.date }
    }

    private var pastItems: [Event] {
        events
            .filter { DateUtils.startOfDay($0.date) < todayStart }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景：淡淡的系统分组背景，提升“卡片”层级感
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if events.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if !futureItems.isEmpty {
                                sectionHeader(title: "未来纪念日", color: coralPink)

                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(futureItems) { event in
                                        card(for: event, isFuture: true)
                                    }
                                }
                            }

                            if !pastItems.isEmpty {
                                sectionHeader(title: "已过纪念日", color: .secondary)

                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(pastItems) { event in
                                        card(for: event, isFuture: false)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("纪念日")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(coralPink)
                    }
                    .accessibilityLabel("添加纪念日")
                }
            }
            .sheet(isPresented: $isPresentingAddSheet) {
                AddEventView { name, date, isLunar in
                    let newEvent = Event(name: name, date: date, isLunar: isLunar)
                    modelContext.insert(newEvent)
                }
            }
        }
    }

    // MARK: - Section Header
    private func sectionHeader(title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color.opacity(0.7))
                .frame(width: 8, height: 8)

            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 4)
    }

    // MARK: - 卡片视图（Bento Grid Cell）
    private func card(for event: Event, isFuture: Bool) -> some View {
        // 天数差 & 文案
        let text = DateUtils.countdownText(targetDate: event.date)
        let delta = DateUtils.dayDifference(from: Date(), to: event.date)

        return Button {
            // 预留点击行为（未来可以跳转详情）
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // 标题：SF Pro Rounded 风格
                Text(event.name)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                // 日期行
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(formatted(date: event.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                // 天数与标签
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    // 数字部分：粗体 + 大字号 + 动画
                    Text(numberPart(from: text))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(isFuture ? coralPink : .primary)
                        .monospacedDigit()
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: delta)

                    // 单位 + 前缀
                    Text(prefixPart(from: text) + "天")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .background(cardBackground(isFuture: isFuture))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(PressableCardStyle())
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(event)
            } label: {
                Label("删除纪念日", systemImage: "trash")
            }
        }
    }

    /// 卡片背景：未来使用浅粉色渐变，过去使用浅灰色
    private func cardBackground(isFuture: Bool) -> some View {
        Group {
            if isFuture {
                LinearGradient(
                    colors: [
                        coralPink.opacity(0.14),
                        mintGreen.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color(.secondarySystemBackground)
            }
        }
    }

    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                coralPink.opacity(0.18),
                                mintGreen.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 220, height: 180)

                VStack(spacing: 12) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.white)

                    Text("记录你的每一个重要日子")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            VStack(spacing: 8) {
                Text("还没有纪念日")
                    .font(.system(.title3, design: .rounded))

                Text("添加第一个纪念日，让重要的日子不再被时间淹没。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                isPresentingAddSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("添加第一个纪念日")
                }
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(coralPink)
                .clipShape(Capsule())
                .shadow(color: coralPink.opacity(0.4), radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 文本工具

    /// 将日期格式化为 yyyy-MM-dd
    private func formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// 从完整文案中提取前缀（“倒计时 ” / “已过 ”）
    private func prefixPart(from text: String) -> String {
        // 文案格式由 DateUtils.countdownText 决定，这里做一个简单拆分：
        // "倒计时 X天" / "已过 X天"
        if text.hasPrefix("倒计时") {
            return "倒计时 "
        } else if text.hasPrefix("已过") {
            return "已过 "
        } else {
            return ""
        }
    }

    /// 从完整文案中提取数字部分（用于大号数字显示）
    private func numberPart(from text: String) -> String {
        // 简单从文案中提取所有数字字符
        let digits = text.filter { $0.isNumber }
        return digits.isEmpty ? "0" : digits
    }
}

// MARK: - 按压卡片按钮样式

/// 为卡片添加按压缩放效果的按钮样式
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
}
