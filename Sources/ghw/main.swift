import Foundation
import Security

// ghw: a minimal GitHub CLI wrapper that injects GH_TOKEN from macOS Keychain.
//
// Threat model goal: prevent `gh` from ever invoking `security` to read tokens.
//
// This version:
// - Supports github.com only.
// - Stores tokens in Keychain (generic password).
// - Requires: --as <github_username> on every command.
// - Blocks `gh auth ...` subcommands.
// - Runs `gh` with GH_TOKEN in env, then executes.
//
// No config file by design.
// Tokens are stored in Keychain under:
//   service: ai.openclaw.ghw.github.com
//   account: <github_username>

enum KeychainError: Error, CustomStringConvertible {
  case notFound
  case unexpectedStatus(OSStatus)

  var description: String {
    switch self {
      case .notFound: return "Keychain item not found"
      case .unexpectedStatus(let s): return "Keychain error: \(s)"
    }
  }
}

func keychainGet(service: String, account: String) throws -> String {
  let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: account,
    kSecReturnData as String: true,
    kSecMatchLimit as String: kSecMatchLimitOne,
  ]

  var item: CFTypeRef?
  let status = SecItemCopyMatching(query as CFDictionary, &item)
  if status == errSecItemNotFound { throw KeychainError.notFound }
  guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
  guard let data = item as? Data, let s = String(data: data, encoding: .utf8) else {
    throw KeychainError.unexpectedStatus(errSecInternalError)
  }
  return s
}

// Legacy simple set (no ACL). Prefer keychainSetWithOptionalACL when possible.
func keychainSet(service: String, account: String, value: String) throws {
  let data = value.data(using: .utf8) ?? Data()

  // Try update
  let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: account,
  ]
  let attrs: [String: Any] = [
    kSecValueData as String: data,
  ]

  let statusUpdate = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
  if statusUpdate == errSecSuccess { return }

  if statusUpdate != errSecItemNotFound {
    throw KeychainError.unexpectedStatus(statusUpdate)
  }

  // Add
  var add = query
  add[kSecValueData as String] = data
  let statusAdd = SecItemAdd(add as CFDictionary, nil)
  guard statusAdd == errSecSuccess else {
    throw KeychainError.unexpectedStatus(statusAdd)
  }
}

func usageAndExit(_ code: Int32 = 2) -> Never {
  let msg = """
Usage:
  ghw --version
  ghw --signing

  # Store token for a github.com username (token via stdin or hidden prompt)
  ghw login --as <github_username>

  # Test
  ghw whoami --as <github_username>

  # Run any gh command (always requires --as)
  ghw --as <github_username> <gh args...>

Environment:
  GHW_DIAG=1   Print version + signing identity to stderr on every invocation.

Notes:
- Blocks: gh auth ... (use ghw login instead)
- github.com only.
""" + "\n"
  FileHandle.standardError.write(Data(msg.utf8))
  exit(code)
}

func readStdinAll() -> String {
  let data = FileHandle.standardInput.readDataToEndOfFile()
  return String(data: data, encoding: .utf8) ?? ""
}


func printDiagIfEnabled() {
  if ProcessInfo.processInfo.environment["GHW_DIAG"] == "1" {
    let execPath = CommandLine.arguments.first ?? ""
    let resolved = URL(fileURLWithPath: execPath).resolvingSymlinksInPath().path
    let msg = "[ghw] version=\(GHW_VERSION) executable=\(resolved) \(SignInfo.signingSummary(executablePath: resolved))\n"
    FileHandle.standardError.write(Data(msg.utf8))
  }
}

let args = CommandLine.arguments.dropFirst()
if args.isEmpty { usageAndExit(2) }

// Always print diagnostics when explicitly requested.
if args.contains("--version") {
  print(GHW_VERSION)
  exit(0)
}
if args.contains("--signing") {
  let execPath = CommandLine.arguments.first ?? ""
  let resolved = URL(fileURLWithPath: execPath).resolvingSymlinksInPath().path
  print("version=\(GHW_VERSION)")
  print("executable=\(resolved)")
  print(SignInfo.signingSummary(executablePath: resolved))
  exit(0)
}

// Print per-invocation diag when enabled.
printDiagIfEnabled()

let isTTY = isatty(STDIN_FILENO) == 1
// Only read stdin when it's not a TTY. Reading a TTY to EOF would block.
let stdinAll = isTTY ? "" : readStdinAll()

let app = GhwApp(keychain: RealKeychainProvider(), runner: RealGhRunner())

do {
  let status = try app.run(
    argv: Array(args),
    stdin: stdinAll,
    isTTY: isTTY,
    promptSecret: { prompt in
      (try? readSecret(prompt: prompt))
    }
  )
  exit(status)
} catch let e as GhwExit {
  switch e {
  case .exit(let code, let msg):
    if let msg {
      FileHandle.standardError.write(Data((msg + "\n").utf8))
    }
    exit(code)
  }
} catch {
  FileHandle.standardError.write(Data(("ghw: \(error)\n").utf8))
  exit(1)
}
