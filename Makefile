APP := build/Audra.app
BUNDLE_ID := com.buemura.Audra

.PHONY: run build reset-accessibility open test dmg clean

## Build, reset the Accessibility grant and open the app
run: build reset-accessibility open

## Build "build/Audra.app" (Apple Silicon, ad-hoc signed)
build:
	./scripts/build-app.sh

## Drop the Accessibility grant (it breaks after every rebuild); grant it again on launch
reset-accessibility:
	-tccutil reset Accessibility $(BUNDLE_ID)

## Quit any running copy, wait for it to exit (opening during shutdown fails with -600), then open the built app
open:
	@pkill -x Audra || true
	@while pgrep -x Audra >/dev/null; do sleep 0.1; done
	open "$(APP)"

## Run all tests with xcodebuild (MLX needs the Metal toolchain). ONLY=Target/TestClass runs a subset.
## The bundle path lets package resources (Misaki dictionaries, Kokoro config) load outside an app.
test:
	TEST_RUNNER_PACKAGE_RESOURCE_BUNDLE_PATH="$(CURDIR)/build/DerivedData/Build/Products/Debug" \
	xcodebuild test -scheme Audra-Package -destination 'platform=macOS,arch=arm64' \
		-derivedDataPath build/DerivedData -quiet $(if $(ONLY),-only-testing:$(ONLY))

dmg:
	./scripts/make-dmg.sh

clean:
	rm -rf build .build
