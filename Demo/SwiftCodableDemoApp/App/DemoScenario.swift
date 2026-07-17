import Foundation

enum DemoScenario: String, CaseIterable, Identifiable {
    case device
    case dirty
    case missing
    case nested
    case classArchive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .device:
            return "设备"
        case .dirty:
            return "脏数据"
        case .missing:
            return "缺字段"
        case .nested:
            return "多嵌套"
        case .classArchive:
            return "Class"
        }
    }

    var detail: String {
        switch self {
        case .device:
            return "真实设备 property/disconnect 消息，包含 Int64、null 和 snake_case。"
        case .dirty:
            return "String、数字、Bool 类型互转，以及无法转换时的默认值。"
        case .missing:
            return "字段缺失和 null 时，验证内置默认值与自定义 pageSize 默认值。"
        case .nested:
            return "Company → Team → Member 多层模型和数组中的脏字段。"
        case .classArchive:
            return "可选默认值修改、归档解档、显式 nil 回退和 Class 默认对象隔离。"
        }
    }

    var json: String {
        switch self {
        case .device:
            return Self.deviceJSON
        case .dirty:
            return Self.dirtyJSON
        case .missing:
            return Self.missingJSON
        case .nested:
            return Self.nestedJSON
        case .classArchive:
            return Self.classArchiveJSON
        }
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
