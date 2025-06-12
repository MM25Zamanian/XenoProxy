########################################
# Stage 1: Builder
########################################
ARG ALPINE_VERSION=3.20
ARG NGINX_VERSION=1.27.4

FROM alpine:${ALPINE_VERSION} AS builder

# 1. نصب ابزارهای مورد نیاز برای build
RUN apk add --no-cache \
    build-base \
    curl \
    git \
    linux-headers \
    openssl-dev \
    pcre-dev \
    zlib-dev

WORKDIR /usr/src

# 2. ساخت پوشه nginx-src و دانلود/اکسترکت Nginx + کلون ماژول Zstd
RUN mkdir -p nginx-src && \
    curl -fsSL https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
      | tar zx --strip-components=1 -C nginx-src && \
    git clone --depth=1 https://github.com/tokers/zstd-nginx-module.git zstd-module

WORKDIR /usr/src/nginx-src

# 3. کانفیگ و ساخت ماژول به صورت dynamic (+ حذف نمادها از باینری)
RUN ./configure \
       --prefix=/etc/nginx \
       --sbin-path=/usr/sbin/nginx \
       --modules-path=/usr/lib/nginx/modules \
       --conf-path=/etc/nginx/nginx.conf \
       --error-log-path=stderr \
       --http-log-path=stdout \
       --pid-path=/var/run/nginx.pid \
       --lock-path=/var/run/nginx.lock \
       --http-client-body-temp-path=/var/cache/nginx/client_temp \
       --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
       --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
       --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
       --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
       --with-http_ssl_module \
       --with-http_v2_module \
       --with-http_gzip_static_module \
       --with-compat \
       --with-ld-opt='-s' \
       --add-dynamic-module=../zstd-module/filter && \
    make -j"$(nproc)" modules

# 4. کپی ماژول ساخته‌شده به فولدر خروجی
RUN mkdir -p /build-output/{etc/nginx,usr/lib/nginx/modules} && \
    cp objs/ngx_http_zstd_filter_module.so /build-output/usr/lib/nginx/modules/

########################################
# Stage 2: Runtime
########################################
FROM alpine:${ALPINE_VERSION}

ARG NGINX_UID=101
ARG NGINX_GID=101

# 1. وابستگی‌های runtime + tini
RUN apk add --no-cache \
    libssl3 \
    pcre \
    zlib \
    tini

# 2. کاربر غیر روت برای اجرای Nginx
RUN addgroup -g ${NGINX_GID} -S nginx && \
    adduser -u ${NGINX_UID} -D -S -G nginx nginx

# 3. کپی باینری Nginx و ماژول‌ها
COPY --from=builder /build-output/usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /build-output/etc/nginx /etc/nginx
COPY --from=builder /build-output/usr/lib/nginx/modules /usr/lib/nginx/modules

# 4. (اختیاری) کپی محتوای html پیش‌فرض
COPY --from=builder /build-output/etc/nginx/html /usr/share/nginx/html

# 5. کپی تنظیمات سفارشی شما
COPY etc/nginx/ /etc/nginx/

# 6. ایجاد دایرکتوری‌های cache/log و تنظیم مالکیت
RUN mkdir -p /var/cache/nginx && \
    chown -R nginx:nginx /var/cache/nginx /var/run /var/log/nginx

# 7. Healthcheck برای اطمینان از در دسترس بودن Nginx
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s \
  CMD wget --quiet --spider http://localhost:80/ || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["nginx", "-g", "daemon off;"]

EXPOSE 80 443
STOPSIGNAL SIGQUIT
