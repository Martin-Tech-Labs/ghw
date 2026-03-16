import Foundation

protocol KeychainProviding {
  func getToken(service: String, account: String) throws -> String
  func setToken(service: String, account: String, value: String, useACL: Bool) throws
}

protocol GhRunning {
  /// Run `gh`.
  /// - Returns: process exit status.
  func runGh(ghPath: String, args: [String], env: [String: String], inheritStdio: Bool) throws -> Int32
}

struct GhwConfig {
  let service = "ai.openclaw.ghw.github.com"
  let ghPath: String

  init() {
    // Security policy: do not allow overriding gh path in production.
    // In DEBUG (tests/CI), allow overriding for deterministic acceptance tests.
    #if DEBUG
    if let p = ProcessInfo.processInfo.environment["GHW_GH_PATH"], !p.isEmpty {
      self.ghPath = p
    } else {
      self.ghPath = "/opt/homebrew/bin/gh"
    }
    #else
    self.ghPath = "/opt/homebrew/bin/gh"
    #endif
  }
}

enum GhwExit: Error {
  case exit(Int32, String?)
}

struct GhwApp {
  let cfg: GhwConfig
  let keychain: KeychainProviding
  let runner: GhRunning

  init(cfg: GhwConfig = GhwConfig(), keychain: KeychainProviding, runner: GhRunning) {
    self.cfg = cfg
    self.keychain = keychain
    self.runner = runner
  }

  func run(argv: [String], stdin: String, isTTY: Bool, promptSecret: (String) -> String?) throws -> Int32 {
    if argv.isEmpty {
      throw GhwExit.exit(2, "Missing args")
    }

    var argsArray = argv

    func popFlag(_ name: String) -> String? {
      if let i = argsArray.firstIndex(of: name), i + 1 < argsArray.count {
        let v = argsArray[i + 1]
        argsArray.removeSubrange(i...i+1)
        return v
      }
      return nil
    }

    if argsArray.contains("--version") {
      // main.swift handles printing; here we just exit 0.
      throw GhwExit.exit(0, nil)
    }

    if argsArray.first == "login" {
      _ = argsArray.removeFirst()
      guard let user = popFlag("--as"), !user.isEmpty else {
        throw GhwExit.exit(2, "login requires --as <alias>")
      }
      if argsArray.contains("--as") {
        throw GhwExit.exit(2, "--as may only be provided once")
      }

      let token: String
      if isTTY {
        token = (promptSecret("GitHub token (input hidden): ") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      } else {
        token = stdin.trimmingCharacters(in: .whitespacesAndNewlines)
      }

      if token.isEmpty {
        throw GhwExit.exit(2, "Token must be provided (interactive prompt or via stdin).")
      }

      // Validate token before storing it.
      let status = (try? runner.runGh(
        ghPath: cfg.ghPath,
        args: ["api", "user"],
        env: mergedEnv(["GH_TOKEN": token]),
        inheritStdio: false
      )) ?? 1

      guard status == 0 else {
        throw GhwExit.exit(2, "Token validation failed (gh api user). Not storing token.")
      }

      // Prefer storing with ACL. Fallback to non-ACL.
      do {
        try keychain.setToken(service: cfg.service, account: user, value: token, useACL: true)
      } catch {
        try keychain.setToken(service: cfg.service, account: user, value: token, useACL: false)
      }

      return 0
    }

    // whoami: transform to `gh api user`
    if argsArray.first == "whoami" {
      _ = argsArray.removeFirst()
      argsArray.insert(contentsOf: ["api", "user"], at: 0)
    }

    let asUser = popFlag("--as")
    if argsArray.contains("--as") {
      throw GhwExit.exit(2, "--as may only be provided once")
    }

    // Block gh auth.*
    if argsArray.count >= 1, argsArray[0] == "auth" {
      throw GhwExit.exit(2, "Blocked: use `ghw login` instead of `gh auth ...`")
    }

    guard let user = asUser, !user.isEmpty else {
      throw GhwExit.exit(2, "Missing --as <alias>.")
    }

    // Load token
    let token: String
    do {
      token = try keychain.getToken(service: cfg.service, account: user)
    } catch {
      throw GhwExit.exit(2, "Failed to load token from Keychain: \(error)")
    }

    // Proxy to gh
    var env = mergedEnv(["GH_TOKEN": token])
    let st = try runner.runGh(ghPath: cfg.ghPath, args: argsArray, env: env, inheritStdio: true)
    return st
  }

  private func mergedEnv(_ add: [String: String]) -> [String: String] {
    var env = ProcessInfo.processInfo.environment
    for (k, v) in add { env[k] = v }
    return env
  }
}
