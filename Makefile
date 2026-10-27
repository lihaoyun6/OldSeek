APP        := OldSeek
SDK        ?= $(TMPDIR)sdk/iPhoneOS3.1.3.sdk
CC         := $(shell xcrun -f clang)
LDID       ?= ldid

BUILD      := build
BUNDLE     := $(BUILD)/$(APP).app
BIN        := $(BUNDLE)/$(APP)

CLIENT_SRC := $(wildcard client/*.m)
CLIENT_OBJ := $(patsubst client/%.m,$(BUILD)/obj/%.o,$(CLIENT_SRC))
MBED_SRC   := $(wildcard vendor/mbedtls/library/*.c)
MBED_OBJ   := $(patsubst vendor/mbedtls/library/%.c,$(BUILD)/mbed/%.o,$(MBED_SRC))

CFLAGS := -target armv6-apple-ios3.1.3 -isysroot $(SDK) -O2 -marm -mno-thumb \
          -fno-objc-arc -fno-stack-protector \
          -Iclient -Ivendor -Ivendor/mbedtls/include \
          -Wno-deprecated-declarations
LDFLAGS := -framework UIKit -framework Foundation -framework QuartzCore \
           -framework CoreGraphics

.PHONY: all bundle clean check-sdk

all: bundle

bundle: $(BIN)

$(BIN): $(CLIENT_OBJ) $(BUILD)/obj/cJSON.o $(MBED_OBJ) client/Info.plist client/Icon.png client/Icon-Small.png client/Icon-72.png client/Icon-Small-50.png client/cacert.pem client/Balloon_1.png client/Balloon_2.png client/PhotoButton.png client/en.lproj/Localizable.strings client/zh_CN.lproj/Localizable.strings
	@mkdir -p $(BUNDLE)
	$(CC) $(CFLAGS) $(CLIENT_OBJ) $(BUILD)/obj/cJSON.o $(MBED_OBJ) $(LDFLAGS) -o $@
	@$(LDID) -S $@
	@cp client/Info.plist $(BUNDLE)/Info.plist
	@cp client/Icon.png $(BUNDLE)/Icon.png
	@cp client/Icon-Small.png $(BUNDLE)/Icon-Small.png
	@cp client/Icon-72.png $(BUNDLE)/Icon-72.png
	@cp client/Icon-Small-50.png $(BUNDLE)/Icon-Small-50.png
	@cp client/cacert.pem $(BUNDLE)/cacert.pem
	@cp client/Balloon_1.png $(BUNDLE)/Balloon_1.png
	@cp client/Balloon_2.png $(BUNDLE)/Balloon_2.png
	@cp client/PhotoButton.png $(BUNDLE)/PhotoButton.png
	@mkdir -p $(BUNDLE)/en.lproj $(BUNDLE)/zh_CN.lproj
	@cp client/en.lproj/Localizable.strings $(BUNDLE)/en.lproj/Localizable.strings
	@cp client/zh_CN.lproj/Localizable.strings $(BUNDLE)/zh_CN.lproj/Localizable.strings
	@chmod 755 $@ $(BUNDLE)/en.lproj $(BUNDLE)/zh_CN.lproj
	@chmod 644 $(BUNDLE)/Info.plist $(BUNDLE)/Icon.png $(BUNDLE)/Icon-Small.png \
	            $(BUNDLE)/Icon-72.png $(BUNDLE)/Icon-Small-50.png \
	            $(BUNDLE)/cacert.pem $(BUNDLE)/Balloon_1.png $(BUNDLE)/Balloon_2.png \
	            $(BUNDLE)/PhotoButton.png $(BUNDLE)/en.lproj/Localizable.strings \
	            $(BUNDLE)/zh_CN.lproj/Localizable.strings

$(BUILD)/obj/%.o: client/%.m
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/obj/cJSON.o: vendor/cJSON.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/mbed/%.o: vendor/mbedtls/library/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

check-sdk:
	@test -f "$(SDK)/System/Library/Frameworks/UIKit.framework/Headers/UIKit.h" || { \
	  echo "error: SDK not found at $(SDK)"; exit 1; }

clean:
	rm -rf $(BUILD)
