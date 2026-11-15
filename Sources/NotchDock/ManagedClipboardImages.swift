import AppKit
import ImageIO

enum ManagedClipboardImages {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Floatsland/ClipboardImages", isDirectory: true)
    }

    static func owns(_ url: URL, in directory: URL = directory) -> Bool {
        let path = url.standardizedFileURL
        guard path.deletingLastPathComponent() == directory.standardizedFileURL,
              path.lastPathComponent.range(of: #"^Clipboard \d{4}-\d{2}-\d{2} \d{2}\.\d{2}\.\d{2} [0-9A-Fa-f]{8}\.png$"#, options: .regularExpression) != nil else { return false }
        // Never follow a symlink to an external original.
        if let values = try? path.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink == true { return false }
        return path.resolvingSymlinksInPath().deletingLastPathComponent() == directory.resolvingSymlinksInPath()
    }

    /// External files are references only. A failed move to Trash keeps the shelf entry.
    static func trashIfOwned(_ url: URL, in directory: URL = directory) throws {
        guard owns(url, in: directory), FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    static func thumbnail(_ url: URL, in directory: URL = directory) -> NSImage? {
        guard owns(url, in: directory), let source = CGImageSourceCreateWithURL(url as CFURL,
                [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 160,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
