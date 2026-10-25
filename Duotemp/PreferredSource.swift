/// Asks two sources at once. The preferred one wins if it answers within `wait`; after that, or once it
/// fails, the fallback's answer is used. If the fallback fails, the preferred one is waited for after all.
func preferred<T: Sendable>(
    _ first: @escaping @Sendable () async throws -> T,
    within wait: Duration,
    else fallback: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: SourceOutcome<T>.self) { group in
        group.addTask { .first(try? await first()) }
        group.addTask { .fallback(try? await fallback()) }
        group.addTask {
            try? await Task.sleep(for: wait)
            return .deadline
        }
        var spare: T?
        var firstDone = false, fallbackDone = false, pastDeadline = false
        while let outcome = try await group.next() {
            switch outcome {
            case .first(let value):
                if let value { group.cancelAll(); return value }
                firstDone = true
            case .fallback(let value):
                spare = value
                fallbackDone = true
            case .deadline:
                pastDeadline = true
            }
            if let spare, firstDone || pastDeadline { group.cancelAll(); return spare }
            if firstDone && fallbackDone { break }
        }
        throw BothSourcesFailed()
    }
}

struct BothSourcesFailed: Error {}

private enum SourceOutcome<T: Sendable>: Sendable {
    case first(T?), fallback(T?), deadline
}
