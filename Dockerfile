FROM golang:1.11.0-alpine3.8 as builder-grok-exporter
ENV GOPATH /go
ENV ONIG_VERSION 6.9.2
ENV ONIG_SHA256SUM db7addb196ecb34e9f38d8f9c97b29a3e962c0e17ea9636127b3e3c42f24976a
ENV GROK_EXP_VERSION 0.2.8
ENV GO111MODULE on

WORKDIR /root

RUN apk update && apk add oniguruma-dev tar g++ make git
RUN wget https://github.com/kkos/oniguruma/releases/download/v${ONIG_VERSION}/onig-${ONIG_VERSION}.tar.gz
RUN echo "${ONIG_SHA256SUM}  onig-${ONIG_VERSION}.tar.gz" | sha256sum -c -
RUN tar xfz onig-${ONIG_VERSION}.tar.gz

WORKDIR /root/onig-${ONIG_VERSION}

RUN ./configure && make && make install
RUN mkdir -p ${GOPATH}/src/github.com/fstab/

WORKDIR ${GOPATH}/src/github.com/fstab

RUN git clone https://github.com/fstab/grok_exporter && cd grok_exporter && git checkout tags/v${GROK_EXP_VERSION} && git submodule update --init --recursive && rm -rf dist

WORKDIR ${GOPATH}/src/github.com/fstab/grok_exporter

RUN go fmt $(go list ./... | grep -v /vendor/)
RUN go test $(go list ./... | grep -v /vendor/)

RUN mkdir -p dist/grok_exporter-${GROK_EXP_VERSION}.linux-amd64
RUN go build -a -ldflags "-X github.com/fstab/grok_exporter/exporter.Version=${GROK_EXP_VERSION} -X github.com/fstab/grok_exporter/exporter.BuildDate=$(date +%Y-%m-%d) -X github.com/fstab/grok_exporter/exporter.Branch=$(git rev-parse --abbrev-ref HEAD) -X github.com/fstab/grok_exporter/exporter.Revision=$(git rev-parse --short HEAD) -w -s -v -extldflags \"-static\"" -o dist/grok_exporter-${GROK_EXP_VERSION}.linux-amd64/grok_exporter

FROM alpine:3.8
ENV SRC_GOPATH /go
ENV GROK_EXP_VERSION 0.2.8
COPY --from=builder-grok-exporter ${SRC_GOPATH}/src/github.com/fstab/grok_exporter/dist/grok_exporter-${GROK_EXP_VERSION}.linux-amd64/grok_exporter /usr/bin/grok_exporter
RUN mkdir -p /etc/grok_exporter/patterns
COPY --from=builder-grok-exporter ${SRC_GOPATH}/src/github.com/fstab/grok_exporter/logstash-patterns-core/patterns /etc/grok_exporter/patterns

ENTRYPOINT ["/usr/bin/grok_exporter"]
CMD ["-version"]
