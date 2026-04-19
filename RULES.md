Swift 6.0, macOS 15.5+, SwiftUI, MVVM. NEVER use Python/UIKit/iOS/Firebase.

Service pattern:
```swift
class MyService {
    private let settings: Settings
    init(settings: Settings) { self.settings = settings }
    // MARK: - Public Methods
    // MARK: - Private Methods
}
```

Model pattern:
```swift
struct MyModel: Identifiable, Codable {
    let id: UUID
    init(...) { self.id = UUID() }
}
```

Rules:
- AppKit not UIKit (NSApplication not UIApplication)
- No force unwrap: use guard let / do-catch
- async/await for async code
- No hardcoded API keys, use settings.apiKey
- Log: ✅ ❌ 🚀 📤 📥 💾
- No UI code in ViewModels
