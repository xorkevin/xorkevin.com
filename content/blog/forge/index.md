---
name: 'forge'
type: 'blog'
title: 'Forge'
author: 'xorkevin'
date: 2019-05-19T16:01:01-07:00
lastmod: 2019-05-22T22:14:19-07:00
description: 'code generation utility for governor'
tags: ['codegen', 'cli', 'go']
projecturl: 'https://github.com/hackform/forge'
---

Forge is a CLI utility I originally wrote to manage the complexity of my
database models in my Governor project. I dislike using ORM's, since they place
many constraints on the types of queries that can be written, or they make
those queries unnecessarily difficult to write with a complex API due to
language limitations. SQL itself, however, is a clear and purpose built
language for querying relational data. Thus, I chose to write all my database
queries with templated SQL strings (with sanitized input, of course).
Unfortunately, SQL strings themselves are not type checked, and adding a field
to the database model can result in having to make many parallel changes across
multiple SQL queries. Furthermore, many models share common query patterns,
such as creating the table, selecting all columns, or selecting rows of a table
where a certain column equals a value. I created Forge in order to solve making
these repetitive changes, and having to rewrite the same common SQL patterns.
It takes in a Go `struct` and code generates typed Go functions with the
required SQL strings.

## Code generation

Code generation, though a term that is gaining buzzword status once again, is a
relatively old concept. It fell out of favor with the web platform of the past
decade because web development was primarily dominated by dynamically typed
interpreted languages such as Ruby, Python, and JS. Though now, as the web
platform matures, so has the tooling, and code generation is beginning to make
a resurgence once more.

The interpreted languages normally make a trade-off of static type safety, for
type "freedom". As in the case of JS, one can create an object out of thin air,
and assign an arbitrary amount of fields to it. Furthermore, these fields are
then reflectively made available to other Javascript code, allowing one to
iterate over all fields of an object. As a result, libraries that take in
arbitrary data are easy to write in these languages. For example, a Join can be
written in the JS ORM library, Sequelize, with the following code:

```js
User.hasMany(Post, {foreignKey: 'user_id'});
Post.belongsTo(User, {foreignKey: 'user_id'});
Post.findAll({ where: { ...}, include: [User]});
```

These types of API's become harder to write when using compiled and statically
typed languages. While generics can solve some issues, they cannot solve all of
them, such as serialization of a struct. The typical way to solve these
problems is to use a form of code generation known as macros. A macro adds an
additional preprocessing step to the compiler pipeline prior to the actual
parsing of the source code. The macro system itself can be as simple as the one
in C/C++, or fully type safe macro system like the one in Rust. For example,
Rust's serde package uses a `derive` macro to generate a serialization function
for a struct:

```rs
//main.rs
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize, Debug)]
struct Point {
    x: i32,
    y: i32,
}
```

## Go generate

For languages like Go (which Governor is written in) with less powerful
metaprogramming, code generation becomes the next best solution. While Go does
have `reflect`, an extremely powerful tool which makes these API's possible to
write, it still is not ergonomic to use since the functions often take
`interface{}` arguments. One does know until runtime whether there is a
potential type error. Thus one loses out on the benefits of having the Go
compiler statically check whether you have called these functions with the
correct types, placing the burden of type checking on the programmer.
Fortunately, Go's code generation is easily invoked. It uses a special comment
directive `go:generate` to specify a command to call when `$ go generate ./...`
is run from the terminal. For example, in the following code, "Hello, World"
will be printed to the shell on running `go generate`.

```go
//main.go
package main
//go:generate echo "Hello, World"
```

```bash
#bash
$ go generate ./...
Hello, World
```

Go uses its `go generate` system to provide a method to generate code. It
provides the command to be run with the `$GOPACKAGE` and `$GOFILE` environment
variables set to the file's package name and filename respectively, in addition
to some other information. Forge uses this information along with the struct
definition in the file itself to generate database model functions. Take the
following code from Governor's user model:

```go
//model.go
package usermodel

import (
  //imports
)

//go:generate forge model -m Model -t users -p user -o model_gen.go Model Info

type (
  Model struct {
    Userid       string `model:"userid,VARCHAR(31) PRIMARY KEY" query:"userid"`
    Username     string `model:"username,VARCHAR(255) NOT NULL UNIQUE" query:"username,get"`
    AuthTags     string
    PassHash     string `model:"pass_hash,VARCHAR(255) NOT NULL" query:"pass_hash"`
    Email        string `model:"email,VARCHAR(255) NOT NULL UNIQUE" query:"email,get"`
    FirstName    string `model:"first_name,VARCHAR(255) NOT NULL" query:"first_name"`
    LastName     string `model:"last_name,VARCHAR(255) NOT NULL" query:"last_name"`
    CreationTime int64  `model:"creation_time,BIGINT NOT NULL" query:"creation_time"`
  }
)
```

Forge uses the `go/ast` package to parse the file `$GOFILE` and look for the
`-m <Model>` struct. It then uses the struct tags to generate the appropriate
model functions as seen below:

```go
//model_gen.go
// Code generated by go generate. DO NOT EDIT.
package usermodel

import (
  "database/sql"
  "github.com/lib/pq"
  "strconv"
  "strings"
)

const (
  userModelTableName = "users"
)

func userModelSetup(db *sql.DB) error {
  _, err := db.Exec("CREATE TABLE IF NOT EXISTS users (userid VARCHAR(31) PRIMARY KEY, username VARCHAR(255) NOT NULL UNIQUE, pass_hash VARCHAR(255) NOT NULL, email VARCHAR(255) NOT NULL UNIQUE, first_name VARCHAR(255) NOT NULL, last_name VARCHAR(255) NOT NULL, creation_time BIGINT NOT NULL);")
  return err
}

func userModelGet(db *sql.DB, key string) (*Model, int, error) {
  m := &Model{}
  if err := db.QueryRow("SELECT userid, username, pass_hash, email, first_name, last_name, creation_time FROM users WHERE userid = $1;", key).Scan(&m.Userid, &m.Username, &m.PassHash, &m.Email, &m.FirstName, &m.LastName, &m.CreationTime); err != nil {
    if err == sql.ErrNoRows {
      return nil, 2, err
    }
    return nil, 0, err
  }
  return m, 0, nil
}
...
```

Forge has been immensely beneficial in making maintaining Governor's models
more bug free. Having Forge allows the model `struct` to be the single source
of truth. I plan to add to Forge the ability to code generate route JSON body
validation, in addition to other repetitive code, in the future.
