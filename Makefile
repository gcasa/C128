UNAME := $(shell uname -s)
CC = clang
GNUSTEP_CONFIG ?= gnustep-config
FLAGS = -std=gnu99 -O2 -Wall -Wextra -Wno-unused-parameter \
        -fobjc-exceptions -DCPU6502_STANDALONE=1 -IC128/CPU -IC128/Core
BUILD_DIR = build
CPU = C128/CPU/CPU6502.m C128/CPU/CPU6502+Instructions.m
CORE = $(CPU) $(wildcard C128/Core/*.m)
UI = C128/AppDelegate.m $(wildcard C128/UI/*.m)
UI_HEADERS = C128/AppDelegate.h $(wildcard C128/UI/*.h)
HEADERS = $(wildcard C128/CPU/*.h C128/Core/*.h)
ifeq ($(UNAME),Darwin)
BASE_LIBS = -framework Foundation
GUI_LIBS = -framework Cocoa
APP = build/C128.app/Contents/MacOS/C128
ICON = build/C128.app/Contents/Resources/AppIcon.icns
else
BUILD_DIR = build/gnustep
CC = $(shell $(GNUSTEP_CONFIG) --variable=CC)
FLAGS += $(shell $(GNUSTEP_CONFIG) --objc-flags)
BASE_LIBS = $(shell $(GNUSTEP_CONFIG) --base-libs)
GUI_LIBS = $(shell $(GNUSTEP_CONFIG) --gui-libs)
APP = build/C128
endif
.PHONY: all test clean run format format-check

all: $(APP) $(ICON)

format:
	sh tools/format.sh

format-check:
	sh tools/format.sh --check

C128/Resources/AppIcon.icns: C128/Resources/AppIcon.png tools/build-icon.sh
	sh tools/build-icon.sh

build/C128.app/Contents/Resources/AppIcon.icns: C128/Resources/AppIcon.icns
	mkdir -p $(dir $@)
	cp $< $@

$(APP): $(CORE) $(HEADERS) $(UI) $(UI_HEADERS) C128/main.m C128/Info.plist
	mkdir -p $(dir $@)
	$(CC) $(FLAGS) $(CORE) $(UI) C128/main.m -o $@ $(GUI_LIBS)
ifeq ($(UNAME),Darwin)
	cp C128/Info.plist build/C128.app/Contents/Info.plist
endif

$(BUILD_DIR)/C128Tests: $(CORE) $(HEADERS) Tests/C128Tests.m
	mkdir -p $(BUILD_DIR)
	$(CC) $(FLAGS) $(CORE) Tests/C128Tests.m -o $@ $(BASE_LIBS)

$(BUILD_DIR)/CPU6502ReusableTest: $(CPU) $(HEADERS) Tests/CPU6502ReusableTest.m
	mkdir -p $(BUILD_DIR)
	$(CC) $(FLAGS) $(CPU) Tests/CPU6502ReusableTest.m -o $@ $(BASE_LIBS)

$(BUILD_DIR)/C64Tests: $(CORE) $(HEADERS) Tests/C64Tests.m
	mkdir -p $(BUILD_DIR)
	$(CC) $(FLAGS) $(CORE) Tests/C64Tests.m -o $@ $(BASE_LIBS)

test: $(BUILD_DIR)/C128Tests $(BUILD_DIR)/CPU6502ReusableTest $(BUILD_DIR)/C64Tests
	./$(BUILD_DIR)/CPU6502ReusableTest
	./$(BUILD_DIR)/C128Tests
	./$(BUILD_DIR)/C64Tests

run: all
	./$(APP)

clean:
	rm -rf build
