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
            print("Unrecognized command '\(input)'")
        }
    }
}
