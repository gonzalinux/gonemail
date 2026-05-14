ARG MIX_ENV=prod

FROM hexpm/elixir:1.17.3-erlang-27.1.2-alpine-3.20.3 AS builder

ARG MIX_ENV
ENV MIX_ENV=${MIX_ENV}

RUN apk add --no-cache build-base

WORKDIR /app

COPY mix.exs mix.lock ./

RUN mix local.hex --force && \
    mix local.rebar --force

RUN if [ "$MIX_ENV" = "prod" ]; then \
      mix deps.get --only prod; \
    else \
      mix deps.get; \
    fi && mix deps.compile

COPY config config
COPY lib lib
COPY priv priv

RUN mix compile && mix release

FROM alpine:3.20.3

ARG MIX_ENV=prod

RUN apk add --no-cache openssl ncurses-libs libstdc++ ca-certificates

RUN addgroup -g 1000 gonemail && \
    adduser -u 1000 -G gonemail -s /bin/sh -D gonemail

RUN mkdir -p /app /app/logs && \
    chown -R gonemail:gonemail /app

COPY --from=builder --chown=gonemail:gonemail /app/_build/${MIX_ENV}/rel/gonemail /app
COPY --chown=gonemail:gonemail script/docker_entrypoint.sh /app/docker_entrypoint.sh

RUN chmod +x /app/docker_entrypoint.sh

WORKDIR /app
USER gonemail

ENV HOME=/app

EXPOSE 7777

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget -q -O /dev/null http://localhost:${PORT:-7777}/health || exit 1

CMD ["/app/docker_entrypoint.sh"]
