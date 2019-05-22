---
name: 'governor'
title: 'Governor'
author: 'xorkevin'
date: 2018-06-25T17:08:18-07:00
description: 'microservice framework'
tags: ['microservice', 'go', 'web', 'backend']
projecturl: 'https://github.com/hackform/governor'
---

As the amount of projects I have worked on grew, I noticed that many
requirements were similar if not identical across them. Not only was rewriting
code tedious every time I needed a similar feature, but also remembering how to
back-port new implementations for existing features as I learned more about the
corresponding subjects was tedious. This often involved (and for my older
projects this is still the case) viewing diffs among various commits for the
new feature to determine how the implementation changed. The process is
bug-inducing and frustrating, as often contained within those diffs are patches
for project specific quirks and differences. This is far from ideal when the
feature in question can compromise security, such as user authentication.

As a result, solving these issues became the motivation for this project,
Governor. Governor is a framework in Go for quickly building microservices
needed for running a website with many common requirements such as user
management already implemented as services out of the box.

### Design

I knew that the code that I would write would always be destined to change as I
learned and grew as a developer. To resolve this issue, if there is one thing
my Operating Systems professor taught us, it is to make clearly defined
interfaces and to isolate services. Thus to facilitate these guaranteed future
refactors, I adopted the Unix philosophy for each of my services. Each is
highly isolated&mdash;depending only on the interfaces of other services.
Furthermore those dependencies are made explicit with constructor based
dependency injection. While this leads to a nontrivial amount of boilerplate,
the upfront cost has already helped me locate and fix many inter-service bugs
as I know clearly where one service ends and another begins.

### Features

Here is a brief summary of the most important features:

#### Message queue

Services can communicate with one another using a NATS message queue set up
with the project. The message queue is durable, backed by Postgres, to ensure
guaranteed delivery across unexpected restarts. Every message broadcasted can
be configured to be delivered to all consumers or to only a single consumer in
the case of a work queue. The message queue enables Governor to scale to
multiple nodes in order to address load and availability concerns. Furthermore,
any load spike can be easily handled through placing more jobs on the queue.

#### Storage

There are in-built wrappers around Postgres, Redis, and Minio (based on the S3
protocol) services that can be launched along with Governor. They handle
relational data, caching, and object storage respectively. I chose these
services both for their reliability and the amount of support they receive both
from their maintainers and the community. These services expose interfaces,
however, and as a result can be easily swapped out in dependent services with
alternative implementations if necessary.

To help write and maintain the SQL for relational models in Postgres, I have
also started a parallel project, Forge, intended for use with Governor though
it does not have any dependencies on Governor itself. Forge is a code
generation utility that generates SQL and functions from structs with tagged
fields. Code generating frequently changing SQL helps reduce errors due to the
lack of types.

#### Mail

An SMTP client and mail workers allow mail to be sent to any SMTP server. The
interface accepts simple strings, which allow anything to be sent. The mail
service is used frequently in the user service in cases such as password reset
and new login notifications. It leverages the message queue service so that any
caller does not have to wait for the mail to finish sending before continuing.
This also gives the mail service the benefit of having the same load handling
characteristics as mentioned before.

#### User Management and Authentication

User Management is the oldest and original service I began working on in
Governor. It takes inspiration from many of my previous projects for
organizations such as LA Hacks, UCLA ACM, and UCLA DevX, and is continuing to
grow as I add more common use cases. The user service uses JWT access and
refresh tokens to manage sessions. It also handles password hashing and reset,
permissions and roles, and many other user tasks.

### Refactoring

Refactors have occurred many times as demands changed, and better
implementations arose. Using Go for this project has enabled me to easily
adhere to interfaces and write new service implementations. Having a compiler
check simple type errors allows me to refactor with confidence, which was never
the case when I built similar previous projects in languages like Javascript on
the NodeJS platform. Thus far, I have refactored the user role engine multiple
times, and all the models as I introduced Forge into the project. These
refactors of core components were only made possible with the service oriented
architecture of Governor.
