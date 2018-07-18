#!/usr/bin/env bash

vendorpath=$1

output=$vendorpath/fontawesome

mkdir -p $output
mkdir -p $output/css
cp node_modules/@fortawesome/fontawesome-free/css/all.min.css $output/css
cp -r node_modules/@fortawesome/fontawesome-free/webfonts $output
