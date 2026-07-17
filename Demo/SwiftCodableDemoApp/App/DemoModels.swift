import Foundation
import SwiftCodable

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

struct DecodeField: Identifiable {
    let name: String
    let value: String

    var id: String { name }
}

struct DecodeReport {
    let fields: [DecodeField]
    let errorMessage: String?

    var isSuccess: Bool { errorMessage == nil }

    static func success(_ fields: [DecodeField]) -> DecodeReport {
        DecodeReport(fields: fields, errorMessage: nil)
    }

    static func failure(_ error: Error) -> DecodeReport {
        DecodeReport(fields: [], errorMessage: String(describing: error))
    }
}

enum DemoDecoder {
    static func decode(scenario: DemoScenario, json: String) -> DecodeReport {
        do {
            let data = Data(json.utf8)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            switch scenario {
            case .device:
                let message = try decoder.decode(DeviceMessage.self, from: data)
                let device = message.data
                return .success([
                    .init(name: "clientId", value: message.clientId),
                    .init(name: "requestId", value: message.requestId),
                    .init(name: "timestamp", value: String(message.timestamp)),
                    .init(name: "messageId", value: message.messageId ?? "nil"),
                    .init(name: "action", value: message.action),
                    .init(name: "device", value: device?.deviceName ?? "nil"),
                    .init(name: "bindUserId", value: String(device?.bindUserId ?? 0)),
                    .init(name: "powerLevel", value: String(device?.powerLevel ?? 0)),
                    .init(name: "IP", value: device?.ipAddress ?? ""),
                    .init(name: "TF capacity", value: String(device?.tfAllCap ?? 0)),
                    .init(name: "Wi-Fi", value: device?.wifiSsid ?? "")
                ])

            case .dirty, .missing:
                let profile = try decoder.decode(BasicProfile.self, from: data)
                return .success([
                    .init(name: "name", value: profile.name),
                    .init(name: "age", value: String(profile.age)),
                    .init(name: "score", value: String(profile.score)),
                    .init(name: "enabled", value: String(profile.enabled)),
                    .init(name: "nickname", value: profile.nickname ?? "nil"),
                    .init(name: "pageSize", value: String(profile.pageSize))
                ])

            case .nested:
                let root = try decoder.decode(CompanyRoot.self, from: data)
                let company = root.company
                let teams = company?.teams ?? []
                let members = teams.flatMap(\.members)
                return .success([
                    .init(name: "company", value: company?.name ?? "nil"),
                    .init(name: "team count", value: String(teams.count)),
                    .init(name: "member count", value: String(members.count)),
                    .init(
                        name: "members",
                        value: members
                            .map { "\($0.name)(\($0.age), \($0.active))" }
                            .joined(separator: ", ")
                    )
                ])

            case .classArchive:
                let user = try decoder.decode(ArchiveUser.self, from: data)
                let initialNickname = user.nickname ?? "nil"
                let initialProfile = user.profile?.displayName ?? "nil"

                user.nickname = "Tom"
                user.profile?.displayName = "修改后的资料"

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                let modifiedData = try encoder.encode(user)
                let restored = try decoder.decode(
                    ArchiveUser.self,
                    from: modifiedData
                )

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

                return .success([
                    .init(name: "初始 nickname", value: initialNickname),
                    .init(name: "初始 profile", value: initialProfile),
                    .init(
                        name: "修改并解档",
                        value: restored.nickname ?? "nil"
                    ),
                    .init(
                        name: "profile 解档",
                        value: restored.profile?.displayName ?? "nil"
                    ),
                    .init(
                        name: "nil 解档结果",
                        value: restoredAfterNil.nickname ?? "nil"
                    ),
                    .init(
                        name: "默认对象独立",
                        value: String(defaultsAreIndependent)
                    ),
                    .init(
                        name: "归档 JSON",
                        value: String(decoding: modifiedData, as: UTF8.self)
                    )
                ])
            }
        } catch {
            return .failure(error)
        }
    }
}
