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

func ghValidateToken(_ token: String) -> Bool {
  // Validate via a lightweight API call.
  // `gh api user` uses GH_TOKEN and returns 0 on success.
  let ghPath = "/opt/homebrew/bin/gh"
  let p = Process()
  p.executableURL = URL(fileURLWithPath: ghPath)
  p.arguments = ["api", "user"]
  var env = ProcessInfo.processInfo.environment
  env["GH_TOKEN"] = token
  p.environment = env

  // Silence output; we only care about exit code.
  p.standardOutput = FileHandle.nullDevice
  p.standardError = FileHandle.nullDevice

  do {
    try p.run()
    p.waitUntilExit()
    return p.terminationStatus == 0
  } catch {
    return false
  }
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

var argsArray = Array(args)

func popFlag(_ name: String) -> String? {
  if let i = argsArray.firstIndex(of: name), i + 1 < argsArray.count {
    let v = argsArray[i + 1]
    argsArray.removeSubrange(i...i+1)
    return v
  }
  return nil
}

if argsArray.first == "login" {
  _ = argsArray.removeFirst()
  guard let user = popFlag("--as") else { usageAndExit(2) }

  // Default behavior:
  // - If stdin is a TTY: prompt for token with hidden input.
  // - Else (piped/CI): read from stdin.
  let token: String
  if isatty(STDIN_FILENO) == 1 {
    token = (try? readSecret(prompt: "GitHub token (input hidden): "))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  } else {
    token = readStdinAll().trimmingCharacters(in: .whitespacesAndNewlines)
  }

  if token.isEmpty {
    FileHandle.standardError.write(Data("Token must be provided (interactive prompt or via stdin).\n".utf8))
    exit(2)
  }

  // Validate token before storing it.
  if !ghValidateToken(token) {
    FileHandle.standardError.write(Data("Token validation failed (gh api user). Not storing token.\n".utf8))
    exit(2)
  }

  // Prefer storing with ACL when possible (requires signed ghw and one-time user approval).
  // If it fails, fall back to a plain Keychain item.
  do {
    try keychainSetWithOptionalACL(service: "ai.openclaw.ghw.github.com", account: user, value: token, useACL: true)
    print("OK: stored token with ACL for github_username=\(user)")
  } catch {
    try keychainSetWithOptionalACL(service: "ai.openclaw.ghw.github.com", account: user, value: token, useACL: false)
    print("OK: stored token (no ACL) for github_username=\(user)")
  }
  exit(0)
}

// whoami: call gh api user
if argsArray.first == "whoami" {
  _ = argsArray.removeFirst()
  argsArray.insert(contentsOf: ["api", "user"], at: 0)
}

let asUser = popFlag("--as")

// Block gh auth.*
if argsArray.count >= 1, argsArray[0] == "auth" {
  FileHandle.standardError.write(Data("Blocked: use `ghw login` instead of `gh auth ...`\n".utf8))
  exit(2)
}

// Load token (always require explicit github username)
guard let user = asUser else {
  FileHandle.standardError.write(Data("Missing --as <github_username>. Run: ghw login --as <github_username> (token via stdin)\n".utf8))
  exit(2)
}

let token: String
 do {
  token = try keychainGet(service: "ai.openclaw.ghw.github.com", account: user)
 } catch {
  FileHandle.standardError.write(Data(("Failed to load token from Keychain: \(error)\n").utf8))
  exit(2)
 }

// Build env
var env = ProcessInfo.processInfo.environment
env["GH_TOKEN"] = token

let ghPath = "/opt/homebrew/bin/gh"

let p = Process()
p.executableURL = URL(fileURLWithPath: ghPath)
p.arguments = argsArray
p.environment = env

// Inherit stdio
p.standardInput = FileHandle.standardInput
p.standardOutput = FileHandle.standardOutput
p.standardError = FileHandle.standardError

do {
  try p.run()
  p.waitUntilExit()
  exit(p.terminationStatus)
} catch {
  FileHandle.standardError.write(Data(("Failed to run gh: \(error)\n").utf8))
  exit(127)
}
