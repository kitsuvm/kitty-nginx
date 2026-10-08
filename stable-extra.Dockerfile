FROM alpine:3.24.1 AS nginx-builder

ARG NGINX_VERSION=1.30.5
ARG PCRE2_VERSION=10.48
ARG ZLIB_VERSION=1.3.2
ARG OPENSSL_VERSION=4.0.3
ARG LIBXSLT_VERSION=1.1
ARG LIBXSLT_PATCH=45
ARG LIBXML2_VERSION=2.15
ARG LIBXML2_PATCH=4
ARG LIBGD_VERSION=2.3.3
ARG LIBMAXMINDDB_VERSION=1.14.1
ARG ZSTD_VERSION=1.5.7
ARG NGX_BROTLI_VERSION=master
ARG NGX_ZSTD_VERSION=0.1.1
ARG NGX_ACCEPT_LANG_VERSION=master
ARG NGX_GEOIP2_VERSION=3.4

WORKDIR /app

RUN apk -U upgrade && apk add --no-cache \
    git  \
    python3 \
    python3-dev \
    cmake \
    make \
    gcc \
    musl-dev \
    linux-headers \
    perl \
    pkgconf \
    autoconf \
    automake \
    libtool

RUN git clone --recurse-submodules --depth 1 --shallow-submodules --branch ${LIBMAXMINDDB_VERSION} -j$(nproc) https://github.com/maxmind/libmaxminddb.git && \
    cd libmaxminddb && \
    ./bootstrap && \
    ./configure --prefix=/usr/local --disable-shared --enable-static && \
    make -j$(nproc) && \
    make install

RUN git clone --recurse-submodules --depth 1 --shallow-submodules --branch v${ZSTD_VERSION} -j$(nproc) https://github.com/facebook/zstd.git && \
    cd zstd && \
    make -j$(nproc) PREFIX=/usr/local && \
    make install PREFIX=/usr/local

RUN git clone --recurse-submodules --depth 1 --shallow-submodules --branch ${NGX_BROTLI_VERSION} -j$(nproc) https://github.com/google/ngx_brotli.git && \
    cd ngx_brotli/deps/brotli && \
    ARCH_CFLAGS="" && \
    if [ "$(uname -m)" = "x86_64" ]; then ARCH_CFLAGS="-m64"; fi && \
    mkdir out && \
    cd out && \
    cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=OFF \
      -DCMAKE_C_FLAGS="${ARCH_CFLAGS} -Ofast -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" \
      -DCMAKE_CXX_FLAGS="${ARCH_CFLAGS} -Ofast -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" \
      -DCMAKE_INSTALL_PREFIX=./installed .. && \
    cmake --build . --config Release --target brotlienc

RUN git clone --recurse-submodules --depth 1 --shallow-submodules --branch ${NGX_ZSTD_VERSION} -j$(nproc) https://github.com/tokers/zstd-nginx-module.git

RUN git clone --recurse-submodules --depth 1 --shallow-submodules --branch ${NGX_ACCEPT_LANG_VERSION} -j$(nproc) https://github.com/giom/nginx_accept_language_module.git

RUN git clone --recurse-submodules --depth 1 --shallow-submodules --branch ${NGX_GEOIP2_VERSION} -j$(nproc) https://github.com/leev/ngx_http_geoip2_module.git

RUN wget https://github.com/libgd/libgd/releases/download/gd-${LIBGD_VERSION}/libgd-${LIBGD_VERSION}.tar.xz && \
    tar Jxvf libgd-${LIBGD_VERSION}.tar.xz && \
    cd libgd-${LIBGD_VERSION} && \
    ./configure --prefix=/usr/local --disable-shared --enable-static && \
    make -j$(nproc) && \
    make install

RUN wget https://download.gnome.org/sources/libxml2/${LIBXML2_VERSION}/libxml2-${LIBXML2_VERSION}.${LIBXML2_PATCH}.tar.xz && \
    tar Jxvf libxml2-${LIBXML2_VERSION}.${LIBXML2_PATCH}.tar.xz && \
    cd libxml2-${LIBXML2_VERSION}.${LIBXML2_PATCH} && \
    ./configure --prefix=/usr/local --disable-shared --enable-static && \
    make -j$(nproc) && \
    make install

RUN wget https://download.gnome.org/sources/libxslt/${LIBXSLT_VERSION}/libxslt-${LIBXSLT_VERSION}.${LIBXSLT_PATCH}.tar.xz && \
    tar Jxvf libxslt-${LIBXSLT_VERSION}.${LIBXSLT_PATCH}.tar.xz && \
    cd libxslt-${LIBXSLT_VERSION}.${LIBXSLT_PATCH} && \
    ./configure --prefix=/usr/local --disable-shared --enable-static --with-libxml-prefix=/usr/local && \
    make -j$(nproc) && \
    make install

RUN git clone --recurse-submodules --depth 1 --shallow-submodules --branch openssl-${OPENSSL_VERSION} -j$(nproc) https://github.com/openssl/openssl.git

RUN git clone --recurse-submodules --depth 1 --shallow-submodules --branch pcre2-${PCRE2_VERSION} -j$(nproc) https://github.com/PCRE2Project/pcre2.git

RUN wget https://zlib.net/zlib-${ZLIB_VERSION}.tar.xz && \
    tar Jxvf zlib-${ZLIB_VERSION}.tar.xz

RUN wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar zxvf nginx-${NGINX_VERSION}.tar.gz

RUN cd nginx-${NGINX_VERSION} && \
    ARCH_CFLAGS="" && \
    if [ "$(uname -m)" = "x86_64" ]; then ARCH_CFLAGS="-m64"; fi && \
    export PKG_CONFIG_PATH=/usr/lib/pkgconfig && \
    export CFLAGS="${ARCH_CFLAGS} -Ofast -flto -funroll-loops -ffunction-sections -fdata-sections" && \
    export LDFLAGS="-Wl,-s -Wl,--gc-sections -static -no-pie" && \
    ./configure \
        --with-ld-opt="-static -no-pie" \
        --prefix=/usr/local/nginx \
        --sbin-path=/usr/bin/nginx \
        --modules-path=/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/run/nginx.pid \
        --lock-path=/run/nginx.lock \
        --with-threads \
        --with-file-aio \
        --with-pcre=../pcre2 \
        --with-zlib=../zlib-${ZLIB_VERSION} \
        --with-openssl=../openssl \
        --with-pcre-jit \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_v3_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_xslt_module \
        --with-http_image_filter_module \
        --with-http_sub_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_auth_request_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_degradation_module \
        --with-http_slice_module \
        --with-http_stub_status_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_realip_module \
        --with-stream_ssl_preread_module \
        --add-module=../ngx_brotli \
        --add-module=../zstd-nginx-module \
        --add-module=../nginx_accept_language_module \
        --add-module=../ngx_http_geoip2_module && \
    make -j$(nproc) && \
    make install

FROM gcr.io/distroless/static-debian13:latest

WORKDIR /app

COPY --from=nginx-builder /usr/local/nginx /usr/local/nginx
COPY --from=nginx-builder /etc/nginx /etc/nginx
COPY --from=nginx-builder /var/log/nginx /var/log/nginx
COPY --from=nginx-builder /usr/bin/nginx /usr/bin/nginx

EXPOSE 80 443

ENTRYPOINT ["/usr/bin/nginx", "-g", "daemon off;"]
