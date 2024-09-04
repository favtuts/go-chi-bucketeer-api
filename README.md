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
* [lib/pq](https://pkg.go.dev/github.com/lib/pq) — to interact with our [PostgreSQL](https://hub.docker.com/_/postgres) database

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

# Using structs as models

We need models to ease how we interact with the database from our Go code. For our case, this model is in the `item.go` file in the `models` folder. With chi, we also get the benefit of rendering them as JSON objects to our API consumer. We do this by making our model implement the [chi.Renderer](https://pkg.go.dev/github.com/go-chi/render?tab=doc#Render) interface i.e, by implementing a `Render` method for it. Open the file (`models/item.go`) and add the following code to it:

```go
package models
import (
    "fmt"
    "net/http"
)
type Item struct {
    ID int `json:"id"`
    Name string `json:"name"`
    Description string `json:"description"`
    CreatedAt string `json:"created_at"`
}
type ItemList struct {
    Items []Item `json:"items"`
}
func (i *Item) Bind(r *http.Request) error {
    if i.Name == "" {
        return fmt.Errorf("name is a required field")
    }
    return nil
}
func (*ItemList) Render(w http.ResponseWriter, r *http.Request) error {
    return nil
}
func (*Item) Render(w http.ResponseWriter, r *http.Request) error {
    return nil
}
```

# Interacting with PostgreSQL

With our database in place now, we can connect to it from our Go code. Edit the `db.go` file in the `db` directory and add the code to manage the connection:

```go
package db
import (
    "database/sql"
    "fmt"
    "log"
    _ "github.com/lib/pq"
)
const (
    HOST = "database"
    PORT = 5432
)
// ErrNoMatch is returned when we request a row that doesn't exist
var ErrNoMatch = fmt.Errorf("no matching record")
type Database struct {
    Conn *sql.DB
}
func Initialize(username, password, database string) (Database, error) {
    db := Database{}
    dsn := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=disable",
        HOST, PORT, username, password, database)
    conn, err := sql.Open("postgres", dsn)
    if err != nil {
        return db, err
    }
    db.Conn = conn
    err = db.Conn.Ping()
    if err != nil {
        return db, err
    }
    log.Println("Database connection established")
    return db, nil
}
```

Next, edit the `item.go` file to make it responsible for interacting with the items table. Such interactions include fetching all list items, creating an item, fetching an item using its ID as well as updating and deleting them:

```go
package db
import (
    "database/sql"
    "github.com/favtuts/go-chi-bucketeer-api/models"
)
func (db Database) GetAllItems() (*models.ItemList, error) {
    list := &models.ItemList{}
    rows, err := db.Conn.Query("SELECT * FROM items ORDER BY ID DESC")
    if err != nil {
        return list, err
    }
    for rows.Next() {
        var item models.Item
        err := rows.Scan(&item.ID, &item.Name, &item.Description, &item.CreatedAt)
        if err != nil {
            return list, err
        }
        list.Items = append(list.Items, item)
    }
    return list, nil
}
func (db Database) AddItem(item *models.Item) error {
    var id int
    var createdAt string
    query := `INSERT INTO items (name, description) VALUES ($1, $2) RETURNING id, created_at`
    err := db.Conn.QueryRow(query, item.Name, item.Description).Scan(&id, &createdAt)
    if err != nil {
        return err
    }
    item.ID = id
    item.CreatedAt = createdAt
    return nil
}
func (db Database) GetItemById(itemId int) (models.Item, error) {
    item := models.Item{}
    query := `SELECT * FROM items WHERE id = $1;`
    row := db.Conn.QueryRow(query, itemId)
    switch err := row.Scan(&item.ID, &item.Name, &item.Description, &item.CreatedAt); err {
    case sql.ErrNoRows:
        return item, ErrNoMatch
    default:
        return item, err
    }
}
func (db Database) DeleteItem(itemId int) error {
    query := `DELETE FROM items WHERE id = $1;`
    _, err := db.Conn.Exec(query, itemId)
    switch err {
    case sql.ErrNoRows:
        return ErrNoMatch
    default:
        return err
    }
}
func (db Database) UpdateItem(itemId int, itemData models.Item) (models.Item, error) {
    item := models.Item{}
    query := `UPDATE items SET name=$1, description=$2 WHERE id=$3 RETURNING id, name, description, created_at;`
    err := db.Conn.QueryRow(query, itemData.Name, itemData.Description, itemId).Scan(&item.ID, &item.Name, &item.Description, &item.CreatedAt)
    if err != nil {
        if err == sql.ErrNoRows {
            return item, ErrNoMatch
        }
        return item, err
    }
    return item, nil
}
```

The code above sets up five methods that match each of our API endpoints. Notice that each of the methods is capable of returning any error they encounter during the database operation. That way, we can bubble the errors all the way up to a place where they are properly handled.

`GetAllItems` retrieves all the items in the database and returns them as an `ItemList` which holds a slice of items.

`AddItem` is responsible for creating a new item in the database. It also updates the `ID` of the `Item` instance it receives by leveraging PostgreSQL’s [RETURNING](https://www.postgresql.org/docs/9.5/dml-returning.html) keyword.

`GetItemById`, `UpdateItem`, and `DeleteItem` are responsible for fetching, updating, and deleting items from our database. In their cases, we perform an additional check and return a different error if the item does not exist in the database.


# Wiring up our route handlers

We are now ready to leverage chi’s powerful routing features. We will first initialize the route handlers in `handler/handler.go` and implement the code to handle HTTP errors such as 404 Not Found and 405 Method Not Allowed. Open the `handler.go` file and paste in the code below:

```go
package handler

import (
	"net/http"

	"github.com/favtuts/go-chi-bucketeer-api/db"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/render"
)

var dbInstance db.Database

func NewHandler(db db.Database) http.Handler {
	router := chi.NewRouter()
	dbInstance = db
	router.MethodNotAllowed(methodNotAllowedHandler)
	router.NotFound(notFoundHandler)
	router.Route("/items", items)
	return router
}
func methodNotAllowedHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-type", "application/json")
	w.WriteHeader(405)
	render.Render(w, r, ErrMethodNotAllowed)
}
func notFoundHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-type", "application/json")
	w.WriteHeader(400)
	render.Render(w, r, ErrNotFound)
}

```

Next, edit the `handler/errors.go` file to declare the error responses we referenced above (i.e., `ErrNotFound` and `ErrMethodNotAllowed`) as well as the ones we will be using later on across the different route handlers:

```go
package handler

import (
	"net/http"

	"github.com/go-chi/render"
)

type ErrorResponse struct {
	Err        error  `json:"-"`
	StatusCode int    `json:"-"`
	StatusText string `json:"status_text"`
	Message    string `json:"message"`
}

var (
	ErrMethodNotAllowed = &ErrorResponse{StatusCode: 405, Message: "Method not allowed"}
	ErrNotFound         = &ErrorResponse{StatusCode: 404, Message: "Resource not found"}
	ErrBadRequest       = &ErrorResponse{StatusCode: 400, Message: "Bad request"}
)

func (e *ErrorResponse) Render(w http.ResponseWriter, r *http.Request) error {
	render.Status(r, e.StatusCode)
	return nil
}

func ErrorRenderer(err error) *ErrorResponse {
	return &ErrorResponse{
		Err:        err,
		StatusCode: 400,
		StatusText: "Bad request",
		Message:    err.Error(),
	}
}

func ServerErrorRenderer(err error) *ErrorResponse {
	return &ErrorResponse{
		Err:        err,
		StatusCode: 500,
		StatusText: "Internal server error",
		Message:    err.Error(),
	}
}
```

Next, we will update `handler/items.go` which is responsible for all API endpoints having the `/items` prefix as we specified in the main handler file. Open it in your editor and add the following:

```go
package handler

import (
	"context"
	"fmt"
	"net/http"
	"strconv"

	"github.com/favtuts/go-chi-bucketeer-api/db"
	"github.com/favtuts/go-chi-bucketeer-api/models"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/render"
)

var itemIDKey = "itemID"

func items(router chi.Router) {
	router.Get("/", getAllItems)
	router.Post("/", createItem)
	router.Route("/{itemId}", func(router chi.Router) {
		router.Use(ItemContext)
		router.Get("/", getItem)
		router.Put("/", updateItem)
		router.Delete("/", deleteItem)
	})
}

func ItemContext(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		itemId := chi.URLParam(r, "itemId")
		if itemId == "" {
			render.Render(w, r, ErrorRenderer(fmt.Errorf("item ID is required")))
			return
		}
		id, err := strconv.Atoi(itemId)
		if err != nil {
			render.Render(w, r, ErrorRenderer(fmt.Errorf("invalid item ID")))
		}
		ctx := context.WithValue(r.Context(), itemIDKey, id)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
```

At the top level, we specified the package name and imported the needed packages. We also declared an `itemIDKey` variable. We will later use this variable for passing the itemID URL parameter across middlewares and request handlers using Go’s context.

We have also created a chi [middleware](https://github.com/go-chi/chi/blob/master/middleware) method (`ItemContext`) to help us extract the `itemID` URL parameter from request URLs and use it in our code. The middleware checks if `itemID` exists and is valid, and goes on to add it to the request context (using the `itemIDKey` variable created earlier).

# Add a new item

To create a new bucket list, we will use chi’s [render.Bind](https://github.com/go-chi/render) to decode the request body into an instance of `models.Item` before sending it to be saved in the database. Add the code below to the end of `handler/items.go` i.e., after the `ItemContext` function:

```go
func createItem(w http.ResponseWriter, r *http.Request) {
    item := &models.Item{}
    if err := render.Bind(r, item); err != nil {
        render.Render(w, r, ErrBadRequest)
        return
    }
    if err := dbInstance.AddItem(item); err != nil {
        render.Render(w, r, ErrorRenderer(err))
        return
    }
    if err := render.Render(w, r, item); err != nil {
        render.Render(w, r, ServerErrorRenderer(err))
        return
    }
}
```

# Fetch all items

To fetch all existing items in the database, append the code below to `handler/items.go`:

```go
func getAllItems(w http.ResponseWriter, r *http.Request) {
    items, err := dbInstance.GetAllItems()
    if err != nil {
        render.Render(w, r, ServerErrorRenderer(err))
        return
    }
    if err := render.Render(w, r, items); err != nil {
        render.Render(w, r, ErrorRenderer(err))
    }
}
```

# View a specific item

Viewing a specific item means we will have to retrieve the item ID added to the request context by the `ItemContext` middleware we implemented earlier and retrieve the matching row from the database:

```go
func getItem(w http.ResponseWriter, r *http.Request) {
    itemID := r.Context().Value(itemIDKey).(int)
    item, err := dbInstance.GetItemById(itemID)
    if err != nil {
        if err == db.ErrNoMatch {
            render.Render(w, r, ErrNotFound)
        } else {
            render.Render(w, r, ErrorRenderer(err))
        }
        return
    }
    if err := render.Render(w, r, &item); err != nil {
        render.Render(w, r, ServerErrorRenderer(err))
        return
    }
}
```

Similarly, we will implement deleting and updating an existing item from the database:
```go
func deleteItem(w http.ResponseWriter, r *http.Request) {
    itemId := r.Context().Value(itemIDKey).(int)
    err := dbInstance.DeleteItem(itemId)
    if err != nil {
        if err == db.ErrNoMatch {
            render.Render(w, r, ErrNotFound)
        } else {
            render.Render(w, r, ServerErrorRenderer(err))
        }
        return
    }
}
func updateItem(w http.ResponseWriter, r *http.Request) {
    itemId := r.Context().Value(itemIDKey).(int)
    itemData := models.Item{}
    if err := render.Bind(r, &itemData); err != nil {
        render.Render(w, r, ErrBadRequest)
        return
    }
    item, err := dbInstance.UpdateItem(itemId, itemData)
    if err != nil {
        if err == db.ErrNoMatch {
            render.Render(w, r, ErrNotFound)
        } else {
            render.Render(w, r, ServerErrorRenderer(err))
        }
        return
    }
    if err := render.Render(w, r, &item); err != nil {
        render.Render(w, r, ServerErrorRenderer(err))
        return
    }
}
```

# Bringing them together in main.go

Having set up the individual components of our API, we will tie them together in the `main.go` file. Open the file and add the following code:

```go
package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/favtuts/go-chi-bucketeer-api/db"
	"github.com/favtuts/go-chi-bucketeer-api/handler"
)

func main() {
	addr := ":8080"
	listener, err := net.Listen("tcp", addr)
	if err != nil {
		log.Fatalf("Error occurred: %s", err.Error())
	}
	dbUser, dbPassword, dbName :=
		os.Getenv("POSTGRES_USER"),
		os.Getenv("POSTGRES_PASSWORD"),
		os.Getenv("POSTGRES_DB")
	database, err := db.Initialize(dbUser, dbPassword, dbName)
	if err != nil {
		log.Fatalf("Could not set up database: %v", err)
	}
	defer database.Conn.Close()

	httpHandler := handler.NewHandler(database)
	server := &http.Server{
		Handler: httpHandler,
	}
	go func() {
		server.Serve(listener)
	}()
	defer Stop(server)
	log.Printf("Started server on %s", addr)
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
	log.Println(fmt.Sprint(<-ch))
	log.Println("Stopping API server.")
}

func Stop(server *http.Server) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := server.Shutdown(ctx); err != nil {
		log.Printf("Could not shut down server correctly: %v\n", err)
		os.Exit(1)
	}
}
```

In the above, we ask the `db` package to create a new database connection using the credentials gotten from the environment variables. The connection is then passed to the handler for its use. Using `defer database.Conn.Close()`, we ensure that the database connection is kept alive while the application is running.

The API server is started on a separate [goroutine](https://tour.golang.org/concurrency/1) and keeps running until it receives a [SIGINT or SIGTERM](https://www.gnu.org/software/libc/manual/html_node/Termination-Signals.html) signal after which it calls the Stop function to clean up and shut down the server.

# Testing our API with cURL

We are now ready to test our application using docker-compose. Run the command below in a terminal to build and start up the services.
```bash
$ docker-compose up --build
```

In a separate terminal, you can run the bellow commands for DB migration first:
```bash
$ cd /home/tvt/go-projects/go-chi-bucketeer-api
$ export POSTGRESQL_URL="postgres://bucketeer:bucketeer_pass@localhost:5432/bucketeer_db?sslmode=disable"
$ migrate -database ${POSTGRESQL_URL} -path db/migrations up
1/u create_items_table (18.280697ms)
```

Then you can test out the individual endpoints using [Postman](https://postman.com/) or by running the following curl commands.

Add a new item to the bucket list:
```bash
$ curl -X POST http://localhost:8080/items -H "Content-type: application/json" -d '{ "name": "swim across the River Benue", "description": "ho ho ho"}'
```

Fetch all items currently in the list by running:
```bash
$ curl http://localhost:8080/items
```

Fetch a single item using its ID:
```bash
$ curl http://localhost:8080/items/8
```

# Development and Debuging

After making your changes, you can rebuild the server service by running the commands below
```bash
$ docker-compose stop server
$ docker-compose build server
$ docker-compose up --no-start server
$ docker-compose start server
```

To start or stop only database
```bash
$ docker-compose stop database
$ docker-compose build database
$ docker-compose up --no-start database
$ docker-compose start database
```

For more information on [how to debug Go with VS Code](https://github.com/favtuts/golang-tutorial-beginners/tree/main/go-debugging).

Install the DLV if not available
```bash
$ go install github.com/go-delve/delve/cmd/dlv@latest
```

We need to load environment variables from `.env` file by using [gotenv](https://github.com/joho/godotenv) package
```bash
$ go get github.com/joho/godotenv
```

In case of debugging the `.env` should be:
```ini
DEBUGGING=true
POSTGRES_USER=bucketeer
POSTGRES_PASSWORD=bucketeer_pass
POSTGRES_DB=bucketeer_db
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
```

In case of running docker the `.env` should be:
```ini
DEBUGGING=false
POSTGRES_USER=bucketeer
POSTGRES_PASSWORD=bucketeer_pass
POSTGRES_DB=bucketeer_db
POSTGRES_HOST=database
POSTGRES_PORT=5432
```