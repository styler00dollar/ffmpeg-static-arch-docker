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

RUN yay -S rust-nightly-bin tcl nasm cmake jq libtool wget fribidi fontconfig libsoxr-git meson pod2man nvidia-utils base-devel --noconfirm --ask 4
USER root

RUN mkdir -p "/home/makepkg/python310"
RUN wget https://github.com/python/cpython/archive/refs/tags/v3.10.10.tar.gz && tar xf v3.10.10.tar.gz && cd cpython-3.10.10 && \
  mkdir debug && cd debug && ../configure --enable-optimizations --disable-shared --prefix="/home/makepkg/python310" && make -j$(nproc) && make install && \
  /home/makepkg/python310/bin/python3.10 -m ensurepip --upgrade
RUN cp /home/makepkg/python310/bin/python3.10 /usr/bin/python
ENV PYTHONPATH /home/makepkg/python310/bin/
ENV PATH "/home/makepkg/python310/bin/:$PATH"

RUN pip3 install Cython meson

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
  git clone https://github.com/gypified/libmp3lame && cd libmp3lame && ./configure --enable-static --enable-nasm --disable-shared && make -j$(nproc) install

RUN \
  git clone https://github.com/mstorsjo/fdk-aac/ && \
  cd fdk-aac && ./autogen.sh && ./configure --enable-static --disable-shared && make -j$(nproc) install

RUN \
  git clone https://github.com/xiph/ogg && cd ogg && ./autogen.sh && ./configure --enable-static --disable-shared && make -j$(nproc) install

RUN \
  git clone https://github.com/xiph/vorbis && cd vorbis && ./autogen.sh && ./configure --enable-static --disable-shared && make -j$(nproc) install

RUN \
  git clone https://github.com/xiph/opus && cd opus && ./autogen.sh && ./configure --enable-static --disable-shared && make -j$(nproc) install

RUN \
  git clone https://github.com/xiph/theora && cd theora && ./autogen.sh && ./configure --disable-examples --enable-static --disable-shared && make -j$(nproc) install

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
  cmake -G "Unix Makefiles" -DENABLE_SHARED=OFF -D HIGH_BIT_DEPTH:BOOL=ON -DENABLE_AGGRESSIVE_CHECKS=ON ../../source -DCMAKE_ASM_NASM_FLAGS=-w-macro-params-legacy && \
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


RUN wget https://github.com/vapoursynth/vapoursynth/archive/refs/tags/R61.tar.gz && \
    tar -zxvf R61.tar.gz && cd vapoursynth-R61 && ./autogen.sh && PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/ ./configure --enable-static --disable-shared && make && make install && cd .. && ldconfig

RUN \
  git clone https://github.com/uclouvain/openjpeg/ && \
  cd openjpeg && cmake -G "Unix Makefiles" -DBUILD_SHARED_LIBS=OFF && make -j$(nproc) install

RUN \
  git clone https://code.videolan.org/videolan/dav1d/ && \
  cd dav1d && meson build --buildtype release -Ddefault_library=static && ninja -C build install

# add extra CFLAGS that are not enabled by -O3
# http://websvn.xvid.org/cvs/viewvc.cgi/trunk/xvidcore/build/generic/configure.in?revision=2146&view=markup
ARG XVID_VERSION=1.3.7
ARG XVID_URL="https://downloads.xvid.com/downloads/xvidcore-$XVID_VERSION.tar.gz"
ARG XVID_SHA256=abbdcbd39555691dd1c9b4d08f0a031376a3b211652c0d8b3b8aa9be1303ce2d
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
  cargo cinstall  --release --library-type=staticlib --crt-static
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
  --enable-optimizations \
  --enable-cuda-llvm \
  --enable-nvdec \
  --enable-nvenc \
  --enable-cuvid \
  --enable-cuda \
  --enable-pthreads \
  #--enable-hardcoded-tables \
  --enable-runtime-cpudetect \
  --enable-lto \
  && make -j$(nproc)

USER root
