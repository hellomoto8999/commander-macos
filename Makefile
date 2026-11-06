.PHONY: build debug run clean

build:
	./scripts/build-app.sh release

debug:
	./scripts/build-app.sh debug

run: build
	open dist/Commander.app

clean:
	rm -rf .build dist
