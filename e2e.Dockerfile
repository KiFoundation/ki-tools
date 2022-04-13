ARG IMG_TAG=latest

# Compile the kid binary
FROM golang:1.18-alpine AS kid-builder
WORKDIR /src/app/
COPY go.mod go.sum* ./
RUN go mod download
COPY . .

# See https://github.com/CosmWasm/wasmvm/releases
# ADD https://github.com/CosmWasm/wasmvm/releases/download/v1.0.0-beta10/libwasmvm_muslc.aarch64.a /lib/libwasmvm_muslc.aarch64.a
# RUN sha256sum /lib/libwasmvm_muslc.aarch64.a | grep 5b7abfdd307568f5339e2bea1523a6aa767cf57d6a8c72bc813476d790918e44  

ADD https://github.com/CosmWasm/wasmvm/releases/download/v1.0.0-beta10/libwasmvm_muslc.x86_64.a /lib/libwasmvm_muslc.a
RUN sha256sum /lib/libwasmvm_muslc.a | grep 2f44efa9c6c1cda138bd1f46d8d53c5ebfe1f4a53cf3457b01db86472c4917ac  

ENV PACKAGES curl make git libc-dev bash gcc linux-headers eudev-dev python3
RUN apk add --no-cache $PACKAGES
RUN CGO_ENABLED=1 BUILD_TAGS=muslc LINK_STATICALLY=true make install

# Add to a distroless container
FROM gcr.io/distroless/cc:$IMG_TAG
ARG IMG_TAG
COPY --from=kid-builder /go/bin/kid /usr/local/bin/
EXPOSE 26656 26657 1317 9090

ENTRYPOINT ["kid", "start"]
