import SwiftUI
import SwiftData

@main
struct PureDaysApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // 为整个 Scene 提供 SwiftData 容器（iOS 17+）
        .modelContainer(for: Event.self)
    }
}
