import Foundation

/// SwiftCodable 的统一诊断入口。
///
/// Debug 构建默认向控制台打印，Release 构建默认关闭打印。
/// 无论是否打印，注册的监听器都会收到问题，便于统一上报线上错误。
public enum SafeCodableDiagnostics {
    public typealias Listener = @Sendable (SafeDecodeIssue) -> Void

    private static let state = State()

    public static var isAutomaticLoggingEnabled: Bool {
        get {
            state.withLock { $0.isAutomaticLoggingEnabled }
        }
        set {
            state.withLock { $0.isAutomaticLoggingEnabled = newValue }
        }
    }

    /// 注册或移除全局问题监听器。传入 `nil` 即移除。
    ///
    /// 监听器在内部锁之外同步调用，避免死锁；监听器自身不应执行耗时工作。
    public static func setListener(_ listener: Listener?) {
        state.withLock { $0.listener = listener }
    }

    /// 恢复当前构建配置的默认打印行为，并移除监听器。
    public static func reset() {
        state.withLock {
            $0.isAutomaticLoggingEnabled = State.defaultLoggingEnabled
            $0.listener = nil
        }
    }

    static func report(_ issue: SafeDecodeIssue) {
        let snapshot = state.withLock {
            (
                logging: $0.isAutomaticLoggingEnabled,
                listener: $0.listener
            )
        }

        if snapshot.logging {
            print("[SwiftCodable] \(issue)")
        }
        snapshot.listener?(issue)
    }
}

private extension SafeCodableDiagnostics {
    final class State: @unchecked Sendable {
        #if DEBUG
        static let defaultLoggingEnabled = true
        #else
        static let defaultLoggingEnabled = false
        #endif

        let lock = NSLock()
        var isAutomaticLoggingEnabled = defaultLoggingEnabled
        var listener: Listener?

        func withLock<Result>(
            _ operation: (State) -> Result
        ) -> Result {
            lock.lock()
            defer { lock.unlock() }
            return operation(self)
        }
    }
}

