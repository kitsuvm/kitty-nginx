# Kitsu/VM // Kitty NGINX

NGINX web server statically compiled and with additional modules for use on distroless containers on Kittyland and other projects.

## Images

### 1.30.5 (Stable)

#### Dependencies

- PCRE2 10.48
- ZLIB 1.3.2
- OpenSSL 4.0.3
- libxml2 2.15.4
- libxslt 1.1.45
- libgd 2.3.3

#### Modules

- file-aio
- http_addition_module
- http_auth_request_module
- http_dav_module
- http_degradation_module
- http_flv_module
- http_gunzip_module
- http_gzip_static_module
- http_image_filter_module
- http_mp4_module
- http_random_index_module
- http_realip_module
- http_secure_link_module
- http_slice_module
- http_ssl_module
- http_stub_status_module
- http_sub_module
- http_v2_module
- http_v3_module
- http_xslt_module
- mail
- mail_ssl_module
- pcre2-jit
- stream
- stream_realip_module
- stream_ssl_module
- stream_ssl_preread_module
- threads

### 1.30.5-extra (Stable)

#### Dependencies

Contains all the dependencies of the 1.30.5 image, plus the following additional dependencies:

- libmaxminddb 1.14.1
- zstd 1.5.7

#### Modules

Contains all the modules of the 1.30.5 image, plus the following additional modules:

- giom/nginx_accept_language_module master
- google/ngx_brotli master
- leev/ngx_http_geoip2_module 3.4
- tokers/zstd-nginx-module 0.1.1
