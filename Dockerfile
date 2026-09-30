# Build whisper.cpp's CLI from source, then ship it in a slim image with ALSA's arecord.
ARG WHISPER_CPP_VERSION=v1.9.4

FROM ubuntu:24.04 AS build
ARG WHISPER_CPP_VERSION
RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential cmake git ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "$WHISPER_CPP_VERSION" https://github.com/ggml-org/whisper.cpp /src
WORKDIR /src
# Built on (and for) the machine running `docker compose build`, so native CPU flags are fine.
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
 && cmake --build build -j"$(nproc)" --target whisper-cli

FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends alsa-utils curl ca-certificates libgomp1 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/build/bin/whisper-cli /usr/local/bin/
COPY --from=build /src/models/download-ggml-model.sh /usr/local/bin/
COPY transcribe.sh /usr/local/bin/transcribe
ENV MODEL_DIR=/models
ENTRYPOINT ["transcribe"]
