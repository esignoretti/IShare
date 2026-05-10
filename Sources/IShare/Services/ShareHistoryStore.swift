import Foundation
import Combine

class ShareHistoryStore: ObservableObject {
    @Published var records: [SharedFileRecord] = []

    private let defaults = UserDefaults.standard
    private let recordsKey = "share_history_records"

    init() {
        load()
        let pruned = pruneExpired()
        if pruned > 0 { save() }
    }

    func add(_ record: SharedFileRecord) {
        records.insert(record, at: 0)
        save()
    }

    func remove(at index: Int) {
        guard records.indices.contains(index) else { return }
        records.remove(at: index)
        save()
    }

    func remove(by id: UUID) {
        records.removeAll { $0.id == id }
        save()
    }

    func pruneExpired() -> Int {
        let before = records.count
        records.removeAll { $0.isExpired }
        return before - records.count
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: recordsKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: recordsKey),
              let decoded = try? JSONDecoder().decode([SharedFileRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded
    }
}
