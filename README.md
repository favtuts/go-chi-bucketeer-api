# go-chi-bucketeer-api
Bucket list API - built with go-chi, docker, and postgresql. Source code for article: https://tuts.heomi.net/how-to-build-a-restful-api-with-docker-postgresql-and-go-chi/)


# Getting started

To get started, create the project folder in your preferred location and initialize the Go module:
```bash
$ mkdir go-chi-bucketeer-api && cd go-chi-bucketeer-api
$ go mod init github.com/favtuts/go-chi-bucketeer-api
```

Run the commands below to install our application dependencies which consist of:

* [go-chi/chi](https://pkg.go.dev/github.com/go-chi/chi) — to power our API routing
* [go-chi/render](https://pkg.go.dev/github.com/go-chi/render) — to manage requests and responses payload
* [lib/pq](https://pkg.go.dev/github.com/lib/pq) — to interact with our PostgreSQL database

```bash
$ go get -u github.com/go-chi/chi/v5
$ go get -u github.com/go-chi/render
$ go get -u github.com/lib/pq
```

In the project directory, create the needed folders and files to match the layout below:
```bash
├── db
│   ├── db.go
│   └── item.go
├── handler
│   ├── errors.go
│   ├── handler.go
│   └── items.go
├── models
│   └── item.go
├── .env
├── docker-compose.yml
├── Dockerfile
├── go.mod
├── go.sum
├── main.go
└── README.md
```

# Decomposing services with docker-compose

Let us set up the Dockerfile to build the API server into a single binary file, expose the server port, and execute the binary on startup.

```Dockerfile
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
```

Next, open the `docker-compose.yml` file and declare the server and database services:
```yml
version: "3.7"
services:
  database:
    image: postgres
    restart: always
    env_file:
      - .env
    ports:
      - "5432:5432"
    volumes:
      - data:/var/lib/postgresql/data
  server:
    build:
      context: .
      dockerfile: Dockerfile
    env_file: 
      - .env
    depends_on:
      - database
    networks:
      - default
    ports:
    - "8080:8080"
volumes:
  data:
```

Also, populate the `.env` file with your app-specific credentials like this:
```ini
POSTGRES_USER=bucketeer
POSTGRES_PASSWORD=bucketeer_pass
POSTGRES_DB=bucketeer_db
```