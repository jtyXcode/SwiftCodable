import Foundation

/// 一个为 `Codable` 模型提供函数式转换、默认值和结构化诊断的属性包装器。
///
/// - 字段正常：按声明类型解码。
/// - 字段可安全转换：按 `Default.decodingRule` 执行组合规则。
/// - 字段失败：生成 ``SafeDecodeIssue`` 并使用策略回退。
/// - `$属性名`：读取本次解码的精确状态。
@propertyWrapper
public struct SafeCodable<Default: SafeCodableDefaultValue>: Codable {
    public typealias Value = Default.Value

    private var value: Value
    private var status: SafeDecodeStatus

    public var wrappedValue: Value {
        get {
            value
        }
        set {
            value = newValue
            status = .assigned
        }
    }

    public var projectedValue: SafeDecodeStatus {
        status
    }

    public init() {
        value = Default.defaultValue
        status = .initialized
    }

    public init(wrappedValue: Value) {
        value = wrappedValue
        status = .initialized
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let actualValue = _safeActualValue(from: container)

        guard !container.decodeNil() else {
            self = Self.fallback(
                codingPath: decoder.codingPath,
                ownerType: nil,
                actualValue: .null,
                reason: .null
            )
            return
        }

        switch Default.decodingRule.decode(
            from: container,
            actualValue: actualValue
        ) {
        case .success(let decoded, let trace):
            value = decoded
            if trace.source == .exact {
                status = .decoded
            } else {
                status = .converted(trace)
            }

        case .mismatch(let actual):
            self = Self.fallback(
                codingPath: decoder.codingPath,
                ownerType: nil,
                actualValue: actual,
                reason: .typeMismatch
            )

        case .failure(let reason, let actual):
            self = Self.fallback(
                codingPath: decoder.codingPath,
                ownerType: nil,
                actualValue: actual,
                reason: reason
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    static func fallback(
        codingPath: [CodingKey],
        ownerType: String?,
        actualValue: SafeActualValue,
        reason: SafeDecodeIssue.Reason
    ) -> Self {
        let initialIssue = SafeDecodeIssue.make(
            codingPath: codingPath,
            ownerType: ownerType,
            expectedType: Value.self,
            actualValue: actualValue,
            reason: reason,
            fallbackValueDescription: nil
        )
        let fallbackValue = Default.fallback(for: initialIssue)
        let finalIssue = SafeDecodeIssue.make(
            codingPath: codingPath,
            ownerType: ownerType,
            expectedType: Value.self,
            actualValue: actualValue,
            reason: reason,
            fallbackValueDescription: String(describing: fallbackValue)
        )

        SafeCodableDiagnostics.report(finalIssue)
        return Self(
            value: fallbackValue,
            status: .fallback(finalIssue)
        )
    }

    private init(
        value: Value,
        status: SafeDecodeStatus
    ) {
        self.value = value
        self.status = status
    }
}

extension SafeCodable: Equatable where Default.Value: Equatable {
    public static func == (
        lhs: SafeCodable<Default>,
        rhs: SafeCodable<Default>
    ) -> Bool {
        lhs.value == rhs.value
    }
}

extension SafeCodable: Hashable where Default.Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

extension SafeCodable: Sendable where Default.Value: Sendable {}

public extension KeyedDecodingContainer {
    /// 该重载会被编译器合成的 `Decodable.init(from:)` 自动选中。
    ///
    /// missing 与 null 在进入属性包装器前分别记录，非空值交给函数式规则。
    func decode<Default>(
        _ type: SafeCodable<Default>.Type,
        forKey key: Key
    ) throws -> SafeCodable<Default> {
        let path = codingPath + [key]
        let ownerType = _safeOwnerTypeName(for: Key.self)

        guard contains(key) else {
            return SafeCodable<Default>.fallback(
                codingPath: path,
                ownerType: ownerType,
                actualValue: .missing,
                reason: .missing
            )
        }

        if try decodeNil(forKey: key) {
            return SafeCodable<Default>.fallback(
                codingPath: path,
                ownerType: ownerType,
                actualValue: .null,
                reason: .null
            )
        }

        return try decodeIfPresent(type, forKey: key)
            ?? SafeCodable<Default>.fallback(
                codingPath: path,
                ownerType: ownerType,
                actualValue: .null,
                reason: .null
            )
    }

    /// 解码并直接返回属性包装器中的值。
    ///
    /// 适用于手动实现 `init(from:)` 和真正不可变的 `let` 属性。
    func decodeSafeValue<Default>(
        _ type: SafeCodable<Default>.Type,
        forKey key: Key
    ) throws -> Default.Value
    where Default: SafeCodableDefaultValue {
        try decode(type, forKey: key).wrappedValue
    }
}
