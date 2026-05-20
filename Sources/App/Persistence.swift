import Foundation
import Security

// MARK: - Keychain (encrypted by macOS)
enum Keychain {
    private static let service = "com.aesthetic.player"

    static func save(_ value: String, account: String) {
        let data = Data(value.utf8)
        let base: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData] = data
        add[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load(account: String) -> String? {
        let q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data,
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    static func remove(account: String) {
        let q: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(q as CFDictionary)
    }
}

// MARK: - Library cache (Application Support)
enum LibraryStore {
    private static var directory: URL {
        let appSupport = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSHomeDirectory())
        let dir = appSupport.appendingPathComponent("AestheticPlayer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var libraryURL: URL { directory.appendingPathComponent("library.json") }

    static func save(_ albums: [Album]) {
        do {
            let data = try JSONEncoder().encode(albums)
            try data.write(to: libraryURL, options: .atomic)
        } catch {
            FileHandle.standardError.write(Data("[Store] save failed: \(error)\n".utf8))
        }
    }

    static func load() -> [Album] {
        guard let data = try? Data(contentsOf: libraryURL) else { return [] }
        return (try? JSONDecoder().decode([Album].self, from: data)) ?? []
    }
}
