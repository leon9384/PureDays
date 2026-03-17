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

    /// 保存回调：把用户输入回传给首页
    /// - 参数：
    ///   - name: 名称
    ///   - date: 归一化后的日期（公历当天 00:00）
    ///   - isLunar: 是否农历（nil 表示未标记）
    let onSave: (_ name: String, _ date: Date, _ isLunar: Bool?) -> Void

    // MARK: - 表单输入状态
    @State private var name: String = ""
    @State private var selectedDate: Date = Date()

    /// 是否使用农历（Chinese calendar）进行日期选择
    @State private var useLunarCalendar: Bool = false

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

                Section {
                    Toggle("农历", isOn: $useLunarCalendar)

                    // 只显示日期，不显示时间
                    //
                    // 关键点：DatePicker 选择的是“绝对时间 Date”，但 UI 展示/滚轮会遵循环境里的 Calendar。
                    // - useLunarCalendar = true：用中国农历的年/月/日选择方式展示
                    // - useLunarCalendar = false：回到公历（系统当前日历/地区）
                    DatePicker(
                        "日期",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .environment(\.calendar, activeCalendar)

                    // 简短提示：帮助第一次接触 iOS 的你理解“农历开关”的含义
                    Text(useLunarCalendar
                         ? "当前以农历选择日期；保存时会转换为对应的公历 Date 存储。"
                         : "当前以公历选择日期。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("日期")
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

                        onSave(trimmed, normalized, useLunarCalendar)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

#Preview {
    AddEventView { _, _, _ in }
}
