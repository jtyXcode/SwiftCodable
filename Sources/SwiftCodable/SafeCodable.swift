import Foundation

/// 一个为 `Codable` 模型提供默认值和常用类型容错转换的属性包装器。
///
/// - 字段正常：按声明类型解码。
/// - 字段类型可安全转换：进行 String、数字、Bool 之间的常用转换。
/// - 字段缺失、为 null 或无法转换：使用 `Default.defaultValue`。
@propertyWrapper
public struct SafeCodable<Default: SafeCodableDefaultValue>: Codable {
    public typealias Value = Default.Value

    public var wrappedValue: Value

    public init() {
        wrappedValue = Default.defaultValue
    }

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        guard !container.decodeNil() else {
            wrappedValue = Default.defaultValue
            return
        }

        if let value = try? container.decode(Value.self) {
            wrappedValue = value
            return
        }

        wrappedValue = Self.decodeLossy(from: container) ?? Default.defaultValue
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension SafeCodable: Equatable where Default.Value: Equatable {}
extension SafeCodable: Hashable where Default.Value: Hashable {}
extension SafeCodable: Sendable where Default.Value: Sendable {}

public extension KeyedDecodingContainer {
    /// 该重载会被编译器合成的 `Decodable.init(from:)` 自动选中。
    ///
    /// `decodeIfPresent` 处理缺失和 null；非 null 的脏数据由
    /// ``SafeCodable/init(from:)`` 处理，因此不会递归调用自身。
    func decode<Default>(
        _ type: SafeCodable<Default>.Type,
        forKey key: Key
    ) throws -> SafeCodable<Default> {
        try decodeIfPresent(type, forKey: key) ?? SafeCodable()
    }
}

// MARK: - Lossy conversion

private extension SafeCodable {
    static func decodeLossy(
        from container: SingleValueDecodingContainer
    ) -> Value? {
        #if swift(>=5.7)
        let optionalType = Value.self as? any _SafeOptional.Type
        #else
        let optionalType = Value.self as? _SafeOptional.Type
        #endif
        let targetType = optionalType?.wrappedType ?? Value.self

        let converted: Any?

        if targetType == String.self {
            converted = decodeString(from: container)
        } else if targetType == Bool.self {
            converted = decodeBool(from: container)
        } else if targetType == Int.self {
            converted = decodeInteger(Int.self, from: container)
        } else if targetType == Int8.self {
            converted = decodeInteger(Int8.self, from: container)
        } else if targetType == Int16.self {
            converted = decodeInteger(Int16.self, from: container)
        } else if targetType == Int32.self {
            converted = decodeInteger(Int32.self, from: container)
        } else if targetType == Int64.self {
            converted = decodeInteger(Int64.self, from: container)
        } else if targetType == UInt.self {
            converted = decodeInteger(UInt.self, from: container)
        } else if targetType == UInt8.self {
            converted = decodeInteger(UInt8.self, from: container)
        } else if targetType == UInt16.self {
            converted = decodeInteger(UInt16.self, from: container)
        } else if targetType == UInt32.self {
            converted = decodeInteger(UInt32.self, from: container)
        } else if targetType == UInt64.self {
            converted = decodeInteger(UInt64.self, from: container)
        } else if targetType == Float.self {
            converted = decodeFloat(from: container)
        } else if targetType == Double.self {
            converted = decodeDouble(from: container)
        } else if targetType == Decimal.self {
            converted = decodeDecimal(from: container)
        } else {
            converted = nil
        }

        guard let converted = converted else {
            return nil
        }

        if let optionalType = optionalType {
            return optionalType.makeSome(converted) as? Value
        }

        return converted as? Value
    }

    static func decodeString(
        from container: SingleValueDecodingContainer
    ) -> String? {
        if let value = try? container.decode(Bool.self) {
            return String(value)
        }

        if let value = try? container.decode(Int64.self) {
            return String(value)
        }

        if let value = try? container.decode(UInt64.self) {
            return String(value)
        }

        if let value = try? container.decode(Double.self), value.isFinite {
            return String(value)
        }

        return nil
    }

    static func decodeBool(
        from container: SingleValueDecodingContainer
    ) -> Bool? {
        if let string = try? container.decode(String.self) {
            switch normalized(string) {
            case "true", "1", "yes", "y", "on":
                return true
            case "false", "0", "no", "n", "off":
                return false
            default:
                return nil
            }
        }

        if let integer = try? container.decode(Int64.self) {
            return integer != 0
        }

        if let number = try? container.decode(Double.self), number.isFinite {
            return number != 0
        }

        return nil
    }

    static func decodeInteger<T: FixedWidthInteger>(
        _ type: T.Type,
        from container: SingleValueDecodingContainer
    ) -> T? {
        if let string = try? container.decode(String.self) {
            return T(normalized(string))
        }

        if let signed = try? container.decode(Int64.self),
           let value = T(exactly: signed) {
            return value
        }

        if let unsigned = try? container.decode(UInt64.self),
           let value = T(exactly: unsigned) {
            return value
        }

        if let number = try? container.decode(Double.self),
           number.isFinite,
           number.rounded(.towardZero) == number {
            return T(exactly: number)
        }

        return nil
    }

    static func decodeFloat(
        from container: SingleValueDecodingContainer
    ) -> Float? {
        guard let string = try? container.decode(String.self) else {
            return nil
        }

        return Float(normalized(string))
    }

    static func decodeDouble(
        from container: SingleValueDecodingContainer
    ) -> Double? {
        guard let string = try? container.decode(String.self) else {
            return nil
        }

        return Double(normalized(string))
    }

    static func decodeDecimal(
        from container: SingleValueDecodingContainer
    ) -> Decimal? {
        guard let string = try? container.decode(String.self) else {
            return nil
        }

        return Decimal(
            string: normalized(string),
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    static func normalized(_ string: String) -> String {
        string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private protocol _SafeOptional {
    static var wrappedType: Any.Type { get }
    static func makeSome(_ value: Any) -> Any?
}

extension Optional: _SafeOptional {
    static var wrappedType: Any.Type {
        Wrapped.self
    }

    static func makeSome(_ value: Any) -> Any? {
        guard let wrapped = value as? Wrapped else {
            return nil
        }

        return Optional.some(wrapped)
    }
}
