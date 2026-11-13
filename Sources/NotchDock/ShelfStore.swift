import AppKit

/// 中转站暂存数据：支持两种条目——文件引用（URL，文件留在原处）与文本片段。
final class ShelfStore {
    enum Kind: Equatable {
        case file(URL)
        case text(String)
    }

    struct Item: Equatable {
        let id: UUID
        let kind: Kind

        var url: URL? {
            if case .file(let u) = kind { return u }
            return nil
        }

        var text: String? {
            if case .text(let s) = kind { return s }
            return nil
        }

        var isText: Bool {
            if case .text = kind { return true }
            return false
        }
    }

    private(set) var items: [Item] = []
    var onChange: (() -> Void)?

    private let defaultsKey = "shelfItems"

    init() {
        load()
    }

    /// 加入文件，返回实际新增数量（自动去重、忽略已不存在的文件）。
    @discardableResult
    func add(urls: [URL]) -> Int {
        var added = 0
        let existing = Set(items.compactMap { $0.url }.map { $0.standardizedFileURL.path })
        for url in urls {
            let std = url.standardizedFileURL
            let path = std.path
            guard !existing.contains(path) else { continue }
            guard FileManager.default.fileExists(atPath: path) else { continue }
            items.append(Item(id: UUID(), kind: .file(std)))
            added += 1
        }
        if added > 0 {
            save()
            onChange?()
        }
        return added
    }

    /// 加入文本片段，返回实际新增数量（空文本忽略、完全相同文本去重）。
    @discardableResult
    func add(text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        guard !items.contains(where: { $0.text == text }) else { return 0 }
        items.append(Item(id: UUID(), kind: .text(text)))
        save()
        onChange?()
        return 1
    }

    func remove(id: UUID) {
        let before = items.count
        items.removeAll { $0.id == id }
        if items.count != before {
            save()
            onChange?()
        }
    }

    func clear() {
        guard !items.isEmpty else { return }
        items.removeAll()
        save()
        onChange?()
    }

    /// 移除已经不存在（被移动/删除）的文件引用；文本条目始终有效。
    func pruneStale() {
        let before = items.count
        items.removeAll { item in
            if case .file(let url) = item.kind {
                return !FileManager.default.fileExists(atPath: url.path)
            }
            return false
        }
        if items.count != before {
            save()
            onChange?()
        }
    }

    func save() {
        let encoded = items.map { item -> String in
            switch item.kind {
            case .file(let url): return "F:" + url.path
            case .text(let text): return "T:" + text
            }
        }
        UserDefaults.standard.set(encoded, forKey: defaultsKey)
    }

    private func load() {
        guard let raw = UserDefaults.standard.array(forKey: defaultsKey) as? [String] else { return }
        var restored: [Item] = []
        var seenFiles = Set<String>()
        for entry in raw {
            if entry.hasPrefix("F:") {
                let path = String(entry.dropFirst(2))
                let std = URL(fileURLWithPath: path).standardizedFileURL
                guard !seenFiles.contains(std.path) else { continue }
                guard FileManager.default.fileExists(atPath: std.path) else { continue }
                seenFiles.insert(std.path)
                restored.append(Item(id: UUID(), kind: .file(std)))
            } else if entry.hasPrefix("T:") {
                restored.append(Item(id: UUID(), kind: .text(String(entry.dropFirst(2)))))
            } else {
                // 兼容旧版本（纯路径字符串）
                let std = URL(fileURLWithPath: entry).standardizedFileURL
                guard !seenFiles.contains(std.path) else { continue }
                guard FileManager.default.fileExists(atPath: std.path) else { continue }
                seenFiles.insert(std.path)
                restored.append(Item(id: UUID(), kind: .file(std)))
            }
        }
        items = restored
    }
}
