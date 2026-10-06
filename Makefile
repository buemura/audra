APP := build/Screen Reader.app
BUNDLE_ID := com.buemura.ScreenReader

.PHONY: run build reset-accessibility open test dmg clean

## Build, reset the Accessibility grant and open the app
run: build reset-accessibility open

## Build "build/Screen Reader.app" (Apple Silicon, ad-hoc signed)
build:
	./scripts/build-app.sh

## Drop the Accessibility grant (it breaks after every rebuild); grant it again on launch
reset-accessibility:
	-tccutil reset Accessibility $(BUNDLE_ID)

## Quit any running copy, then open the built app
open:
	-pkill -x ScreenReader
	open "$(APP)"

## Run all tests with xcodebuild (MLX needs the Metal toolchain). ONLY=Target/TestClass runs a subset.
## The bundle path lets package resources (Misaki dictionaries, Kokoro config) load outside an app.
test:
	TEST_RUNNER_PACKAGE_RESOURCE_BUNDLE_PATH="$(CURDIR)/build/DerivedData/Build/Products/Debug" \
	xcodebuild test -scheme ScreenReader-Package -destination 'platform=macOS,arch=arm64' \
		-derivedDataPath build/DerivedData -quiet $(if $(ONLY),-only-testing:$(ONLY))

dmg:
	./scripts/make-dmg.sh

clean:
	rm -rf build .build
