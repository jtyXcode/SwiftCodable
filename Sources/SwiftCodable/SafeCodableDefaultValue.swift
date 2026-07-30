import Foundation

/// 为 ``SafeCodable`` 提供在字段缺失、为 `null` 或无法转换时使用的默认值。
///
/// 自定义业务默认值示例：
///
/// ```swift
/// enum DefaultPageSize: SafeCodableDefaultValue {
///     static let defaultValue = 20
/// }
/// ```
public protocol SafeCodableDefaultValue {
    associatedtype Value: Codable

    static var defaultValue: Value { get }

    /// 当前值类型使用的函数式解码规则。
    ///
    /// 默认规则保持原有行为：先精确解码，再执行 String、数字和 Bool
    /// 之间的常用安全转换。已有自定义默认值无需增加任何代码。
    static var decodingRule: SafeDecodeRule<Value> { get }

    /// 字段解码失败时生成最终回退值。
    ///
    /// 默认返回 ``defaultValue``。业务可以根据 missing、null、
    /// conversionFailed 等原因返回不同结果。
    static func fallback(for issue: SafeDecodeIssue) -> Value
}

public extension SafeCodableDefaultValue {
    static var decodingRule: SafeDecodeRule<Value> {
        .automatic
    }

    static func fallback(for issue: SafeDecodeIssue) -> Value {
        defaultValue
    }
}

/// SwiftCodable 内置的常用默认值。
public enum SafeDefaults {
    public enum EmptyString: SafeCodableDefaultValue {
        public static let defaultValue = ""
    }

    public enum ZeroInt: SafeCodableDefaultValue {
        public static let defaultValue = 0
    }

    public enum ZeroInt8: SafeCodableDefaultValue {
        public static let defaultValue: Int8 = 0
    }

    public enum ZeroInt16: SafeCodableDefaultValue {
        public static let defaultValue: Int16 = 0
    }

    public enum ZeroInt32: SafeCodableDefaultValue {
        public static let defaultValue: Int32 = 0
    }

    public enum ZeroInt64: SafeCodableDefaultValue {
        public static let defaultValue: Int64 = 0
    }

    public enum ZeroUInt: SafeCodableDefaultValue {
        public static let defaultValue: UInt = 0
    }

    public enum ZeroUInt8: SafeCodableDefaultValue {
        public static let defaultValue: UInt8 = 0
    }

    public enum ZeroUInt16: SafeCodableDefaultValue {
        public static let defaultValue: UInt16 = 0
    }

    public enum ZeroUInt32: SafeCodableDefaultValue {
        public static let defaultValue: UInt32 = 0
    }

    public enum ZeroUInt64: SafeCodableDefaultValue {
        public static let defaultValue: UInt64 = 0
    }

    public enum ZeroFloat: SafeCodableDefaultValue {
        public static let defaultValue: Float = 0
    }

    public enum ZeroDouble: SafeCodableDefaultValue {
        public static let defaultValue: Double = 0
    }

    public enum ZeroDecimal: SafeCodableDefaultValue {
        public static let defaultValue: Decimal = 0
    }

    public enum False: SafeCodableDefaultValue {
        public static let defaultValue = false
    }

    public enum True: SafeCodableDefaultValue {
        public static let defaultValue = true
    }

    public enum Nil<Wrapped: Codable>: SafeCodableDefaultValue {
        public static var defaultValue: Wrapped? { nil }
    }

    public enum EmptyArray<Element: Codable>: SafeCodableDefaultValue {
        public static var defaultValue: [Element] { [] }
    }

    public enum EmptyDictionary<Key: Hashable & Codable, Value: Codable>: SafeCodableDefaultValue {
        public static var defaultValue: [Key: Value] { [:] }
    }
}
