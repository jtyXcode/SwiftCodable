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
