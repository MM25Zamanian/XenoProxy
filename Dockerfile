# Base image
FROM docker.io/library/nginx:1.27.4-alpine-slim

# Cleanup
RUN rm -rfv /docker-entrypoint* /etc/nginx/conf.d/* /etc/nginx/nginx.conf /var/www/html /usr/share/nginx/html /data

# Copy configurations and data
COPY etc/nginx/ /etc/nginx/
COPY default-data/ /default-data/
RUN chmod a+rx /etc/nginx/entrypoint.sh /etc/nginx/entrypoint.d/*.sh
RUN ls -RlahF /etc/nginx /default-data /data

# Expose port
EXPOSE 80

# Set stop signal
STOPSIGNAL SIGQUIT

# Set working directory
WORKDIR /data

# Entrypoint and command
ENTRYPOINT ["/etc/nginx/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]

# Nginx core settings
ENV NGINX_WORKER_CONNECTIONS=1024 \
    NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE=1 \
    NGINX_ENTRYPOINT_QUIET_LOGS=""

# Logging and security settings
ENV NGINX_ACCESS_LOG="/var/log/nginx/access.log json" \
    NGINX_ERROR_LOG_LEVEL=notice \
    NGINX_LIMIT_REQ_ERROR=503 \
    NGINX_LIMIT_REQ_LOG=notice \
    NGINX_AUTOINDEX=off \
    NGINX_FORCE_DOMAIN="" \
    NGINX_FORCE_DOMAIN_STATUS=307 \
    NGINX_FORCE_REDIRECT_STATUS=307

# CORS settings
ENV NGINX_CORS_ENABLE="" \
    NGINX_CORS_ORIGIN="*" \
    NGINX_CORS_METHODS="GET, OPTIONS" \
    NGINX_CORS_HEADERS="*" \
    NGINX_CORS_MAXAGE=86400

# DNS and resolver settings
ENV NGINX_RESOLVERS="127.0.0.11" \
    NGINX_RESOLVER_VALID=10s

# Performance settings
ENV NGINX_CLIENT_MAX_BODY_SIZE=10m \
    NGINX_SENDFILE=on \
    NGINX_SENDFILE_MAX_CHUNK=2m \
    NGINX_TCP_NOPUSH=on \
    NGINX_TCP_NODELAY=on \
    NGINX_OPEN_FILE_CACHE="max=1000 inactive=30m" \
    NGINX_OPEN_FILE_CACHE_VALID=1s \
    NGINX_OPEN_FILE_CACHE_MIN_USES=2 \
    NGINX_OUTPUT_BUFFERS="8 16k"

# Cache and compression settings
ENV NGINX_EXPIRES_DYNAMIC=epoch \
    NGINX_EXPIRES_STATIC=epoch \
    NGINX_EXPIRES_DEFAULT=epoch \
    NGINX_GZIP=on \
    NGINX_GZIP_VARY=on \
    NGINX_GZIP_COMP_LEVEL=5 \
    NGINX_GZIP_MIN_LENGTH=256

# Security and routing settings
ENV NGINX_LIMIT_REQ_RATE=10 \
    NGINX_LIMIT_REQ_BURST=20 \
    NGINX_DISABLE_SYMLINKS=if_not_owner \
    NGINX_DOCUMENT_ROOT=/data \
    NGINX_DISALLOW_ROBOTS=true \
    NEXT_HOST=localhost \
    NEXT_PORT=3000

# Build arguments
ARG BUILD_REV
ARG BUILD_DATE

# Labels
LABEL org.opencontainers.image.title="MM25Zamanian/XenoProxy" \
      org.opencontainers.image.description="A high-performance, stable Nginx configuration tailored as a reverse proxy for demanding Next.js applications." \
      org.opencontainers.image.version="0.0.1-nginx1.27.4" \
      org.opencontainers.image.ref.name="0.0.1-nginx1.27.4-alpine-slim" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.created=${BUILD_DATE} \
      org.opencontainers.image.revision=${BUILD_REV} \
      org.opencontainers.image.vendor="MM25Zamanian" \
      org.opencontainers.image.source="https://github.com/MM25Zamanian/XenoProxy" \
      org.opencontainers.image.url="https://github.com/MM25Zamanian/XenoProxy" \
      org.opencontainers.image.documentation="https://github.com/MM25Zamanian/XenoProxy" \
      org.opencontainers.image.authors="S. MohammadMahdi Zamanian <dev@mm25zamanian.ir> (https://dev.mm25zamanian.ir)"
