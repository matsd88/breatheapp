//
//  KeychainService.swift
//  Meditation Sleep Mindset
//
//  Persists a flag in the Keychain to detect app reinstalls.
//  Keychain data survives uninstall/reinstall, unlike UserDefaults.
//

import Foundation
import Security

enum KeychainService {

    private static let installKey = "com.meditation.app.installed"

    /// Returns true if this is a reinstall (Keychain flag exists but UserDefaults was wiped).
    /// Call once at launch, before other services initialize.
    static func checkAndMarkInstall() -> Bool {
        let wasInstalled = read(key: installKey) != nil
        let isFirstLaunchPerDefaults = !UserDefaults.standard.bool(forKey: "isFirstLaunch")

        if !wasInstalled {
            // First ever install — write the Keychain flag
            write(key: installKey, value: "1")
            return false
        }

        // Keychain says we've been installed before.
        // If UserDefaults thinks it's a first launch, this is a reinstall.
        return isFirstLaunchPerDefaults
    }

    // MARK: - Keychain Helpers

    private static func write(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
