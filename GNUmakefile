# milan: a small, fast GNUstep file manager (Finder-style) -- see README.md.
include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = Milan
VERSION = 0.1
Milan_OBJC_FILES = main.m MilanEntry.m MilanFileOps.m MilanIcons.m MilanInfoPanel.m \
	MilanIconView.m MilanListView.m MilanColumnView.m MilanWindow.m
Milan_MAIN_MODEL_FILE =
Milan_RESOURCE_FILES = $(wildcard icons/*.tiff)
Milan_LOCALIZED_RESOURCE_FILES =

ADDITIONAL_OBJCFLAGS += -O2 -Wall -fblocks

include $(GNUSTEP_MAKEFILES)/application.make
