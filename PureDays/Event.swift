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

    /// 是否按农历计算（可选）
    ///
    /// - true：用户是以农历选择/记忆这个日期
    /// - false：明确是公历
    /// - nil：未标记/无所谓
    var isLunar: Bool?

    init(name: String, date: Date, isLunar: Bool? = nil) {
        self.name = name
        self.date = date
        self.isLunar = isLunar
    }
}

