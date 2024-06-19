FROM ghcr.io/gleam-lang/gleam:v1.2.1-erlang-alpine AS builder

# Add project code
COPY . /build/

# Compile the project
WORKDIR /build

RUN gleam export erlang-shipment \
  && mv build/erlang-shipment /app \
  && rm -r /build


FROM ghcr.io/gleam-lang/gleam:v1.2.1-erlang  as runner
ARG LITEFS_CONFIG=litefs.yml

# Copy binaries from the previous build stages.
COPY --from=builder /app /app
COPY ./priv /priv


ENTRYPOINT ["app/entrypoint.sh"]
CMD ["run"]
