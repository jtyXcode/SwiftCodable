import Foundation

enum DemoSection: String, CaseIterable {
    case basics = "基础能力"
    case structures = "集合与模型"
    case functional = "函数式与诊断"
    case production = "实际工程"
}

enum DemoScenario: String, CaseIterable, Identifiable {
    case dirty
    case missing
    case optional
    case collections
    case nested
    case polymorphic
    case functionalRules
    case diagnostics
    case immutable
    case classArchive
    case device

    var id: String { rawValue }

    var section: DemoSection {
        switch self {
        case .dirty, .missing, .optional:
            return .basics
        case .collections, .nested, .polymorphic:
            return .structures
        case .functionalRules, .diagnostics:
            return .functional
        case .immutable, .classArchive, .device:
            return .production
        }
    }

    var title: String {
        switch self {
        case .dirty:
            return "常用类型容错"
        case .missing:
            return "缺失与 null"
        case .optional:
            return "可选值"
        case .collections:
            return "数组与字典"
        case .nested:
            return "多层嵌套"
        case .polymorphic:
            return "多态 data 模型"
        case .functionalRules:
            return "函数式规则"
        case .diagnostics:
            return "六类错误诊断"
        case .immutable:
            return "不可变 let 属性"
        case .classArchive:
            return "Class 与归档"
        case .device:
            return "真实设备数据"
        }
    }

    var detail: String {
        switch self {
        case .dirty:
            return "String、数字、Bool 类型互转，以及失败后的默认值。"
        case .missing:
            return "区分 missing 和 null，并展示内置与业务默认值。"
        case .optional:
            return "SafeOptional 的精确解码、容错转换和 nil 回退。"
        case .collections:
            return "数组、字典缺失或整体类型错误时使用空集合。"
        case .nested:
            return "Company → Team → Member，多层数组中的字段路径诊断。"
        case .polymorphic:
            return "根据 type 将 data 解码为不同的强类型关联值。"
        case .functionalRules:
            return "使用 automatic、map、or、convert、validate 组合业务规则。"
        case .diagnostics:
            return "一次触发 missing、null、类型错误、转换失败、溢出和校验失败。"
        case .immutable:
            return "通过 decodeSafeValue 为真正的 let 属性提供相同容错。"
        case .classArchive:
            return "可选默认值、修改归档、显式 nil 回退和默认对象隔离。"
        case .device:
            return "真实 property/disconnect 消息，包含 Int64、null 和 snake_case。"
        }
    }

    var symbolName: String {
        switch self {
        case .dirty:
            return "arrow.triangle.2.circlepath"
        case .missing:
            return "questionmark.diamond"
        case .optional:
            return "questionmark.circle"
        case .collections:
            return "square.stack.3d.up"
        case .nested:
            return "point.3.connected.trianglepath.dotted"
        case .polymorphic:
            return "arrow.triangle.branch"
        case .functionalRules:
            return "function"
        case .diagnostics:
            return "exclamationmark.bubble"
        case .immutable:
            return "lock"
        case .classArchive:
            return "archivebox"
        case .device:
            return "sensor"
        }
    }

    var json: String {
        switch self {
        case .dirty:
            return Self.dirtyJSON
        case .missing:
            return Self.missingJSON
        case .optional:
            return Self.optionalJSON
        case .collections:
            return Self.collectionsJSON
        case .nested:
            return Self.nestedJSON
        case .polymorphic:
            return Self.polymorphicJSON
        case .functionalRules:
            return Self.functionalRulesJSON
        case .diagnostics:
            return Self.diagnosticsJSON
        case .immutable:
            return Self.immutableJSON
        case .classArchive:
            return Self.classArchiveJSON
        case .device:
            return Self.deviceJSON
        }
    }

    static func scenarios(in section: DemoSection) -> [DemoScenario] {
        allCases.filter { $0.section == section }
    }

    private static let dirtyJSON = """
    {
      "name": 1001,
      "age": "18",
      "score": "invalid",
      "enabled": "yes",
      "nickname": 9527,
      "pageSize": "50"
    }
    """

    private static let missingJSON = """
    {
      "name": null,
      "nickname": null
    }
    """

    private static let optionalJSON = """
    {
      "age": "21",
      "nickname": 9527,
      "score": "unknown"
    }
    """

    private static let collectionsJSON = """
    {
      "items": "not-an-array",
      "lookup": [],
      "validItems": [1, 2, 3]
    }
    """

    private static let nestedJSON = """
    {
      "company": {
        "name": "Swift Lab",
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

    private static let polymorphicJSON = """
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

    private static let functionalRulesJSON = """
    {
      "age": "18",
      "port": "70000"
    }
    """

    private static let diagnosticsJSON = """
    {
      "nullValue": null,
      "typeMismatch": {},
      "conversionFailed": "abc",
      "overflow": "128",
      "validationFailed": 200
    }
    """

    private static let immutableJSON = """
    {
      "score": "99",
      "age": "21",
      "backupAge": null
    }
    """

    private static let classArchiveJSON = """
    {
      "userId": "U-1001"
    }
    """

    private static let deviceJSON = """
    {
      "clientId": "VSF101265200040DE",
      "requestId": "1593",
      "timestamp": 1784273874665,
      "messageId": null,
      "messageType": "property",
      "action": "disconnect",
      "data": {
        "adaptive_resolution": 0,
        "audio_mode": 1,
        "auto_find_pet": 1,
        "auto_firmware": 1,
        "bind_user_id": 2047212303078641666,
        "charging_status": 1,
        "detect_record": 0,
        "device_model": "Mero F10",
        "device_name": "Mero F10 40DE",
        "device_speed": 20,
        "device_status": 0,
        "device_time": "2026-07-17 15:37:54",
        "eye_mode": 0,
        "find_power_status": 1,
        "firmware_version": "1.1.34",
        "interact_record": 0,
        "ip_address": "192.168.124.171",
        "ipc_version": "1.0.0",
        "laser_status": 0,
        "mcu_version": "1.1.37",
        "moving_state": 13,
        "net_status": 1,
        "night_mode": 0,
        "ota_exec_download_progress": 0,
        "ota_exec_status": 0,
        "ota_status": 0,
        "patrol_record": 0,
        "power_level": 80,
        "record_coder": 2,
        "record_resolution": "1920x1080",
        "rtsa_coder": 2,
        "rtsa_low_coder": 1,
        "rtsa_low_resolution": "720x480",
        "rtsa_resolution": "1920x1080",
        "rtsa_stream_speed": 0,
        "tf_all_cap": 29.280000686645508,
        "tf_avil_cap": 27.969999313354492,
        "tf_status": 0,
        "volume": 50,
        "wifi_ssid": "VS_AI_TEST_5G",
        "working_state": 0
      }
    }
    """
}
