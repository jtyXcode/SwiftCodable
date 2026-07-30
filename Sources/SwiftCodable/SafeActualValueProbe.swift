import Foundation

func _safeActualValue(
    from container: SingleValueDecodingContainer
) -> SafeActualValue {
    if container.decodeNil() {
        return .null
    }
    if let value = try? container.decode(Bool.self) {
        return .bool(value)
    }
    if let value = try? container.decode(String.self) {
        return .string(value)
    }
    if let value = try? container.decode(Int64.self) {
        return .integer(String(value))
    }
    if let value = try? container.decode(UInt64.self) {
        return .integer(String(value))
    }
    if let value = try? container.decode(Double.self) {
        return .floatingPoint(String(value))
    }
    if let probe = try? container.decode(_SafeStructuredValueProbe.self) {
        return probe.value
    }
    return .unknown
}

private struct _SafeStructuredValueProbe: Decodable {
    let value: SafeActualValue

    init(from decoder: Decoder) throws {
        if (try? decoder.unkeyedContainer()) != nil {
            value = .array
            return
        }
        if (try? decoder.container(keyedBy: DynamicCodingKey.self)) != nil {
            value = .object
            return
        }
        value = .unknown
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}
