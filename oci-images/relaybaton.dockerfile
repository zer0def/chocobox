#FROM golang:1.15-alpine AS builder
FROM golang:1.15 AS builder
ARG VERSION=ech
ARG SOURCE_REPO=https://github.com/iyouport-org/relaybaton
WORKDIR /go/src/github.com/iyouport-org
#RUN apk add --no-cache git make perl rsync \
RUN apt update && apt -y install git make perl rsync \
 && git clone ${SOURCE_REPO} -b ${VERSION} \
 && cd relaybaton \
 && make

#FROM alpine:edge
FROM debian:testing-slim
COPY --from=builder /go/src/github.com/iyouport-org/relaybaton/bin/relaybaton /relaybaton
ENTRYPOINT ["/relaybaton"]
