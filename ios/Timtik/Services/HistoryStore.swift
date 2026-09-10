import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [TimerRecord] = []
    private let key = "timtik.ios.history.v1"

    init() { load() }

    func add(_ record: TimerRecord) {
        records.insert(record, at: 0)
        records = Array(records.prefix(100))
        save()
    }

    func clear() {
        records = []
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TimerRecord].self, from: data) else { return }
        records = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
