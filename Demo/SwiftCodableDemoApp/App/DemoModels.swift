import Foundation
import SwiftCodable

// MARK: - Real device payload

struct DeviceMessage: Codable {
    @SafeString var clientId: String
    @SafeString var requestId: String
    @SafeInt64 var timestamp: Int64
    @SafeOptional<String> var messageId: String?
    @SafeString var messageType: String
    @SafeString var action: String
    @SafeOptional<DeviceProperties> var data: DeviceProperties?
}

struct DeviceProperties: Codable {
    @SafeInt64 var bindUserId: Int64
    @SafeString var deviceModel: String
    @SafeString var deviceName: String
    @SafeInt var deviceSpeed: Int
    @SafeString var deviceTime: String
    @SafeString var firmwareVersion: String
    @SafeString var ipAddress: String
    @SafeString var mcuVersion: String
    @SafeInt var movingState: Int
    @SafeInt var powerLevel: Int
    @SafeString var recordResolution: String
    @SafeString var rtsaLowResolution: String
    @SafeString var rtsaResolution: String
    @SafeDouble var tfAllCap: Double
    @SafeDouble var tfAvilCap: Double
    @SafeInt var volume: Int
    @SafeString var wifiSsid: String
}

// MARK: - Basic values

enum DefaultPageSize: SafeCodableDefaultValue {
    static let defaultValue = 20
}

struct BasicProfile: Codable {
    @SafeString var name: String
    @SafeInt var age: Int
    @SafeDouble var score: Double
    @SafeBool var enabled: Bool
    @SafeOptional<String> var nickname: String?
    @SafeCodable<DefaultPageSize> var pageSize: Int
}

struct OptionalProfile: Codable {
    @SafeOptional<Int> var age: Int?
    @SafeOptional<String> var nickname: String?
    @SafeOptional<Double> var score: Double?
}

struct CollectionProfile: Codable {
    @SafeArray<Int> var items: [Int]
    @SafeDictionary<String, Int> var lookup: [String: Int]
    @SafeArray<Int> var validItems: [Int]
}

// MARK: - Nested models

struct CompanyRoot: Codable {
    @SafeOptional<Company> var company: Company?
}

struct Company: Codable {
    @SafeString var name: String
    @SafeArray<Team> var teams: [Team]
}

struct Team: Codable {
    @SafeString var name: String
    @SafeArray<Member> var members: [Member]
}

struct Member: Codable {
    @SafeString var name: String
    @SafeInt var age: Int
    @SafeBool var active: Bool
}

// MARK: - Polymorphic data

struct TextData: Codable {
    @SafeString var content: String
}

struct ImageData: Codable {
    @SafeString var url: String
    @SafeInt var width: Int
    @SafeInt var height: Int
}

enum DemoMessage: Codable {
    case text(TextData)
    case image(ImageData)

    private enum CodingKeys: String, CodingKey {
        case type
        case data
    }

    private enum MessageType: String, Codable {
        case text
        case image
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .text:
            self = .text(
                try container.decode(TextData.self, forKey: .data)
            )
        case .image:
            self = .image(
                try container.decode(ImageData.self, forKey: .data)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let data):
            try container.encode(MessageType.text, forKey: .type)
            try container.encode(data, forKey: .data)
        case .image(let data):
            try container.encode(MessageType.image, forKey: .type)
            try container.encode(data, forKey: .data)
        }
    }
}

// MARK: - Functional rules

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

enum PortPolicy: SafeCodableDefaultValue {
    static let defaultValue = 8080

    static var decodingRule: SafeDecodeRule<Int> {
        .exact.or(
            .convert(String.self) { text in
                guard let value = Int(text) else {
                    throw SafeDecodeRuleError.conversionFailed
                }
                return value
            }
        )
        .validate("端口必须在 1～65535 之间") {
            (1...65_535).contains($0)
        }
    }
}

struct FunctionalProfile: Codable {
    @SafeCodable<OptionalAgePolicy> var age: Int?
    @SafeCodable<PortPolicy> var port: Int
}

enum ValidatedAgePolicy: SafeCodableDefaultValue {
    static let defaultValue = 0

    static var decodingRule: SafeDecodeRule<Int> {
        .automatic.validate("年龄必须在 0～150 之间") {
            (0...150).contains($0)
        }
    }
}

struct DiagnosticProfile: Codable {
    @SafeInt var missing: Int
    @SafeInt var nullValue: Int
    @SafeInt var typeMismatch: Int
    @SafeInt var conversionFailed: Int
    @SafeInt8 var overflow: Int8
    @SafeCodable<ValidatedAgePolicy> var validationFailed: Int

    enum CodingKeys: String, CodingKey {
        case missing
        case nullValue
        case typeMismatch
        case conversionFailed
        case overflow
        case validationFailed
    }
}

// MARK: - Immutable values

enum DefaultBackupAge: SafeCodableDefaultValue {
    static let defaultValue: Int? = 18
}

final class ImmutableUser: Codable {
    let score: Int
    let age: Int?
    let backupAge: Int?

    private enum CodingKeys: String, CodingKey {
        case score
        case age
        case backupAge
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        score = try container.decodeSafeValue(SafeInt.self, forKey: .score)
        age = try container.decodeSafeValue(
            SafeOptional<Int>.self,
            forKey: .age
        )
        backupAge = try container.decodeSafeValue(
            SafeCodable<DefaultBackupAge>.self,
            forKey: .backupAge
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(score, forKey: .score)
        try container.encodeIfPresent(age, forKey: .age)
        try container.encodeIfPresent(backupAge, forKey: .backupAge)
    }
}

// MARK: - Class archive

enum DefaultOptionalNickname: SafeCodableDefaultValue {
    static let defaultValue: String? = "游客"
}

final class ArchiveProfile: Codable {
    @SafeString var displayName: String

    init(displayName: String = "默认资料") {
        self.displayName = displayName
    }
}

enum DefaultOptionalProfile: SafeCodableDefaultValue {
    /// 使用计算属性，确保每个 ArchiveUser 获得独立的 Class 实例。
    static var defaultValue: ArchiveProfile? {
        ArchiveProfile()
    }
}

final class ArchiveUser: Codable {
    @SafeString var userId: String
    @SafeCodable<DefaultOptionalNickname> var nickname: String?
    @SafeCodable<DefaultOptionalProfile> var profile: ArchiveProfile?

    init(userId: String = "") {
        self.userId = userId
    }
}

// MARK: - Demo report

struct DecodeField: Identifiable {
    let name: String
    let value: String

    var id: String { name }
}

struct DecodeReport {
    let fields: [DecodeField]
    let issues: [SafeDecodeIssue]
    let errorMessage: String?

    var isSuccess: Bool { errorMessage == nil }

    static func success(
        _ fields: [DecodeField],
        issues: [SafeDecodeIssue]
    ) -> DecodeReport {
        DecodeReport(
            fields: fields,
            issues: issues,
            errorMessage: nil
        )
    }

    static func failure(
        _ error: Error,
        issues: [SafeDecodeIssue]
    ) -> DecodeReport {
        DecodeReport(
            fields: [],
            issues: issues,
            errorMessage: String(describing: error)
        )
    }
}

final class DemoDiagnosticsStore: @unchecked Sendable {
    static let shared = DemoDiagnosticsStore()

    private let lock = NSLock()
    private var issues: [SafeDecodeIssue] = []

    static func install() {
        SafeCodableDiagnostics.setListener { issue in
            DemoDiagnosticsStore.shared.append(issue)
        }
    }

    func reset() {
        lock.lock()
        issues.removeAll()
        lock.unlock()
    }

    func snapshot() -> [SafeDecodeIssue] {
        lock.lock()
        defer { lock.unlock() }
        return issues
    }

    private func append(_ issue: SafeDecodeIssue) {
        lock.lock()
        issues.append(issue)
        lock.unlock()
    }
}

enum DemoDecoder {
    static func decode(
        scenario: DemoScenario,
        json: String
    ) -> DecodeReport {
        DemoDiagnosticsStore.shared.reset()

        do {
            let data = Data(json.utf8)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let fields = try decodeFields(
                scenario: scenario,
                data: data,
                decoder: decoder
            )
            return .success(
                fields,
                issues: DemoDiagnosticsStore.shared.snapshot()
            )
        } catch {
            return .failure(
                error,
                issues: DemoDiagnosticsStore.shared.snapshot()
            )
        }
    }

    private static func decodeFields(
        scenario: DemoScenario,
        data: Data,
        decoder: JSONDecoder
    ) throws -> [DecodeField] {
        switch scenario {
        case .dirty, .missing:
            let profile = try decoder.decode(BasicProfile.self, from: data)
            return [
                .init(name: "name", value: profile.name),
                .init(name: "age", value: String(profile.age)),
                .init(name: "score", value: String(profile.score)),
                .init(name: "enabled", value: String(profile.enabled)),
                .init(name: "nickname", value: profile.nickname ?? "nil"),
                .init(name: "pageSize", value: String(profile.pageSize))
            ]

        case .optional:
            let profile = try decoder.decode(OptionalProfile.self, from: data)
            return [
                .init(name: "age", value: optional(profile.age)),
                .init(name: "age 状态", value: status(profile.$age)),
                .init(name: "nickname", value: profile.nickname ?? "nil"),
                .init(name: "nickname 状态", value: status(profile.$nickname)),
                .init(name: "score", value: optional(profile.score)),
                .init(name: "score 状态", value: status(profile.$score))
            ]

        case .collections:
            let profile = try decoder.decode(CollectionProfile.self, from: data)
            return [
                .init(name: "items", value: String(describing: profile.items)),
                .init(name: "lookup", value: String(describing: profile.lookup)),
                .init(
                    name: "validItems",
                    value: String(describing: profile.validItems)
                ),
                .init(name: "items 状态", value: status(profile.$items)),
                .init(name: "lookup 状态", value: status(profile.$lookup))
            ]

        case .nested:
            let root = try decoder.decode(CompanyRoot.self, from: data)
            let company = root.company
            let teams = company?.teams ?? []
            let members = teams.flatMap(\.members)
            return [
                .init(name: "company", value: company?.name ?? "nil"),
                .init(name: "team count", value: String(teams.count)),
                .init(name: "member count", value: String(members.count)),
                .init(
                    name: "members",
                    value: members
                        .map { "\($0.name)(\($0.age), \($0.active))" }
                        .joined(separator: ", ")
                )
            ]

        case .polymorphic:
            let messages = try decoder.decode([DemoMessage].self, from: data)
            return messages.enumerated().map { index, message in
                switch message {
                case .text(let value):
                    return .init(
                        name: "[\(index)] TextData",
                        value: value.content
                    )
                case .image(let value):
                    return .init(
                        name: "[\(index)] ImageData",
                        value: "\(value.url) · \(value.width)x\(value.height)"
                    )
                }
            }

        case .functionalRules:
            let profile = try decoder.decode(FunctionalProfile.self, from: data)
            return [
                .init(name: "age", value: optional(profile.age)),
                .init(name: "age 状态", value: status(profile.$age)),
                .init(name: "port", value: String(profile.port)),
                .init(name: "port 状态", value: status(profile.$port))
            ]

        case .diagnostics:
            let profile = try decoder.decode(DiagnosticProfile.self, from: data)
            return [
                .init(name: "missing", value: status(profile.$missing)),
                .init(name: "null", value: status(profile.$nullValue)),
                .init(
                    name: "typeMismatch",
                    value: status(profile.$typeMismatch)
                ),
                .init(
                    name: "conversionFailed",
                    value: status(profile.$conversionFailed)
                ),
                .init(name: "overflow", value: status(profile.$overflow)),
                .init(
                    name: "validationFailed",
                    value: status(profile.$validationFailed)
                )
            ]

        case .immutable:
            let user = try decoder.decode(ImmutableUser.self, from: data)
            return [
                .init(name: "score · let Int", value: String(user.score)),
                .init(name: "age · let Int?", value: optional(user.age)),
                .init(
                    name: "backupAge · let Int?",
                    value: optional(user.backupAge)
                )
            ]

        case .classArchive:
            return try decodeClassArchive(data: data, decoder: decoder)

        case .device:
            let message = try decoder.decode(DeviceMessage.self, from: data)
            let device = message.data
            return [
                .init(name: "clientId", value: message.clientId),
                .init(name: "requestId", value: message.requestId),
                .init(name: "timestamp", value: String(message.timestamp)),
                .init(name: "messageId", value: message.messageId ?? "nil"),
                .init(name: "action", value: message.action),
                .init(name: "device", value: device?.deviceName ?? "nil"),
                .init(
                    name: "bindUserId",
                    value: String(device?.bindUserId ?? 0)
                ),
                .init(
                    name: "powerLevel",
                    value: String(device?.powerLevel ?? 0)
                ),
                .init(name: "IP", value: device?.ipAddress ?? ""),
                .init(
                    name: "TF capacity",
                    value: String(device?.tfAllCap ?? 0)
                ),
                .init(name: "Wi-Fi", value: device?.wifiSsid ?? "")
            ]
        }
    }

    private static func decodeClassArchive(
        data: Data,
        decoder: JSONDecoder
    ) throws -> [DecodeField] {
        let user = try decoder.decode(ArchiveUser.self, from: data)
        let initialNickname = user.nickname ?? "nil"
        let initialProfile = user.profile?.displayName ?? "nil"

        user.nickname = "Tom"
        user.profile?.displayName = "修改后的资料"

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let modifiedData = try encoder.encode(user)
        let restored = try decoder.decode(ArchiveUser.self, from: modifiedData)

        user.nickname = nil
        let nilData = try encoder.encode(user)
        let restoredAfterNil = try decoder.decode(
            ArchiveUser.self,
            from: nilData
        )

        let first = ArchiveUser()
        let second = ArchiveUser()
        let defaultsAreIndependent: Bool
        if let firstProfile = first.profile,
           let secondProfile = second.profile {
            defaultsAreIndependent = firstProfile !== secondProfile
        } else {
            defaultsAreIndependent = false
        }

        return [
            .init(name: "初始 nickname", value: initialNickname),
            .init(name: "初始 profile", value: initialProfile),
            .init(name: "修改并解档", value: restored.nickname ?? "nil"),
            .init(
                name: "profile 解档",
                value: restored.profile?.displayName ?? "nil"
            ),
            .init(
                name: "nil 解档结果",
                value: restoredAfterNil.nickname ?? "nil"
            ),
            .init(name: "默认对象独立", value: String(defaultsAreIndependent)),
            .init(
                name: "归档 JSON",
                value: String(decoding: modifiedData, as: UTF8.self)
            )
        ]
    }

    private static func optional<Value>(_ value: Value?) -> String {
        value.map { String(describing: $0) } ?? "nil"
    }

    private static func status(_ status: SafeDecodeStatus) -> String {
        switch status {
        case .initialized:
            return "initialized"
        case .assigned:
            return "assigned"
        case .decoded:
            return "decoded"
        case .converted(let trace):
            switch trace.source {
            case .exact:
                return "decoded"
            case .converted(let source, let target):
                return "converted · \(source) → \(target)"
            }
        case .fallback(let issue):
            return "fallback · \(issue.reasonCode)"
        }
    }
}
