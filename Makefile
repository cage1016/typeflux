RELEASE_VARIANT := $(if $(TYPEFLUX_RELEASE_VARIANT),$(TYPEFLUX_RELEASE_VARIANT),minimal)
RELEASE_ARCH := $(if $(TYPEFLUX_RELEASE_ARCH),$(TYPEFLUX_RELEASE_ARCH),native)
PACKAGE_NAME = Typeflux$(if $(filter full,$(RELEASE_VARIANT)),-full,$(if $(filter app-only,$(RELEASE_VARIANT)),-app-only,))$(if $(filter arm64,$(RELEASE_ARCH)),-apple-silicon,$(if $(filter x86_64,$(RELEASE_ARCH)),-intel,$(if $(filter universal,$(RELEASE_ARCH)),-universal,)))

run:
	./scripts/run_dev_app.sh

release:
	./scripts/release_notarize.sh --move-to-downloads

intel-release:
	./scripts/release_intel.sh --move-to-downloads

release-continue:
	./scripts/release_notarize.sh --continue --move-to-downloads

intel-release-continue:
	./scripts/release_intel.sh --continue --move-to-downloads

full-release:
	TYPEFLUX_RELEASE_VARIANT=full $(MAKE) release

full-intel-release:
	TYPEFLUX_RELEASE_VARIANT=full $(MAKE) intel-release

app-only-release:
	TYPEFLUX_RELEASE_VARIANT=app-only $(MAKE) release

app-only-intel-release:
	TYPEFLUX_RELEASE_VARIANT=app-only $(MAKE) intel-release

full-release-continue:
	TYPEFLUX_RELEASE_VARIANT=full $(MAKE) release-continue

dev:
	TYPEFLUX_API_URL=http://127.0.0.1:8080 ./scripts/run_dev_attached.sh

full-dev:
	TYPEFLUX_API_URL=http://127.0.0.1:8080 TYPEFLUX_DEV_VARIANT=full ./scripts/run_dev_attached.sh

build:
	swift build

test:
	swift test

coverage:
	./scripts/coverage.sh

dmg:
	./scripts/build_dmg.sh

release-notarize:
	./scripts/release_notarize.sh

release-notarize-continue:
	./scripts/release_notarize.sh --continue

format:
	./scripts/format.sh

.PHONY: run release intel-release release-continue intel-release-continue full-release full-intel-release app-only-release app-only-intel-release full-release-continue dev full-dev build test coverage dmg release-notarize release-notarize-continue format
