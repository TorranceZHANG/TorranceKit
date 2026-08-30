.PHONY: test build install install-system package clean

test:
	./scripts/test.sh

build:
	./scripts/build_app.sh

install:
	./scripts/install.sh

install-system:
	./scripts/install.sh --system

package:
	./scripts/package_release.sh

clean:
	swift package clean 2>/dev/null || true
	find .build/torrancekit .build/torrancekit-tests dist -depth -delete 2>/dev/null || true
