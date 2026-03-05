import Foundation
import Darwin

// Read a secret from the terminal without echoing.
// This is used for `ghw login --prompt`.

func readSecret(prompt: String) throws -> String {
  // Print prompt to stderr (so stdout can be piped)
  if let data = prompt.data(using: .utf8) {
    FileHandle.standardError.write(data)
    FileHandle.standardError.synchronizeFile()
  }

  var oldt = termios()
  if tcgetattr(STDIN_FILENO, &oldt) != 0 {
    throw NSError(domain: "ghw.term", code: 1, userInfo: [NSLocalizedDescriptionKey: "tcgetattr failed"])
  }

  var newt = oldt
  newt.c_lflag &= ~UInt(ECHO)
  if tcsetattr(STDIN_FILENO, TCSANOW, &newt) != 0 {
    throw NSError(domain: "ghw.term", code: 2, userInfo: [NSLocalizedDescriptionKey: "tcsetattr failed"])
  }

  defer {
    _ = tcsetattr(STDIN_FILENO, TCSANOW, &oldt)
    // newline after hidden input
    FileHandle.standardError.write(Data("\n".utf8))
  }

  // Read line
  let line = readLine(strippingNewline: true) ?? ""
  return line
}
