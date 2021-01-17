# [Choice] Debian / Ubuntu version: debian-10, debian-9, ubuntu-20.04, ubuntu-18.04
ARG VARIANT=buster
FROM mcr.microsoft.com/vscode/devcontainers/cpp:0-${VARIANT}

RUN mkdir ~/bin && cd ~/bin && curl -L --output ninja-linux.zip https://github.com/ninja-build/ninja/releases/download/v1.10.2/ninja-linux.zip && \
    unzip ninja-linux.zip && rm ninja-linux.zip

RUN wget https://github.com/PowerShell/PowerShell/releases/download/v7.1.0/powershell_7.1.0-1.ubuntu.20.04_amd64.deb && \
    dpkg -i powershell_7.1.0-1.ubuntu.20.04_amd64.deb && \
    rm powershell_7.1.0-1.ubuntu.20.04_amd64.deb
    
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install build-essential cmake gdb pkg-config autoconf automake \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

ENV PATH /root/bin:$PATH
ENV VCPKG_DEFAULT_BINARY_CACHE /workspaces/.cache/vcpkg

# [Optional] Uncomment this section to install additional packages.
# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends <your-package-list-here>
