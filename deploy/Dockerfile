# notebook stand image (dev only). Build args carry build identity into /healthz.
FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -o /out/notebook .

FROM alpine:3.20
ARG NEXUS_BUILD_SHA=""
ARG NEXUS_BUILD_REF=""
ARG NEXUS_BUILD_ARGS_HASH=""
ARG NEXUS_GATE_BUNDLE_DIGEST=""
ENV NEXUS_BUILD_SHA=$NEXUS_BUILD_SHA \
    NEXUS_BUILD_REF=$NEXUS_BUILD_REF \
    NEXUS_BUILD_ARGS_HASH=$NEXUS_BUILD_ARGS_HASH \
    NEXUS_GATE_BUNDLE_DIGEST=$NEXUS_GATE_BUNDLE_DIGEST
COPY --from=build /out/notebook /notebook
EXPOSE 8080
ENTRYPOINT ["/notebook"]
