---
name: 'forge'
title: 'Forge'
date: 2019-05-19T16:01:01-07:00
description: 'code generation utility for governor'
tags: ['codegen', 'cli', 'go']
projecturl: 'https://github.com/hackform/forge'
draft: true
---

Forge is a cli utility I originally wrote to manage the complexity of my
database models in my Governor project. I dislike using ORM's, since they place
many constraints on the types of queries that can be written, or they make
those queries unnecessarily difficult to write with a complex API due to
language limitations. SQL itself, however, is a clear and purpose built
language for querying relational data. Thus, I chose to write all my database
queries with templated SQL strings (with sanitized input, of course).
Unfortunately, SQL strings themselves are not type checked, and adding a field
to the db model can result in having to make many parallel changes across
multiple SQL queries. Furthermore, many queries share common patterns, such as
creating the table, selecting all columns, or selecting rows of a table where a
certain column equals a value. I created Forge, in order to solve making these
repetitive changes, and rewriting the same common SQL patterns. It takes in a
Go `struct` and code generates typed Go functions with the required SQL
strings.

### Code generation

Code generation, though a new term that is gaining buzzword status, is a
relatively old concept. It fell out of favor with the web platform of the past
decade because web development was primarily dominated by dynamically typed
interpreted languages such as Ruby, Python, and JS. Though now, as the web
platform matures, so has the tooling, and code generation is beginning to make
a resurgence once more.

The interpreted languages normally make a trade-off of static type safety, for
type "freedom". As in the case of JS, one can create an object out of thin air,
and assign an arbitrary amount of fields to it. This libraries that take in
arbitrary data easy to write in these languages. For example, a Join can be
written in the JS ORM library, Sequelize, with the following code:

```js
User.hasMany(Post, {foreignKey: 'user_id'});
Post.belongsTo(User, {foreignKey: 'user_id'});
Post.findAll({ where: { ...}, include: [User]});
```

These types of API's become harder to write when using compiled and statically
typed languages, as is the case with Go. While Go does have `reflect`, an
extremely powerful tool which makes these API's possible to write, it still is
not ergonomic to use since the functions often take `interface{}` arguments.
One does know until runtime whether there is a potential type error. The
typical way to solve these issues is to use a form of code generation known as
macros. A macro adds an additional preprocessing step to the compiler pipeline
prior to the actual parsing of the source code. The macro system itself can be
as simple as the one in C/C++, or fully type safe macro system like the one in
Rust.

While Go does not have a macro system, it does have a way to generate code. It
uses a special comment directive `go:generate` to specify a command to call
when `go generate ./...` is run. For example in the following example, "Hello,
World" will be printed to the shell when `go generate` is run.

```go
package usermodel

//go:generate echo "Hello, World"
```

```go
package usermodel

//go:generate forge model -m Model -t users -p user -o model_gen.go Model Info
```
