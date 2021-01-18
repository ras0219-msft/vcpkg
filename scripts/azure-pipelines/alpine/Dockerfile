FROM alpine:latest

RUN apk add alpine-sdk cmake ninja git curl tar gzip

RUN curl -sL https://github.com/microsoft/vcpkg/archive/master.tar.gz | tar xzf -

RUN mkdir build && \
    cd build && \
    export CXXFLAGS="-Wl,--gc-sections -static -fdata-sections -ffunction-sections -s -static-libgcc" && \
    cmake /vcpkg-master/toolsrc -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -G Ninja && \
    ninja

# This should report "Not a valid dynamic program"
RUN ldd /build/vcpkg || true
