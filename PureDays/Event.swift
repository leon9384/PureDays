import Foundation
import SwiftData

/// SwiftData 持久化模型：纪念日事件
///
/// - 相当于一张表的一行数据
/// - SwiftData 会自动给它生成主键和持久化逻辑
@Model
final class Event {
    /// 事件名称，例如“在一起纪念日”
    var name: String

    /// 事件日期（统一按公历天来存储，取当天 00:00）
    var date: Date

    /// 是否按农历计算
    ///
    /// - 为了避免旧数据迁移时出现 nil，这里使用非可选并提供默认值 false
    var isLunar: Bool = false

    /// 是否每年重复
    ///
    /// - true：节日型（生日/周年等），按“月-日”每年重复，只显示倒计时
    /// - false：累计型（一次性事件），显示从事件日到今天的累计天数，只显示已过
    var isRecurring: Bool

    /// 是否一次性（默认 false）
    ///
    /// - 与 `isRecurring` 并存：不删除旧字段，便于你后续逐步迁移业务逻辑
    /// - 你可以约定：
    ///   - isOneTime = true  → 一次性累计型
    ///   - isOneTime = false → 允许做节日型/其他
    var isOneTime: Bool = false

    /// 分类颜色（Hex 字符串），默认随机暖色
    var categoryColor: String = Event.randomWarmHexColor()

    /// 分类图标（SF Symbol 名称）
    var categoryIcon: String = "star.fill"

    /// 备注（默认空字符串）
    var notes: String = ""

    /// 创建时间（默认当前时间）
    var createdAt: Date = Date()

    init(
        name: String,
        date: Date,
        isLunar: Bool = false,
        isRecurring: Bool = false,
        isOneTime: Bool = false,
        categoryColor: String = Event.randomWarmHexColor(),
        categoryIcon: String = "star.fill",
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.name = name
        self.date = date
        self.isLunar = isLunar
        self.isRecurring = isRecurring
        self.isOneTime = isOneTime
        self.categoryColor = categoryColor
        self.categoryIcon = categoryIcon
        self.notes = notes
        self.createdAt = createdAt
    }

    /// 随机生成一个“暖色系”Hex 颜色字符串（用于分类色默认值）
    ///
    /// - 说明：默认值必须“总能生成”，避免迁移/创建时出错
    /// - 这里用一组固定暖色调色板，随机取一个，保证观感统一
    static func randomWarmHexColor() -> String {
        let palette: [String] = [
            "#FF6B6B", // 珊瑚粉
            "#FFA94D", // 橘子橙
            "#FFD93D", // 暖黄
            "#FF8FAB", // 粉桃
            "#FFB703", // 琥珀
            "#F77F00"  // 暖橙
        ]
        return palette.randomElement() ?? "#FF6B6B"
    }
}

