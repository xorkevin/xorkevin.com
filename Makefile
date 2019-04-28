HUGO=hugo

VENDORPATH=static/vendor

.PHONY: all build dev deps clean-deps

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
