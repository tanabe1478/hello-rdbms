import Foundation

func printPrompt() {
    print("db > ", terminator: "")
}

@main
struct HelloRdbms {
    static func main() {
        while true {
            printPrompt()
            guard let input = readLine() else {
                // EOF (Ctrl-D) で終了
                print()
                return
            }
            if input.hasPrefix(".") {
                switch input {
                case ".exit":
                    return
                default:
                    print("Unrecognized meta command '\(input)'")
                }
                continue
            }
            switch prepareStatement(input) {
            case .success(let statement):
                executeStatement(statement)
            case .failure(.unrecognizedStatement(let keyword)):
                print("Unrecognized keyword at start of '\(keyword)'.")
            case .failure(.syntaxError(let message)):
                print("Syntax error: \(message)")
            }
        }
    }
}
