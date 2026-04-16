import Combine
import Foundation

/// Owns the Claude.ai session cookie + organization UUID. Persists to Keychain.
@MainActor
final class ClaudeAuth: ObservableObject {
    static let shared = ClaudeAuth()

    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var organizationUUID: String?
    @Published private(set) var accountEmail: String?

    private static let sessionKeyAccount = "claude_session_key"
    private static let orgUUIDAccount    = "claude_org_uuid"
    private static let emailAccount      = "claude_account_email"

    private init() {
        isAuthenticated = (sessionKey != nil)
        organizationUUID = Keychain.get(Self.orgUUIDAccount)
        accountEmail = Keychain.get(Self.emailAccount)
    }

    var sessionKey: String? {
        Keychain.get(Self.sessionKeyAccount)
    }

    func store(sessionKey: String, organizationUUID: String?, email: String?) {
        Keychain.set(sessionKey, for: Self.sessionKeyAccount)
        if let uuid = organizationUUID {
            Keychain.set(uuid, for: Self.orgUUIDAccount)
        }
        if let email {
            Keychain.set(email, for: Self.emailAccount)
        }
        self.organizationUUID = organizationUUID
        self.accountEmail = email
        self.isAuthenticated = true
    }

    func signOut() {
        Keychain.delete(Self.sessionKeyAccount)
        Keychain.delete(Self.orgUUIDAccount)
        Keychain.delete(Self.emailAccount)
        organizationUUID = nil
        accountEmail = nil
        isAuthenticated = false
    }
}
