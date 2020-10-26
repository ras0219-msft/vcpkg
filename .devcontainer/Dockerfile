# [Choice] Debian / Ubuntu version: debian-10, debian-9, ubuntu-20.04, ubuntu-18.04
ARG VARIANT=buster
FROM mcr.microsoft.com/vscode/devcontainers/cpp:dev-${VARIANT}

# [Optional] Uncomment this section to install additional packages.
# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends <your-package-list-here>

RUN curl -SL https://raw.githubusercontent.com/microsoft/vcpkg/master/scripts/azure-pipelines/linux/provision-image.sh | bash -s

RUN export DEBIAN_FRONTEND=noninteractive && apt install curl gnupg && \
curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > bazel.gpg && \
mv bazel.gpg /etc/apt/trusted.gpg.d/ && \
echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | sudo tee /etc/apt/sources.list.d/bazel.list

RUN apt update && export DEBIAN_FRONTEND=noninteractive && apt install -y bazel
