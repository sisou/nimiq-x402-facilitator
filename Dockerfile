ARG ELIXIR_VERSION=1.19-otp-28
ARG GLEAM_VERSION=v1.14.0

# Gleam stage
FROM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-scratch AS gleam

# Build stage
FROM elixir:${ELIXIR_VERSION}-alpine AS build
RUN mix local.hex --force
COPY --from=gleam /bin/gleam /bin/gleam
COPY . /app/
RUN cd /app && gleam export erlang-shipment

# Final stage
FROM elixir:${ELIXIR_VERSION}-alpine
# Install curl for health checks
RUN apk --no-cache add curl
RUN \
  addgroup --system webapp \
  && adduser --system webapp -g webapp
COPY --from=build /app/build/erlang-shipment /app
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
