# Builds, checks and installs Workspace Matrix. `make check` is the gate every change passes (docs/STANDARDS.md).
BUNDLE_ID := local.workspace-matrix
# A real .app bundle, so macOS lists it as "WorkspaceMatrix" in Privacy & Security.
APP := $(HOME)/Applications/WorkspaceMatrix.app
BIN := $(APP)/Contents/MacOS/workspace-matrix
PLIST := $(HOME)/Library/LaunchAgents/$(BUNDLE_ID).plist
CONFIG := $(HOME)/.config/workspace-matrix/config.json
# Only what the process writes to stderr, such as a crash; its own messages are in the unified log (`make logs`).
STDERR := $(HOME)/Library/Logs/workspace-matrix.log
DOMAIN := gui/$(shell id -u)
SWIFT_SOURCES := Package.swift Sources Tests
# Command Line Tools (no Xcode) ship swift-testing's macro plugin outside the default search path.
CLT_PLUGINS := /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
TEST_FLAGS := $(if $(wildcard $(CLT_PLUGINS)),-Xswiftc -plugin-path -Xswiftc $(CLT_PLUGINS))

build:
	swift build -c release -Xswiftc -warnings-as-errors

test:
	swift test $(TEST_FLAGS)

fmt:
	swift format format --in-place --recursive $(SWIFT_SOURCES)

lint:
	swift format lint --strict --recursive $(SWIFT_SOURCES)

# The gate: formatting and lint, a warning-free build, the tests.
check: lint build test

install: build
	mkdir -p $(APP)/Contents/MacOS $(dir $(CONFIG))
	cp Info.plist $(APP)/Contents/
	cp .build/release/WorkspaceMatrix $(BIN)
	# A fixed designated requirement: macOS keeps the granted permissions across rebuilds.
	codesign -f -s - -r='designated => identifier "$(BUNDLE_ID)"' $(APP)
	[ -f $(CONFIG) ] || cp config.example.json $(CONFIG)
	sed 's|__LABEL__|$(BUNDLE_ID)|; s|__BIN__|$(BIN)|; s|__LOG__|$(STDERR)|' launchd.plist > $(PLIST)
	launchctl bootout $(DOMAIN) $(PLIST) 2>/dev/null || true
	launchctl bootstrap $(DOMAIN) $(PLIST)

# Settings edited by hand are read at launch, so run this after editing the file.
restart:
	launchctl kickstart -k $(DOMAIN)/$(BUNDLE_ID)

# Follows what the app logs.
logs:
	/usr/bin/log stream --style compact --predicate 'subsystem == "$(BUNDLE_ID)"'

# Clears the granted permissions, if macOS ever stops honoring them.
reset-permissions:
	tccutil reset Accessibility $(BUNDLE_ID)
	tccutil reset ScreenCapture $(BUNDLE_ID)

uninstall:
	launchctl bootout $(DOMAIN) $(PLIST) 2>/dev/null || true
	rm -rf $(APP) $(PLIST)

.PHONY: build test fmt lint check install restart logs reset-permissions uninstall
