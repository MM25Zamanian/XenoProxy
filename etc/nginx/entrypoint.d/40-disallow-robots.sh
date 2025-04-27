#!/bin/sh

set -eu

ME=$(basename "$0")

if [ -n "${NGINX_DISALLOW_ROBOTS:-}" ]; then
    echo "$ME: Replace robots.txt to disallow all robots"
    cp -afv /default-data/robots.txt $NGINX_DOCUMENT_ROOT/
else
    echo "$ME: Remove robots.txt file"
    if [ -f "$NGINX_DOCUMENT_ROOT/robots.txt" ]; then
        rm -fv "$NGINX_DOCUMENT_ROOT/robots.txt"
    fi
fi

exit 0