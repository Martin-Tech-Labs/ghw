import Foundation
import Security

// Keychain access helpers.
//
// Next hardening step: attach an ACL so only the signed ghw binary can read the token.
// This uses SecTrustedApplication + SecAccess (legacy but effective on macOS).
//
// NOTE: This typically requires the binary to be signed and the user to approve once.

func makeSecAccessForThisExecutable(label: String) throws -> SecAccess {
  // Resolve executable path (prefer realpath)
  let path = (CommandLine.arguments.first ?? "")
  let execPath = (try? URL(fileURLWithPath: path).resolvingSymlinksInPath().path) ?? path

  var trusted: SecTrustedApplication?
  let stTA = SecTrustedApplicationCreateFromPath(execPath, &trusted)
  guard stTA == errSecSuccess, let trustedApp = trusted else {
    throw NSError(domain: "ghw.keychain", code: Int(stTA), userInfo: [NSLocalizedDescriptionKey: "SecTrustedApplicationCreateFromPath failed for: \(execPath)"])
  }

  var access: SecAccess?
  let trustedList = [trustedApp] as CFArray
  let stAcc = SecAccessCreate(label as CFString, trustedList, &access)
  guard stAcc == errSecSuccess, let secAccess = access else {
    throw NSError(domain: "ghw.keychain", code: Int(stAcc), userInfo: [NSLocalizedDescriptionKey: "SecAccessCreate failed"])
  }

  return secAccess
}

func keychainSetWithOptionalACL(service: String, account: String, value: String, useACL: Bool) throws {
  let data = value.data(using: .utf8) ?? Data()

  var query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: account,
  ]

  // Update first (cannot update access control easily; if ACL requested, we delete+add)
  if !useACL {
    let attrs: [String: Any] = [kSecValueData as String: data]
    let stUp = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
    if stUp == errSecSuccess { return }
    if stUp != errSecItemNotFound {
      throw NSError(domain: "ghw.keychain", code: Int(stUp), userInfo: [NSLocalizedDescriptionKey: "SecItemUpdate failed"])
    }

    query[kSecValueData as String] = data
    let stAdd = SecItemAdd(query as CFDictionary, nil)
    guard stAdd == errSecSuccess else {
      throw NSError(domain: "ghw.keychain", code: Int(stAdd), userInfo: [NSLocalizedDescriptionKey: "SecItemAdd failed"])
    }
    return
  }

  // With ACL: delete existing then add with kSecAttrAccess.
  _ = SecItemDelete(query as CFDictionary)

  let access = try makeSecAccessForThisExecutable(label: "ghw token")
  query[kSecValueData as String] = data
  query[kSecAttrAccess as String] = access

  let stAdd = SecItemAdd(query as CFDictionary, nil)
  guard stAdd == errSecSuccess else {
    throw NSError(domain: "ghw.keychain", code: Int(stAdd), userInfo: [NSLocalizedDescriptionKey: "SecItemAdd (with ACL) failed"])
  }
}
