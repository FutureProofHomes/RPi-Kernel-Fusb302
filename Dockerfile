FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

# Basic build + kernel deps + deb packaging tools
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    bc \
    bison \
    build-essential \
    flex \
    git \
    libncurses-dev \
    libssl-dev \
    libelf-dev \
    dwarves \
    libdw-dev \
    cpio \
    kmod \
    fakeroot \
    dpkg-dev \
    debhelper \
    devscripts \
    python3 \
    rsync \
    lsb-release \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

# Fetch the Trixie kernel source without following a moving branch.
RUN git init rpi-linux \
    && git -C rpi-linux remote add origin https://github.com/raspberrypi/linux.git \
    && git -C rpi-linux fetch --depth=1 origin stable_20260724 \
    && git -C rpi-linux checkout --detach FETCH_HEAD

WORKDIR /usr/src/rpi-linux

COPY builddeb.patch /usr/src/rpi-linux
RUN patch -p1 < builddeb.patch

# Add a helper script that will build the kernel + .deb packages
COPY build-rpi-kernel-deb.sh /usr/local/bin/build-rpi-kernel-deb.sh
RUN chmod +x /usr/local/bin/build-rpi-kernel-deb.sh

# Default to an interactive shell so you can run the build script with args
# ENTRYPOINT ["/bin/bash"]
