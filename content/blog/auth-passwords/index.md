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
`users` table in the database. Unfortunately, that is a security issue that we
are all too well aware of by now[^fb-password]. Users place their trust in the
website to safely store their information, and that trust needs to be
respected. Passwords should not even be encrypted and stored in the database.
First and foremost, it does not solve the underlying problem, it just
obfuscates it and moves it up one level. The master key to all the passwords
must be stored somewhere.

[^fb-password]: Facebook plaintext passwords https://www.wired.com/story/facebook-passwords-plaintext-change-yours/

Second, even if the key were somehow safely stored, it would have to be
replaced every once in a while. Assume that we are using the strongest
encryption available to us, symmetric encryption, and our chosen algorithm is
the industry standard AES. AES depends on a key and a random initialization
vector which is at most 16 bytes, but more often 12 bytes for modes such as
GCM. As mentioned in Part 1, any reuse of an initialization vector with the
same key on a symmetric cipher immediately breaks the cipher. Thus it is
guaranteed that every 2<sup>96</sup> password encryptions there will be a
collision. However, this does not take into account the birthday problem, which
predicts that there more than likely be a collision in initialization vectors
after only 2<sup>48</sup> encryptions[^birthday-problem]. Thus it is
recommended not to use a key for more than 2<sup>32</sup>
encryptions[^nist:aes-rec]. This is enough to give everyone on the planet just
1 password reset.

[^birthday-problem]: Birthday problem https://en.wikipedia.org/wiki/Birthday_problem
[^nist:aes-rec]: NIST AES recommendations https://csrc.nist.gov/publications/detail/sp/800-38d/final

Finally, any attacker who manages to guess the master key, or more likely phish
it from vulnerable sources, now has access to all the passwords.

Currently, the safest method of storing passwords is with cryptographic
password hashes. I briefly mentioned this in Part 1, though I think the details
of and motivations behind each step are important to cover.

### Hashing a password

Again, a password hash is a one-way (irreversible) function. Critically, it is
also extremely slow to execute (targeting several hundred milliseconds on the
target machine). This prevents anyone&mdash;hackers, the admins, even the
user&mdash;from ever recovering the password from the hash itself in any
reasonable amount of time. If the hash is cryptographically secure, the output
will be highly random and the only way to find the original password is to try
every possible password. Assuming that the attackers would like to break the
hash before the sun explodes[^sun-age], they would need a hash rate of
2<sup>59</sup> Hashes/second. A hash requires at least 100ms to compute, thus
the attackers would need 10<sup>50</sup> Summit supercomputers[^summit-specs]
working around the clock to meet the deadline.

[^sun-age]: Sun lifetime https://www.sciencealert.com/what-will-happen-after-the-sun-dies-planetary-nebula-solar-system
[^summit-specs]: Summit press release https://www.olcf.ornl.gov/summit/

Checking whether a password is correct is simple: hash the password, and
compare the hash to the corresponding stored password hash in the database. If
they match, the password matches, otherwise they do not. This process takes at
most several hundred milliseconds.
