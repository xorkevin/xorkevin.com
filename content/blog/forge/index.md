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
Go `struct`, code generates typed Go functions with the required SQL strings.
