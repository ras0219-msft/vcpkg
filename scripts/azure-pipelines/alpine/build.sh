#!/bin/sh
docker build -t vcpkgalpine .
docker create -ti --name dummy vcpkgalpine sh
docker cp dummy:/build/vcpkg ./vcpkg
docker rm -f dummy
