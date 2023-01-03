FROM archlinux
RUN --mount=type=cache,sharing=locked,target=/var/cache/pacman \
    pacman -Syu --noconfirm --needed base base-devel cuda git 
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
ARG user=makepkg
RUN useradd --system --create-home $user \
  && echo "$user ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/$user
USER $user
WORKDIR /home/$user
RUN git clone https://aur.archlinux.org/yay.git \
  && cd yay \
  && makepkg -sri --needed --noconfirm \
  && cd \
  && rm -rf .cache yay

RUN yay -S tcl nasm cmake jq libtool wget fribidi fontconfig libsoxr-git meson rust python38 pod2man --noconfirm
USER root

# https://github.com/NSLS-II/debian-with-miniconda/blob/master/Dockerfile
ENV PATH /opt/conda/bin:$PATH
RUN cd && \
    wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh --no-verbose && \
    bash Miniconda3-latest-Linux-x86_64.sh -b -p /opt/conda && \
    rm Miniconda*.sh
RUN conda install python=3.8 -y

ARG MP3LAME_VERSION=3.100
ARG MP3LAME_URL="https://sourceforge.net/projects/lame/files/lame/$MP3LAME_VERSION/lame-$MP3LAME_VERSION.tar.gz/download"
ARG MP3LAME_SHA256=ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e
ARG OGG_VERSION=1.3.5
ARG OGG_URL="https://downloads.xiph.org/releases/ogg/libogg-$OGG_VERSION.tar.gz"
ARG OGG_SHA256=0eb4b4b9420a0f51db142ba3f9c64b333f826532dc0f48c6410ae51f4799b664
ARG VORBIS_VERSION=1.3.7
ARG VORBIS_URL="https://downloads.xiph.org/releases/vorbis/libvorbis-$VORBIS_VERSION.tar.gz"
ARG VORBIS_SHA256=0e982409a9c3fc82ee06e08205b1355e5c6aa4c36bca58146ef399621b0ce5ab
ARG OPUS_VERSION=1.3.1
ARG OPUS_URL="https://archive.mozilla.org/pub/opus/opus-$OPUS_VERSION.tar.gz"
ARG OPUS_SHA256=65b58e1e25b2a114157014736a3d9dfeaad8d41be1c8179866f144a2fb44ff9d
ARG THEORA_VERSION=1.1.1
ARG THEORA_URL="https://downloads.xiph.org/releases/theora/libtheora-$THEORA_VERSION.tar.bz2"
ARG THEORA_SHA256=b6ae1ee2fa3d42ac489287d3ec34c5885730b1296f0801ae577a35193d3affbc
ARG XVID_VERSION=1.3.7
ARG XVID_URL="https://downloads.xvid.com/downloads/xvidcore-$XVID_VERSION.tar.gz"
ARG XVID_SHA256=abbdcbd39555691dd1c9b4d08f0a031376a3b211652c0d8b3b8aa9be1303ce2d

ENV PATH "$PATH:/opt/cuda/bin/nvcc"
ENV PATH "$PATH:/opt/cuda/bin"
ENV LD_LIBRARY_PATH "/opt/cuda/lib64"

# -O3 makes sure we compile with optimization. setting CFLAGS/CXXFLAGS seems to override
# default automake cflags.
# -static-libgcc is needed to make gcc not include gcc_s as "as-needed" shared library which
# cmake will include as a implicit library.
# other options to get hardened build (same as ffmpeg hardened)
ARG CFLAGS="-O3 -static-libgcc -fno-strict-overflow -fstack-protector-all -fPIE"
ARG CXXFLAGS="-O3 -static-libgcc -fno-strict-overflow -fstack-protector-all -fPIE"
ARG LDFLAGS="-Wl,-z,relro,-z,now"

RUN \
  wget -O lame.tar.gz "$MP3LAME_URL" && \
  echo "$MP3LAME_SHA256  lame.tar.gz" | sha256sum --status -c - && \
  tar xf lame.tar.gz && \
  cd lame-* && ./configure --enable-static --enable-nasm --disable-shared && make -j$(nproc) install

RUN \
  git clone https://github.com/mstorsjo/fdk-aac/ && \
  cd fdk-aac && ./autogen.sh && ./configure --enable-static --disable-shared && make -j$(nproc) install

RUN \
  wget -O libogg.tar.gz "$OGG_URL" && \
  echo "$OGG_SHA256  libogg.tar.gz" | sha256sum --status -c - && \
  tar xf libogg.tar.gz && \
  cd libogg-* && ./configure --enable-static --disable-shared && make -j$(nproc) install

RUN \
  wget -O libvorbis.tar.gz "$VORBIS_URL" && \
  echo "$VORBIS_SHA256  libvorbis.tar.gz" | sha256sum --status -c - && \
  tar xf libvorbis.tar.gz && \
  cd libvorbis-* && ./configure --enable-static --disable-shared && make -j$(nproc) install

RUN \
  wget -O opus.tar.gz "$OPUS_URL" && \
  echo "$OPUS_SHA256  opus.tar.gz" | sha256sum --status -c - && \
  tar xf opus.tar.gz && \
  cd opus-* && ./configure --enable-static --disable-shared && make -j$(nproc) install

RUN \
  wget -O libtheora.tar.bz2 "$THEORA_URL" && \
  echo "$THEORA_SHA256  libtheora.tar.bz2" | sha256sum --status -c - && \
  tar xf libtheora.tar.bz2 && \
  cd libtheora-* && ./configure --disable-examples --enable-static --disable-shared && make -j$(nproc) install

RUN \
  git clone https://github.com/webmproject/libvpx/ && \
  cd libvpx && ./configure --enable-static --enable-vp9-highbitdepth --disable-shared --disable-unit-tests --disable-examples && \
  make -j$(nproc) install

RUN \
  git clone https://code.videolan.org/videolan/x264.git && \
  cd x264 && ./configure --enable-pic --enable-static && make -j$(nproc) install

# -w-macro-params-legacy to not log lots of asm warnings
# https://bitbucket.org/multicoreware/x265_git/issues/559/warnings-when-assembling-with-nasm-215
RUN \
  git clone https://bitbucket.org/multicoreware/x265_git/ && cd x265_git/build/linux && \
  cmake -G "Unix Makefiles" -DENABLE_SHARED=OFF -DENABLE_AGGRESSIVE_CHECKS=ON ../../source -DCMAKE_ASM_NASM_FLAGS=-w-macro-params-legacy && \
  make -j$(nproc) install

RUN \
  git clone https://github.com/webmproject/libwebp/ && \
  cd libwebp && ./autogen.sh && ./configure --enable-static --disable-shared && make -j$(nproc) install

RUN \
  git clone https://github.com/xiph/speex/ && \
  cd speex && ./autogen.sh && ./configure --enable-static --disable-shared && make -j$(nproc) install

RUN \
  git clone --depth 1 https://aomedia.googlesource.com/aom && \
  cd aom && \
  mkdir build_tmp && cd build_tmp && cmake -DBUILD_SHARED_LIBS=0 -DENABLE_TESTS=0 -DENABLE_NASM=on -DCMAKE_INSTALL_LIBDIR=lib .. && make -j$(nproc) install

RUN \
  git clone https://github.com/georgmartius/vid.stab/ && \
  cd vid.stab && cmake -DBUILD_SHARED_LIBS=OFF . && make -j$(nproc) install

RUN \
  git clone https://github.com/ultravideo/kvazaar/ && \
  cd kvazaar && ./autogen.sh && ./configure --enable-static --disable-shared && make -j$(nproc) install

RUN \
  git clone https://github.com/libass/libass/ && \
  cd libass && ./autogen.sh && ./configure --enable-static --disable-shared && make -j$(nproc) && make install

# master is broken https://github.com/sekrit-twc/zimg/issues/181
# No rule to make target 'graphengine/graphengine/cpuinfo.cpp', needed by 'graphengine/graphengine/libzimg_internal_la-cpuinfo.lo'.  Stop.
RUN \
  wget https://github.com/sekrit-twc/zimg/archive/refs/tags/release-3.0.4.tar.gz && tar -zxvf release-3.0.4.tar.gz && cd zimg-release-3.0.4 && \
  ./autogen.sh && ./configure --enable-static --disable-shared && make -j$(nproc) install

RUN pip3 install Cython && wget https://github.com/vapoursynth/vapoursynth/archive/refs/tags/R61.tar.gz && \
    tar -zxvf R61.tar.gz && cd vapoursynth-R61 && ./autogen.sh && PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/ ./configure --enable-static --disable-shared && make && make install && cd .. && ldconfig

RUN \
  git clone https://github.com/uclouvain/openjpeg/ && \
  cd openjpeg && cmake -G "Unix Makefiles" -DBUILD_SHARED_LIBS=OFF && make -j$(nproc) install

RUN \
  git clone https://code.videolan.org/videolan/dav1d/ && \
  cd dav1d && meson build --buildtype release -Ddefault_library=static && ninja -C build install

# add extra CFLAGS that are not enabled by -O3
# http://websvn.xvid.org/cvs/viewvc.cgi/trunk/xvidcore/build/generic/configure.in?revision=2146&view=markup
RUN \
  wget -O libxvid.tar.gz "$XVID_URL" && \
  echo "$XVID_SHA256  libxvid.tar.gz" | sha256sum --status -c - && \
  tar xf libxvid.tar.gz && \
  cd xvidcore/build/generic && \
  CFLAGS="$CLFAGS -fstrength-reduce -ffast-math" \
  ./configure && make -j$(nproc) && make install

RUN \
  git clone https://github.com/xiph/rav1e/ && \
  cd rav1e && \
  cargo install cargo-c && \
  cargo cinstall --release  --library-type=staticlib --crt-static
RUN sed -i 's/-lgcc_s//' /usr/local/lib/pkgconfig/rav1e.pc

RUN \
  git clone https://github.com/Haivision/srt/ && \
  cd srt && ./configure --enable-shared=0 --cmake-install-libdir=lib --cmake-install-includedir=include --cmake-install-bindir=bin && \
  make -j$(nproc) && make install

RUN \
  git clone https://gitlab.com/AOMediaCodec/SVT-AV1/ && \
  cd SVT-AV1 && \
  sed -i 's/picture_copy(/svt_av1_picture_copy(/g' \
    Source/Lib/Common/Codec/EbPictureOperators.c \
    Source/Lib/Common/Codec/EbPictureOperators.h \
    Source/Lib/Encoder/Codec/EbFullLoop.c \
    Source/Lib/Encoder/Codec/EbProductCodingLoop.c && \
  cd Build && \
  cmake .. -G"Unix Makefiles" -DCMAKE_INSTALL_LIBDIR=lib -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release && \
  make -j$(nproc) install

RUN \
  git clone https://github.com/pkuvcl/davs2/ && \
  cd davs2/build/linux && ./configure --disable-asm --enable-pic && \
  make -j$(nproc) install

RUN \
  git clone https://github.com/pkuvcl/xavs2/ && \
  cd xavs2/build/linux && ./configure --disable-asm --enable-pic && \
  make -j$(nproc) install

RUN \
  git clone https://github.com/Netflix/vmaf/ && \
  cd vmaf/libvmaf && meson build --buildtype release -Ddefault_library=static && ninja -vC build install

RUN \
  git clone https://github.com/cisco/openh264 && \
  cd openh264 && meson build --buildtype release -Ddefault_library=static && ninja -C build install

RUN \
  git clone https://github.com/FFmpeg/nv-codec-headers && cd nv-codec-headers && make -j$(nproc) && make install

# https://github.com/shadowsocks/shadowsocks-libev/issues/623
RUN mkdir -p "/home/makepkg/ssl"
RUN git clone git://git.openssl.org/openssl.git && cd openssl && LIBS="-ldl -lz" LDFLAGS="-Wl,-static -static -static-libgcc -s" ./config no-shared -static --prefix="/home/makepkg/ssl" --openssldir="/home/makepkg/ssl" && sed -i 's/^LDFLAGS = /LDFLAGS = -all-static -s/g' Makefile &&  make -j$(nproc) && make install_sw && make install

# https://stackoverflow.com/questions/18185618/how-to-use-static-linking-with-openssl-in-c-c
RUN \
  git clone https://github.com/FFmpeg/FFmpeg && cd FFmpeg && \
  PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/:/home/makepkg/ssl/lib64/pkgconfig/ ./configure \
  --pkg-config-flags=--static \
  --extra-cflags="-fopenmp -lcrypto -lz -ldl -static-libgcc" \
  --extra-ldflags="-fopenmp -lcrypto -lz -ldl -static-libgcc" \
  --extra-libs="-lstdc++ -lcrypto -lz -ldl -static-libgcc" \
  --toolchain=hardened \
  --disable-debug \
  --disable-shared \
  --disable-ffplay \
  --enable-static \
  --enable-gpl \
  --enable-gray \
  --enable-nonfree \
  --enable-openssl \
  --enable-iconv \
  --enable-libxml2 \
  --enable-libmp3lame \
  --enable-libfdk-aac \
  --enable-libvorbis \
  --enable-libopus \
  --enable-libtheora \
  --enable-libvpx \
  --enable-libx264 \
  --enable-libx265 \
  --enable-libwebp \
  --enable-libspeex \
  --enable-libaom \
  --enable-libvidstab \
  --enable-libkvazaar \
  --enable-libfreetype \
  --enable-fontconfig \
  --enable-libfribidi \
  --enable-libass \
  #--enable-libzimg \
  --enable-libsoxr \
  --enable-libopenjpeg \
  --enable-libdav1d \
  --enable-librav1e \
  --enable-libsrt \
  --enable-libsvtav1 \
  --enable-libdavs2 \
  --enable-libxavs2 \
  --enable-libvmaf \
  --enable-cuda-nvcc \
  --extra-cflags=-I/opt/cuda/include --extra-ldflags=-L/opt/cuda/lib64 \
  --enable-vapoursynth \
  --enable-libopenh264 \
  && make -j$(nproc)

USER root