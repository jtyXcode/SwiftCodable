import Foundation
import XCTest
@testable import SwiftCodable

final class SafeCodableTests: XCTestCase {
    func testMissingKeysUseCommonDefaults() throws {
        let value = try decode(CommonValues.self, from: "{}")

        XCTAssertEqual(value.string, "")
        XCTAssertEqual(value.int, 0)
        XCTAssertEqual(value.int64, 0)
        XCTAssertEqual(value.uint, 0)
        XCTAssertEqual(value.float, 0)
        XCTAssertEqual(value.double, 0)
        XCTAssertEqual(value.decimal, 0)
        XCTAssertFalse(value.bool)
        XCTAssertTrue(value.trueBool)
    }

    func testNullUsesDefaults() throws {
        let value = try decode(
            CommonValues.self,
            from: """
            {
              "string": null,
              "int": null,
              "int64": null,
              "uint": null,
              "float": null,
              "double": null,
              "decimal": null,
              "bool": null,
              "trueBool": null
            }
            """
        )

        XCTAssertEqual(value.string, "")
        XCTAssertEqual(value.int, 0)
        XCTAssertEqual(value.double, 0)
        XCTAssertFalse(value.bool)
        XCTAssertTrue(value.trueBool)
    }

    func testStringNumericAndBoolLossyConversions() throws {
        let value = try decode(
            CommonValues.self,
            from: """
            {
              "string": 9527,
              "int": " 42 ",
              "int64": "9223372036854775807",
              "uint": "12",
              "float": "1.25",
              "double": "3.1415",
              "decimal": "19.99",
              "bool": "YES",
              "trueBool": "off"
            }
            """
        )

        XCTAssertEqual(value.string, "9527")
        XCTAssertEqual(value.int, 42)
        XCTAssertEqual(value.int64, Int64.max)
        XCTAssertEqual(value.uint, 12)
        XCTAssertEqual(value.float, 1.25, accuracy: 0.0001)
        XCTAssertEqual(value.double, 3.1415, accuracy: 0.0001)
        XCTAssertEqual(value.decimal, Decimal(string: "19.99"))
        XCTAssertTrue(value.bool)
        XCTAssertFalse(value.trueBool)
    }

    func testAllIntegerConvenienceWrappers() throws {
        let value = try decode(
            IntegerValues.self,
            from: """
            {
              "int": "-1",
              "int8": "-8",
              "int16": "-16",
              "int32": "-32",
              "int64": "-64",
              "uint": "1",
              "uint8": "8",
              "uint16": "16",
              "uint32": "32",
              "uint64": "64"
            }
            """
        )

        XCTAssertEqual(value.int, -1)
        XCTAssertEqual(value.int8, -8)
        XCTAssertEqual(value.int16, -16)
        XCTAssertEqual(value.int32, -32)
        XCTAssertEqual(value.int64, -64)
        XCTAssertEqual(value.uint, 1)
        XCTAssertEqual(value.uint8, 8)
        XCTAssertEqual(value.uint16, 16)
        XCTAssertEqual(value.uint32, 32)
        XCTAssertEqual(value.uint64, 64)
    }

    func testStringConvertsBoolAndFloatingPointSources() throws {
        let bool = try decode(StringValue.self, from: #"{"value":true}"#)
        let double = try decode(StringValue.self, from: #"{"value":1.25}"#)

        XCTAssertEqual(bool.value, "true")
        XCTAssertEqual(double.value, "1.25")
    }

    func testBoolSupportsNumericInputs() throws {
        let trueValue = try decode(BoolValue.self, from: #"{"value":2}"#)
        let falseValue = try decode(BoolValue.self, from: #"{"value":0}"#)

        XCTAssertTrue(trueValue.value)
        XCTAssertFalse(falseValue.value)
    }

    func testInvalidAndOverflowValuesFallBack() throws {
        let value = try decode(
            BoundaryValues.self,
            from: """
            {
              "small": "128",
              "unsigned": "-1",
              "integer": 1.5,
              "bool": "sometimes"
            }
            """
        )

        XCTAssertEqual(value.small, 0)
        XCTAssertEqual(value.unsigned, 0)
        XCTAssertEqual(value.integer, 0)
        XCTAssertFalse(value.bool)
    }

    func testOptionalCommonValuesSupportExactAndLossyDecode() throws {
        let value = try decode(
            OptionalValues.self,
            from: """
            {
              "int": "18",
              "bool": "true",
              "string": 100,
              "double": "6.25"
            }
            """
        )

        XCTAssertEqual(value.int, 18)
        XCTAssertEqual(value.bool, true)
        XCTAssertEqual(value.string, "100")
        XCTAssertEqual(value.double, 6.25)
    }

    func testOptionalValuesBecomeNilForMissingNullAndInvalidInputs() throws {
        let missing = try decode(OptionalValues.self, from: "{}")
        let null = try decode(
            OptionalValues.self,
            from: """
            {"int":null,"bool":null,"string":null,"double":null}
            """
        )
        let invalid = try decode(
            OptionalValues.self,
            from: """
            {"int":"x","bool":"x","string":[],"double":"x"}
            """
        )

        XCTAssertNil(missing.int)
        XCTAssertNil(null.bool)
        XCTAssertNil(invalid.string)
        XCTAssertNil(invalid.double)
    }

    func testCustomDefaultHandlesMissingNullAndInvalidValues() throws {
        let missing = try decode(CustomDefaultValue.self, from: "{}")
        let null = try decode(CustomDefaultValue.self, from: #"{"pageSize":null}"#)
        let invalid = try decode(CustomDefaultValue.self, from: #"{"pageSize":"many"}"#)
        let valid = try decode(CustomDefaultValue.self, from: #"{"pageSize":"50"}"#)

        XCTAssertEqual(missing.pageSize, 20)
        XCTAssertEqual(null.pageSize, 20)
        XCTAssertEqual(invalid.pageSize, 20)
        XCTAssertEqual(valid.pageSize, 50)
    }

    func testDeeplyNestedModelsKeepDecodingWhenLeavesAreDirty() throws {
        let value = try decode(
            Root.self,
            from: """
            {
              "company": {
                "teams": [
                  {
                    "name": 101,
                    "members": [
                      {"name": "Ana", "age": "31", "active": "1"},
                      {"name": null, "age": "unknown", "active": "no"}
                    ]
                  }
                ]
              }
            }
            """
        )

        let team = try XCTUnwrap(value.company?.teams.first)
        XCTAssertEqual(team.name, "101")
        XCTAssertEqual(team.members.count, 2)
        XCTAssertEqual(team.members[0].name, "Ana")
        XCTAssertEqual(team.members[0].age, 31)
        XCTAssertTrue(team.members[0].active)
        XCTAssertEqual(team.members[1].name, "")
        XCTAssertEqual(team.members[1].age, 0)
        XCTAssertFalse(team.members[1].active)
    }

    func testCollectionsUseEmptyDefaults() throws {
        let missing = try decode(Collections.self, from: "{}")
        let invalid = try decode(
            Collections.self,
            from: #"{"items":"not-an-array","lookup":[]}"#
        )

        XCTAssertEqual(missing.items, [])
        XCTAssertEqual(missing.lookup, [:])
        XCTAssertEqual(invalid.items, [])
        XCTAssertEqual(invalid.lookup, [:])
    }

    func testInvalidNestedObjectCanUseBusinessDefault() throws {
        let value = try decode(
            FeatureContainer.self,
            from: #"{"feature":"invalid"}"#
        )

        XCTAssertEqual(value.feature, Feature(name: "fallback", level: 1))
    }

    func testEncodingRoundTripUsesWrappedValues() throws {
        let original = try decode(
            RoundTrip.self,
            from: #"{"name":123,"count":"7","flag":"true"}"#
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RoundTrip.self, from: data)

        XCTAssertEqual(decoded, original)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(object["name"] as? String, "123")
        XCTAssertEqual(object["count"] as? Int, 7)
        XCTAssertEqual(object["flag"] as? Bool, true)
    }

    func testTopLevelWrapperCanDecodeAndEncode() throws {
        let wrapper = try JSONDecoder().decode(
            SafeInt.self,
            from: Data(#""99""#.utf8)
        )

        XCTAssertEqual(wrapper.wrappedValue, 99)
        XCTAssertEqual(
            String(data: try JSONEncoder().encode(wrapper), encoding: .utf8),
            "99"
        )
    }

    func testOptionalDefaultCanBeModifiedAndRoundTripped() throws {
        let user = ArchiveTestUser()
        XCTAssertEqual(user.nickname, "游客")

        user.nickname = "Tom"

        let data = try JSONEncoder().encode(user)
        let restored = try JSONDecoder().decode(ArchiveTestUser.self, from: data)

        XCTAssertEqual(restored.nickname, "Tom")
    }

    func testExplicitNilReturnsToNonNilDefaultAfterRoundTrip() throws {
        let user = ArchiveTestUser()
        user.nickname = nil

        let data = try JSONEncoder().encode(user)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let restored = try JSONDecoder().decode(ArchiveTestUser.self, from: data)

        XCTAssertTrue(object["nickname"] is NSNull)
        XCTAssertEqual(restored.nickname, "游客")
    }

    func testComputedClassDefaultCreatesIndependentInstances() {
        let first = ArchiveTestUser()
        let second = ArchiveTestUser()

        XCTAssertNotNil(first.profile)
        XCTAssertNotNil(second.profile)
        XCTAssertFalse(first.profile === second.profile)

        first.profile?.displayName = "已修改"

        XCTAssertEqual(first.profile?.displayName, "已修改")
        XCTAssertEqual(second.profile?.displayName, "默认资料")
    }

    func testRealDevicePropertyDisconnectPayload() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: "device_property_disconnect",
                withExtension: "json"
            )
        )
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let message = try decoder.decode(DeviceMessage.self, from: data)
        let properties = try XCTUnwrap(message.data)

        XCTAssertEqual(message.clientId, "VSF101265200040DE")
        XCTAssertEqual(message.requestId, "1593")
        XCTAssertEqual(message.timestamp, 1_784_273_874_665)
        XCTAssertNil(message.messageId)
        XCTAssertEqual(message.messageType, "property")
        XCTAssertEqual(message.action, "disconnect")

        XCTAssertEqual(properties.bindUserId, 2_047_212_303_078_641_666)
        XCTAssertEqual(properties.deviceModel, "Mero F10")
        XCTAssertEqual(properties.deviceName, "Mero F10 40DE")
        XCTAssertEqual(properties.deviceTime, "2026-07-17 15:37:54")
        XCTAssertEqual(properties.ipAddress, "192.168.124.171")
        XCTAssertEqual(properties.firmwareVersion, "1.1.34")
        XCTAssertEqual(properties.mcuVersion, "1.1.37")
        XCTAssertEqual(properties.powerLevel, 80)
        XCTAssertEqual(properties.recordResolution, "1920x1080")
        XCTAssertEqual(properties.rtsaLowResolution, "720x480")
        XCTAssertEqual(properties.tfAllCap, 29.280000686645508)
        XCTAssertEqual(properties.tfAvilCap, 27.969999313354492)
        XCTAssertEqual(properties.wifiSsid, "VS_AI_TEST_5G")
        XCTAssertEqual(properties.volume, 50)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let roundTripData = try encoder.encode(message)
        let roundTrip = try decoder.decode(DeviceMessage.self, from: roundTripData)

        XCTAssertEqual(roundTrip.clientId, message.clientId)
        XCTAssertEqual(roundTrip.data?.bindUserId, properties.bindUserId)
        XCTAssertEqual(roundTrip.data?.rtsaResolution, "1920x1080")
    }
}

// MARK: - Fixtures

private struct CommonValues: Codable {
    @SafeString var string: String
    @SafeInt var int: Int
    @SafeInt64 var int64: Int64
    @SafeUInt var uint: UInt
    @SafeFloat var float: Float
    @SafeDouble var double: Double
    @SafeDecimal var decimal: Decimal
    @SafeBool var bool: Bool
    @SafeCodable<SafeDefaults.True> var trueBool: Bool
}

private struct BoolValue: Codable {
    @SafeBool var value: Bool
}

private struct StringValue: Codable {
    @SafeString var value: String
}

private struct IntegerValues: Codable {
    @SafeInt var int: Int
    @SafeInt8 var int8: Int8
    @SafeInt16 var int16: Int16
    @SafeInt32 var int32: Int32
    @SafeInt64 var int64: Int64
    @SafeUInt var uint: UInt
    @SafeUInt8 var uint8: UInt8
    @SafeUInt16 var uint16: UInt16
    @SafeUInt32 var uint32: UInt32
    @SafeUInt64 var uint64: UInt64
}

private struct BoundaryValues: Codable {
    @SafeInt8 var small: Int8
    @SafeUInt var unsigned: UInt
    @SafeInt var integer: Int
    @SafeBool var bool: Bool
}

private struct OptionalValues: Codable {
    @SafeOptional<Int> var int: Int?
    @SafeOptional<Bool> var bool: Bool?
    @SafeOptional<String> var string: String?
    @SafeOptional<Double> var double: Double?
}

private enum PageSize20: SafeCodableDefaultValue {
    static let defaultValue = 20
}

private struct CustomDefaultValue: Codable {
    @SafeCodable<PageSize20> var pageSize: Int
}

private struct Root: Codable {
    @SafeOptional<Company> var company: Company?
}

private struct Company: Codable {
    @SafeArray<Team> var teams: [Team]
}

private struct Team: Codable {
    @SafeString var name: String
    @SafeArray<Member> var members: [Member]
}

private struct Member: Codable {
    @SafeString var name: String
    @SafeInt var age: Int
    @SafeBool var active: Bool
}

private struct Collections: Codable {
    @SafeArray<Int> var items: [Int]
    @SafeDictionary<String, Int> var lookup: [String: Int]
}

private struct Feature: Codable, Equatable {
    let name: String
    let level: Int
}

private enum DefaultFeature: SafeCodableDefaultValue {
    static let defaultValue = Feature(name: "fallback", level: 1)
}

private struct FeatureContainer: Codable {
    @SafeCodable<DefaultFeature> var feature: Feature
}

private struct RoundTrip: Codable, Equatable {
    @SafeString var name: String
    @SafeInt var count: Int
    @SafeBool var flag: Bool
}

private enum ArchiveTestNicknameDefault: SafeCodableDefaultValue {
    static let defaultValue: String? = "游客"
}

private final class ArchiveTestProfile: Codable {
    @SafeString var displayName: String

    init(displayName: String = "默认资料") {
        self.displayName = displayName
    }
}

private enum ArchiveTestProfileDefault: SafeCodableDefaultValue {
    static var defaultValue: ArchiveTestProfile? {
        ArchiveTestProfile()
    }
}

private final class ArchiveTestUser: Codable {
    @SafeCodable<ArchiveTestNicknameDefault> var nickname: String?
    @SafeCodable<ArchiveTestProfileDefault> var profile: ArchiveTestProfile?

    init() {}
}

private struct DeviceMessage: Codable {
    @SafeString var clientId: String
    @SafeString var requestId: String
    @SafeInt64 var timestamp: Int64
    @SafeOptional<String> var messageId: String?
    @SafeString var messageType: String
    @SafeString var action: String
    @SafeOptional<DeviceProperties> var data: DeviceProperties?
}

private struct DeviceProperties: Codable {
    @SafeInt var adaptiveResolution: Int
    @SafeInt var audioMode: Int
    @SafeInt var autoFindPet: Int
    @SafeInt var autoFirmware: Int
    @SafeInt64 var bindUserId: Int64
    @SafeInt var chargingStatus: Int
    @SafeInt var detectRecord: Int
    @SafeString var deviceModel: String
    @SafeString var deviceName: String
    @SafeInt var deviceSpeed: Int
    @SafeInt var deviceStatus: Int
    @SafeString var deviceTime: String
    @SafeInt var eyeMode: Int
    @SafeInt var findPowerStatus: Int
    @SafeString var firmwareVersion: String
    @SafeInt var interactRecord: Int
    @SafeString var ipAddress: String
    @SafeString var ipcVersion: String
    @SafeInt var laserStatus: Int
    @SafeString var mcuVersion: String
    @SafeInt var movingState: Int
    @SafeInt var netStatus: Int
    @SafeInt var nightMode: Int
    @SafeInt var otaExecDownloadProgress: Int
    @SafeInt var otaExecStatus: Int
    @SafeInt var otaStatus: Int
    @SafeInt var patrolRecord: Int
    @SafeInt var powerLevel: Int
    @SafeInt var recordCoder: Int
    @SafeString var recordResolution: String
    @SafeInt var rtsaCoder: Int
    @SafeInt var rtsaLowCoder: Int
    @SafeString var rtsaLowResolution: String
    @SafeString var rtsaResolution: String
    @SafeInt var rtsaStreamSpeed: Int
    @SafeDouble var tfAllCap: Double
    @SafeDouble var tfAvilCap: Double
    @SafeInt var tfStatus: Int
    @SafeInt var volume: Int
    @SafeString var wifiSsid: String
    @SafeInt var workingState: Int
}

private func decode<T: Decodable>(
    _ type: T.Type,
    from json: String,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> T {
    do {
        return try JSONDecoder().decode(T.self, from: Data(json.utf8))
    } catch {
        XCTFail("Decode failed: \(error)", file: file, line: line)
        throw error
    }
}
