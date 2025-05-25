ARG CMAKEVERSION=3.31.2
ARG REPO_URL=https://github.com/ollama/ollama
ARG TAG=v0.7.0

FROM alpine:3 AS base
RUN apk update && apk add --no-cache \
    git curl tar gzip build-base musl-dev \
    && rm -rf /var/cache/apk/*
RUN git clone https://github.com/ollama/ollama.git /opt/ollama
WORKDIR /opt/ollama

FROM almalinux:8 AS cpu
COPY --from=base /opt/ollama /opt/ollama
WORKDIR /opt/ollama
ARG CMAKEVERSION
RUN dnf install -y curl tar gzip gcc-toolset-11-gcc gcc-toolset-11-gcc-c++
ENV PATH=/opt/rh/gcc-toolset-11/root/usr/bin:$PATH
RUN curl -fsSL https://github.com/Kitware/CMake/releases/download/v${CMAKEVERSION}/cmake-${CMAKEVERSION}-linux-$(uname -m).tar.gz | tar xz -C /usr/local --strip-components 1
ENV LDFLAGS=-s
RUN echo "set(CMAKE_FIND_STATIC_LIBS_ONLY TRUE)" >> /opt/ollama/CMakeLists.txt
RUN echo "set(CMAKE_CXX_FLAGS \"\${CMAKE_CXX_FLAGS} -static-libstdc++ -static-libgcc -static\")" >> /opt/ollama/CMakeLists.txt
RUN --mount=type=cache,target=/root/.ccache \
    cmake --preset 'CPU' \
        && cmake --build --parallel --preset 'CPU' \
        && cmake --install build --component CPU --strip --parallel 8


FROM alpine:3
RUN apk update && apk add --no-cache \
    git curl tar gzip build-base musl-dev \
    && rm -rf /var/cache/apk/*
COPY --from=base /opt/ollama /opt/ollama
COPY --from=cpu /opt/ollama/dist/lib/ollama /lib/ollama
WORKDIR /opt/ollama
RUN curl -fsSL https://golang.org/dl/go$(awk '/^go/ { print $2 }' go.mod).linux-$(case $(uname -m) in x86_64) echo amd64 ;; aarch64) echo arm64 ;; esac).tar.gz | tar xz -C /usr/local
ENV PATH=/usr/local/go/bin:$PATH
RUN go mod download
ENV CGO_ENABLED=1
RUN --mount=type=cache,target=/root/.cache/go-build \
  go build -trimpath -buildmode=pie -o /bin/ollama .
