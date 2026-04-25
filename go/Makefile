##
## Makefile – build the dnsly tunnel Go mobile library
##
## Prerequisites
##   brew install go
##   go install golang.org/x/mobile/cmd/gomobile@latest
##   go install golang.org/x/mobile/cmd/gobind@latest
##   gomobile init
##
## Usage
##   make ios        – produce Tunnel.xcframework (embed in Xcode)
##   make android    – produce tunnel.aar + tunnel-sources.jar
##   make clean
##

GOMODULE   = dnsly.app/tunnel
PACKAGE    = $(GOMODULE)/tunnel
IOS_OUT    = ../ios/Frameworks/Tunnel.xcframework
ANDROID_OUT = ../android/libs

.PHONY: all ios android clean deps

all: ios

## Download dependencies
deps:
	go mod download
	go mod tidy

## iOS xcframework (arm64 device + arm64 simulator)
ios: deps
	@mkdir -p $(dir $(IOS_OUT))
	gomobile bind \
		-target ios/arm64,iossimulator/arm64 \
		-o $(IOS_OUT) \
		-v \
		$(PACKAGE)
	@echo "✓ Tunnel.xcframework written to $(IOS_OUT)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Open ios/Runner.xcworkspace in Xcode"
	@echo "  2. Add Tunnel.xcframework to the DNSly target's"
	@echo "     'Frameworks, Libraries and Embedded Content'"
	@echo "  3. Set embed = 'Embed & Sign'"

## Android aar
android: deps
	@mkdir -p $(ANDROID_OUT)
	gomobile bind \
		-target android/arm64,android/arm,android/amd64 \
		-o $(ANDROID_OUT)/tunnel.aar \
		-v \
		$(PACKAGE)
	@echo "✓ tunnel.aar written to $(ANDROID_OUT)"

clean:
	rm -rf $(IOS_OUT) $(ANDROID_OUT)/tunnel.aar $(ANDROID_OUT)/tunnel-sources.jar
