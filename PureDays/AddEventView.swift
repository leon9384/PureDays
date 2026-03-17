import SwiftUI

/// 添加纪念日页面（独立 Swift 文件）
///
/// 设计目标：
/// - 只负责“采集输入 + 校验 + 回传数据”，不直接操作首页数组
/// - 首页通过 `onSave` 回调接收 (name, date) 并保存
///
/// 你可以把它类比成 Android/Java 里的：
/// - 一个“新增页面/对话框”
/// - 保存时通过接口回调把数据传回调用方
struct AddEventView: View {
    // SwiftUI 提供的 dismiss，用于“保存/取消后关闭当前页面”
    @Environment(\.dismiss) private var dismiss

    /// 保存回调：回传完整的 Event（包含所有新字段）
    ///
    /// - 注意：这里只负责创建 `Event` 对象并回传，真正的持久化（insert/save）由外层决定
    let onSaveEvent: (_ event: Event) -> Void

    /// 兼容旧代码：如果你的调用方还在使用旧签名（name/date/isLunar/isRecurring），也能继续编译运行
    init(onSaveEvent: @escaping (_ event: Event) -> Void) {
        self.onSaveEvent = onSaveEvent
    }

    init(onSave: @escaping (_ name: String, _ date: Date, _ isLunar: Bool?, _ isRecurring: Bool) -> Void) {
        self.onSaveEvent = { event in
            onSave(event.name, event.date, event.isLunar, event.isRecurring)
        }
    }

    // MARK: - 表单输入状态
    @State private var name: String = ""
    @State private var selectedDate: Date = Date()

    /// 是否使用农历（Chinese calendar）进行日期选择
    @State private var useLunarCalendar: Bool = false

    // 新增字段（按你的要求）
    @State private var isOneTime = false
    @State private var selectedColor = "FF6B6B"  // 默认珊瑚粉（不带 #）
    @State private var selectedIcon = "star.fill"
    @State private var notes = ""

    // MARK: - Calendars
    private let gregorianCalendar = Calendar.current
    private let lunarCalendar = Calendar(identifier: .chinese)

    /// 根据开关返回当前 DatePicker 使用的日历
    private var activeCalendar: Calendar {
        useLunarCalendar ? lunarCalendar : gregorianCalendar
    }

    /// 保存按钮是否可用（最基础校验：名称去掉空白后不能为空）
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("事件名称") {
                    TextField("例如：在一起纪念日 / 生日 / 入职", text: $name)
                        .textInputAutocapitalization(.sentences)
                }

                Section("日期") {
                    Toggle("农历", isOn: $useLunarCalendar)

                    // 关键交互：用 compact 样式，让选择日期后自动收起（系统行为）
                    DatePicker(
                        "日期",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                    .environment(\.calendar, activeCalendar)
                }

                Section("类型") {
                    Toggle("一次性事件", isOn: $isOneTime)
                    Text(isOneTime ? "一次性：只显示已过总天数，不计算下一次发生日。" : "非一次性：会计算下一次发生日并显示倒计时。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("分类") {
                    CategoryColorPicker(selectedHex: $selectedColor)
                    CategoryIconPicker(selectedIcon: $selectedIcon)
                }

                Section("备注") {
                    TextField("可选，记录一些小细节…", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle("添加纪念日")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        // 取消：直接关闭页面
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        // 保存：校验 -> 归一化日期（00:00）-> 回调 -> 关闭
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }

                        // 按“天”使用的 App：统一保存为当天 00:00，避免后续计算出现 0/1 天误差
                        //
                        // 说明：
                        // - selectedDate 是一个绝对时间点（Date）
                        // - 当 useLunarCalendar = true 时，DatePicker 的选择界面是农历，但最终仍会落到一个 Date
                        // - 我们用公历的 startOfDay 做归一化，保证全 App 一致按“公历天”计算天数差
                        let normalized = gregorianCalendar.startOfDay(for: selectedDate)

                        // 创建 Event，并传入所有新字段
                        //
                        // 说明：
                        // - `categoryColor` 统一存成带 `#` 的 Hex 字符串，方便全局一致解析
                        // - 旧字段 `isRecurring` 不删除：这里给一个合理默认（非一次性视为“可重复”）
                        let event = Event(
                            name: trimmed,
                            date: normalized,
                            isLunar: useLunarCalendar,
                            isRecurring: !isOneTime,
                            isOneTime: isOneTime,
                            categoryColor: selectedColor.hasPrefix("#") ? selectedColor : "#\(selectedColor)",
                            categoryIcon: selectedIcon,
                            notes: notes,
                            createdAt: Date()
                        )

                        onSaveEvent(event)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

#Preview {
    AddEventView { _ in }
}
