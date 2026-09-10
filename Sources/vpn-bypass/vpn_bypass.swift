import Foundation
import SystemConfiguration

let TARGET_HOSTS = ["chatgpt.com", "auth.openai.com", "opencode.ai"]
let TARGET_IPS: [String] = [
    // Add direct IPs here, e.g.:
    "173.245.48.0/20",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "141.101.64.0/18",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
    "162.158.0.0/15",
    "104.16.0.0/13",
    "104.24.0.0/14",
    "172.64.0.0/13",
    "131.0.72.0/22",
]
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

func isValidIPv4(_ ip: String) -> Bool {
    let parts = ip.split(separator: ".", omittingEmptySubsequences: false)
    return parts.count == 4 && parts.allSatisfy { part in
        guard let num = Int(part) else { return false }
        return num >= 0 && num <= 255
    }
}

func applyRoutes() {
    print("\nApplying bypass routes...")
    guard let gateway = getGateway() else {
        print("  No gateway found - network down?")
        return
    }
    print("  Gateway: \(gateway)")

    // Route hostnames (DNS-resolved)
    for host in TARGET_HOSTS {
        let ips = resolveIPv4(host: host)
        print("  \(host) -> \(ips)")
        for ip in ips { deleteRoute(ip: ip) }
        for ip in ips { addRoute(ip: ip, via: gateway) }
    }

    // Route direct IPs (no DNS resolution)
    if !TARGET_IPS.isEmpty {
        print("  Direct IPs:")
        for ip in TARGET_IPS {
            guard isValidIPv4(ip) else {
                print("  ! Skipping invalid IP: \(ip)")
                continue
            }
            deleteRoute(ip: ip)
            addRoute(ip: ip, via: gateway)
        }
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
