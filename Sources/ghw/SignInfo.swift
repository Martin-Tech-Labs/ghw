import Foundation
import Security

struct SignInfo {
  static func designatedRequirement(executablePath: String) -> String? {
    let url = URL(fileURLWithPath: executablePath)
    var staticCode: SecStaticCode?
    let st1 = SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &staticCode)
    guard st1 == errSecSuccess, let code = staticCode else { return nil }

    var req: SecRequirement?
    let st2 = SecCodeCopyDesignatedRequirement(code, SecCSFlags(), &req)
    guard st2 == errSecSuccess, let requirement = req else { return nil }

    var cfStr: CFString?
    let st3 = SecRequirementCopyString(requirement, SecCSFlags(), &cfStr)
    guard st3 == errSecSuccess, let s = cfStr as String? else { return nil }
    return s
  }

  static func cdhash(executablePath: String) -> String? {
    let url = URL(fileURLWithPath: executablePath)
    var staticCode: SecStaticCode?
    let st1 = SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &staticCode)
    guard st1 == errSecSuccess, let code = staticCode else { return nil }

    var info: CFDictionary?
    let st2 = SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info)
    guard st2 == errSecSuccess, let dict = info as? [String: Any] else { return nil }

    if let cd = dict[kSecCodeInfoUnique as String] as? Data {
      return cd.map { String(format: "%02x", $0) }.joined()
    }
    return nil
  }

  static func signingSummary(executablePath: String) -> String {
    var parts: [String] = []
    if let req = designatedRequirement(executablePath: executablePath) {
      parts.append("designatedRequirement=\(req)")
    } else {
      parts.append("designatedRequirement=<unavailable>")
    }
    if let cd = cdhash(executablePath: executablePath) {
      parts.append("cdhash=\(cd)")
    }
    return parts.joined(separator: " ")
  }
}
