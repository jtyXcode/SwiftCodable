# SwiftCodable

`SwiftCodable` 是一个轻量的 Codable 属性包装器库，用来处理真实接口中常见的字段缺失、`null`、类型不一致和业务默认值。

最低支持 Swift 5.6，并已通过 Swift 6.2 严格语言模式构建与测试。

## 能力

- 常用类型：String、Bool、所有常用整数、Float、Double、Decimal
- 可选类型：`@SafeOptional<T>`
- 集合类型：`@SafeArray<T>`、`@SafeDictionary<Key, Value>`
- 自定义模型与业务默认值
- String、数字、Bool 之间的常用安全转换
- 多层嵌套模型和数组中的嵌套模型
- Swift Package Manager 与 CocoaPods
- Apple Privacy Manifest（不跟踪、不收集数据、不使用 Required Reason API）
- 函数式解码规则：`exact`、`or`、`map`、`validate`
- 精确诊断：missing、null、类型错误、转换失败、溢出、业务校验失败
- Debug 默认打印、Release 默认静默，并支持统一监听线上问题

完整设计和诊断接入方式见
[函数式解码与统一诊断方案](Docs/FunctionalDiagnosticsDesign.md)。

## 统一错误监听

Debug 构建默认打印容错失败，Release 构建默认不打印。可以随时手动调整：

```swift
SafeCodableDiagnostics.isAutomaticLoggingEnabled = false
```

监听器与打印开关相互独立，因此 Release 可以静默收集并统一上报：

```swift
SafeCodableDiagnostics.setListener { issue in
    print(
        issue.reasonCode,
        issue.ownerType ?? "UnknownModel",
        issue.pathDescription,
        issue.expectedType,
        issue.actualValue.typeName
    )
}
```

单个属性的结果可以通过 `$属性名` 查看：

```swift
let user = try JSONDecoder().decode(User.self, from: data)

if case .fallback(let issue) = user.$age {
    print(issue.message)
}
```

线上上报建议只发送类型、路径和错误码，避免上传接口字段原值。

## Swift Package Manager

```swift
dependencies: [
    .package(
        url: "https://github.com/yuantao/SwiftCodable.git",
        from: "0.1.0"
    )
]
```

然后在 target 中添加：

```swift
.product(name: "SwiftCodable", package: "SwiftCodable")
```

## CocoaPods

```ruby
pod "SwiftCodable", "~> 0.1.0"
```


## 常用类型

```swift
import SwiftCodable

struct User: Codable {
    @SafeString var name: String
    @SafeInt var age: Int
    @SafeDouble var balance: Double
    @SafeBool var enabled: Bool
}
```

例如下面的 JSON 可以正常解码：

```json
{
  "name": 1001,
  "age": "18",
  "balance": "99.5",
  "enabled": "yes"
}
```

转换结果分别是 `"1001"`、`18`、`99.5`、`true`。

## 可选类型

```swift
struct User: Codable {
    @SafeOptional<String> var nickname: String?
    @SafeOptional<Int> var score: Int?
}
```

字段缺失、为 `null` 或无法安全转换时，值为 `nil`。

## 数组、字典和嵌套模型

```swift
struct Address: Codable {
    @SafeString var city: String
    @SafeInt var zipCode: Int
}

struct User: Codable {
    @SafeOptional<Address> var address: Address?
    @SafeArray<Address> var history: [Address]
    @SafeDictionary<String, Int> var scores: [String: Int]
}
```

嵌套模型自己的包装字段会逐层容错。若整个数组或字典类型错误，则使用空集合。

## 自定义默认值

Swift 自动合成的 `Decodable` 无法读取属性声明处单独设置的初始值，因此业务默认值需要放入一个类型中：

```swift
enum DefaultPageSize: SafeCodableDefaultValue {
    static let defaultValue = 20
}

struct Request: Codable {
    @SafeCodable<DefaultPageSize> var pageSize: Int
}
```

`pageSize` 缺失、为 `null` 或值无法转换时都会得到 `20`。

任何 `Codable` 类型都能作为自定义默认值：

```swift
struct Feature: Codable {
    let name: String
    let level: Int
}

enum DefaultFeature: SafeCodableDefaultValue {
    static let defaultValue = Feature(name: "fallback", level: 1)
}

struct Config: Codable {
    @SafeCodable<DefaultFeature> var feature: Feature
}
```

## 根据属性解析不同的 data 模型

当接口通过 `type` 决定 `data` 的结构时，可以使用带关联值的枚举，
先解析 `type`，再解析对应的模型：

```json
[
  {
    "type": "text",
    "data": {
      "content": "Hello"
    }
  },
  {
    "type": "image",
    "data": {
      "url": "https://example.com/photo.png",
      "width": "1280",
      "height": 720
    }
  }
]
```

```swift
import SwiftCodable

struct TextData: Codable {
    @SafeString var content: String
}

struct ImageData: Codable {
    @SafeString var url: String
    @SafeInt var width: Int
    @SafeInt var height: Int
}

enum Message: Codable {
    case text(TextData)
    case image(ImageData)

    enum CodingKeys: String, CodingKey {
        case type
        case data
    }

    enum MessageType: String, Codable {
        case text
        case image
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let type = try container.decode(
            MessageType.self,
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
        case .text(let data):
            try container.encode(MessageType.text, forKey: .type)
            try container.encode(data, forKey: .data)
        case .image(let data):
            try container.encode(MessageType.image, forKey: .type)
            try container.encode(data, forKey: .data)
        }
    }
}
```

使用时对枚举进行匹配，就可以安全取得具体模型：

```swift
let messages = try JSONDecoder().decode(
    [Message].self,
    from: jsonData
)

for message in messages {
    switch message {
    case .text(let data):
        print(data.content)
    case .image(let data):
        print(data.url, data.width, data.height)
    }
}
```

这种方式保留了完整的类型检查，也支持重新编码。服务端新增 `type` 时，
在 `MessageType` 和 `Message` 中增加对应分支即可。

### 没有 type 等固定区分值

如果数组元素没有 `type`、`kind` 等类型标识，只能根据模型独有的字段或
字段组合判断类型。例如：

```json
[
  { "content": "Hello" },
  { "imageURL": "a.png", "width": "200" },
  { "videoURL": "a.mp4", "duration": 120 },
  { "userID": 1001, "name": "张三" }
]
```

先定义具体模型：

```swift
struct TextData: Codable {
    @SafeString var content: String
}

struct ImageData: Codable {
    @SafeString var imageURL: String
    @SafeInt var width: Int
}

struct VideoData: Codable {
    @SafeString var videoURL: String
    @SafeInt var duration: Int
}

struct UserData: Codable {
    @SafeInt var userID: Int
    @SafeString var name: String
}
```

然后在统一的枚举中先检查特征字段，再解码为具体模型：

```swift
enum ListItem: Codable {
    case text(TextData)
    case image(ImageData)
    case video(VideoData)
    case user(UserData)

    enum CodingKeys: String, CodingKey {
        case content
        case imageURL
        case width
        case videoURL
        case duration
        case userID
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        // 特征越明确的条件越应该放在前面。
        if container.contains(.videoURL),
           container.contains(.duration) {
            self = .video(try VideoData(from: decoder))
        } else if container.contains(.imageURL),
                  container.contains(.width) {
            self = .image(try ImageData(from: decoder))
        } else if container.contains(.userID) {
            self = .user(try UserData(from: decoder))
        } else if container.contains(.content) {
            self = .text(try TextData(from: decoder))
        } else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "无法根据字段判断数组元素类型"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let model):
            try model.encode(to: encoder)
        case .image(let model):
            try model.encode(to: encoder)
        case .video(let model):
            try model.encode(to: encoder)
        case .user(let model):
            try model.encode(to: encoder)
        }
    }
}
```

整个数组仍然可以直接解码：

```swift
let items = try JSONDecoder().decode(
    [ListItem].self,
    from: jsonData
)
```

不建议通过依次执行 `try? container.decode(...)` 来猜测类型。
`@SafeString`、`@SafeInt` 等包装器会在字段缺失或类型异常时返回默认值，
因此错误的模型也可能解码成功。应当先用 `container.contains(_:)` 检查
唯一字段或字段组合，再解码具体模型。

如果不同模型的字段名、字段类型和结构完全相同，JSON 本身就不包含足够的
类型信息，客户端无法可靠区分。此时需要服务端增加类型字段、增加唯一字段，
或者由外层上下文和固定数组位置提供类型信息。

## Class 手写解码

当 `class` 需要自己实现 `init(from:)` 时，`container.decode(...)`
返回的是属性包装器。通过包装器的 `wrappedValue` 可以取得真正的属性值：

```swift
import Foundation
import SwiftCodable

// 自定义可选默认值：字段异常时默认 18
enum DefaultBackupAge: SafeCodableDefaultValue {
    static let defaultValue: Int? = 18
}

final class User: Codable {

    // 缺失、null、类型错误时为 nil
    @SafeOptional<Int>
    var age: Int?

    // 支持数字转 String
    @SafeOptional<String>
    var nickname: String?

    // 非可选 Int，异常时默认 0
    @SafeInt
    var score: Int

    // 可选 Int，但异常时默认 18
    @SafeCodable<DefaultBackupAge>
    var backupAge: Int?

    enum CodingKeys: String, CodingKey {
        case age
        case nickname
        case score
        case backupAge
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        // container.decode(...) 返回 SafeOptional<Int>
        // 再通过 wrappedValue 取得真正的 Int?
        self.age = try container.decode(
            SafeOptional<Int>.self,
            forKey: .age
        ).wrappedValue

        self.nickname = try container.decode(
            SafeOptional<String>.self,
            forKey: .nickname
        ).wrappedValue

        self.score = try container.decode(
            SafeInt.self,
            forKey: .score
        ).wrappedValue

        self.backupAge = try container.decode(
            SafeCodable<DefaultBackupAge>.self,
            forKey: .backupAge
        ).wrappedValue
    }
}
```

例如解码 `{"nickname":9527,"score":"bad","backupAge":null}` 后，
`age == nil`、`nickname == "9527"`、`score == 0`、`backupAge == 18`。

### 真正不可变的 let 属性

Swift 不允许把 Property Wrapper 直接声明在 `let` 上，因此
`@SafeInt let score: Int` 无法编译。需要使用普通 `let` 属性，并在
手写的 `init(from:)` 中调用 `decodeSafeValue(_:forKey:)`：

```swift
final class ImmutableUser: Codable {
    let score: Int
    let age: Int?
    let backupAge: Int?

    enum CodingKeys: String, CodingKey {
        case score
        case age
        case backupAge
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        score = try container.decodeSafeValue(
            SafeInt.self,
            forKey: .score
        )

        age = try container.decodeSafeValue(
            SafeOptional<Int>.self,
            forKey: .age
        )

        backupAge = try container.decodeSafeValue(
            SafeCodable<DefaultBackupAge>.self,
            forKey: .backupAge
        )
    }
}
```

例如 JSON 为：

```json
{
  "score": "99",
  "age": "21",
  "backupAge": null
}
```

结果为 `score == 99`、`age == 21`、`backupAge == 18`。三个属性都是真正
不可再次赋值的 `let`。

## 转换规则

| 目标类型 | 支持的容错来源 |
| --- | --- |
| String | Bool、整数、有限浮点数 |
| Bool | true/false、1/0、yes/no、y/n、on/off、数字 |
| 整数 | 数字字符串、范围内的整数数字 |
| Float/Double/Decimal | 合法数字字符串 |
| Optional | 与其 Wrapped 类型相同的转换规则 |
| 自定义 Codable | 标准 Codable 解码；失败后使用自定义默认值 |

有歧义或可能丢失数据的转换会被拒绝，例如 `1.5` 不会转换为 `Int`，`128` 不会转换为 `Int8`。

## Demo 与测试

```bash
swift run SwiftCodableDemo
swift test
```

测试覆盖缺失字段、null、脏类型、数值边界、可选类型、自定义默认值、深层嵌套、集合、Class 默认对象和编码往返。

Class、可选默认值和归档的完整说明见
[ClassCodableGuide.md](Docs/ClassCodableGuide.md)。

Swift 6、严格并发、`Sendable` 和多态数组的完整说明见
[Swift6UsageGuide.md](Docs/Swift6UsageGuide.md)。

### UIKit 页面 Demo

使用 Xcode 打开：

```text
Demo/SwiftCodableDemoApp/SwiftCodableDemoApp.xcodeproj
```

选择 `SwiftCodableDemoApp` Scheme 和任意 iOS 16+ 模拟器运行。Demo 使用
`SceneDelegate`、纯 UIKit 和 Auto Layout，不依赖 Storyboard：

- 首页使用分组 `UITableView` 展示 11 个可运行示例
- 点击示例进入独立解析页
- 覆盖常用容错、missing/null、Optional、集合、嵌套、多态模型
- 覆盖函数式规则、六类诊断、不可变 let、Class 归档和真实设备消息
- 详情页支持编辑 JSON、一键恢复并重新解析
- 同时展示字段值、`$属性` 状态和统一监听捕获的结构化问题
- Debug 自动打印开关与本地 Swift Package 集成
