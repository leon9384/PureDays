import SwiftUI
import SwiftData

/// 纪念日详情页：查看与编辑 Event
///
/// 说明（SwiftData + Navigation）：
/// - SwiftData 的 `@Model` 通常不直接拿来当 Navigation 的 value（它不一定 Hashable）
/// - 这里用 `Event.persistentModelID` 作为路由参数（Hashable），在详情页通过 Query 精确取回对应 Event
struct EventDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let eventID: PersistentIdentifier

    // 通过 id 精确加载单条 Event
    @Query private var events: [Event]

    // 删除确认
    @State private var isShowingDeleteConfirm = false
    // 保存失败提示（极少见，但显式 save 更符合你的“保存按钮”心智）
    @State private var saveErrorMessage: String?

    init(eventID: PersistentIdentifier) {
        self.eventID = eventID
        _events = Query(filter: #Predicate<Event> { $0.persistentModelID == eventID })
    }

    var body: some View {
        Group {
            if let event = events.first {
                EventDetailContent(
                    event: event,
                    onDelete: {
                        isShowingDeleteConfirm = true
                    },
                    onSave: {
                        do {
                            try modelContext.save()
                        } catch {
                            saveErrorMessage = error.localizedDescription
                        }
                    }
                )
                .navigationTitle("详情")
                .navigationBarTitleDisplayMode(.inline)
                .alert("删除纪念日", isPresented: $isShowingDeleteConfirm) {
                    Button("取消", role: .cancel) {}
                    Button("删除", role: .destructive) {
                        modelContext.delete(event)
                        dismiss()
                    }
                } message: {
                    Text("确定删除「\(event.name)」吗？")
                }
                .alert("保存失败", isPresented: Binding(get: { saveErrorMessage != nil }, set: { if !$0 { saveErrorMessage = nil } })) {
                    Button("好") { saveErrorMessage = nil }
                } message: {
                    Text(saveErrorMessage ?? "")
                }
            } else {
                // 极端情况：记录已被删除/查询不到
                ContentUnavailableView("事件不存在", systemImage: "questionmark.folder")
                    .navigationTitle("详情")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

// MARK: - 详情内容（Bento 设计语言）

private struct EventDetailContent: View {
    @Environment(\.modelContext) private var modelContext

    // `@Bindable` 用于直接双向绑定 SwiftData 模型字段（iOS 17+）
    @Bindable var event: Event

    let onDelete: () -> Void
    let onSave: () -> Void

    // 农历开关（Event.isLunar 是可选 Bool，这里用 computed Binding 适配 UI）
    private var isLunarBinding: Binding<Bool> {
        Binding(
            get: { event.isLunar ?? false },
            set: { event.isLunar = $0 }
        )
    }

    // DatePicker 使用的日历
    private var activeCalendar: Calendar {
        (event.isLunar ?? false) ? Calendar(identifier: .chinese) : Calendar.current
    }

    // 显示文案
    private var countdownText: String {
        DateUtils.countdownText(targetDate: event.date)
    }

    private var delta: Int {
        DateUtils.dayDifference(from: Date(), to: event.date)
    }

    // 颜色：沿用首页主色/辅助色
    private let coralPink = Color(red: 1.0, green: 0.42, blue: 0.42)      // #FF6B6B
    private let mintGreen = Color(red: 0.31, green: 0.80, blue: 0.77)     // #4ECDC4

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 顶部摘要卡片（Bento 卡片风格）
                summaryCard

                // 编辑卡片
                editCard

                // 操作区
                actionCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("当前状态")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(numberOnly(from: countdownText))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(delta >= 0 ? coralPink : .primary)
                    .monospacedDigit()
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: delta)

                Text(labelOnly(from: countdownText))
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Divider().opacity(0.6)

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)

                Text(formatted(date: event.date))
                    .font(.system(.headline, design: .rounded))

                Spacer()

                if event.isLunar == true {
                    Text("农历")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(mintGreen.opacity(0.18))
                        .foregroundStyle(mintGreen)
                        .clipShape(Capsule())
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
                        coralPink.opacity(0.16),
                        mintGreen.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }

    private var editCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("编辑")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("名称")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)

                TextField("请输入事件名称", text: $event.name)
                    .textInputAutocapitalization(.sentences)
                    .padding(12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("日期")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Toggle("农历", isOn: isLunarBinding)
                        .labelsHidden()
                }

                DatePicker(
                    "选择日期",
                    selection: Binding(
                        get: { event.date },
                        set: { event.date = DateUtils.startOfDay($0) }
                    ),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .environment(\.calendar, activeCalendar)
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }

    private var actionCard: some View {
        VStack(spacing: 12) {
            Button {
                // 显式保存（同时仍能依赖 SwiftData 自动持久化）
                onSave()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("保存")
                }
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(coralPink)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                onDelete()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "trash.fill")
                    Text("删除")
                }
                .font(.system(.headline, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }

    // MARK: - Formatting helpers

    private func formatted(date: Date) -> String {
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

    private func labelOnly(from text: String) -> String {
        // "倒计时 12天" -> "倒计时 天"
        if text.hasPrefix("倒计时") { return "倒计时 天" }
        if text.hasPrefix("已过") { return "已过 天" }
        return "天"
    }
}

#Preview {
    // 预览里无法直接构造有效的 `PersistentIdentifier`，用占位视图即可
    ContentUnavailableView("预览请在真机/模拟器运行", systemImage: "eye")
}

