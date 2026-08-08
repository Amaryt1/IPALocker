TARGET := iphone:clang:latest:13.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = IPALocker

IPALocker_FILES = Tweak.m
IPALocker_CFLAGS = -fobjc-arc
IPALocker_FRAMEWORKS = UIKit Foundation CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk

