EXT?=0

HUGO=hugo
ifeq ($(EXT),1)
	HUGO=./build/hugo
endif

BINPATH=build
BIN=hugo

HUGO_URL=https://github.com/gohugoio/hugo/releases/download/v0.48/hugo_extended_0.48_Linux-64bit.tar.gz

VENDORPATH=static/vendor

.PHONY: all build dev init deps clean-deps clean-tools

all: build

build:
	$(HUGO) --cleanDestinationDir

dev:
	$(HUGO) server --disableFastRender -D -w

TEMPTAR=hugo.tar.gz
TEMPDIR=temp

init:
	mkdir -p $(BINPATH)
	if [ ! -x $(BINPATH)/$(BIN) ]; then \
		wget -q --show-progress $(HUGO_URL) -O $(TEMPTAR); \
		mkdir -p $(TEMPDIR); \
		tar xzvf $(TEMPTAR) -C $(TEMPDIR); \
		mv $(TEMPDIR)/hugo $(BINPATH)/$(BIN); \
		chmod 755 $(BINPATH)/$(BIN); \
	fi;
	rm -rf $(TEMPDIR) $(TEMPTAR)

deps: clean-deps
	mkdir -p $(VENDORPATH)
	./deps.sh $(VENDORPATH)

clean-deps:
	rm -rf $(VENDORPATH)

clean-tools:
	rm -rf $(TEMPDIR) $(TEMPTAR) $(BINPATH)
