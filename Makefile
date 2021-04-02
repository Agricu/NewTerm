ifeq ($(PLATFORM),mac)
export TARGET = uikitformac:latest:13.0
else
export TARGET = iphone:13.7:13.0
export ARCHS = arm64
LINK_CEPHEI := 1
endif

INSTALL_TARGET_PROCESSES = NewTerm

include $(THEOS)/makefiles/common.mk

XCODEPROJ_NAME = NewTerm

NewTerm_XCODEFLAGS = LINK_CEPHEI=-DLINK_CEPHEI CEPHEI_LDFLAGS="-framework Cephei -framework Preferences" SWIFT_OLD_RPATH=/usr/lib/libswift/stable
NewTerm_XCODE_SCHEME = NewTerm (iOS)
NewTerm_CODESIGN_FLAGS = -SiOS/entitlements.plist

include $(THEOS_MAKE_PATH)/xcodeproj.mk

ifeq ($(LINK_CEPHEI),1)
SUBPROJECTS = prefs

include $(THEOS_MAKE_PATH)/aggregate.mk
endif

all stage package install::
# TODO: This should be possible natively in Theos!
ifeq ($(or $(INSTALL_FONTS),$(FINALPACKAGE)),1)
	+$(MAKE) -C Fonts $@ THEOS_PROJECT_DIR=$(THEOS_PROJECT_DIR)/Fonts
endif
