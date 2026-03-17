import Foundation

/// 日期相关工具（只比较“年月日”，去除时间影响）
///
/// 设计原则：
/// - 任何“天数差”都先把日期归一化为某个时区下的当天 00:00，再计算 day 差值
/// - 默认使用系统当前时区（`TimeZone.current`），保证“今天”的判断符合用户所在地
///
/// 你可以把它理解成 Java 里的 `DateUtils`/`DateTimeUtils` 静态工具类。
enum DateUtils {
    // MARK: - Day Normalization（去除时间影响 / 基础方法）

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

    // MARK: - Day Difference（精确天数差 / 基础方法）

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

    /// 按你的新 API 命名：计算两个日期之间的天数差（只比较年月日）
    ///
    /// - 这是对旧的 `dayDifference(from:to:)` 的语义化封装，便于调用侧更直观。
    static func daysBetween(from: Date, to: Date, timeZone: TimeZone = .current) -> Int {
        dayDifference(from: from, to: to, timeZone: timeZone)
    }

    // MARK: - Lunar（农历相关）

    /// 按你的要求：返回“农历日历”，并显式绑定当前时区
    static func chineseCalendar() -> Calendar {
        var calendar = Calendar(identifier: .chinese)
        calendar.timeZone = TimeZone.current
        return calendar
    }

    // MARK: - Business Logic（新业务逻辑）

    /// 计算“下一次发生日期”
    ///
    /// - 规则：
    ///   - 一次性（event.isOneTime = true）：没有“下一次”，返回 nil
    ///   - 非一次性：
    ///     - 公历：只看月-日，拼到今年；若已过则拼到明年
    ///     - 农历：只看农历月-日（含闰月标记），拼到今年农历年；若已过则拼到下一农历年
    ///
    /// - 边界处理：
    ///   - 2 月 29 日：当年不是闰年时，回退到 2 月 28 日（常见产品约定）
    ///   - 闰月：若指定闰月在目标年份不存在，回退为同月非闰月（兜底策略）
    static func nextOccurrence(for event: Event) -> Date? {
        guard event.isOneTime == false else { return nil }

        let today = startOfToday()
        let thisYear = thisYearDate(for: event.date, isLunar: event.isLunar)
        if startOfDay(thisYear) >= today {
            return startOfDay(thisYear)
        }
        let nextYear = nextYearDate(for: event.date, isLunar: event.isLunar)
        return startOfDay(nextYear)
    }

    /// 计算“累计总天数”
    ///
    /// - 规则：从 event.date 到今天（按天）累计
    /// - 农历说明：
    ///   - 你的模型里 `event.date` 存的是一个绝对的公历 Date（创建时已归一到 00:00）
    ///   - 因此“累计天数”直接按存储 date 与今天计算即可；isLunar 主要影响“下一次发生日”的推算
    static func totalDays(for event: Event) -> Int {
        let today = startOfToday()
        return max(0, daysBetween(from: event.date, to: today))
    }

    /// 生成显示文本
    ///
    /// - 返回值：
    ///   - countdown：倒计时文案（一次性事件为 nil）
    ///   - total：主文案（一次性：已过；非一次性：给出“下次日期”）
    static func displayText(for event: Event) -> (countdown: String?, total: String) {
        if event.isOneTime {
            let days = totalDays(for: event)
            return (nil, "已过 \(days)天")
        } else {
            guard let next = nextOccurrence(for: event) else {
                return ("倒计时 0天", "下次日期未知")
            }
            let days = max(0, daysBetween(from: startOfToday(), to: next))
            return ("倒计时 \(days)天", "下次 \(formatYMD(next))")
        }
    }

    // MARK: - Helpers（本年/明年日期拼接）

    /// 把 originalDate 的“月-日”（或农历月-日）映射为“今年”的发生日期（公历 Date）
    static func thisYearDate(for originalDate: Date, isLunar: Bool) -> Date {
        let today = startOfToday()

        if isLunar {
            let lunar = chineseCalendar()
            let original = lunar.dateComponents([.month, .day, .isLeapMonth], from: originalDate)
            let month = original.month ?? 1
            let day = original.day ?? 1
            let isLeap = original.isLeapMonth ?? false

            let thisYear = lunar.component(.year, from: today)
            return lunarDateToGregorian(
                lunarYear: thisYear,
                lunarMonth: month,
                lunarDay: day,
                isLeapMonth: isLeap
            ) ?? startOfDay(originalDate)
        } else {
            return gregorianMonthDayInYear(of: originalDate, year: Calendar.current.component(.year, from: today))
        }
    }

    /// 把 originalDate 的“月-日”（或农历月-日）映射为“明年”的发生日期（公历 Date）
    static func nextYearDate(for originalDate: Date, isLunar: Bool) -> Date {
        let today = startOfToday()

        if isLunar {
            let lunar = chineseCalendar()
            let original = lunar.dateComponents([.month, .day, .isLeapMonth], from: originalDate)
            let month = original.month ?? 1
            let day = original.day ?? 1
            let isLeap = original.isLeapMonth ?? false

            let nextYear = lunar.component(.year, from: today) + 1
            return lunarDateToGregorian(
                lunarYear: nextYear,
                lunarMonth: month,
                lunarDay: day,
                isLeapMonth: isLeap
            ) ?? startOfDay(originalDate)
        } else {
            return gregorianMonthDayInYear(of: originalDate, year: Calendar.current.component(.year, from: today) + 1)
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

    // MARK: - Private helpers（实现细节）

    /// 农历年月日 -> 公历 Date（带闰月兜底）
    private static func lunarDateToGregorian(
        lunarYear: Int,
        lunarMonth: Int,
        lunarDay: Int,
        isLeapMonth: Bool
    ) -> Date? {
        // 先按指定 isLeapMonth 转一次
        if let d = gregorianDateFromLunar(
            lunarYear: lunarYear,
            lunarMonth: lunarMonth,
            lunarDay: lunarDay,
            isLeapMonth: isLeapMonth,
            timeZone: .current
        ) {
            return startOfDay(d)
        }

        // 若闰月不存在，回退为非闰月（兜底策略）
        if isLeapMonth {
            if let d = gregorianDateFromLunar(
                lunarYear: lunarYear,
                lunarMonth: lunarMonth,
                lunarDay: lunarDay,
                isLeapMonth: false,
                timeZone: .current
            ) {
                return startOfDay(d)
            }
        }

        return nil
    }

    /// 把某个日期的月日映射到指定年份（公历）
    ///
    /// - 处理 2/29：目标年不是闰年时，回退到 2/28
    private static func gregorianMonthDayInYear(of originalDate: Date, year: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = .current
        cal.timeZone = .current

        let md = cal.dateComponents([.month, .day], from: originalDate)
        let month = md.month ?? 1
        let day = md.day ?? 1

        var comps = DateComponents()
        comps.calendar = cal
        comps.year = year
        comps.month = month
        comps.day = day

        if let d = cal.date(from: comps) {
            return cal.startOfDay(for: d)
        }

        // 兜底：最常见的无效日期是 2/29 在非闰年
        if month == 2 && day == 29 {
            comps.day = 28
            if let d = cal.date(from: comps) {
                return cal.startOfDay(for: d)
            }
        }

        // 再兜底：回到 originalDate 的 startOfDay（保证永不返回 nil）
        return cal.startOfDay(for: originalDate)
    }

    private static func formatYMD(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

