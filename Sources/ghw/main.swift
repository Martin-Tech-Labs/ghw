import Foundation
import Security

// ghw: a minimal GitHub CLI wrapper that injects GH_TOKEN from macOS Keychain.
//
// Threat model goal: prevent `gh` from ever invoking `security` to read tokens,
// and support multiple profiles.
//
// This initial version:
// - Supports github.com only.
// - Stores tokens in Keychain (generic password).
// - Selects profile by: --as <name> flag, else default profile.
// - Blocks `gh auth ...` subcommands.
// - Runs `gh` with GH_TOKEN in env, then execs.

struct Config: Codable {
  struct Profile: Codable {
    var username: String
    var keychainService: String
    var keychainAccount: String
  }
  var defaultProfile: String?
  var profiles: [String: Profile]

  static func configPath() -> URL {
    // ~/.config/ghw/config.json
    let home = FileManager.default.homeDirectoryForCurrentUser
    return home.appendingPathComponent(".config/ghw/config.json")
  }

  static func load() throws -> Config {
    let url = configPath()
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(Config.self, from: data)
  }

  func save() throws {
    let url = Config.configPath()
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(self)
    try data.write(to: url, options: [.atomic])
  }
}

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
  ghw login --profile <name> --user <github_username>   # reads token from stdin
  ghw profiles list
  ghw profiles use <name>      # (deprecated; no defaults)
  ghw whoami --as <name>
  ghw --as <name> <gh args...>

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

let args = CommandLine.arguments.dropFirst()
if args.isEmpty { usageAndExit(2) }

var argsArray = Array(args)

func popFlag(_ name: String) -> String? {
  if let i = argsArray.firstIndex(of: name), i + 1 < argsArray.count {
    let v = argsArray[i + 1]
    argsArray.removeSubrange(i...i+1)
    return v
  }
  return nil
}

let asProfile = popFlag("--as")

if argsArray.first == "login" {
  _ = argsArray.removeFirst()
  guard let prof = popFlag("--profile"), let user = popFlag("--user") else { usageAndExit(2) }

  let token = readStdinAll().trimmingCharacters(in: .whitespacesAndNewlines)
  if token.isEmpty {
    FileHandle.standardError.write(Data("Token must be provided via stdin.\n".utf8))
    exit(2)
  }

  var cfg: Config
  do {
    cfg = try Config.load()
  } catch {
    cfg = Config(defaultProfile: nil, profiles: [:])
  }

  let service = "ai.openclaw.ghw.github.com"
  let account = "\(prof):\(user)"
  try keychainSet(service: service, account: account, value: token)

  cfg.profiles[prof] = .init(username: user, keychainService: service, keychainAccount: account)
  if cfg.defaultProfile == nil { cfg.defaultProfile = prof }
  try cfg.save()

  print("OK: stored token for profile=\(prof), user=\(user)")
  exit(0)
}

if argsArray.count >= 2, argsArray[0] == "profiles", argsArray[1] == "list" {
  let cfg = (try? Config.load()) ?? Config(defaultProfile: nil, profiles: [:])
  for (k,v) in cfg.profiles.sorted(by: { $0.key < $1.key }) {
    let star = (cfg.defaultProfile == k) ? "*" : " "
    print("\(star) \(k) -> \(v.username)")
  }
  exit(0)
}

if argsArray.count >= 3, argsArray[0] == "profiles", argsArray[1] == "use" {
  let name = argsArray[2]
  var cfg = (try? Config.load()) ?? Config(defaultProfile: nil, profiles: [:])
  guard cfg.profiles[name] != nil else {
    FileHandle.standardError.write(Data("Unknown profile: \(name)\\n".utf8))
    exit(2)
  }
  cfg.defaultProfile = name
  try cfg.save()
  // Deprecated: we no longer support default profiles. Keep for backwards-compat,
  // but do not rely on it.
  print("Deprecated: default profiles are disabled. Use --as on every command.")
  exit(0)
}

// whoami: call gh api user
if argsArray.first == "whoami" {
  _ = argsArray.removeFirst()
  argsArray.insert(contentsOf: ["api","user"], at: 0)
}

// Block gh auth.*
if argsArray.count >= 2, argsArray[0] == "auth" {
  FileHandle.standardError.write(Data("Blocked: use `ghw login` instead of `gh auth ...`\\n".utf8))
  exit(2)
}

// Load token
let cfg = (try? Config.load()) ?? Config(defaultProfile: nil, profiles: [:])

// Security: require explicit profile selection per command.
// This prevents accidentally using a different account.
guard let pn = asProfile, let prof = cfg.profiles[pn] else {
  FileHandle.standardError.write(Data("Missing --as <profile>. (No default profiles allowed.) Run: ghw profiles list\\n".utf8))
  exit(2)
}

let token: String
 do {
  token = try keychainGet(service: prof.keychainService, account: prof.keychainAccount)
 } catch {
  FileHandle.standardError.write(Data(("Failed to load token from Keychain: \(error)\\n").utf8))
  exit(2)
 }

// Build env
var env = ProcessInfo.processInfo.environment
env["GH_TOKEN"] = token
env["GITHUB_TOKEN"] = token // some tools look for this

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
  FileHandle.standardError.write(Data(("Failed to run gh: \(error)\\n").utf8))
  exit(127)
}
