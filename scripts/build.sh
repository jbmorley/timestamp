#!/bin/bash

set -e

# Build the project.
xcodebuild clean build || exit 1

# Archive the binary.
tar -zcf build/timestamp.tar.gz \
  LICENSE \
  build/Release/timestamp || exit 1