.PHONY: build release test clean lint open

PROJECT = OpenShot.xcodeproj
SCHEME  = OpenShot
CONFIG_DEBUG   = Debug
CONFIG_RELEASE = Release

# ── Build ──────────────────────────────────────────────

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG_DEBUG) build

release:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG_RELEASE) build

# ── Test ───────────────────────────────────────────────

test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG_DEBUG) test

# ── Clean ──────────────────────────────────────────────

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
	rm -rf ~/Library/Developer/Xcode/DerivedData/OpenShot-*

# ── Helpers ────────────────────────────────────────────

open:
	open $(PROJECT)

run: build
	@APP=$$(find ~/Library/Developer/Xcode/DerivedData/OpenShot-*/Build/Products/Debug -name "OpenShot.app" -maxdepth 1 2>/dev/null | head -1); \
	if [ -n "$$APP" ]; then open "$$APP"; else echo "Build first: make build"; fi

loc:
	@find OpenShot -name "*.swift" | xargs wc -l | tail -1
