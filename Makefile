APP := build/Screen Reader.app
BUNDLE_ID := com.buemura.ScreenReader

.PHONY: run build reset-accessibility open test dmg clean

## Build, reset the Accessibility grant and open the app
run: build reset-accessibility open

## Build "build/Screen Reader.app" (universal, ad-hoc signed)
build:
	./scripts/build-app.sh

## Drop the Accessibility grant (it breaks after every rebuild); grant it again on launch
reset-accessibility:
	-tccutil reset Accessibility $(BUNDLE_ID)

## Quit any running copy, then open the built app
open:
	-pkill -x ScreenReader
	open "$(APP)"

test:
	swift test

dmg:
	./scripts/make-dmg.sh

clean:
	rm -rf build .build
