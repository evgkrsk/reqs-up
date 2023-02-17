FROM crystallang/crystal:latest-alpine as build-env
ENV BUILD_PACKAGES upx yaml-static
WORKDIR /app

# hadolint ignore=DL3018
RUN apk --update --no-cache upgrade && \
    apk --no-cache add $BUILD_PACKAGES

COPY shard.yml shard.lock ./
RUN set -ex && \
    shards install && \
    :

COPY . /app

RUN set -ex && \
    crystal bin/ameba.cr && \
    shards build --release --static && \
    strip bin/reqs-up && \
    upx -9 bin/reqs-up && \
    :

FROM alpine:3.17
ENV CRYSTAL_ENV production
WORKDIR /app

COPY --from=build-env /app/bin/reqs-up /app/bin/reqs-up

RUN set -ex && \
    apk --update --no-cache upgrade && \
    rm -rf /var/cache/apk/* && \
    :

ENTRYPOINT ["/app/bin/reqs-up"]
