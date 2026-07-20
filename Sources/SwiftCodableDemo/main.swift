import Foundation
import SwiftCodable

private enum DefaultPort: SafeCodableDefaultValue {
    static let defaultValue = 8080
}

private struct Address: Codable {
    @SafeString var city: String
    @SafeInt var zipCode: Int
}

private struct Profile: Codable {
    @SafeString var name: String
    @SafeCodable<DefaultPort> var port: Int
    @SafeBool var enabled: Bool
    @SafeOptional<String> var nickname: String?
    @SafeOptional<Address> var address: Address?
    @SafeArray<String> var tags: [String]
    @SafeDictionary<String, Int> var scores: [String: Int]
}

// MARK: - 根据 type 解析不同的 data 模型

private struct TextData: Codable {
    @SafeString var content: String
}

private struct ImageData: Codable {
    @SafeString var url: String
    @SafeInt var width: Int
    @SafeInt var height: Int
}

/// 使用枚举关联值保存真正的数据类型，避免把 data 声明成 Any。
private enum Message: Codable {
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

private enum DefaultBackupAge: SafeCodableDefaultValue {
    static let defaultValue: Int? = 18
}

private final class User: Codable {
    @SafeOptional<Int> var age: Int?
    @SafeOptional<String> var nickname: String?
    @SafeInt var score: Int
    @SafeCodable<DefaultBackupAge> var backupAge: Int?

    private enum CodingKeys: String, CodingKey {
        case age
        case nickname
        case score
        case backupAge
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        age = try container.decode(
            SafeOptional<Int>.self,
            forKey: .age
        ).wrappedValue
        nickname = try container.decode(
            SafeOptional<String>.self,
            forKey: .nickname
        ).wrappedValue
        score = try container.decode(
            SafeInt.self,
            forKey: .score
        ).wrappedValue
        backupAge = try container.decode(
            SafeCodable<DefaultBackupAge>.self,
            forKey: .backupAge
        ).wrappedValue
    }
}

/// Property Wrapper 不能直接声明在 `let` 上。
/// 使用 `decodeSafeValue` 可以让真正不可变的属性继续获得相同容错能力。
private final class ImmutableUser: Codable {
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

        score = try container.decodeSafeValue(
            SafeInt.self,
            forKey: .score
        )
        age = try container.decodeSafeValue(
            SafeOptional<Int>.self,
            forKey: .age
        )
        backupAge = try container.decodeSafeValue(
            SafeCodable<DefaultBackupAge>.self,
            forKey: .backupAge
        )
    }
}

let json = """
{
  "name": 9527,
  "port": "invalid",
  "enabled": "yes",
  "nickname": 100,
  "address": {
    "city": "Shanghai",
    "zipCode": "200000"
  },
  "tags": ["swift", "codable"],
  "scores": {
    "safety": 100
  }
}
"""

do {
    let profile = try JSONDecoder().decode(Profile.self, from: Data(json.utf8))

    print("name:", profile.name)
    print("port:", profile.port)
    print("enabled:", profile.enabled)
    print("nickname:", profile.nickname ?? "nil")
    print("address:", profile.address?.city ?? "nil", profile.address?.zipCode ?? 0)
    print("tags:", profile.tags)
    print("scores:", profile.scores)

    let encoded = try JSONEncoder().encode(profile)
    print("round-trip bytes:", encoded.count)
} catch {
    print("Demo failed:", error)
}

let polymorphicJSON = """
[
  {
    "type": "text",
    "data": {
      "content": "Hello SwiftCodable"
    }
  },
  {
    "type": "image",
    "data": {
      "url": "https://example.com/photo.png",
      "width": "1280",
      "height": 720
    }
  }
]
"""

do {
    let messages = try JSONDecoder().decode(
        [Message].self,
        from: Data(polymorphicJSON.utf8)
    )

    for message in messages {
        switch message {
        case .text(let data):
            print("text message:", data.content)
        case .image(let data):
            print("image message:", data.url, "\(data.width)x\(data.height)")
        }
    }

    let encoded = try JSONEncoder().encode(messages)
    print("polymorphic round-trip bytes:", encoded.count)
} catch {
    print("Polymorphic demo failed:", error)
}

let manualClassJSON = """
{
  "nickname": 9527,
  "score": "bad",
  "backupAge": null
}
"""

do {
    let user = try JSONDecoder().decode(
        User.self,
        from: Data(manualClassJSON.utf8)
    )

    print("manual class age:", user.age as Any)
    print("manual class nickname:", user.nickname ?? "nil")
    print("manual class score:", user.score)
    print("manual class backupAge:", user.backupAge as Any)
} catch {
    print("Manual class demo failed:", error)
}

let immutableClassJSON = """
{
  "score": "99",
  "age": "21",
  "backupAge": null
}
"""

do {
    let user = try JSONDecoder().decode(
        ImmutableUser.self,
        from: Data(immutableClassJSON.utf8)
    )

    print("immutable score:", user.score)
    print("immutable age:", user.age as Any)
    print("immutable backupAge:", user.backupAge as Any)
} catch {
    print("Immutable class demo failed:", error)
}
