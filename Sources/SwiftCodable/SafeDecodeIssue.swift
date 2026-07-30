import Foundation

/// Codable 字段在容错解码过程中产生的问题。
public struct SafeDecodeIssue: Error, Sendable, Equatable {
    public enum Reason: Sendable, Equatable {
        case missing
        case null
        case typeMismatch
        case conversionFailed
        case overflow
        case validationFailed(message: String)
    }

    /// 字段所属模型的最佳可用类型名。
    ///
    /// 标准 `Decoder` 不直接暴露所属模型。本值根据 `CodingKeys` 类型生成；
    /// 无法可靠识别时为 `nil`，此时仍可通过 ``pathDescription`` 精确定位。
    public let ownerType: String?

    /// JSON 中的字段名。
    public let field: String?

    /// 从根节点开始的完整 CodingPath。
    public let path: [SafeCodingPathComponent]

    /// 字段声明所期望的 Swift 类型。
    public let expectedType: String

    /// 输入数据的实际类型和值摘要。
    public let actualValue: SafeActualValue

    /// 失败原因。
    public let reason: Reason

    /// 容错后使用的值摘要。
    public let fallbackValue: String?

    public var pathDescription: String {
        path.reduce(into: "$") { result, component in
            switch component {
            case .key(let key):
                result += ".\(_safeDiagnosticText(key))"
            case .index(let index):
                result += "[\(index)]"
            }
        }
    }

    public var reasonCode: String {
        switch reason {
        case .missing:
            return "missing"
        case .null:
            return "null"
        case .typeMismatch:
            return "typeMismatch"
        case .conversionFailed:
            return "conversionFailed"
        case .overflow:
            return "overflow"
        case .validationFailed:
            return "validationFailed"
        }
    }

    /// 面向开发者和日志系统的简洁中文错误。
    public var message: String {
        let location: String
        if let ownerType = ownerType, let field = field {
            location = "\(_safeDiagnosticText(Self.shortTypeName(ownerType)))."
                + "\(_safeDiagnosticText(field))（\(pathDescription)）"
        } else {
            location = pathDescription
        }

        let fallback: String
        if let fallbackValue = fallbackValue {
            fallback = "已使用默认值 \(_safeDiagnosticText(fallbackValue))。"
        } else {
            fallback = "将按策略使用回退值。"
        }

        let safeExpectedType = _safeDiagnosticText(expectedType)
        switch reason {
        case .missing:
            return "\(location) 字段缺失，期望 \(safeExpectedType)，\(fallback)"
        case .null:
            return "\(location) 收到 null，期望 \(safeExpectedType)，\(fallback)"
        case .typeMismatch:
            return "\(location) 类型错误：期望 \(safeExpectedType)，实际为 \(actualValue.summary)，\(fallback)"
        case .conversionFailed:
            return "\(location) 无法将 \(actualValue.summary) 转换为 \(safeExpectedType)，\(fallback)"
        case .overflow:
            return "\(location) 的 \(actualValue.summary) 超出 \(safeExpectedType) 可表示范围，\(fallback)"
        case .validationFailed(let message):
            return "\(location) 未通过校验：\(_safeDiagnosticText(message))，实际为 \(actualValue.summary)，\(fallback)"
        }
    }

    private static func shortTypeName(_ typeName: String) -> String {
        typeName.split(separator: ".").last.map(String.init) ?? typeName
    }
}

extension SafeDecodeIssue: CustomStringConvertible {
    public var description: String {
        "[\(reasonCode)] \(message)"
    }
}

extension SafeDecodeIssue: LocalizedError {
    public var errorDescription: String? {
        message
    }
}

public enum SafeCodingPathComponent: Sendable, Equatable {
    case key(String)
    case index(Int)

    init(_ key: CodingKey) {
        if let index = key.intValue {
            self = .index(index)
        } else {
            self = .key(key.stringValue)
        }
    }
}

public enum SafeActualValue: Sendable, Equatable {
    case missing
    case null
    case string(String)
    case integer(String)
    case floatingPoint(String)
    case bool(Bool)
    case array
    case object
    case unknown

    public var typeName: String {
        switch self {
        case .missing:
            return "Missing"
        case .null:
            return "Null"
        case .string:
            return "String"
        case .integer:
            return "Integer"
        case .floatingPoint:
            return "FloatingPoint"
        case .bool:
            return "Bool"
        case .array:
            return "Array"
        case .object:
            return "Object"
        case .unknown:
            return "Unknown"
        }
    }

    public var summary: String {
        switch self {
        case .missing:
            return "缺失值"
        case .null:
            return "null"
        case .string(let value):
            return "String(\"\(Self.preview(value))\")"
        case .integer(let value):
            return "Integer(\(value))"
        case .floatingPoint(let value):
            return "FloatingPoint(\(value))"
        case .bool(let value):
            return "Bool(\(value))"
        case .array:
            return "Array"
        case .object:
            return "Object"
        case .unknown:
            return "未知类型"
        }
    }

    private static func preview(_ value: String) -> String {
        let limit = 64
        let prefix = value.unicodeScalars.prefix(limit)
        var result = _safeDiagnosticText(String(prefix))
        if value.unicodeScalars.dropFirst(limit).isEmpty {
            return result
        }
        result += "…"
        return result
    }
}

/// 将诊断边界中的控制字符编码为可见文本，避免终端和日志查看器解释它们。
private func _safeDiagnosticText(_ value: String) -> String {
    var result = ""
    result.reserveCapacity(value.count)

    for scalar in value.unicodeScalars {
        switch scalar.value {
        case 0x0A:
            result += "\\n"
        case 0x0D:
            result += "\\r"
        case 0x09:
            result += "\\t"
        case 0x00...0x1F, 0x7F...0x9F, 0x2028, 0x2029:
            result += "\\u{\(String(scalar.value, radix: 16, uppercase: true))}"
        default:
            result.unicodeScalars.append(scalar)
        }
    }

    return result
}

extension SafeDecodeIssue {
    static func make(
        codingPath: [CodingKey],
        ownerType: String?,
        expectedType: Any.Type,
        actualValue: SafeActualValue,
        reason: Reason,
        fallbackValueDescription: String?
    ) -> SafeDecodeIssue {
        SafeDecodeIssue(
            ownerType: ownerType ?? _safeOwnerTypeName(from: codingPath),
            field: codingPath.last?.stringValue,
            path: codingPath.map(SafeCodingPathComponent.init),
            expectedType: String(describing: expectedType),
            actualValue: actualValue,
            reason: reason,
            fallbackValue: fallbackValueDescription
        )
    }
}

func _safeOwnerTypeName(from codingPath: [CodingKey]) -> String? {
    guard let lastKey = codingPath.last else {
        return nil
    }
    return _safeOwnerTypeName(fromKeyTypeName: String(reflecting: type(of: lastKey)))
}

func _safeOwnerTypeName<Key: CodingKey>(for keyType: Key.Type) -> String? {
    _safeOwnerTypeName(fromKeyTypeName: String(reflecting: keyType))
}

private func _safeOwnerTypeName(fromKeyTypeName name: String) -> String? {
    let suffix = ".CodingKeys"
    guard name.hasSuffix(suffix) else {
        return nil
    }
    var owner = String(name.dropLast(suffix.count))
    while let start = owner.range(of: "(unknown context")?.lowerBound,
          let end = owner[start...].firstIndex(of: ")") {
        var removalEnd = owner.index(after: end)
        if removalEnd < owner.endIndex, owner[removalEnd] == "." {
            removalEnd = owner.index(after: removalEnd)
        }
        owner.removeSubrange(start..<removalEnd)
    }
    return owner.isEmpty ? nil : owner
}
