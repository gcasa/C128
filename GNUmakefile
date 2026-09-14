ifeq ($(strip $(GNUSTEP_MAKEFILES)),)
include Makefile
else
include $(GNUSTEP_MAKEFILES)/common.make
APP_NAME = C128
C128_APPLICATION_ICON = AppIcon.png
C128_RESOURCE_FILES = C128/Resources/AppIcon.png
C128_OBJC_FILES = $(wildcard C128/CPU/*.m C128/Core/*.m) C128/main.m
C128_HEADER_FILES = $(wildcard C128/CPU/*.h C128/Core/*.h)
C128_CPPFLAGS = -DCPU6502_STANDALONE=1 -IC128/CPU -IC128/Core
C128_OBJCFLAGS = -std=gnu99
include $(GNUSTEP_MAKEFILES)/application.make
.PHONY: test
test:
	$(MAKE) -f Makefile UNAME=GNUstep test
endif
