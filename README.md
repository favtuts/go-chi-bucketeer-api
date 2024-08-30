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


# Setting up the database

We will be using [golang-migrate](https://github.com/golang-migrate/migrate) to manage our database migrations.

Follow the [installation document](https://github.com/golang-migrate/migrate/tree/master/cmd/migrate) to Install the migrate binary. Or follow the article: [How to Install Golang Migrate on Ubuntu](https://www.geeksforgeeks.org/how-to-install-golang-migrate-on-ubuntu/)


Let us setup the repository to install the migrate package.
```bash
$ curl -s https://packagecloud.io/install/repositories/golang-migrate/migrate/script.deb.sh | sudo bash

Detected operating system as Ubuntu/jammy.
Checking for curl...
Detected curl...
Checking for gpg...
Detected gpg...
Detected apt version as 2.4.12
Running apt-get update... done.
Installing apt-transport-https... done.
Installing /etc/apt/sources.list.d/golang-migrate_migrate.list...done.
Importing packagecloud gpg key... Packagecloud gpg key imported to /etc/apt/keyrings/golang-migrate_migrate-archive-keyring.gpg
done.
Running apt-get update... done.

The repository is setup! You can now install packages.
```

Update the system by executing the following command.
```bash
$ sudo apt-get update
```

Now, it’s time to set up golang migrate. Execute the following command in the terminal to install migrate.
```bash
sudo apt-get install migrate
```

Now you can use golang migrate to perform database migrations. Check by running:
```bash
$ migrate -version
4.17.1
```

Generate the database migrations by running:
```bash
$ migrate create -ext sql -dir db/migrations -seq create_items_table
```

The command creates two SQL files in the `db/migrations` folder. The `XXXXXX_create_items_table.up.sql` file is executed when we run our migrations. Open it and add the SQL code to create a new table:
```sql
CREATE TABLE IF NOT EXISTS items(
id SERIAL PRIMARY KEY,
name VARCHAR(100) NOT NULL,
description TEXT,
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

Conversely, the `XXXXXX_create_items_table.down.sql` file is executed when we roll back the migration. In this case, we simply want to drop the table during rollback, so add this code block to it:
```sql
DROP TABLE IF EXISTS items;
```

We can now apply our migrations with `migrate` by passing in the database connection and the folder that contains our migration files as command-line arguments. The command below does that by creating a bash environment variable using the same credentials declared in the `.env` file:
```bash
$ export POSTGRESQL_URL="postgres://bucketeer:bucketeer_pass@localhost:5432/bucketeer_db?sslmode=disable"
$ migrate -database ${POSTGRESQL_URL} -path db/migrations up
```