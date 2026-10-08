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
    pkgconf

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
        --with-stream_ssl_preread_module && \
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
