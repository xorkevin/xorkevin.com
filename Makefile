HUGO=./build/hugo

BINPATH=build
BIN=hugo

URL=https://github.com/gohugoio/hugo/releases/download/v0.44/hugo_extended_0.44_Linux-64bit.tar.gz

.PHONY: all build dev init clean

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
		wget -q --show-progress $(URL) -O $(TEMPTAR); \
		mkdir -p $(TEMPDIR); \
		tar xzvf $(TEMPTAR) -C $(TEMPDIR); \
		mv $(TEMPDIR)/hugo $(BINPATH)/$(BIN); \
		chmod 755 $(BINPATH)/$(BIN); \
	fi;
	rm -rf $(TEMPDIR) $(TEMPTAR)

clean:
	rm -rf $(TEMPDIR) $(TEMPTAR) $(BINPATH)
