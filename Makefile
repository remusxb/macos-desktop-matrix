# A real .app bundle, so macOS lists it as "Workspace Matrix" in Privacy & Security.
APP := $(HOME)/Applications/WorkspaceMatrix.app
BIN := $(APP)/Contents/MacOS/workspace-matrix
PLIST := $(HOME)/Library/LaunchAgents/local.workspace-matrix.plist
CONFIG := $(HOME)/.config/workspace-matrix/config.json
LOG := $(HOME)/Library/Logs/workspace-matrix.log
DOMAIN := gui/$(shell id -u)
# Command Line Tools (no Xcode) ship swift-testing's macro plugin outside the default search path.
CLT_PLUGINS := /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing

build:
	swift build -c release

test:
	swift test $(if $(wildcard $(CLT_PLUGINS)),-Xswiftc -plugin-path -Xswiftc $(CLT_PLUGINS))

install: build
	mkdir -p $(APP)/Contents/MacOS $(dir $(CONFIG))
	cp Info.plist $(APP)/Contents/
	cp .build/release/WorkspaceMatrix $(BIN)
	# Fixed designated requirement: macOS keeps the granted permissions across rebuilds.
	codesign -f -s - -r='designated => identifier "local.workspace-matrix"' $(APP)
	[ -f $(CONFIG) ] || cp config.example.json $(CONFIG)
	sed 's|__BIN__|$(BIN)|; s|__LOG__|$(LOG)|' launchd.plist > $(PLIST)
	launchctl bootout $(DOMAIN) $(PLIST) 2>/dev/null || true
	launchctl bootstrap $(DOMAIN) $(PLIST)

# Config is read at startup, so run this after editing it.
restart:
	launchctl kickstart -k $(DOMAIN)/local.workspace-matrix

# Clears the granted permissions, if macOS ever stops honoring them.
reset-permissions:
	tccutil reset Accessibility local.workspace-matrix
	tccutil reset ScreenCapture local.workspace-matrix

uninstall:
	launchctl bootout $(DOMAIN) $(PLIST) 2>/dev/null || true
	rm -rf $(APP) $(PLIST)

.PHONY: build test install restart reset-permissions uninstall
