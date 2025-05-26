ARG REPO_URL=https://github.com/ollama/ollama
ARG TAG=v0.7.0
ARG OLLAMA_REGISTRY_URL=https://registry.ollama.ai

FROM alpine:3 AS build
ARG REPO_URL
ARG TAG
RUN apk update && apk add --no-cache \
    git curl tar gzip build-base musl-dev \
    && rm -rf /var/cache/apk/*
RUN git clone --branch=${TAG} ${REPO_URL} /opt/ollama
WORKDIR /opt/ollama
RUN curl -fsSL https://golang.org/dl/go$(awk '/^go/ { print $2 }' go.mod).linux-$(case $(uname -m) in x86_64) echo amd64 ;; aarch64) echo arm64 ;; esac).tar.gz | tar xz -C /usr/local
ENV PATH=/usr/local/go/bin:$PATH
RUN go mod download
ENV CGO_ENABLED=1
RUN --mount=type=cache,target=/root/.cache/go-build \
  go build -ldflags="-extldflags=-static" -trimpath -buildmode=pie -o /bin/ollama .

FROM alpine:3
ARG OLLAMA_REGISTRY_URL
COPY --from=build /bin/ollama /bin/ollama
ENV OLLAMA_HOST=0.0.0.0:11434
EXPOSE 11434
ENTRYPOINT ["/bin/ollama"]
CMD ["serve"]
