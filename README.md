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