import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Reads new image clipboard entries without modifying the clipboard.
final class ClipboardImageMonitor {
    private let store: ShelfStore
    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var observedChange: Int
    private var wasEnabled: Bool
    private var attempts = 0
    private var pendingChange: Int?
    private let conversionQueue = DispatchQueue(label: "com.floatisland.clipboard-image", qos: .utility)

    init(store: ShelfStore, pasteboard: NSPasteboard = .general) {
        self.store = store
        self.pasteboard = pasteboard
        observedChange = pasteboard.changeCount
        wasEnabled = AppSettings.shared.captureClipboardImages
    }

    func start() {
        guard timer == nil else { return }
        observedChange = pasteboard.changeCount
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.poll() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() { timer?.invalidate(); timer = nil }
    deinit { timer?.invalidate() }

    private func poll() {
        let enabled = AppSettings.shared.captureClipboardImages
        let change = pasteboard.changeCount
        guard enabled && wasEnabled else {
            observedChange = change
            wasEnabled = enabled
            attempts = 0
            return
        }
        guard change != observedChange, pendingChange == nil else { return }
        // Ignore copied files and their preview representations; only capture actual image data.
        guard !(pasteboard.types ?? []).contains(.fileURL) else {
            observedChange = change
            return
        }
        let type = pasteboard.availableType(from: [.png, .tiff])
        guard let type, let data = pasteboard.data(forType: type), !data.isEmpty else {
            attempts += 1
            if attempts >= 3 { observedChange = change; attempts = 0 }
            return
        }
        guard pasteboard.changeCount == change else { return }
        pendingChange = change
        conversionQueue.async { [weak self] in
            let png = Self.pngData(from: data)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingChange = nil
                self.observedChange = change
                self.attempts = 0
                guard AppSettings.shared.captureClipboardImages, let png else { return }
                do {
                    let directory = try FileManager.default.url(for: .applicationSupportDirectory,
                        in: .userDomainMask, appropriateFor: nil, create: true)
                        .appendingPathComponent("Floatsland/ClipboardImages", isDirectory: true)
                    let url = try Self.save(png, in: directory)
                    self.store.add(urls: [url])
                } catch {
                    NSLog("Floatsland: could not save clipboard image: %@", error.localizedDescription)
                }
            }
        }
    }

    static func pngData(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    static func save(_ png: Data, in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let name = "Clipboard \(formatter.string(from: Date())) \(UUID().uuidString.prefix(8)).png"
        let url = directory.appendingPathComponent(name)
        try png.write(to: url, options: .atomic)
        return url
    }
}
