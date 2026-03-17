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
    @State private var path = NavigationPath()

    // 左滑删除确认弹窗：记录待删除的事件
    @State private var pendingDeleteEvent: Event?

    // Bento Grid：自适应列数，让卡片在不同尺寸下自动排布
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
    ]

    // 色彩（根据需求固定主辅色）
    private let coralPink = Color(red: 1.0, green: 0.42, blue: 0.42)      // #FF6B6B
    private let mintGreen = Color(red: 0.31, green: 0.80, blue: 0.77)     // #4ECDC4

    // MARK: - 分区与排序（新规则）

    /// 即将到来：有下一次发生日期的所有事件
    private var upcomingItems: [Event] {
        events.filter { DateUtils.nextOccurrence(for: $0) != nil }
            .sorted { event1, event2 in
                let date1 = DateUtils.nextOccurrence(for: event1) ?? Date.distantFuture
                let date2 = DateUtils.nextOccurrence(for: event2) ?? Date.distantFuture
                return date1 < date2
            }
    }
    
    /// 已过记录：一次性事件且已过（没有下一次）
    private var pastItems: [Event] {
        events.filter {
            $0.isOneTime && DateUtils.nextOccurrence(for: $0) == nil
        }.sorted { event1, event2 in
            DateUtils.totalDays(for: event1) > DateUtils.totalDays(for: event2)
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // 背景：淡淡的系统分组背景，提升“卡片”层级感
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if upcomingItems.isEmpty && pastItems.isEmpty {
                    EmptyStateView(onAdd: {
                        isPresentingAddSheet = true
                    })
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if !upcomingItems.isEmpty {
                                sectionHeader(title: "即将到来", count: upcomingItems.count, tint: coralPink)

                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(upcomingItems) { event in
                                        card(for: event, isFuture: true)
                                    }
                                }
                            }

                            if !pastItems.isEmpty {
                                sectionHeader(title: "已过记录", count: pastItems.count, tint: .secondary)

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
                AddEventView(onSaveEvent: { newEvent in
                    modelContext.insert(newEvent)
                })
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
            .navigationDestination(for: PersistentIdentifier.self) { id in
                EventDetailView(eventID: id)
            }
        }
    }

    // MARK: - Section Header
    private func sectionHeader(title: String, count: Int, tint: Color) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(tint.opacity(0.75))
                .frame(width: 8, height: 8)

            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.9))

            Spacer()

            Text("\(count)")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 6)
    }

    // MARK: - 卡片视图（Bento Grid Cell）
    private func card(for event: Event, isFuture: Bool) -> some View {
        return SwipeToRevealDeleteCard(
            content: {
                EventCard(event: event, isFutureSection: isFuture)
            },
            onTap: {
                // 点击跳转详情页（保持现有卡片交互：若卡片已露出删除按钮，卡片内部会优先收回）
                path.append(event.persistentModelID)
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

    // 卡片背景已下沉到 `EventCard.swift`

    // MARK: - 文本工具
    // 已迁移到 `EventCard.swift` 与 `DateUtils.display(...)`
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
private struct SwipeToRevealDeleteCard<Content: View>: View {
    /// 卡片内容（保持 Bento Grid 视觉语言由外部决定，例如 `EventCard`）
    @ViewBuilder let content: () -> Content
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
        content()
            // 关键：让整个卡片区域都可命中手势（不止文字部分）
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
