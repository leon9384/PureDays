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
    @Environment(\.dismiss) private var dismiss

    // `@Bindable` 用于直接双向绑定 SwiftData 模型字段（iOS 17+）
    @Bindable var event: Event

    let onDelete: () -> Void
    let onSave: () -> Void

    // MARK: - Draft（草稿）
    //
    // 需求：修改实时生效（UI 预览实时变化），但“返回前可以取消”
    // 做法：页面上编辑的是草稿 State；只有点击“保存”才写回 `event` 并持久化。
    @State private var draftName: String = ""
    @State private var draftDate: Date = Date()
    @State private var draftIsLunar: Bool = false
    @State private var draftIsOneTime: Bool = false
    @State private var draftColor: String = "FF6B6B"
    @State private var draftIcon: String = "star.fill"
    @State private var draftNotes: String = ""
    @State private var didLoadDraft = false

    // DatePicker 使用的日历（跟随草稿开关）
    private var activeCalendar: Calendar {
        draftIsLunar ? Calendar(identifier: .chinese) : Calendar.current
    }

    // 统计信息（用草稿构造一个“临时 Event”来计算，保证 UI 预览实时变化）
    private var previewEvent: Event {
        Event(
            name: draftName.isEmpty ? event.name : draftName,
            date: DateUtils.startOfDay(draftDate),
            isLunar: draftIsLunar,
            isRecurring: !draftIsOneTime, // 兼容旧字段：非一次性视为可重复
            isOneTime: draftIsOneTime,
            categoryColor: normalizeHex(draftColor),
            categoryIcon: draftIcon,
            notes: draftNotes,
            createdAt: event.createdAt
        )
    }

    private var statsTotalDays: Int {
        DateUtils.totalDays(for: previewEvent)
    }

    private var statsNextDate: Date? {
        DateUtils.nextOccurrence(for: previewEvent)
    }

    private var statsCountdownText: String? {
        DateUtils.displayText(for: previewEvent).countdown
    }

    private var statsTotalText: String {
        DateUtils.displayText(for: previewEvent).total
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
        .onAppear {
            // 初始化草稿（只做一次）
            guard !didLoadDraft else { return }
            didLoadDraft = true

            draftName = event.name
            draftDate = event.date
            draftIsLunar = event.isLunar
            draftIsOneTime = event.isOneTime
            draftIcon = event.categoryIcon
            draftNotes = event.notes
            draftColor = stripHash(event.categoryColor).isEmpty ? "FF6B6B" : stripHash(event.categoryColor)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("统计信息")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.secondary)

            // 倒计时（如果有）
            if let c = statsCountdownText {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(numberOnly(from: c))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(coralPink)
                        .monospacedDigit()

                    Text("倒计时 天")
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Divider().opacity(0.6)

            VStack(alignment: .leading, spacing: 8) {
                statRow(title: "总天数", value: "\(formattedNumber(statsTotalDays)) 天")
                if let next = statsNextDate, draftIsOneTime == false {
                    statRow(title: "下次日期", value: formatted(date: next))
                }
                statRow(title: "状态", value: statsTotalText)
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
                HStack {
                    Text("一次性事件")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("一次性事件", isOn: $draftIsOneTime)
                        .labelsHidden()
                }
                Text(draftIsOneTime ? "一次性：只显示已过总天数，不计算下一次发生日。" : "非一次性：会计算下一次发生日并显示倒计时。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("名称")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)

                TextField("请输入事件名称", text: $draftName)
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

                    Toggle("农历", isOn: $draftIsLunar)
                        .labelsHidden()
                }

                DatePicker(
                    "选择日期",
                    selection: $draftDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .environment(\.calendar, activeCalendar)
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("分类")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)

                CategoryColorPicker(selectedHex: $draftColor)
                CategoryIconPicker(selectedIcon: $draftIcon)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("备注")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)

                TextField("可选，记录一些小细节…", text: $draftNotes, axis: .vertical)
                    .lineLimit(2...6)
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
                // 保存：把草稿写回模型，再持久化，然后返回首页
                applyDraftToEvent()
                onSave()
                dismiss()
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
                .background(Color.red.opacity(0.14))
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

    private func formattedNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func statRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
        }
    }

    private func stripHash(_ s: String) -> String {
        s.replacingOccurrences(of: "#", with: "")
    }

    private func normalizeHex(_ s: String) -> String {
        let cleaned = stripHash(s).uppercased()
        return cleaned.hasPrefix("#") ? cleaned : "#\(cleaned)"
    }

    private func applyDraftToEvent() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            event.name = trimmed
        }

        event.date = DateUtils.startOfDay(draftDate)
        event.isLunar = draftIsLunar
        event.isOneTime = draftIsOneTime
        event.isRecurring = !draftIsOneTime
        event.categoryColor = normalizeHex(draftColor)
        event.categoryIcon = draftIcon
        event.notes = draftNotes
    }
}

#Preview {
    // 预览里无法直接构造有效的 `PersistentIdentifier`，用占位视图即可
    ContentUnavailableView("预览请在真机/模拟器运行", systemImage: "eye")
}

