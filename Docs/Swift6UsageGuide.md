# SwiftCodable：Swift 6+ 使用指南

本文面向使用 Swift 6、严格并发检查和 Swift Concurrency 的项目。
`SwiftCodable` 仍兼容较早的 Swift 工具链，因此不要求应用降低部署版本。

## 环境要求

- Swift 6.0 或更高版本
- iOS 12+、macOS 10.13+、tvOS 12+ 或 watchOS 5+
- Swift Package Manager 或 CocoaPods

库中的 `SafeCodable` 在其包装值符合 `Sendable` 时自动符合 `Sendable`，
因此可以用于 Swift 6 的跨 actor 数据模型。

## Swift Package Manager

在 Swift 6 项目的 `Package.swift` 中添加：

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MyApp",
    dependencies: [
        .package(
            url: "https://github.com/yuantao/SwiftCodable.git",
            from: "0.1.0"
        )
    ],
    targets: [
        .target(
            name: "MyApp",
            dependencies: [
                .product(
                    name: "SwiftCodable",
                    package: "SwiftCodable"
                )
            ]
        )
    ]
)
```

在源码中导入：

```swift
import SwiftCodable
```

## 快速开始

```swift
import Foundation
import SwiftCodable

struct User: Codable, Sendable {
    @SafeInt var id: Int
    @SafeString var name: String
    @SafeInt var age: Int
    @SafeBool var enabled: Bool
}
```

下面的数据可以正常解析：

```json
{
  "id": "1001",
  "name": 9527,
  "age": "18",
  "enabled": "yes"
}
```

```swift
let user = try JSONDecoder().decode(
    User.self,
    from: jsonData
)

print(user.id)       // 1001
print(user.name)     // "9527"
print(user.age)      // 18
print(user.enabled)  // true
```

字段缺失、为 `null` 或无法安全转换时，分别使用 `0`、空字符串或 `false`
等默认值。

## 常用包装器

| 声明 | 值类型 | 异常时默认值 |
| --- | --- | --- |
| `@SafeString` | `String` | `""` |
| `@SafeInt` | `Int` | `0` |
| `@SafeDouble` | `Double` | `0` |
| `@SafeDecimal` | `Decimal` | `0` |
| `@SafeBool` | `Bool` | `false` |
| `@SafeOptional<T>` | `T?` | `nil` |
| `@SafeArray<T>` | `[T]` | `[]` |
| `@SafeDictionary<K, V>` | `[K: V]` | `[:]` |

此外还提供所有常用有符号、无符号整数及 `Float` 的包装器。

## 可选值、集合和嵌套模型

```swift
struct Address: Codable, Sendable {
    @SafeString var city: String
    @SafeInt var zipCode: Int
}

struct Profile: Codable, Sendable {
    @SafeOptional<String> var nickname: String?
    @SafeOptional<Address> var address: Address?
    @SafeArray<String> var tags: [String]
    @SafeDictionary<String, Int> var scores: [String: Int]
}
```

- 可选字段缺失、为 `null` 或无法转换时得到 `nil`。
- 整个数组类型错误时得到空数组。
- 整个字典类型错误时得到空字典。
- 嵌套模型中的包装字段继续逐层执行容错转换。

标准 `Array` 解码是整体性的。如果数组中一个元素无法解码，
`@SafeArray` 会把整个数组回退为空数组，而不是只跳过该元素。

## 自定义业务默认值

Swift 自动合成的 `Decodable` 不会把普通属性初始值当作解码失败时的默认值。
需要通过 `SafeCodableDefaultValue` 明确声明：

```swift
enum DefaultPageSize: SafeCodableDefaultValue {
    static let defaultValue = 20
}

struct Request: Codable, Sendable {
    @SafeCodable<DefaultPageSize>
    var pageSize: Int
}
```

`pageSize` 缺失、为 `null` 或无法转换时为 `20`。

自定义模型也可以作为默认值。若模型需要跨 actor 传递，应同时符合
`Sendable`：

```swift
struct Feature: Codable, Sendable {
    let name: String
    let level: Int
}

enum DefaultFeature: SafeCodableDefaultValue {
    static let defaultValue = Feature(
        name: "fallback",
        level: 1
    )
}

struct Config: Codable, Sendable {
    @SafeCodable<DefaultFeature>
    var feature: Feature
}
```

## Swift 6 严格并发

推荐网络层返回同时符合 `Decodable` 和 `Sendable` 的值类型：

```swift
import Foundation
import SwiftCodable

struct User: Decodable, Sendable {
    @SafeInt var id: Int
    @SafeString var name: String
}

actor APIClient {
    func decodeUser(from data: Data) throws -> User {
        // Decoder 在当前调用中创建，不与其他并发任务共享。
        try JSONDecoder().decode(User.self, from: data)
    }
}
```

调用 actor：

```swift
let client = APIClient()
let user = try await client.decodeUser(from: jsonData)
```

注意以下规则：

1. `SafeCodable` 只有在包装值符合 `Sendable` 时才符合 `Sendable`。
2. `String`、数字、Bool、数组和由 Sendable 成员组成的 struct 通常可以
   自动满足严格并发检查。
3. 引用类型模型不会因为符合 `Codable` 就自动线程安全。跨 actor 使用时，
   优先选择不可变 struct；不要为了消除警告随意使用
   `@unchecked Sendable`。
4. 不要在多个并发任务之间共享并修改同一个 `JSONDecoder`。按请求创建
   decoder，或者把它隔离在 actor 内。

## 真正不可变的 let 属性

Swift 不允许在 `let` 属性上直接声明 Property Wrapper：

```swift
// 无法编译
@SafeInt let score: Int
```

需要使用普通 `let`，并手写解码：

```swift
final class ImmutableUser: Codable, @unchecked Sendable {
    let score: Int
    let nickname: String?

    enum CodingKeys: String, CodingKey {
        case score
        case nickname
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        score = try container.decodeSafeValue(
            SafeInt.self,
            forKey: .score
        )
        nickname = try container.decodeSafeValue(
            SafeOptional<String>.self,
            forKey: .nickname
        )
    }
}
```

上例只有不可变、线程安全的值成员，因此可以人工确认
`@unchecked Sendable`。如果 class 存在可变状态，应使用 actor 隔离或改成
struct，而不是直接添加 `@unchecked Sendable`。

更推荐的 Swift 6 写法是不可变 struct：

```swift
struct ImmutableUser: Codable, Sendable {
    let score: Int
    let nickname: String?

    enum CodingKeys: String, CodingKey {
        case score
        case nickname
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        score = try container.decodeSafeValue(
            SafeInt.self,
            forKey: .score
        )
        nickname = try container.decodeSafeValue(
            SafeOptional<String>.self,
            forKey: .nickname
        )
    }
}
```

如果模型只实现 `Decodable`，不需要补充 `encode(to:)`；如果声明
`Codable`，手写 `init(from:)` 后，编译器仍可根据 `CodingKeys` 合成编码。

## 根据 type 解析混合数组

数组中的元素模型不同时，使用带关联值的枚举统一表示：

```json
[
  {
    "type": "text",
    "data": { "content": "Hello" }
  },
  {
    "type": "image",
    "data": {
      "url": "a.png",
      "width": "1280"
    }
  }
]
```

```swift
struct TextData: Codable, Sendable {
    @SafeString var content: String
}

struct ImageData: Codable, Sendable {
    @SafeString var url: String
    @SafeInt var width: Int
}

enum ListItem: Codable, Sendable {
    case text(TextData)
    case image(ImageData)

    enum CodingKeys: String, CodingKey {
        case type
        case data
    }

    enum ItemType: String, Codable {
        case text
        case image
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let type = try container.decode(
            ItemType.self,
            forKey: .type
        )

        switch type {
        case .text:
            self = .text(
                try container.decode(TextData.self, forKey: .data)
            )
        case .image:
            self = .image(
                try container.decode(ImageData.self, forKey: .data)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        switch self {
        case .text(let model):
            try container.encode(ItemType.text, forKey: .type)
            try container.encode(model, forKey: .data)
        case .image(let model):
            try container.encode(ItemType.image, forKey: .type)
            try container.encode(model, forKey: .data)
        }
    }
}
```

解析：

```swift
let items = try JSONDecoder().decode(
    [ListItem].self,
    from: jsonData
)
```

枚举及其关联模型都符合 `Sendable`，因此 `[ListItem]` 可以安全跨 actor
边界传递。

## 没有类型字段的混合数组

如果没有 `type`，只能根据独有字段或字段组合判断：

```swift
enum ListItem: Decodable, Sendable {
    case text(TextData)
    case image(ImageData)

    enum CodingKeys: String, CodingKey {
        case content
        case imageURL
        case width
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        if container.contains(.imageURL),
           container.contains(.width) {
            self = .image(try ImageData(from: decoder))
        } else if container.contains(.content) {
            self = .text(try TextData(from: decoder))
        } else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "无法判断元素模型"
                )
            )
        }
    }
}
```

不要依次使用 `try? TextData(from:)`、`try? ImageData(from:)` 猜测类型。
安全包装器会为缺失字段提供默认值，错误模型也可能解码成功。

如果多个模型的字段名、字段类型和结构完全一致，JSON 本身没有足够信息，
客户端无法可靠区分。此时必须增加类型字段、唯一字段，或通过外层上下文、
固定数组位置确定类型。

## 容错边界

`SwiftCodable` 主要处理模型字段级问题：

- 字段缺失
- 字段为 `null`
- 字段类型不一致但可以安全转换
- 字段无法转换时使用默认值

下列问题仍然可能抛出错误：

- JSON 语法错误
- 顶层期望对象但实际是数组
- 自定义多态模型遇到未知类型
- 手写 `init(from:)` 主动抛出错误
- 数组中的元素无法解码

因此仍然需要在请求边界处理错误：

```swift
do {
    let value = try JSONDecoder().decode(
        User.self,
        from: jsonData
    )
    // 使用 value
} catch {
    // 记录数据格式问题或转换为业务错误
}
```

## 编码与回环

包装器编码的是 `wrappedValue`，可以正常完成解码、修改和重新编码：

```swift
var user = try JSONDecoder().decode(
    User.self,
    from: jsonData
)

user.name = "New Name"

let encoded = try JSONEncoder().encode(user)
```

编码默认值时不会自动省略字段。例如缺失的 `@SafeInt` 解码为 `0` 后，
重新编码会输出该字段及其值 `0`。

## 转换规则

| 目标类型 | 支持的输入 |
| --- | --- |
| String | Bool、整数、有限浮点数 |
| Bool | true/false、1/0、yes/no、y/n、on/off、数字 |
| 整数 | 数字字符串、范围内的整数、无小数部分的有限浮点数 |
| Float/Double/Decimal | 合法数字字符串 |
| Optional | 与 Wrapped 类型相同的转换规则 |
| 自定义 Codable | 标准 Codable 解码；失败时使用指定默认值 |

有歧义或可能丢失数据的转换会被拒绝。例如 `1.5` 不会转换为 `Int`，
`128` 不会转换为 `Int8`，非有限浮点数不会转换为字符串或整数。

## Swift 6 迁移检查清单

- 为需要跨 actor 传递的模型添加 `Sendable`。
- 确认自定义默认值的 `Value` 也符合 `Sendable`。
- 优先使用 struct 表示接口数据。
- 不要跨并发任务共享可变 class 模型。
- 不要为消除警告而随意添加 `@unchecked Sendable`。
- 每次请求创建 decoder，或使用 actor 隔离共享 decoder。
- 对多态数组先检查唯一字段，再解码具体模型。
- 在网络请求边界保留 `do/catch`，不要把字段容错等同于整个响应永不失败。

## 构建与测试

使用 Swift 6 语言模式验证：

```bash
swift test -Xswiftc -swift-version -Xswiftc 6
```

运行示例：

```bash
swift run SwiftCodableDemo
```
