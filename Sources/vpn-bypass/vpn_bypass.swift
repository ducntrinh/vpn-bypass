import Foundation
import SystemConfiguration

let TARGET_HOSTS = ["chatgpt.com", "auth.openai.com", "opencode.ai"]
let DNS_SERVER = "1.1.1.1"

func run(_ command: String, arguments: [String]) -> (Int32, String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: command)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    } catch {
        return (-1, "Error: \(error)")
    }
}

func resolveIPv4(host: String) -> [String] {
    let (_, output) = run("/usr/bin/dig", arguments: ["@\(DNS_SERVER)", "+short", "A", host])
    return output
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { ip in
            let parts = ip.split(separator: ".", omittingEmptySubsequences: false)
            return parts.count == 4 && parts.allSatisfy { $0.allSatisfy { $0.isNumber } }
        }
}

func getGateway() -> String? {
    guard let store = SCDynamicStoreCreate(nil, "vpn-bypass" as CFString, nil, nil) else { return nil }
    guard let info = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any] else { return nil }
    return info["Router"] as? String
}

func addRoute(ip: String, via gateway: String) {
    let (status, output) = run("/sbin/route", arguments: ["-n", "add", "-host", ip, gateway])
    if status == 0 || output.contains("add host") {
        print("  + \(ip) -> \(gateway)")
    }
}

func deleteRoute(ip: String) {
    let (status, _) = run("/sbin/route", arguments: ["-n", "delete", ip])
    if status == 0 {
        print("  - \(ip)")
    }
}

func applyRoutes() {
    print("\nApplying bypass routes...")
    guard let gateway = getGateway() else {
        print("  No gateway found - network down?")
        return
    }
    print("  Gateway: \(gateway)")

    for host in TARGET_HOSTS {
        let ips = resolveIPv4(host: host)
        print("  \(host) -> \(ips)")
        for ip in ips { deleteRoute(ip: ip) }
        for ip in ips { addRoute(ip: ip, via: gateway) }
    }
}

func storeCallback(store: SCDynamicStore, changedKeys: CFArray?, info: UnsafeMutableRawPointer?) {
    if let keys = changedKeys as? [String] {
        print("Network change: \(keys)")
        applyRoutes()
    }
}

@main
struct VPNBypass {
    static func main() {
        applyRoutes()

        guard let store = SCDynamicStoreCreate(
            nil, "vpn-bypass" as CFString,
            storeCallback, nil
        ) else {
            print("Fatal: SCDynamicStoreCreate failed")
            exit(1)
        }

        SCDynamicStoreSetNotificationKeys(
            store,
            ["State:/Network/Global/IPv4"] as CFArray,
            nil
        )

        let source = SCDynamicStoreCreateRunLoopSource(nil, store, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)

        print("Watching for network changes...")
        CFRunLoopRun()
    }
}
