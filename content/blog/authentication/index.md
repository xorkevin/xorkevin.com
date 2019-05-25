---
name: 'authentication'
title: 'Authentication in a Nutshell'
author: 'xorkevin'
date: 2019-05-23T18:03:31-07:00
description: 'a brief look at authentication strategies'
tags: ['auth', 'web']
projecturl: ''
draft: true
---

Authentication is often one of the most complicated portions of an application
to design and write, simply due to the breadth of services that depend on it,
and the depth of features that it as a service must provide. Dependent services
often have unique requirements from the authentication service such as resource
ownership, permissions, and access control. It is important to note, that
despite this perceived importance, authentication is not inherently more
important compared to the other services that compose an application. As Linus
Torvalds famously said, "security problems are just bugs"[^torvalds:bugs].
Nevertheless, just as correctness of the OS kernel is more important than user
level applications, correctness of the authentication service is usually one of
the most important parts of an application due to its large number of
dependants.

[^torvalds:bugs]: Linus Torvalds Linux Kernel Mailing List: https://lkml.org/lkml/2017/11/17/767

It is no surprise, then, to find that many projects choose to use an OAuth
provider for application sign-in, instead of rolling their own. This makes the
sign-in process harder to implement incorrectly, but with the added cost of a
large amount of complexity in the authentication flow. However, there are many
benefits to rolling your own authentication. It gives you, the developer, full
control over your authentication flow, and reduces the number of dependencies
on external web services, improving application reliability. Unfortunately,
authentication has a large amount of moving parts, and they can be overwhelming
to understand and design and use correctly. While I am by no means a security
expert, I want to share my experiences designing the authentication system for
my Governor microservice project[^xorkevin:governor], and how it all works.

[^xorkevin:governor]: Governor project repository: https://github.com/hackform/governor
