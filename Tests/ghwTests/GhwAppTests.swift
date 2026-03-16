import Foundation
import Testing
@testable import ghw

final class MockKeychain: KeychainProviding {
  struct SetCall: Equatable {
    let service: String
    let account: String
    let value: String
    let useACL: Bool
  }

  var tokens: [String: String] = [:]
  var getCalls: [(service: String, account: String)] = []
  var setCalls: [SetCall] = []
  var failACLWrite: Bool = false

  func getToken(service: String, account: String) throws -> String {
    getCalls.append((service, account))
    if let t = tokens[account] { return t }
    throw NSError(domain: "MockKeychain", code: 404)
  }

  func setToken(service: String, account: String, value: String, useACL: Bool) throws {
    setCalls.append(.init(service: service, account: account, value: value, useACL: useACL))
    if useACL && failACLWrite {
      throw NSError(domain: "MockKeychain", code: 1)
    }
    tokens[account] = value
  }
}

final class MockRunner: GhRunning {
  struct Call: Equatable {
    let ghPath: String
    let args: [String]
    let envToken: String?
    let inheritStdio: Bool
  }

  var calls: [Call] = []
  var nextStatus: Int32 = 0

  func runGh(ghPath: String, args: [String], env: [String : String], inheritStdio: Bool) throws -> Int32 {
    calls.append(.init(ghPath: ghPath, args: args, envToken: env["GH_TOKEN"], inheritStdio: inheritStdio))
    return nextStatus
  }
}

struct GhwAppTests {
  @Test
  func proxiesToGhAndSelectsTokenByAsUser() throws {
    let keychain = MockKeychain()
    keychain.tokens = ["alice": "tok-alice", "bob": "tok-bob"]
    let runner = MockRunner()
    let app = GhwApp(keychain: keychain, runner: runner)

    let status = try app.run(
      argv: ["--as", "bob", "repo", "view", "Martin-Tech-Labs/ghw"],
      stdin: "",
      isTTY: false,
      promptSecret: { _ in nil }
    )

    #expect(status == 0)
    #expect(keychain.getCalls.count == 1)
    #expect(keychain.getCalls.first?.account == "bob")
    #expect(runner.calls.count == 1)
    #expect(runner.calls[0].args == ["repo", "view", "Martin-Tech-Labs/ghw"])
    #expect(runner.calls[0].envToken == "tok-bob")
    #expect(runner.calls[0].inheritStdio == true)
  }

  @Test
  func blocksAuthWithoutInvokingKeychainOrGh() {
    let keychain = MockKeychain()
    let runner = MockRunner()
    let app = GhwApp(keychain: keychain, runner: runner)

    do {
      _ = try app.run(
        argv: ["--as", "alice", "auth", "login"],
        stdin: "",
        isTTY: false,
        promptSecret: { _ in nil }
      )
      Issue.record("Expected auth to be blocked")
    } catch let e as GhwExit {
      if case .exit(let code, _) = e {
        #expect(code == 2)
      }
    } catch {
      Issue.record("Unexpected error: \(error)")
    }

    #expect(keychain.getCalls.isEmpty)
    #expect(keychain.setCalls.isEmpty)
    #expect(runner.calls.isEmpty)
  }

  @Test
  func loginStoresTokenOnlyAfterValidationSucceeds() throws {
    let keychain = MockKeychain()
    let runner = MockRunner()

    // First call is token validation: gh api user
    runner.nextStatus = 0

    let app = GhwApp(keychain: keychain, runner: runner)
    let status = try app.run(
      argv: ["login", "--as", "alice"],
      stdin: "tok-123\n",
      isTTY: false,
      promptSecret: { _ in nil }
    )

    #expect(status == 0)
    #expect(runner.calls.count == 1)
    #expect(runner.calls[0].args == ["api", "user"])
    #expect(runner.calls[0].envToken == "tok-123")
    #expect(runner.calls[0].inheritStdio == false)

    #expect(keychain.setCalls.count >= 1)
    #expect(keychain.tokens["alice"] == "tok-123")
  }

  @Test
  func loginDoesNotStoreTokenIfValidationFails() {
    let keychain = MockKeychain()
    let runner = MockRunner()

    runner.nextStatus = 1 // validation fails

    let app = GhwApp(keychain: keychain, runner: runner)

    do {
      _ = try app.run(
        argv: ["login", "--as", "alice"],
        stdin: "bad-token\n",
        isTTY: false,
        promptSecret: { _ in nil }
      )
      Issue.record("Expected login to fail when token validation fails")
    } catch let e as GhwExit {
      if case .exit(let code, let msg) = e {
        #expect(code == 2)
        #expect((msg ?? "").contains("Token validation failed"))
      }
    } catch {
      Issue.record("Unexpected error: \(error)")
    }

    #expect(keychain.setCalls.isEmpty)
    #expect(keychain.tokens.isEmpty)
  }

  @Test
  func loginFallsBackToNonACLWriteIfACLWriteFails() throws {
    let keychain = MockKeychain()
    keychain.failACLWrite = true

    let runner = MockRunner()
    runner.nextStatus = 0

    let app = GhwApp(keychain: keychain, runner: runner)
    _ = try app.run(
      argv: ["login", "--as", "alice"],
      stdin: "tok-xyz\n",
      isTTY: false,
      promptSecret: { _ in nil }
    )

    // two set attempts: first with ACL (fails), then without
    #expect(keychain.setCalls.count == 2)
    #expect(keychain.setCalls[0].useACL == true)
    #expect(keychain.setCalls[1].useACL == false)
    #expect(keychain.tokens["alice"] == "tok-xyz")
  }
}
