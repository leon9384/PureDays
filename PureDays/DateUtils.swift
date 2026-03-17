import Foundation

/// 日期相关工具（只比较“年月日”，去除时间影响）
///
/// 设计原则：
/// - 任何“天数差”都先把日期归一化为某个时区下的当天 00:00，再计算 day 差值
/// - 默认使用系统当前时区（`TimeZone.current`），保证“今天”的判断符合用户所在地
///
/// 你可以把它理解成 Java 里的 `DateUtils`/`DateTimeUtils` 静态工具类。
enum DateUtils {
    // MARK: - Day Normalization（去除时间影响）

    /// 把某个 Date 归一化为“该时区下的当天 00:00”
    ///
    /// - 为什么需要这个：
    ///   - `Date` 本质是一个绝对时间点（UTC 时间戳）
    ///   - 直接比较两个 Date 的差值会受到时分秒、时区、夏令时影响
    ///   - 纪念日 App 按“天”工作，所以需要先把它们都转成“某时区的那一天”
    static func startOfDay(_ date: Date, timeZone: TimeZone = .current) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = .current
        cal.timeZone = timeZone
        return cal.startOfDay(for: date)
    }

    /// 获取“今天”的 00:00（在指定时区下）
    static func startOfToday(timeZone: TimeZone = .current, now: Date = Date()) -> Date {
        startOfDay(now, timeZone: timeZone)
    }

    // MARK: - Day Difference（精确天数差）

    /// 计算两个日期之间的“天数差”（只比较年月日）
    ///
    /// - 返回值定义：
    ///   - `> 0`：toDate 在 fromDate 之后 N 天
    ///   - `= 0`：同一天
    ///   - `< 0`：toDate 在 fromDate 之前 N 天
    ///
    /// - 精确性说明：
    ///   - 会先将 `fromDate` 和 `toDate` 都归一化为指定时区下的当天 00:00
    ///   - 再使用 Gregorian Calendar 计算 `.day` 差值
    ///   - 这样能避免“23:xx/00:xx”跨天和 DST（夏令时）带来的误差
    static func dayDifference(
        from fromDate: Date,
        to toDate: Date,
        timeZone: TimeZone = .current
    ) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = .current
        cal.timeZone = timeZone

        let fromDay = cal.startOfDay(for: fromDate)
        let toDay = cal.startOfDay(for: toDate)
        return cal.dateComponents([.day], from: fromDay, to: toDay).day ?? 0
    }

    // MARK: - Display Text（倒计时/已过）

    /// 根据目标日期返回显示文本：
    /// - 未来（含今天）：`倒计时 X天`
    /// - 过去：`已过 X天`
    ///
    /// - referenceDate：参照日期，默认是“现在”
    static func countdownText(
        targetDate: Date,
        referenceDate: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        let delta = dayDifference(from: referenceDate, to: targetDate, timeZone: timeZone)
        if delta >= 0 {
            return "倒计时 \(delta)天"
        } else {
            return "已过 \(-delta)天"
        }
    }

    // MARK: - Lunar Support（农历支持）

    /// 将“农历年月日”转换成对应的 `Date`（绝对时间点）
    ///
    /// - 说明：
    ///   - iOS 自带 `Calendar(identifier: .chinese)` 能表达农历日期并与 `Date` 相互转换
    ///   - 这里使用 `chinese calendar` 生成一个 Date，再交由上面的函数统一按“天”归一化/计算
    ///
    /// - 参数：
    ///   - lunarYear/lunarMonth/lunarDay：农历的年/月/日（注意：农历“年”的含义与干支纪年有关，通常用于“把某个 Date 转回农历”更自然）
    ///   - isLeapMonth：是否闰月（若你需要支持闰月输入，请在 UI 里提供选择）
    ///
    /// - 重要提醒（为什么这里会有坑）：
    ///   - “农历选择”常见诉求其实是：每年按农历生日/节日去计算下一次公历日期
    ///   - 这涉及“按当前年份推算下一次发生日”的逻辑，而不是一次性把某个农历年月日转成 Date
    ///   - 如果你要做“每年重复”的农历事件，建议引入更完整的农历库来处理闰月/节气等规则
    static func gregorianDateFromLunar(
        lunarYear: Int,
        lunarMonth: Int,
        lunarDay: Int,
        isLeapMonth: Bool = false,
        timeZone: TimeZone = .current
    ) -> Date? {
        var lunar = Calendar(identifier: .chinese)
        lunar.locale = .current
        lunar.timeZone = timeZone

        var comps = DateComponents()
        comps.calendar = lunar
        comps.year = lunarYear
        comps.month = lunarMonth
        comps.day = lunarDay
        comps.isLeapMonth = isLeapMonth

        return lunar.date(from: comps)
    }

    /// 把某个 `Date` 转成农历组件（用于展示或调试）
    static func lunarComponents(
        from date: Date,
        timeZone: TimeZone = .current
    ) -> DateComponents {
        var lunar = Calendar(identifier: .chinese)
        lunar.locale = .current
        lunar.timeZone = timeZone
        return lunar.dateComponents([.year, .month, .day, .isLeapMonth], from: date)
    }

    /// 若你需要更“产品级”的农历能力（例如：把农历生日映射到每年的公历日期、闰月规则、人性化文案），可以考虑引入第三方库。
    ///
    /// - 建议方向：
    ///   - 搜索关键词：`Swift lunar calendar conversion`, `农历 转 公历 Swift`, `ChineseCalendar Swift library`
    ///   - 常见实现会基于天文历法/预置表，能够更准确处理“按年份推算下一次发生日”等需求
    ///
    /// 目前这个 App 的最小可用版本：可以先只存储 `isLunar` 标记，并且天数计算仍按已存的公历 `Date` 进行。
    static func lunarLibraryHint() {
        // 这是一个“占位函数”，用于让你在代码里快速定位到说明文档。
        // 不需要调用它。
    }
}

