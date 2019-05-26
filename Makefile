HUGO=hugo

VENDORPATH=static/vendor

.PHONY: all build dev deps clean-deps deploycopy

all: build

build:
	$(HUGO) --cleanDestinationDir

dev:
	$(HUGO) server --disableFastRender -D -w

deps: clean-deps
	mkdir -p $(VENDORPATH)
	./deps.sh $(VENDORPATH)

clean-deps:
	rm -rf $(VENDORPATH)

deploycopy: build
	cp -r public/* ../xorkevin.github.io
