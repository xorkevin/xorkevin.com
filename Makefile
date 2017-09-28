all: build

build:
	npm run build-css

dev:
	npm run watch-css

devserver:
	hugo server -D -w
