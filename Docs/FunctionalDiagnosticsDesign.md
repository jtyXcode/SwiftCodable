# SwiftCodable 函数式解码与统一诊断方案

本文说明 SwiftCodable 当前实现的函数式规则、精确错误分类、Debug/Release
打印策略，以及统一监听线上问题的方式。

## 设计目标

- 保持 `@SafeInt`、`@SafeString`、`@SafeOptional<T>` 等现有 API 兼容。
- 转换规则可以通过 `or`、`map`、`validate` 组合。
- 准确区分 `missing`、`null`、`typeMismatch`、`conversionFailed`、
  `overflow`、`validationFailed`。
- 错误包含所属模型、字段、完整 CodingPath、期望类型、实际值摘要和回退值。
- Debug 默认打印并允许关闭。
- Release 默认不打印，但统一监听入口始终可用。
- Swift 6 并发环境下安全读写全局诊断配置。

## 总体流程

```text
JSON 字段
  → 精确解码规则
  → 容错转换规则
  → 业务校验规则
  → success / mismatch / failure
  → 成功：保存 decoded 或 converted 状态
  → 失败：生成 SafeDecodeIssue
  → Policy 生成回退值
  → $属性 保存 fallback 状态
  → Debug 自动打印
  → 统一 Listener 接收问题
```

## 函数式规则

每个 `SafeCodableDefaultValue` 都可以提供 `decodingRule`。已有业务默认值只实现
`defaultValue` 即可，默认自动获得原有的精确解码和常用容错转换。

### 业务校验

```swift
enum AgePolicy: SafeCodableDefaultValue {
    static let defaultValue = 0

    static var decodingRule: SafeDecodeRule<Int> {
        .automatic
            .validate("年龄必须在 0～150 之间") {
                (0...150).contains($0)
            }
    }
}

struct User: Codable {
    @SafeCodable<AgePolicy>
    var age: Int
}
```

规则执行顺序是：

1. 精确解码 `Int`。
2. 尝试 String、整数、浮点数到 Int 的安全转换。
3. 校验结果是否在 `0...150`。
4. 任一步发生终态失败就生成结构化问题并回退为 `0`。

### 自定义来源转换

```swift
enum PortPolicy: SafeCodableDefaultValue {
    static let defaultValue = 8080

    static var decodingRule: SafeDecodeRule<Int> {
        .exact.or(
            .convert(String.self) { text in
                guard let value = Int(text) else {
                    throw SafeDecodeRuleError.conversionFailed
                }
                guard value <= 65_535 else {
                    throw SafeDecodeRuleError.overflow
                }
                return value
            }
        )
        .validate("端口必须在 1～65535 之间") {
            (1...65_535).contains($0)
        }
    }
}
```

`SafeDecodeRuleError` 支持：

- `conversionFailed`
- `overflow`
- `validationFailed(message:)`

未知错误统一归类为 `conversionFailed`。

### 可选 Int

属性类型是 `Int?` 时，Policy 的 `Value` 和规则输出也必须是 `Int?`：

```swift
enum OptionalAgePolicy: SafeCodableDefaultValue {
    static let defaultValue: Int? = nil

    static var decodingRule: SafeDecodeRule<Int?> {
        SafeDecodeRule<Int>.automatic
            .validate("年龄必须在 0～150 之间") {
                (0...150).contains($0)
            }
            .map(Optional.some)
    }
}

struct User: Codable {
    @SafeCodable<OptionalAgePolicy>
    var age: Int?
}
```

默认行为：

| 输入 | 值 | 状态 |
| --- | --- | --- |
| `18` | `18` | `decoded` |
| `"18"` | `18` | `converted` |
| `"abc"` | `nil` | `conversionFailed` |
| 超出业务范围 | `nil` | `validationFailed` |
| `null` | `nil` | `null` |
| 字段缺失 | `nil` | `missing` |

如果 missing 和 null 需要不同回退值，可以覆盖：

```swift
static func fallback(
    for issue: SafeDecodeIssue
) -> Int? {
    switch issue.reason {
    case .null:
        return nil
    default:
        return 18
    }
}
```

## 错误分类

| 原因 | 判断方式 | 示例 |
| --- | --- | --- |
| `missing` | Keyed 容器不包含 key | `{}` |
| `null` | key 存在且 `decodeNil` 为 true | `{"age":null}` |
| `typeMismatch` | 精确规则失败且没有来源规则接受实际类型 | `{"age":{}}` |
| `conversionFailed` | 来源类型匹配，但内容不能转换 | `{"age":"abc"}` |
| `overflow` | 内容格式合法，但超出目标数字范围 | `{"age":"999999999999999999999"}` |
| `validationFailed` | 已成功得到目标值，但业务谓词失败 | `{"age":200}` |

示例错误：

```text
[conversionFailed] User.age（$.data.users[2].age）无法将
String("abc") 转换为 Int，已使用默认值 0。
```

`SafeDecodeIssue` 提供：

- `ownerType`
- `field`
- `path`
- `pathDescription`
- `expectedType`
- `actualValue`
- `reason`
- `reasonCode`
- `fallbackValue`
- `message`

`ownerType` 根据字段 `CodingKeys` 类型生成。对于无法提供稳定 CodingKeys
类型的自定义 Decoder，它可能为 `nil`，但 `pathDescription` 仍然可用于定位。

## 读取单个属性状态

属性包装器通过 `$属性名` 暴露 `SafeDecodeStatus`：

```swift
let user = try JSONDecoder().decode(
    User.self,
    from: data
)

switch user.$age {
case .decoded:
    break

case .converted(let trace):
    print("发生容错转换：", trace)

case .fallback(let issue):
    print(issue.message)

case .initialized, .assigned:
    break
}
```

状态不会参与 JSON 编码，也不会影响包装值的 `Equatable` 和 `Hashable` 语义。
代码主动修改属性后，状态变为 `assigned`。

## Debug 与 Release 打印

默认行为：

| 构建配置 | 自动控制台打印 |
| --- | --- |
| Debug | 开启 |
| Release | 关闭 |

手动关闭：

```swift
SafeCodableDiagnostics.isAutomaticLoggingEnabled = false
```

手动开启：

```swift
SafeCodableDiagnostics.isAutomaticLoggingEnabled = true
```

恢复当前构建配置的默认值，并移除监听器：

```swift
SafeCodableDiagnostics.reset()
```

## 统一监听与线上上报

监听器与自动打印相互独立。Release 即使默认不打印，仍然会调用监听器：

```swift
SafeCodableDiagnostics.isAutomaticLoggingEnabled = false

SafeCodableDiagnostics.setListener { issue in
    OnlineErrorReporter.enqueue(
        code: issue.reasonCode,
        model: issue.ownerType,
        field: issue.field,
        path: issue.pathDescription,
        expectedType: issue.expectedType,
        actualType: issue.actualValue.typeName,
        message: issue.message
    )
}
```

移除监听器：

```swift
SafeCodableDiagnostics.setListener(nil)
```

监听器会在内部锁之外同步调用，不会被 SwiftCodable 的锁包围。监听器中不应执行
网络请求、磁盘写入等耗时操作，建议写入应用自己的内存队列，再由后台任务批量
上报。

### 推荐线上聚合维度

优先使用稳定字段聚合，不要只按完整 message：

```text
reasonCode + ownerType + field + pathDescription + expectedType + actualType
```

例如：

```text
conversionFailed | User | age | $.data.users[2].age | Int | String
```

数组下标会造成聚合离散时，可以在上报端把 `[2]` 归一化成 `[]`。

### 隐私注意

`actualValue` 可能包含接口字符串摘要，库会截断较长字符串，但无法判断业务敏感
字段。线上上报建议默认只发送 `actualValue.typeName`；只有确认安全的字段才发送
`actualValue.summary` 或完整 `message`。

## 兼容性

- `@SafeInt`、`@SafeString`、`@SafeBool` 等声明不变。
- `@SafeOptional<T>`、`@SafeArray<T>`、`@SafeDictionary<K, V>` 不变。
- 只实现 `defaultValue` 的现有 `SafeCodableDefaultValue` 不需要迁移。
- 编码结果仍然只包含 `wrappedValue`。
- missing、null 和转换失败仍默认使用原来的默认值。

变化是：容错失败现在会保留结构化状态；Debug 构建还会默认输出错误。如果旧项目
不希望控制台打印，可在应用启动时关闭：

```swift
SafeCodableDiagnostics.isAutomaticLoggingEnabled = false
```

