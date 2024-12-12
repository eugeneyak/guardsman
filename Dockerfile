FROM crystallang/crystal:1.14.0-alpine AS builder

WORKDIR "/app"

COPY . .

RUN crystal build src/server.cr --release --static


FROM scratch AS runner

WORKDIR "/app"

COPY --from=builder /app/server server

CMD ["/app/server"]