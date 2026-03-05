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

  static func signingSummary(executablePath: String) -> String {
    if let req = designatedRequirement(executablePath: executablePath) {
      return "designatedRequirement=\(req)"
    }
    return "designatedRequirement=<unavailable>"
  }
}
