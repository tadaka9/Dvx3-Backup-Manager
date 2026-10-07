.PHONY: all core manager gui clean test

all:
	./build.sh all

core:
	./build.sh core

manager:
	./build.sh manager

gui:
	./build.sh gui

clean:
	./build.sh clean

test: manager
	./scripts/run-tests.sh
