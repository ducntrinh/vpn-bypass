BINARY = /usr/local/bin/vpn-bypass
PLIST = /Library/LaunchDaemons/com.vpnbypass.daemon.plist

build:
	swift build --configuration release

install: build
	cp .build/release/vpn-bypass $(BINARY)
	cp Resources/com.vpnbypass.plist $(PLIST)
	launchctl load $(PLIST)

uninstall:
	launchctl unload $(PLIST) 2>/dev/null || true
	rm -f $(PLIST) $(BINARY)

test:
	swift run

.PHONY: build install uninstall test
