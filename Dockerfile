FROM debian:bullseye

RUN mkdir -p /JitStreamer /DMG \
    && apt-get update \
    && apt-get install -y \
        udev \
        libudev1 \
        libssl1.1 \
        libudev-dev \
        libssl-dev \
        python3-dev \
        build-essential \
        pkg-config \
        checkinstall \
        git autoconf \
        automake \
        libtool-bin \
        curl \
    && git clone https://github.com/libusb/libusb /build/libusb \
    && cd /build/libusb && git checkout cc498de \
    && ./autogen.sh && make install \
    && git clone https://github.com/libimobiledevice/libplist /build/libplist \
    && cd /build/libplist && git checkout bfc9778 \
    && ./autogen.sh && make install \
    && git clone https://github.com/libimobiledevice/libimobiledevice-glue /build/libimobiledevice-glue \
    && cd /build/libimobiledevice-glue && git checkout d2ff796 \
    && ./autogen.sh && make install \
    && git clone https://github.com/libimobiledevice/libusbmuxd /build/libusbmuxd \
    && cd /build/libusbmuxd && git checkout f47c36f \
    && ./autogen.sh && make install \
    && git clone https://github.com/libimobiledevice/libimobiledevice /build/libimobiledevice \
    && cd /build/libimobiledevice && git checkout 963083b \
    && ./autogen.sh && make install \
    && git clone https://github.com/libimobiledevice/usbmuxd /build/usbmuxd \
    && cd /build/usbmuxd && git checkout d0cda19 \ 
    && ./autogen.sh && make install

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.72.1

RUN set -eux; \
    dpkgArch="$(dpkg --print-architecture)"; \
    case "${dpkgArch##*-}" in \
        amd64) rustArch='x86_64-unknown-linux-gnu'; rustupSha256='0b2f6c8f85a3d02fde2efc0ced4657869d73fccfce59defb4e8d29233116e6db' ;; \
        armhf) rustArch='armv7-unknown-linux-gnueabihf'; rustupSha256='f21c44b01678c645d8fbba1e55e4180a01ac5af2d38bcbd14aa665e0d96ed69a' ;; \
        arm64) rustArch='aarch64-unknown-linux-gnu'; rustupSha256='673e336c81c65e6b16dcdede33f4cc9ed0f08bde1dbe7a935f113605292dc800' ;; \
        i386) rustArch='i686-unknown-linux-gnu'; rustupSha256='e7b0f47557c1afcd86939b118cbcf7fb95a5d1d917bdd355157b63ca00fc4333' ;; \
        *) echo >&2 "unsupported architecture: ${dpkgArch}"; exit 1 ;; \
    esac; \
    url="https://static.rust-lang.org/rustup/archive/1.26.0/${rustArch}/rustup-init"; \
    curl -O "$url"; \
    echo "${rustupSha256} *rustup-init" | sha256sum -c -; \
    chmod +x rustup-init; \
    ./rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --default-host ${rustArch}; \
    rm rustup-init; \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME

RUN git clone https://github.com/jkcoxson/JitStreamer /build/JitStreamer \
    && cd /build/JitStreamer && git checkout c2fda05 \
    && sed -i 's/,\?\s*"vendored"//g' Cargo.toml \
    && cargo build --release \
    && mv target/release/jit_streamer /JitStreamer \
    && mv /build/JitStreamer/target/release/pair /JitStreamer \
    && rm -r /build \
    && cd / && rustup self uninstall -y \
    && apt-get remove -y \
        libudev-dev \
        libssl-dev \
        python3-dev \
        build-essential \
        pkg-config \
        checkinstall \
        git \
        autoconf \
        automake \
        libtool-bin \
        curl \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 

COPY ./scripts/pair-device.sh /usr/local/bin/pair-device
COPY ./scripts/entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/pair-device /usr/local/bin/entrypoint
WORKDIR /JitStreamer
ENTRYPOINT entrypoint
