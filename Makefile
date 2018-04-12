all: build

build: build-css build-hugo

build-css:
	npm run build-css

build-hugo:
	hugo --cleanDestinationDir

dev:
	npm run watch-css

devserver:
	hugo server --disableFastRender -D -w
