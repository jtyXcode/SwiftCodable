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

### UIKit 页面 Demo

使用 Xcode 打开：

```text
Demo/SwiftCodableDemoApp/SwiftCodableDemoApp.xcodeproj
```

选择 `SwiftCodableDemoApp` Scheme 和任意 iOS 16+ 模拟器运行。Demo 使用纯 UIKit 和 Auto Layout，不依赖 Storyboard，包含：

- 设备真实消息、脏数据、缺失字段、多层嵌套、Class 归档五种场景
- 可编辑 JSON 输入
- 一键恢复示例与重新解码
- 每个字段的解码结果和错误信息
- 本地 Swift Package 集成
