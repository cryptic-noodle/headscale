# renovate: datasource=github-releases depName=aptible/supercronic
ARG SUPERCRONIC_VERSION=v0.2.29

# renovate: datasource=github-releases depName=DarthSim/overmind
ARG OVERMIND_VERSION=v2.5.1

# renovate: datasource=github-releases depName=rclone/rclone
ARG RCLONE_VERSION=v1.69.3


# Binary file names
ARG SUPERCRONIC=supercronic-linux-amd64
ARG OVERMIND=overmind-${OVERMIND_VERSION}-linux-amd64
ARG RCLONE=rclone
ARG RCLONE_DIRECTORY=rclone-${RCLONE_VERSION}-linux-amd64 

FROM vaultwarden/server:alpine as vaultwarden

#
# Supercronic
#
FROM alpine:3.19 as supercronic

ARG SUPERCRONIC_VERSION
ARG OVERMIND_VERSION
ARG SUPERCRONIC
ARG OVERMIND

ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/${SUPERCRONIC}

WORKDIR /

RUN wget "$SUPERCRONIC_URL" && chmod +x "$SUPERCRONIC"

#
# Overmind
#
FROM alpine:3.19 as overmind

ARG OVERMIND_VERSION
ARG SUPERCRONIC
ARG OVERMIND

ENV OVERMIND_FILE=overmind-${OVERMIND_VERSION}-linux-amd64.gz

ENV OVERMIND_URL=https://github.com/DarthSim/overmind/releases/download/${OVERMIND_VERSION}/${OVERMIND_FILE}

WORKDIR /

RUN wget "$OVERMIND_URL" && gunzip ${OVERMIND_FILE} && chmod +x "$OVERMIND"

#
# Rclone
#
FROM alpine:3.19 as rclone

ARG RCLONE_VERSION
ARG RCLONE

ENV RCLONE_FILE=rclone-${RCLONE_VERSION}-linux-amd64.zip
ARG RCLONE_DIRECTORY

ENV RCLONE_URL=https://github.com/rclone/rclone/releases/download/${RCLONE_VERSION}/${RCLONE_FILE}

WORKDIR /

RUN wget "$RCLONE_URL" && unzip ${RCLONE_FILE} && chmod +x "$RCLONE_DIRECTORY/$RCLONE"

#
# Fly app
#
FROM caddy:alpine AS caddy

FROM ghcr.io/tale/headplane:latest AS headplane

FROM headscale/headscale:0.29.4 AS headscale

FROM node:24-alpine

ARG SUPERCRONIC
ARG OVERMIND
ARG RCLONE_DIRECTORY
ARG RCLONE

ENV TZ="Asia/Kolkata"

# ENV OVERMIND_CAN_DIE=swapcreate

VOLUME /data

RUN mkdir -p /etc/headscale /data/headscale /var/run/headscale /data/headplane /data/caddy

COPY --from=headscale ko-app/headscale /usr/bin/headscale
COPY --from=headplane /app/build /opt/headplane/build
COPY --from=headplane /app/drizzle /opt/headplane/drizzle
COPY --from=headplane /var/lib/headplane /data/headplane
COPY --from=headplane /usr/libexec/headplane/agent /usr/libexec/headplane/agent

COPY --from=caddy /usr/bin/caddy /usr/bin/caddy
COPY --from=supercronic /${SUPERCRONIC} /usr/bin/supercronic
COPY --from=overmind /${OVERMIND} /usr/bin/overmind
COPY --from=rclone ${RCLONE_DIRECTORY}/${RCLONE} /usr/bin/rclone


WORKDIR /etc/headscale


RUN apk add --no-cache \
  ca-certificates \
  curl \
  openssl \
  tzdata \
  iptables \
  ip6tables \
  tmux \
  sqlite \
  vim \
  libcap \
  entr

RUN apk add --no-cache \
  --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing \
  rustic

RUN setcap 'cap_net_bind_service=+ep' /usr/bin/caddy
# RUN addgroup -g 1000 -S headscale && adduser -u 1000 -S -s /bin/sh -G headscale headscale
COPY configs/* ./


RUN chown -R node:node /etc/headscale /data/headscale /var/run/headscale /data/headplane /data/caddy /opt/headplane


EXPOSE 80
EXPOSE 443

USER node

ENV TZ="Asia/Kolkata" \
  OVERMIND_AUTO_RESTART=all

CMD ["overmind", "start"]
