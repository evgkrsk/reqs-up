FROM crystallang/crystal:latest-alpine as build-env
ENV BUILD_PACKAGES upx yaml-static
WORKDIR /app

RUN apk --update --no-cache add $BUILD_PACKAGES

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
    rm -f bin/reqs-up.dwarf && \
    :

FROM alpine:3.13
ENV UPDATE_PACKAGES dumb-init
ENV CRYSTAL_ENV production
WORKDIR /app

COPY --from=build-env /app/bin/reqs-up /app/bin/reqs-up

RUN set -ex && \
    apk --update --no-cache -u add $UPDATE_PACKAGES && \
    rm -rf /var/cache/apk/* && \
    :

ENTRYPOINT ["/app/bin/reqs-up"]
