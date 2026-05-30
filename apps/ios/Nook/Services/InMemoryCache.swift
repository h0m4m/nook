import Foundation

actor InMemoryCache<Key: Hashable & Sendable, Value: Sendable> {
    private var storage: [Key: (value: Value, timestamp: Date)] = [:]
    private let ttl: TimeInterval

    init(ttl: TimeInterval) {
        self.ttl = ttl
    }

    func get(_ key: Key) -> Value? {
        guard let entry = storage[key] else { return nil }
        if Date().timeIntervalSince(entry.timestamp) > ttl {
            storage[key] = nil
            return nil
        }
        return entry.value
    }

    func set(_ key: Key, value: Value) {
        storage[key] = (value: value, timestamp: Date())
    }

    func invalidate(_ key: Key) {
        storage[key] = nil
    }

    func invalidateAll() {
        storage.removeAll()
    }
}
