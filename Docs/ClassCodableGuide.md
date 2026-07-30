# Class、可选默认值与归档指南

本文说明 SwiftCodable 在 Class 模型、可选属性、默认值、属性修改及归档解档场景中的行为。

## 1. Class 模型

SwiftCodable 同时支持 Struct 和 Class。没有继承需求时，建议使用 `final class`：

```swift
import SwiftCodable

final class User: Codable {
    @SafeString var userId: String
    @SafeOptional<String> var nickname: String?

    init() {}
}
```

JSON 中比 Class 多出的字段会被 `Codable` 忽略。需要解析的固定字段必须在模型中声明，并确保属性名、`CodingKeys` 和 JSON 嵌套层级一致。

snake_case 数据可以使用：

```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
```

## 2. 可选值默认 nil

使用 `SafeOptional`：

```swift
final class User: Codable {
    @SafeOptional<String> var nickname: String?

    init() {}
}
```

字段缺失、为 `null` 或无法转换时，结果为 `nil`。

## 3. 可选值使用非 nil 默认值

默认值需要通过 `SafeCodableDefaultValue` 提供：

```swift
enum DefaultNickname: SafeCodableDefaultValue {
    static let defaultValue: String? = "游客"
}

final class User: Codable {
    @SafeCodable<DefaultNickname> var nickname: String?

    init() {}
}
```

字段缺失、为 `null` 或转换失败时，`nickname` 为 `"游客"`。

不能依赖下面这种声明为自动解码提供默认值：

```swift
@SafeOptional<String> var nickname: String? = "游客"
```

Swift 自动合成的 `Decodable` 无法在字段缺失时取得声明处的单独初始值。

## 4. 修改默认值后归档

编码器保存属性的当前值，不会强制写回最初的默认值：

```swift
let user = User()
print(user.nickname) // 游客

user.nickname = "Tom"

let data = try JSONEncoder().encode(user)
let restored = try JSONDecoder().decode(User.self, from: data)

print(restored.nickname) // Tom
```

修改后的普通值可以正常归档和解档。

## 5. 显式设置 nil

当前 SwiftCodable 语义把字段缺失和 JSON `null` 都视为需要回退：

```swift
let user = User()
user.nickname = nil

let data = try JSONEncoder().encode(user)
// {"nickname":null}

let restored = try JSONDecoder().decode(User.self, from: data)
print(restored.nickname) // 游客
```

行为汇总：

| 当前值 | 默认值 | 解档结果 |
| --- | --- | --- |
| `"Tom"` | `"游客"` | `"Tom"` |
| `nil` | `nil` | `nil` |
| `nil` | `"游客"` | `"游客"` |
| 字段缺失 | `"游客"` | `"游客"` |

如果业务要求“字段缺失时使用默认值，但明确的 `null` 必须保留 nil”，需要增加独立的 null 策略，不能继续把 missing 和 null 合并处理。

## 6. Class 类型默认对象

Class 是引用类型。不要使用一个静态对象作为所有模型共享的默认值：

```swift
// 不推荐
enum DefaultProfile: SafeCodableDefaultValue {
    static let defaultValue: Profile? = Profile()
}
```

这会让多个 User 可能持有同一个 Profile，修改其中一个会影响其他对象。

应该使用计算属性，每次创建新实例：

```swift
final class Profile: Codable {
    @SafeString var displayName: String

    init() {}
}

enum DefaultProfile: SafeCodableDefaultValue {
    static var defaultValue: Profile? {
        Profile()
    }
}

final class User: Codable {
    @SafeCodable<DefaultProfile> var profile: Profile?

    init() {}
}
```

验证实例隔离：

```swift
let first = User()
let second = User()

print(first.profile === second.profile) // false
```

## 7. 模型版本变化

新增安全包装属性时，旧归档没有该字段，会使用默认值：

```swift
@SafeBool var isVIP: Bool
```

删除属性时，旧归档中多出的字段会被忽略。

重命名属性时需要保持旧字段映射：

```swift
enum CodingKeys: String, CodingKey {
    case userName = "name"
}
```

## 8. Class 的 Codable 限制

- Codable 保存值，不保存对象身份。
- 两个属性原本引用同一个实例，解档后可能成为两个实例。
- 循环引用会导致编码递归，不能直接使用普通 Codable 归档。
- Class 继承通常需要手动实现 `required init(from:)` 和 `encode(to:)`。
- 需要保留共享引用或循环对象图时，应考虑 `NSKeyedArchiver` 与 `NSSecureCoding`。

## 9. UIKit Demo

打开：

```text
Demo/SwiftCodableDemoApp/SwiftCodableDemoApp.xcodeproj
```

在首页选择“Class 与归档”，进入独立解析页后可以直接查看：

- 初始可选默认值
- 修改后归档解档的结果
- 设置 nil 后恢复默认值
- Class 默认对象是否独立
- 实际编码得到的 JSON
