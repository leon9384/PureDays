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

    // 左滑删除确认弹窗：记录待删除的事件
    @State private var pendingDeleteEvent: Event?

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
            .alert(
                "删除纪念日",
                isPresented: Binding(
                    get: { pendingDeleteEvent != nil },
                    set: { if !$0 { pendingDeleteEvent = nil } }
                )
            ) {
                Button("取消", role: .cancel) {
                    pendingDeleteEvent = nil
                }
                Button("删除", role: .destructive) {
                    if let event = pendingDeleteEvent {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            modelContext.delete(event)
                        }
                    }
                    pendingDeleteEvent = nil
                }
            } message: {
                Text("确定删除\(pendingDeleteEvent.map { "「\($0.name)」" } ?? "")吗？")
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

        return SwipeToRevealDeleteCard(
            title: event.name,
            subtitle: formatted(date: event.date),
            numberText: numberPart(from: text),
            suffixText: prefixPart(from: text) + "天",
            accentColor: isFuture ? coralPink : .primary,
            background: cardBackground(isFuture: isFuture),
            deltaAnimationKey: delta,
            onTap: {
                // 点击行为（保留：后续可跳详情页）
            },
            onRequestDelete: {
                pendingDeleteEvent = event
            }
        )
        .contextMenu {
            Button(role: .destructive) {
                pendingDeleteEvent = event
            } label: {
                Label("删除纪念日", systemImage: "trash")
            }
        }
    }

    /// 卡片背景：未来使用浅粉色渐变，过去使用浅灰色
    private func cardBackground(isFuture: Bool) -> some View {
        Group {
            if isFuture {
                // 关键修复：
                // 之前渐变使用了较低透明度，导致在“未滑动”时也能隐约看到后面的红色删除底板。
                // 这里先铺一层不透明底色，再叠加柔和渐变，从而保证卡片本体始终不透底。
                ZStack {
                    Color(.secondarySystemBackground)
                    LinearGradient(
                        colors: [
                            coralPink.opacity(0.18),
                            mintGreen.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
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

// MARK: - 按压卡片效果（不抢滑动手势）

/// 为卡片添加“按下缩放”的微交互，但不使用 DragGesture（避免影响 swipeActions）
private struct PressableCardModifier: ViewModifier {
    @GestureState private var isPressed: Bool = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: isPressed)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.01, maximumDistance: 12)
                    .updating($isPressed) { value, state, _ in
                        state = value
                    }
            )
    }
}

// MARK: - 自实现左滑删除（适配 ScrollView + LazyVGrid）

/// 在 `ScrollView + LazyVGrid` 中，系统 `.swipeActions` 经常无法稳定触发。
/// 这里做一个轻量自实现：左滑露出删除按钮，右滑/点击收回。
///
/// 关键点（对应你提到的内容）：
/// - `.contentShape(Rectangle())`：让整个卡片区域都可命中手势
/// - 手势优先级：用自定义 `DragGesture`，仅在“横向位移 > 纵向位移”时处理，避免抢 ScrollView 的竖向滚动
private struct SwipeToRevealDeleteCard<Background: View>: View {
    let title: String
    let subtitle: String
    let numberText: String
    let suffixText: String
    let accentColor: Color
    let background: Background
    let deltaAnimationKey: Int
    let onTap: () -> Void
    let onRequestDelete: () -> Void

    private let cornerRadius: CGFloat = 20
    private let deleteWidth: CGFloat = 92
    private let minSwipeToOpen: CGFloat = 44

    @State private var baseOffsetX: CGFloat = 0
    @GestureState private var dragX: CGFloat = 0

    private var totalOffsetX: CGFloat {
        clamp(baseOffsetX + dragX, min: -deleteWidth, max: 0)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // 右侧删除底板
            Button(role: .destructive) {
                onRequestDelete()
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("删除")
                        .font(.system(.subheadline, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(width: deleteWidth, height: 130)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            // 卡片本体（可滑动）
            cardBody
                .offset(x: totalOffsetX)
                .animation(.spring(response: 0.25, dampingFraction: 0.86), value: baseOffsetX)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)

            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(numberText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                    .monospacedDigit()
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: deltaAnimationKey)

                Text(suffixText)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(background)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
        .contentShape(Rectangle())
        .onTapGesture {
            // 如果已经露出删除按钮，优先收回；否则触发点击
            if baseOffsetX != 0 {
                baseOffsetX = 0
            } else {
                onTap()
            }
        }
        .modifier(PressableCardModifier())
        .simultaneousGesture(horizontalSwipeGesture)
    }

    private var horizontalSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .updating($dragX) { value, state, _ in
                // 只在横向位移明显大于纵向位移时才处理（不抢竖向滚动）
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                if value.translation.width <= -minSwipeToOpen {
                    baseOffsetX = -deleteWidth
                } else if value.translation.width >= minSwipeToOpen {
                    baseOffsetX = 0
                } else {
                    baseOffsetX = (abs(baseOffsetX) > deleteWidth / 2) ? -deleteWidth : 0
                }
            }
    }

    private func clamp(_ x: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(x, min), max)
    }
}

#Preview {
    ContentView()
}
