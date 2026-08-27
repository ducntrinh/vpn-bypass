# vpn-bypass

A lightweight macOS background daemon written in Swift that selectively routes specific domains directly through your local network gateway, bypassing active VPN connections (split-tunneling / VPN bypass).

## Features

- **Selective Domain Routing**: Directs traffic for specified hosts outside of your VPN interface.
- **Dynamic Network Monitoring**: Listens to macOS `SystemConfiguration` (`SCDynamicStore`) events to automatically re-resolve IPs and reapply routes whenever network interfaces change or reconnect.
- **Background Daemon Support**: Runs natively as a `launchd` LaunchDaemon on macOS with automatic startup on boot.
- **Zero Heavy Dependencies**: Built with native Swift using Apple's `SystemConfiguration` framework and standard macOS utilities (`dig`, `route`).

## How It Works

1. **Gateway Detection**: Queries macOS `SCDynamicStore` (`State:/Network/Global/IPv4`) to find your local router's default IPv4 gateway.
2. **DNS Resolution**: Resolves the configured domain names to IPv4 addresses using Cloudflare DNS (`1.1.1.1` via `dig`).
3. **Route Management**: Injects host-specific static routing table entries (`/sbin/route add -host <ip> <gateway>`) pointing directly to your local gateway instead of the VPN tunnel.
4. **Auto-Update**: Subscribes to `SCDynamicStore` runloop notifications to update routes automatically when network states change (e.g., VPN connects, disconnects, or WiFi switches).

## Prerequisites

- **macOS**
- **Swift 6.0+** / Xcode Command Line Tools (`xcode-select --install`)
- **Root / Administrator Privileges** (required to manage system routing tables and install LaunchDaemons)

## Configuration

To customize target domains or the DNS server, edit [`Sources/vpn-bypass/vpn_bypass.swift`](file:///Users/ducntrinh/scripts/vpn-bypass/Sources/vpn-bypass/vpn_bypass.swift):

```swift
let TARGET_HOSTS = ["chatgpt.com", "auth.openai.com"]
let DNS_SERVER = "1.1.1.1"
```

## Installation & Usage

### 1. Build and Install as a Background Service

Build the release binary, copy it to `/usr/local/bin/vpn-bypass`, install the LaunchDaemon, and start the service:

```bash
sudo make install
```

### 2. View Service Logs

When running as a launch daemon, logs are written to `/var/log/vpnbypass.log`:

```bash
tail -f /var/log/vpnbypass.log
```

### 3. Uninstall

To stop the daemon and remove installed files:

```bash
sudo make uninstall
```

### 4. Running for Testing / Development

To run directly in the foreground:

```bash
sudo swift run
```

Or via Makefile:

```bash
sudo make test
```

## Makefile Targets

| Target | Description |
|---|---|
| `make build` | Builds the project in release mode (`swift build --configuration release`) |
| `sudo make install` | Installs the binary to `/usr/local/bin` and starts the `launchd` daemon |
| `sudo make uninstall` | Unloads the `launchd` daemon and deletes installed files |
| `sudo make test` | Runs the executable directly via `swift run` |

## License

This project is licensed under the [MIT License](file:///Users/ducntrinh/scripts/vpn-bypass/LICENSE).
