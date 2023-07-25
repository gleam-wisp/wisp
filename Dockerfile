FROM ghcr.io/gleam-lang/gleam:v0.30.3-erlang-alpine

# Add project code
COPY . /build/

# Compile the application
RUN apk add --no-cache sqlite gcc make libc-dev bsd-compat-headers \
  && cd /build/action \
  && gleam export erlang-shipment \
  && mv build/erlang-shipment /app \
  && rm -r /build \
  && addgroup -S action \
  && adduser -S action -G action \
  && chown -R action /app

USER action
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run", "server"]
