---
title:       "Governor"
date:        2017-03-01T00:00:00-00:00
draft:       true
name:        "Governor"
description: "microservice framework"
tags:        ["web", "microservice", "go"]
datebegin:   "March 2017"
dateend:     "Present"
projecturl:  "https://github.com/hackform/governor"
---

### Motivation

As the amount of projects I have worked on grew, I noticed that many
requirements were similar if not identical across my projects. Not only was
rewriting code tedious every time I needed a similar feature, but also
remembering how to backport new implementations for older features as I learned
more about the subject was tedious. This often involved (and for my older
projects this is still the case) viewing diffs among various commits for the
new feature. The process is bug-inducing and frustrating as often contained
within those diffs are patches for project specific quirks and differences.
This is far from ideal when the feature in question can compromise security,
such as user authentication.

As a result, solving these issues became the motivation for this project,
Governor. Governor is a framework in Go for quickly building microservices
needed for running a website with many common requirements such as user
management already implemented as services out of the box.

### Design

I knew that the code that I would write would always be destined to change as
I learned and grew as a developer. If there is one thing my Operating Systems
professor taught us, it was to make clearly defined interfaces and to isolate
services. Thus to facilitate these potential future refactors, I adopted the
Unix philosophy for each of my services. Each is highly isolated - depending
only on the interfaces of other services, and furthermore those dependencies
are made explicit with constructor based dependency injection. While this leads
to a nontrivial amount of boilerplate, the upfront cost has already helped me
locate and fix many inter-service bugs as I know clearly where one service ends
and another begins.
