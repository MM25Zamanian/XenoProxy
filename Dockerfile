# Stage 1: Build Nginx from source with the Zstd module
# We use a specific version of Alpine for reproducibility.
ARG ALPINE_VERSION=3.20
FROM alpine:${ALPINE_VERSION} AS builder

# Set Nginx version as a build-time argument
ARG NGINX_VERSION=1.27.4

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    curl \
    git \
    linux-headers \
    openssl-dev \
    pcre-dev \
    zlib-dev

# Set working directory
WORKDIR /usr/src

# Download and extract Nginx source code and the Zstd module source
RUN curl -O https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -zxf nginx-${NGINX_VERSION}.tar.gz && \
    git clone https://github.com/tokers/zstd-nginx-module.git

# Enter the Nginx source directory
WORKDIR /usr/src/nginx-${NGINX_VERSION}

# Configure Nginx build with necessary modules and paths.
# Logs are redirected to stdout/stderr, which is a container best practice.
# Temporary file paths are set for caching.
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
    --add-dynamic-module=/usr/src/zstd-nginx-module && \
    make -j$(nproc) && \
    make install DESTDIR=/build-output

# ---
# Stage 2: Create the final, optimized image
# We use the same Alpine base for a smaller final image.
FROM alpine:${ALPINE_VERSION}

# Set arguments for user/group IDs for security
ARG NGINX_UID=101
ARG NGINX_GID=101

# Install runtime dependencies only
# tini is used as a lightweight init system to properly handle signals
RUN apk add --no-cache \
    libssl3 \
    pcre \
    zlib \
    tini

# Create a non-root user and group for running Nginx
RUN addgroup -g ${NGINX_GID} -S nginx && \
    adduser -u ${NGINX_UID} -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx

# Copy compiled Nginx binary and default configuration from the builder stage
COPY --from=builder /build-output/usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /build-output/etc/nginx /etc/nginx
COPY --from=builder /build-output/usr/lib/nginx/modules /usr/lib/nginx/modules

# Copy default Nginx html content
COPY --from=builder /build-output/etc/nginx/html /usr/share/nginx/html

# Copy custom configuration from the build context.
# This will overwrite the default nginx.conf.
# Place your custom nginx.conf in an 'etc/nginx' directory next to your Dockerfile.
COPY etc/nginx/ /etc/nginx/

# Create necessary directories and set correct permissions for the non-root user
RUN mkdir -p /var/cache/nginx/ && \
    chown -R nginx:nginx /var/cache/nginx /var/run /var/log/nginx

# Use tini as the entrypoint to manage the Nginx process
ENTRYPOINT ["/sbin/tini", "--"]

# The command to run Nginx in the foreground
# The 'daemon off;' directive is essential for containerization.
CMD ["nginx", "-g", "daemon off;"]

# Expose standard HTTP and HTTPS ports
EXPOSE 80
EXPOSE 443

# Set the stop signal for graceful shutdown of Nginx
STOPSIGNAL SIGQUIT
