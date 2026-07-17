import Foundation

public typealias SafeString = SafeCodable<SafeDefaults.EmptyString>
public typealias SafeInt = SafeCodable<SafeDefaults.ZeroInt>
public typealias SafeInt8 = SafeCodable<SafeDefaults.ZeroInt8>
public typealias SafeInt16 = SafeCodable<SafeDefaults.ZeroInt16>
public typealias SafeInt32 = SafeCodable<SafeDefaults.ZeroInt32>
public typealias SafeInt64 = SafeCodable<SafeDefaults.ZeroInt64>
public typealias SafeUInt = SafeCodable<SafeDefaults.ZeroUInt>
public typealias SafeUInt8 = SafeCodable<SafeDefaults.ZeroUInt8>
public typealias SafeUInt16 = SafeCodable<SafeDefaults.ZeroUInt16>
public typealias SafeUInt32 = SafeCodable<SafeDefaults.ZeroUInt32>
public typealias SafeUInt64 = SafeCodable<SafeDefaults.ZeroUInt64>
public typealias SafeFloat = SafeCodable<SafeDefaults.ZeroFloat>
public typealias SafeDouble = SafeCodable<SafeDefaults.ZeroDouble>
public typealias SafeDecimal = SafeCodable<SafeDefaults.ZeroDecimal>
public typealias SafeBool = SafeCodable<SafeDefaults.False>

public typealias SafeOptional<Wrapped: Codable> =
    SafeCodable<SafeDefaults.Nil<Wrapped>>

public typealias SafeArray<Element: Codable> =
    SafeCodable<SafeDefaults.EmptyArray<Element>>

public typealias SafeDictionary<Key: Hashable & Codable, Value: Codable> =
    SafeCodable<SafeDefaults.EmptyDictionary<Key, Value>>
