# XenoProxy: High-Performance Nginx Reverse Proxy for Next.js

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

XenoProxy provides a robust, production-ready Nginx configuration meticulously tuned to act as a high-performance reverse proxy for Next.js applications, especially those experiencing high traffic volumes. It leverages Nginx's power for load balancing (implicitly ready), caching, compression, security, and efficient connection management, offloading these tasks from your Next.js server.

This configuration is based on extensive research into best practices for optimizing Nginx when serving demanding Next.js applications, incorporating lessons learned from managing high-traffic scenarios.

## Why XenoProxy? (The Philosophy)

The name 'XenoProxy' is inspired by **Xenon (Xe)**, a heavy, stable noble gas known for its use in high-intensity lighting and its inert nature. This mirrors the goals of this configuration:

*   **Stability & Reliability:** Like a noble gas, this configuration aims to provide a stable, reliable, and non-interfering layer in front of your Next.js application. It's designed to run consistently under pressure.
*   **Handling Heavy Loads:** Just as Xenon is one of the heavier noble gases, this configuration is built to manage significant traffic ("heavy loads") efficiently, preventing your Next.js instances from becoming overwhelmed.
*   **High Performance:** Xenon is used in high-intensity discharge lamps for bright, efficient lighting. Similarly, XenoProxy aims to maximize the performance and speed of your Next.js application delivery through optimized caching, compression, and connection handling.
*   **Protection (Shielding):** While not a direct property of Xenon, noble gases are used as shielding atmospheres. XenoProxy acts as a protective shield, offering basic security measures like rate limiting and hiding your application servers.

Essentially, XenoProxy is designed to be the stable, high-performance, load-bearing gateway your Next.js application deserves.

## Key Features

*   **Optimized Reverse Proxying:** Efficiently forwards requests to your Next.js application running typically on `localhost:3000`.
*   **Aggressive Static Asset Caching:** Configured to heavily cache Next.js static assets (`/_next/static/`) and other common static files (`.css`, `.js`, `.png`, etc.) using `expires` and `immutable` Cache-Control headers for maximum browser and CDN performance.
*   **Gzip Compression Enabled:** Reduces the size of text-based assets (HTML, CSS, JS, JSON, etc.) to speed up load times and save bandwidth. Tuned `gzip_comp_level` and `gzip_min_length`.
*   **Keep-Alive Optimization:** Fine-tuned `keepalive_timeout` and `keepalive_requests` for efficient connection reuse between clients and Nginx, and uses HTTP/1.1 for upstream connections.
*   **Basic Rate Limiting:** Includes a basic `limit_req_zone` configuration to help mitigate brute-force attacks and excessive requests from single IP addresses.
*   **WebSocket Support Ready:** Headers (`Upgrade`, `Connection`) are configured for seamless WebSocket proxying often used by Next.js features.
*   **Security Headers:** Passes essential headers like `X-Real-IP`, `X-Forwarded-For`, and `X-Forwarded-Proto` to your Next.js application.
*   **Optimized Worker Configuration:** Uses `worker_processes auto;` and a sensible default for `worker_connections`.
*   **Logging:** Standard access and error logging configured, with logging disabled for static assets to reduce noise.

## Usage

1.  **Obtain the Configuration:** Clone this repository or download the `nginx.conf` file (or the relevant parts for your setup, e.g., the `server` block).
2.  **Place the Configuration:**
    *   You can use the provided `nginx.conf` as your main Nginx configuration file (backup your existing one first!).
    *   Alternatively, and often recommended, place the `server` block content into a new file within your Nginx sites-available directory (e.g., `/etc/nginx/sites-available/yourdomain.com`) and create a symbolic link in `sites-enabled`.
3.  **Customize:**
    *   **`server_name yourdomain.com;`**: Replace `yourdomain.com` with your actual domain name(s).
    *   **`proxy_pass http://localhost:3000;`**: Ensure the port (`3000`) matches the port your Next.js application is running on. Adjust if necessary (e.g., if using multiple upstreams for load balancing).
    *   **(Optional) SSL:** If you need HTTPS, uncomment and configure the SSL certificate lines (or use Certbot which often handles this). You might want to add a redirect from HTTP to HTTPS as shown commented out in the config.
    *   **Rate Limiting:** Adjust the `rate=10r/s` and `burst=20` values in `limit_req_zone` and `limit_req` based on your expected traffic patterns and server capacity.
4.  **Test Configuration:** Before applying, always test your Nginx configuration:
    ```bash
    sudo nginx -t
    ```
5.  **Reload Nginx:** If the test is successful, reload Nginx to apply the changes:
    ```bash
    sudo systemctl reload nginx
    # or
    # sudo service nginx reload
    ```

## Full Configuration & Explanation

Below is the complete `nginx.conf` provided by XenoProxy, followed by a detailed explanation of each directive.

### Configuration (`nginx.conf`)

```nginx
# Base worker configuration for optimal CPU usage and connection handling
worker_processes auto;
worker_connections 1024; # Adjust based on expected load and server resources

http {
    # Include standard MIME types and set default
    include       mime.types;
    default_type  application/octet-stream;

    # Define a custom log format including forwarded IPs
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    # Define log file paths
    access_log  /var/log/nginx/access.log  main;
    error_log   /var/log/nginx/error.log;

    # Optimize file serving
    sendfile        on;
    tcp_nopush      on; # Send headers and data together
    tcp_nodelay     on; # Send small packets immediately (good for interactive apps)

    # Keep-Alive settings for client connections
    keepalive_timeout  75; # How long idle connections stay open
    keepalive_requests 100; # Max requests per keep-alive connection

    # Gzip compression settings
    gzip on;
    gzip_disable "msie6"; # Disable for buggy IE6
    gzip_vary on; # Add Vary: Accept-Encoding header for proxies
    gzip_proxied any; # Compress responses from proxied servers
    gzip_comp_level 6; # Balance between compression ratio and CPU usage (1-9)
    gzip_buffers 16 8k; # Buffers for compression
    gzip_http_version 1.1; # Enable for HTTP/1.1
    gzip_min_length 1000; # Minimum response size to compress (bytes)
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Define a rate limiting zone (shared memory)
    # key: $binary_remote_addr (client IP), zone: name 'one', size 10MB, rate: 10 requests/second
    limit_req_zone $binary_remote_addr zone=one:10m rate=10r/s;

    # Define the server block for your Next.js application
    server {
        listen 80; # Listen on port 80 for HTTP
        server_name yourdomain.com; # *** REPLACE WITH YOUR DOMAIN ***

        # Optional: Redirect all HTTP traffic to HTTPS (Uncomment if SSL is configured)
        # location / {
        #     return 301 https://$host$request_uri;
        # }
        # } # Close the HTTP server block if redirecting everything

    # If not redirecting all HTTP to HTTPS, or for HTTPS server block:
    # server {
        # listen 443 ssl http2; # Listen for HTTPS
        # server_name yourdomain.com; # *** REPLACE WITH YOUR DOMAIN ***

        # ssl_certificate /path/to/your/fullchain.pem; # *** REPLACE WITH YOUR CERT PATH ***
        # ssl_certificate_key /path/to/your/privkey.pem; # *** REPLACE WITH YOUR KEY PATH ***
        # Include other SSL hardening options here (e.g., protocols, ciphers)

        # Location block for Next.js static assets generated by the build
        location ~* ^/(_next|__next)/static/ {
            expires 365d; # Cache aggressively for 1 year
            add_header Cache-Control "public, max-age=31536000, immutable";
            access_log off; # Don't log access for static files
            log_not_found off; # Don't log 404s for static files

            # Proxy pass needed if files are served by Next.js itself,
            # Or use 'root'/'alias' if files are served directly from filesystem
            proxy_pass http://localhost:3000; # *** Point to your Next.js app ***
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Location block for other common static files
        location ~* \.(?:css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|otf|eot)$ {
            expires 365d; # Cache aggressively for 1 year
            add_header Cache-Control "public, max-age=31536000, immutable";
            access_log off; # Don't log access
            log_not_found off; # Don't log 404s

            # Depending on your setup, you might serve these directly via Nginx 'root'
            # or proxy them if they are handled by Next.js public folder serving
            # Example for direct serving (if files are in /var/www/html/):
            # root /var/www/html;
            # try_files $uri =404;

            # Example for proxying (if served by Next.js):
            proxy_pass http://localhost:3000; # *** Point to your Next.js app ***
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Location block for all other requests (SSR pages, API routes, etc.)
        location / {
            # Apply the rate limit defined earlier
            # zone=one (matches the zone name), burst=20 (allow bursts of 20 requests), nodelay (reject immediately if limit exceeded)
            limit_req zone=one burst=20 nodelay;

            # Proxy settings to forward requests to the Next.js app
            proxy_pass http://localhost:3000; # *** Point to your Next.js app ***
            proxy_http_version 1.1; # Use HTTP/1.1 for upstream keep-alive
            proxy_set_header Upgrade $http_upgrade; # Necessary for WebSockets
            proxy_set_header Connection 'upgrade'; # Necessary for WebSockets
            proxy_set_header Host $host; # Pass the original host header
            proxy_cache_bypass $http_upgrade; # Don't cache WebSocket upgrades
            proxy_set_header X-Real-IP $remote_addr; # Pass the real client IP
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; # Append IPs if behind multiple proxies
            proxy_set_header X-Forwarded-Proto $scheme; # Pass the original protocol (http/https)
        }
    } # End of server block
} # End of http block

```

### Line-by-Line Explanation

<details>
<summary>Click to expand detailed configuration explanation</summary>

*   `worker_processes auto;`: Automatically sets the number of Nginx worker processes based on the number of available CPU cores. This optimizes resource utilization.
*   `worker_connections 1024;`: Sets the maximum number of simultaneous connections that each worker process can handle. 1024 is a common default, but may need adjustment based on traffic and system limits (`ulimit -n`).
*   `http { ... }`: Main configuration block for HTTP server settings.
*   `include mime.types;`: Includes a file mapping file extensions to MIME types, crucial for browsers to correctly interpret content.
*   `default_type application/octet-stream;`: Sets the default MIME type if it cannot be determined from the `mime.types` file.
*   `log_format main ...;`: Defines a custom format named `main` for access logs, including useful information like the real client IP (`$remote_addr`) and forwarded IPs (`$http_x_forwarded_for`).
*   `access_log /var/log/nginx/access.log main;`: Specifies the path and format for the access log file.
*   `error_log /var/log/nginx/error.log;`: Specifies the path for the error log file.
*   `sendfile on;`: Enables the use of the kernel's `sendfile()` system call for more efficient serving of static files directly from disk.
*   `tcp_nopush on;`: Optimizes packet sending by ensuring Nginx sends response headers and the beginning of the file data in the same packet (used with `sendfile on`).
*   `tcp_nodelay on;`: Allows Nginx to send small packets immediately, reducing latency, especially important for keep-alive connections and interactive applications.
*   `keepalive_timeout 75;`: Sets the timeout (in seconds) during which an idle keep-alive connection to a client will remain open. 75s is a common default.
*   `keepalive_requests 100;`: Sets the maximum number of requests that can be served through one keep-alive connection before it's closed. Prevents connections from being held open indefinitely.
*   `gzip on;`: Enables Gzip compression for HTTP responses.
*   `gzip_disable "msie6";`: Disables Gzip for older, buggy versions of Internet Explorer 6.
*   `gzip_vary on;`: Adds the `Vary: Accept-Encoding` header, telling intermediate caches that the response varies based on client compression support. Crucial for correct caching.
*   `gzip_proxied any;`: Instructs Nginx to compress responses even if the request came through a proxy.
*   `gzip_comp_level 6;`: Sets the Gzip compression level (1=fastest, least compression; 9=slowest, most compression). Level 6 is a good balance.
*   `gzip_buffers 16 8k;`: Sets the number and size of buffers used for Gzip compression.
*   `gzip_http_version 1.1;`: Enables Gzip only for HTTP/1.1 requests (or higher).
*   `gzip_min_length 1000;`: Sets the minimum response length (in bytes) required for Gzip compression to be applied. Compressing very small files can be inefficient due to overhead.
*   `gzip_types ...;`: Specifies the MIME types of content that should be compressed. Focuses on text-based assets.
*   `limit_req_zone $binary_remote_addr zone=one:10m rate=10r/s;`: Defines a shared memory zone named `one` (10MB size) to track request rates based on the client's binary IP address (`$binary_remote_addr`). It sets a baseline rate limit of 10 requests per second.
*   `server { ... }`: Defines a virtual server block to handle requests for a specific domain/IP and port.
*   `listen 80;`: Instructs the server to listen for incoming connections on port 80 (standard HTTP).
*   `server_name yourdomain.com;`: Specifies the domain name(s) this server block should respond to. **Replace with your actual domain.**
*   `location ~* ^/(_next|__next)/static/ { ... }`: Location block matching requests for Next.js's static build assets. The `~*` means case-insensitive regex matching.
    *   `expires 365d;`: Sets the `Expires` header to 365 days in the future, telling browsers they can cache this resource for a long time.
    *   `add_header Cache-Control "public, max-age=31536000, immutable";`: Adds a `Cache-Control` header: `public` (cacheable by intermediaries), `max-age` (cache duration in seconds, matching 365d), `immutable` (tells browsers the file content will never change, allowing them to skip revalidation checks - safe for hashed filenames used by Next.js).
    *   `access_log off;`: Disables access logging for these requests to reduce log noise.
    *   `log_not_found off;`: Disables logging of "file not found" errors for these paths.
    *   `proxy_pass http://localhost:3000;`: Forwards the request to the upstream Next.js server. **Adjust port if needed.** (Note: If serving directly from filesystem, you'd use `root` or `alias` here instead).
    *   *(Proxy headers inside this block ensure correct forwarding if serving via Next.js)*
*   `location ~* \.(?:css|js|...|eot)$ { ... }`: Location block matching requests for common static file extensions.
    *   *(Similar caching headers and logging directives as the `/_next/static/` block)*
    *   *(Requires either `proxy_pass` if served by Next.js, or `root`/`alias` + `try_files` if served directly by Nginx)*
*   `location / { ... }`: A catch-all location block for any request not matched by previous, more specific location blocks (e.g., SSR pages, API routes).
    *   `limit_req zone=one burst=20 nodelay;`: Applies the rate limit defined in the `one` zone. Allows a burst of up to 20 requests exceeding the rate, and `nodelay` ensures excess requests beyond the burst are rejected immediately instead of being queued.
    *   `proxy_pass http://localhost:3000;`: Forwards the request to the upstream Next.js server. **Adjust port if needed.**
    *   `proxy_http_version 1.1;`: Uses HTTP/1.1 for the connection to the upstream server, enabling keep-alive connections between Nginx and Next.js.
    *   `proxy_set_header Upgrade $http_upgrade;`: Passes the `Upgrade` header from the client, necessary for protocols like WebSockets.
    *   `proxy_set_header Connection 'upgrade';`: Sets the `Connection` header correctly for protocol upgrades (like WebSockets).
    *   `proxy_set_header Host $host;`: Passes the original `Host` header requested by the client to the Next.js application. Crucial for multi-domain setups or if the app uses the Host header.
    *   `proxy_cache_bypass $http_upgrade;`: Tells Nginx not to serve from its cache if the request involves a protocol upgrade (relevant if using `proxy_cache`).
    *   `proxy_set_header X-Real-IP $remote_addr;`: Sends the actual client IP address to the Next.js application in the `X-Real-IP` header.
    *   `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`: Appends the client IP (and any previous proxy IPs) to the `X-Forwarded-For` header. Standard way to track the originating client IP through proxies.
    *   `proxy_set_header X-Forwarded-Proto $scheme;`: Sends the original protocol used by the client (http or https) to the Next.js application in the `X-Forwarded-Proto` header. Useful for generating correct URLs or enforcing HTTPS within the app.

</details>

## Contributing

Contributions are welcome! Please refer to the `CONTRIBUTING.md` file for guidelines.

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.
