---
name: 'auth-passwords'
title: 'Auth in a Nutshell: Passwords'
author: 'xorkevin'
date: 2019-05-27T15:34:21-07:00
description: 'on the subject of passwords'
tags: ['auth', 'web']
projecturl: ''
draft: true
---

This is Part 2 of my series on how I built the authentication system in
[Governor][xorkevin:governor] and what I learned in the process. Here is a link
to [Part 1][auth-part-1]. Now that we have covered the cryptographic
primitives, it is time to begin assembling them into the useful components of
an authentication system.

[xorkevin:governor]: https://github.com/hackform/governor
[auth-part-1]: {{<relref "/blog/auth-crypto">}}

## Creating an account

Creating a new account is the first time a user interacts with the Governor
auth engine, and that is most likely the component that you as a developer will
be creating first as well. While the creation of an account may seem to have no
impact on authentication, it is a crucial part of the auth security model.
First, the user enters their information on the frontend, and it is posted to
the following endpoint:

```json
"POST /api/u/user"
{
  "username": "<username>",
  "password": "<password>",
  "email": "<email>",
  "first_name": "<first name>",
  "last_name": "<last name>",
}
```

The backend then validates the input to ensure that it conforms to some
constraints, as it should for all requests. A web request should never be
trusted by default by the web server. A user may unintentionally enter in bogus
or incorrect information, or the HTTP request may not even be issued by your
own web frontend client and instead by some malicious actor via an arbitrary
http client. One can always assume that given enough time, an attack will
eventually occur. Validation consists of checking that:

1. All the required fields are entered. (Username, password, and email
   definitely need to be present. First and last name may vary depending on the
   use case.)
2. All the fields do not exceed a certain reasonably long length that covers
   99.9% of sanctioned use cases. A user probably did not intend to enter in a
   256 character long first or last name. (Not to mention this would give your
   web designers a big headache.)
3. The password is of an appropriate length. Aside from the most common
   passwords which allow attackers to use dictionary attacks or rainbow tables,
   password strength is almost entirely dependent on its length and the size of
   its alphabet[^diceware]. The longer the password the better. (You can try
   generating your own [here][diceware-gen].)
4. The username and email are unique. (For obvious reasons.)
5. The email is valid.

[^diceware]: password length and diceware http://world.std.com/%7Ereinhold/dicewarefaq.html
[diceware-gen]: https://www.rempe.us/diceware/#eff

In step 5, the validity of the email address is checked by sending an email to
the address with a unique random key. Assuming that the request passed checks 1
through 4, the information is put into a cache (Governor currently uses Redis
by default), with a randomly generated key and a configurable time limit before
it is erased from memory. At the same time, an email with the key is sent via
Governor's SMTP email service to the user's email address. If the user has
entered a valid email address, he or she should receive the email and complete
their sign up with the key which posts a request to:

```json
"POST /api/u/user/confirm"
{
  "key": "<confirmation key>",
}
```

It is necessary to validate the email address because email serves as the de
facto method to contact the user and handle other authentication concerns, such
as password reset and login notifications. Tying every account to a unique
validated email has the added benefit of reducing user creation spam, as any
emails that fail validation prevent the account from being created.

Once the user has confirmed that their email is valid, the account creation
process moves into its next phase.

## Passwords

One might be tempted to just put all the user's information verbatim into the
`users` table in the database.
