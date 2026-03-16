import Foundation

struct RealKeychainProvider: KeychainProviding {
  func getToken(service: String, account: String) throws -> String {
    try keychainGet(service: service, account: account)
  }

  func setToken(service: String, account: String, value: String, useACL: Bool) throws {
    try keychainSetWithOptionalACL(service: service, account: account, value: value, useACL: useACL)
  }
}

struct RealGhRunner: GhRunning {
  func runGh(ghPath: String, args: [String], env: [String : String], inheritStdio: Bool) throws -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: ghPath)
    p.arguments = args
    p.environment = env

    if inheritStdio {
      p.standardInput = FileHandle.standardInput
      p.standardOutput = FileHandle.standardOutput
      p.standardError = FileHandle.standardError
    } else {
      p.standardOutput = FileHandle.nullDevice
      p.standardError = FileHandle.nullDevice
    }

    try p.run()
    p.waitUntilExit()
    return p.terminationStatus
  }
}
