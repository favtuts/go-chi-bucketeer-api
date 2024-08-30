FROM golang:1.18.3-alpine3.16 as builder

COPY go.mod go.sum /go/src/github.com/favtuts/go-chi-bucketeer-api/
WORKDIR /go/src/github.com/favtuts/go-chi-bucketeer-api
RUN go mod download
COPY . /go/src/github.com/favtuts/go-chi-bucketeer-api
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o build/bucketeer github.com/favtuts/go-chi-bucketeer-api

FROM alpine
RUN apk add --no-cache ca-certificates && update-ca-certificates
COPY --from=builder /go/src/github.com/favtuts/go-chi-bucketeer-api/build/bucketeer /usr/bin/bucketeer
EXPOSE 8080 8080
ENTRYPOINT ["/usr/bin/bucketeer"]