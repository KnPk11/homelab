# custom_caddy:latest
FROM caddy:2-builder AS builder

RUN xcaddy build \
    --with github.com/caddyserver/transform-encoder \
    --with github.com/mholt/caddy-ratelimit

FROM caddy:2

# Copy the custom-built caddy binary
COPY --from=builder /usr/bin/caddy /usr/bin/caddy