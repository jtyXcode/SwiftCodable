import Foundation

/// 自定义函数式转换闭包可抛出的标准错误。
public enum SafeDecodeRuleError: Error, Sendable, Equatable {
    case conversionFailed
    case overflow
    case validationFailed(message: String)
}

/// 成功解码时记录精确解码或容错转换来源。
public struct SafeDecodeTrace: Sendable, Equatable {
    public enum Source: Sendable, Equatable {
        case exact
        case converted(from: String, to: String)
    }

    public let source: Source

    public static var exact: SafeDecodeTrace {
        SafeDecodeTrace(source: .exact)
    }

    public static func converted(
        from: Any.Type,
        to: Any.Type
    ) -> SafeDecodeTrace {
        SafeDecodeTrace(
            source: .converted(
                from: String(describing: from),
                to: String(describing: to)
            )
        )
    }
}

/// 属性包装器通过 `$属性名` 暴露的本次解码状态。
public enum SafeDecodeStatus: Sendable, Equatable {
    case initialized
    case assigned
    case decoded
    case converted(SafeDecodeTrace)
    case fallback(SafeDecodeIssue)

    public var issue: SafeDecodeIssue? {
        guard case .fallback(let issue) = self else {
            return nil
        }
        return issue
    }
}

/// 可组合的字段解码规则。
///
/// 使用 ``or(_:)`` 组合不同来源，使用 ``map(_:)`` 转换输出，
/// 使用 ``validate(_:_:)`` 添加业务校验。
public struct SafeDecodeRule<Value: Codable> {
    fileprivate let body: (_SafeDecodeInput) -> _SafeRuleOutcome<Value>

    fileprivate init(
        body: @escaping (_SafeDecodeInput) -> _SafeRuleOutcome<Value>
    ) {
        self.body = body
    }

    /// 按 `Value` 的声明类型精确解码。
    public static var exact: SafeDecodeRule<Value> {
        SafeDecodeRule<Value> { input in
            do {
                return .success(
                    try input.container.decode(Value.self),
                    .exact
                )
            } catch {
                return .mismatch(input.actualValue)
            }
        }
    }

    /// 精确解码后继续使用 SwiftCodable 内置的常用类型容错转换。
    public static var automatic: SafeDecodeRule<Value> {
        exact.or(
            SafeDecodeRule<Value> { input in
                _SafeLossyConverter<Value>.decode(input)
            }
        )
    }

    /// 从一个 `Decodable` 来源类型转换为当前输出类型。
    public static func convert<Source: Decodable>(
        _ sourceType: Source.Type,
        _ transform: @escaping (Source) throws -> Value
    ) -> SafeDecodeRule<Value> {
        SafeDecodeRule<Value> { input in
            let source: Source
            do {
                source = try input.container.decode(Source.self)
            } catch {
                return .mismatch(input.actualValue)
            }

            do {
                return .success(
                    try transform(source),
                    .converted(from: Source.self, to: Value.self)
                )
            } catch let error as SafeDecodeRuleError {
                switch error {
                case .conversionFailed:
                    return .failure(.conversionFailed, input.actualValue)
                case .overflow:
                    return .failure(.overflow, input.actualValue)
                case .validationFailed(let message):
                    return .failure(
                        .validationFailed(message: message),
                        input.actualValue
                    )
                }
            } catch {
                return .failure(.conversionFailed, input.actualValue)
            }
        }
    }

    /// 当前规则不匹配时尝试下一条规则。
    public func or(_ next: SafeDecodeRule<Value>) -> SafeDecodeRule<Value> {
        SafeDecodeRule<Value> { input in
            let outcome = body(input)
            switch outcome {
            case .mismatch:
                return next.body(input)
            case .success, .failure:
                return outcome
            }
        }
    }

    /// 转换成功值，同时保留原来的解码轨迹和错误。
    public func map<Output: Codable>(
        _ transform: @escaping (Value) -> Output
    ) -> SafeDecodeRule<Output> {
        SafeDecodeRule<Output> { input in
            switch body(input) {
            case .success(let value, let trace):
                return .success(transform(value), trace)
            case .mismatch(let actual):
                return .mismatch(actual)
            case .failure(let reason, let actual):
                return .failure(reason, actual)
            }
        }
    }

    /// 在解码或转换成功后执行业务校验。
    public func validate(
        _ message: String,
        _ predicate: @escaping (Value) -> Bool
    ) -> SafeDecodeRule<Value> {
        SafeDecodeRule<Value> { input in
            switch body(input) {
            case .success(let value, let trace):
                guard predicate(value) else {
                    return .failure(
                        .validationFailed(message: message),
                        input.actualValue
                    )
                }
                return .success(value, trace)
            case .mismatch(let actual):
                return .mismatch(actual)
            case .failure(let reason, let actual):
                return .failure(reason, actual)
            }
        }
    }
}

struct _SafeDecodeInput {
    let container: SingleValueDecodingContainer
    let actualValue: SafeActualValue
}

enum _SafeRuleOutcome<Value> {
    case success(Value, SafeDecodeTrace)
    case mismatch(SafeActualValue)
    case failure(SafeDecodeIssue.Reason, SafeActualValue)
}

extension SafeDecodeRule {
    func decode(
        from container: SingleValueDecodingContainer,
        actualValue: SafeActualValue
    ) -> _SafeRuleOutcome<Value> {
        body(
            _SafeDecodeInput(
                container: container,
                actualValue: actualValue
            )
        )
    }
}

// MARK: - Built-in lossy conversions

private enum _SafeLossyConverter<Value: Codable> {
    static func decode(_ input: _SafeDecodeInput) -> _SafeRuleOutcome<Value> {
        #if swift(>=5.7)
        let optionalType = Value.self as? any _SafeOptional.Type
        #else
        let optionalType = Value.self as? _SafeOptional.Type
        #endif
        let targetType = optionalType?.wrappedType ?? Value.self

        let converted: _SafeAnyConversion

        if targetType == String.self {
            converted = decodeString(input)
        } else if targetType == Bool.self {
            converted = decodeBool(input)
        } else if targetType == Int.self {
            converted = decodeInteger(Int.self, input)
        } else if targetType == Int8.self {
            converted = decodeInteger(Int8.self, input)
        } else if targetType == Int16.self {
            converted = decodeInteger(Int16.self, input)
        } else if targetType == Int32.self {
            converted = decodeInteger(Int32.self, input)
        } else if targetType == Int64.self {
            converted = decodeInteger(Int64.self, input)
        } else if targetType == UInt.self {
            converted = decodeInteger(UInt.self, input)
        } else if targetType == UInt8.self {
            converted = decodeInteger(UInt8.self, input)
        } else if targetType == UInt16.self {
            converted = decodeInteger(UInt16.self, input)
        } else if targetType == UInt32.self {
            converted = decodeInteger(UInt32.self, input)
        } else if targetType == UInt64.self {
            converted = decodeInteger(UInt64.self, input)
        } else if targetType == Float.self {
            converted = decodeFloat(input)
        } else if targetType == Double.self {
            converted = decodeDouble(input)
        } else if targetType == Decimal.self {
            converted = decodeDecimal(input)
        } else {
            return .mismatch(input.actualValue)
        }

        switch converted {
        case .success(let value):
            let finalValue: Any
            if let optionalType = optionalType {
                guard let optional = optionalType.makeSome(value) else {
                    return .failure(.conversionFailed, input.actualValue)
                }
                finalValue = optional
            } else {
                finalValue = value
            }

            guard let typed = finalValue as? Value else {
                return .failure(.conversionFailed, input.actualValue)
            }
            return .success(
                typed,
                .converted(from: input.actualValue.swiftType, to: targetType)
            )

        case .mismatch:
            return .mismatch(input.actualValue)
        case .failure(let reason):
            return .failure(reason, input.actualValue)
        }
    }

    private static func decodeString(
        _ input: _SafeDecodeInput
    ) -> _SafeAnyConversion {
        let container = input.container
        if let value = try? container.decode(Bool.self) {
            return .success(String(value))
        }
        if let value = try? container.decode(Int64.self) {
            return .success(String(value))
        }
        if let value = try? container.decode(UInt64.self) {
            return .success(String(value))
        }
        if let value = try? container.decode(Double.self), value.isFinite {
            return .success(String(value))
        }
        return .mismatch
    }

    private static func decodeBool(
        _ input: _SafeDecodeInput
    ) -> _SafeAnyConversion {
        let container = input.container
        if let string = try? container.decode(String.self) {
            switch normalized(string) {
            case "true", "1", "yes", "y", "on":
                return .success(true)
            case "false", "0", "no", "n", "off":
                return .success(false)
            default:
                return .failure(.conversionFailed)
            }
        }
        if let integer = try? container.decode(Int64.self) {
            return .success(integer != 0)
        }
        if let number = try? container.decode(Double.self), number.isFinite {
            return .success(number != 0)
        }
        return .mismatch
    }

    private static func decodeInteger<T: FixedWidthInteger>(
        _ type: T.Type,
        _ input: _SafeDecodeInput
    ) -> _SafeAnyConversion {
        let container = input.container
        if let string = try? container.decode(String.self) {
            let value = normalized(string)
            guard isIntegerLiteral(value) else {
                return .failure(.conversionFailed)
            }
            guard let number = T(value) else {
                return .failure(.overflow)
            }
            return .success(number)
        }
        if let signed = try? container.decode(Int64.self) {
            guard let value = T(exactly: signed) else {
                return .failure(.overflow)
            }
            return .success(value)
        }
        if let unsigned = try? container.decode(UInt64.self) {
            guard let value = T(exactly: unsigned) else {
                return .failure(.overflow)
            }
            return .success(value)
        }
        if let number = try? container.decode(Double.self), number.isFinite {
            guard number.rounded(.towardZero) == number else {
                return .failure(.conversionFailed)
            }
            guard let value = T(exactly: number) else {
                return .failure(.overflow)
            }
            return .success(value)
        }
        return .mismatch
    }

    private static func decodeFloat(
        _ input: _SafeDecodeInput
    ) -> _SafeAnyConversion {
        guard let string = try? input.container.decode(String.self) else {
            return .mismatch
        }
        guard let value = Float(normalized(string)) else {
            return .failure(.conversionFailed)
        }
        guard value.isFinite else {
            return .failure(value.isInfinite ? .overflow : .conversionFailed)
        }
        return .success(value)
    }

    private static func decodeDouble(
        _ input: _SafeDecodeInput
    ) -> _SafeAnyConversion {
        guard let string = try? input.container.decode(String.self) else {
            return .mismatch
        }
        guard let value = Double(normalized(string)) else {
            return .failure(.conversionFailed)
        }
        guard value.isFinite else {
            return .failure(value.isInfinite ? .overflow : .conversionFailed)
        }
        return .success(value)
    }

    private static func decodeDecimal(
        _ input: _SafeDecodeInput
    ) -> _SafeAnyConversion {
        guard let string = try? input.container.decode(String.self) else {
            return .mismatch
        }
        let literal = normalized(string)
        guard isDecimalLiteral(literal) else {
            return .failure(.conversionFailed)
        }
        guard let value = Decimal(
            string: literal,
            locale: Locale(identifier: "en_US_POSIX")
        ) else {
            return .failure(.conversionFailed)
        }
        return .success(value)
    }

    private static func normalized(_ string: String) -> String {
        string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isIntegerLiteral(_ string: String) -> Bool {
        guard !string.isEmpty else {
            return false
        }
        let digits: Substring
        if string.first == "+" || string.first == "-" {
            digits = string.dropFirst()
        } else {
            digits = string[...]
        }
        return !digits.isEmpty
            && digits.utf8.allSatisfy { (48...57).contains($0) }
    }

    /// 接受 `[+-]?(digits[.digits?]?|.digits)([eE][+-]?digits)?`，
    /// 并要求整个输入均被该语法覆盖。
    private static func isDecimalLiteral(_ string: String) -> Bool {
        let bytes = Array(string.utf8)
        guard !bytes.isEmpty else {
            return false
        }

        var index = 0
        if bytes[index] == 43 || bytes[index] == 45 {
            index += 1
        }

        let integerStart = index
        while index < bytes.count, (48...57).contains(bytes[index]) {
            index += 1
        }
        let integerDigits = index - integerStart

        var fractionDigits = 0
        if index < bytes.count, bytes[index] == 46 {
            index += 1
            let fractionStart = index
            while index < bytes.count, (48...57).contains(bytes[index]) {
                index += 1
            }
            fractionDigits = index - fractionStart
        }

        guard integerDigits + fractionDigits > 0 else {
            return false
        }

        if index < bytes.count, bytes[index] == 101 {
            index += 1
            if index < bytes.count, bytes[index] == 43 || bytes[index] == 45 {
                index += 1
            }
            let exponentStart = index
            while index < bytes.count, (48...57).contains(bytes[index]) {
                index += 1
            }
            guard index > exponentStart else {
                return false
            }
        }

        return index == bytes.count
    }
}

private enum _SafeAnyConversion {
    case success(Any)
    case mismatch
    case failure(SafeDecodeIssue.Reason)
}

private extension SafeActualValue {
    var swiftType: Any.Type {
        switch self {
        case .string:
            return String.self
        case .integer:
            return Int64.self
        case .floatingPoint:
            return Double.self
        case .bool:
            return Bool.self
        case .null:
            return Optional<Any>.self
        case .array:
            return Array<Any>.self
        case .object:
            return Dictionary<String, Any>.self
        case .missing, .unknown:
            return Any.self
        }
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
