---
name: 'auth-passwords'
title: 'Auth in a Nutshell: Passwords'
author: 'xorkevin'
date: 2019-05-27T15:34:21-07:00
lastmod: 2019-05-29T22:33:55-07:00
description: 'on the subject of passwords'
tags: ['auth', 'web']
projecturl: 'https://github.com/hackform/hunter2'
---

This is Part 2 of my series on how I built the authentication system in
[Governor][xorkevin:governor] and what I learned in the process. Here are links
to all sections:

[xorkevin:governor]: https://github.com/hackform/governor

* [Part 1]({{<relref "/blog/auth-crypto">}}) Auth in a Nutshell: Cryptography
* Part 2 Auth in a Nutshell: Passwords

Now that we have covered the cryptographic primitives, it is time to begin
assembling them into the useful components of an authentication system.

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
`users` table in the database. Unfortunately, storing passwords in plaintext is
a security issue that we are all too well aware of by now[^fb-password]. Users
place their trust in the website to safely store their information, and that
trust needs to be respected.

Passwords should not even be encrypted and stored in the database. First and
foremost, it does not solve the underlying problem, it just obfuscates it and
moves it up one level. The master key to all the passwords must be stored
somewhere.

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

Finally, any attacker who manages to guess the master key, or more likely
[phish it from vulnerable sources][phishing-demo], now has access to all the
passwords.

[phishing-demo]: https://www.youtube.com/watch?v=PWVN3Rq4gzw

Currently, the safest method of storing passwords is with cryptographic
password hashes, of which the details and motivations behind each step are
important to understand.

### Hashing a password

Again, a password hash is a one-way (irreversible) function. Critically, it is
also extremely slow to execute (targeting several hundred milliseconds on the
target machine). This prevents anyone&mdash;hackers, the admins, even the
user&mdash;from ever recovering the password from the hash itself in any
reasonable amount of time. If the hash is cryptographically secure, the output
will be highly random and the only way to find the original password is to try
every possible password. Assume that some attackers would like to break a 256
bit hash before the sun explodes[^sun-age], they would need a hash rate of
2\*10<sup>59</sup> Hashes/second. A hash requires at least 100ms to compute,
thus the attackers would need 2\*10<sup>52</sup> Summit
supercomputers[^summit-specs] working around the clock to meet the deadline.

[^sun-age]: Sun lifetime https://www.sciencealert.com/what-will-happen-after-the-sun-dies-planetary-nebula-solar-system
[^summit-specs]: Summit press release https://www.olcf.ornl.gov/summit/

Checking whether a password is correct is simple: hash the password, and
compare the hash to the corresponding stored password hash in the database. If
they match, the password matches, otherwise they do not. This process takes at
most several hundred milliseconds.

Unfortunately, humans are lazy users, and not all of them use
[diceware][diceware-gen] to generate passwords like "correct horse battery
staple"[^xkcd:936]. It is likely that 10% of your users will have one of [these
passwords][common passwords]. This means that naively hashing passwords will
lead to the same 25 password hashes in your database, which if ever obtained by
an attacker, would be extremely easy to identify. Attackers will also use
[rainbow tables][rainbow-table] full of passwords and their precomputed hashes.
This reduces the problem of breaking a simple password's hash into a lookup in
the table. If a rainbow table is not available, [dictionary
attacks][dictionary-attack] are also common. Naively storing hashes means that
any users with the same password have their passwords all broken at the same
time. In order to address these issues, one should salt passwords before
storage.

[^xkcd:936]: XKCD: password strength https://xkcd.com/936/
[common passwords]: https://en.wikipedia.org/wiki/List_of_the_most_common_passwords
[rainbow-table]: https://en.wikipedia.org/wiki/Rainbow_table
[dictionary-attack]: https://en.wikipedia.org/wiki/Dictionary_attack

### Salting a password

Naively storing password hashes looks like `H(x) -> hash_x`, where `H` is the
hash function. Salting a password involves concatenating some randomly
generated bytes, known as the salt, to the password prior to hashing it.
Salting looks like `H(x+salt) -> (hash_xs, salt)`, and both the hash and the
salt are stored in the database. When checking whether the user entered the
same password in the future, the salt is retrieved from the database,
concatenated in the same exact manner to the password, and the resulting hash
is compared to the stored hash. This process has the benefit of generating
different hashes for the same password input, thus resolving the previously
mentioned issues. For example, `H("hunter2"+"31415") != H("hunter2"+"27182")`.
Even though the passwords are the same, the random salts are different.

There are several rules for using salts effectively:

* Every time the user changes the password, a new salt should be generated in
  the event that the user uses the same password again.
* Salts should be *truly* random and unique. The more predictable the salt, the
  more likely it will exist in a rainbow table.
* Salts should be as long as necessary to guarantee that every single user is
  assigned a unique salt. Uuid's are typically 128 bits in size, thus it makes
  sense to make salts at least the same length.

### Storing a password

The actual format of storing a password, while not as important to security, is
important to the authentication system as a whole because it affects how easy
it is to maintain its implementation. Password hashes normally have varying
amounts of configuration as seen in:

```go
package scrypt
func Key(password, salt []byte, N, r, p, keyLen int) ([]byte, error)
```

```go
package bcrypt
func GenerateFromPassword(password []byte, cost int) ([]byte, error)
```

It may be tempting to store this configuration in some configuration file,
which can be read whenever a new user is created or authenticating a user's
password. However, this becomes increasingly more difficult to maintain over
the course of an auth system's lifetime. Computing hardware will improve,
forcing you to increase the computation cost of the password hash for newly
created passwords. A password hash may, itself, be compromised because a new
ASIC has been developed, forcing you to use an entirely different password
hashing function altogether. In these scenarios, one needs to still maintain
all past configurations in order to ensure that current user passwords and
their hashes are still valid. This would require storing, perhaps, some
password configuration version as a column in the database, which corresponds
to the correct configuration of the password hash. I think this adds too much
complexity, however.

To solve this configuration issue, I developed a library for Governor,
[hunter2][hunter2:repo], but its actual implementation is quite simple. Hunter2
exports a `Hasher` interface as follows:

[hunter2:repo]: https://github.com/hackform/hunter2

```go
package hunter2

type (
  Hasher interface {
    ID() string
    Hash(key string) (string, error)
    Verify(key string, hash string) (bool, error)
  }
)
```

Any hash may fulfill this simplified interface, which just takes in simple
strings as input and outputs hashes as strings. One of these implemented hashes is scrypt:

```go
func (h *ScryptHasher) exec(key string, salt []byte, hashLength int, c ScryptConfig) ([]byte, error) {
  return scrypt.Key([]byte(key), salt, c.workFactor, c.memBlocksize, c.parallelFactor, hashLength)
}

func (h *ScryptHasher) Hash(key string) (string, error) {
  salt := make([]byte, h.saltlen)
  if _, err := rand.Read(salt); err != nil {
    return "", err
  }
  hash, err := h.exec(key, salt, h.hashlen, h.config)
  if err != nil {
    return "", err
  }

  b := strings.Builder{}
  b.WriteString("$")
  b.WriteString(h.hashid)
  b.WriteString("$")
  b.WriteString(h.config.String())
  b.WriteString("$")
  b.WriteString(base64.RawURLEncoding.EncodeToString(salt))
  b.WriteString("$")
  b.WriteString(base64.RawURLEncoding.EncodeToString(hash))
  return b.String(), nil
}
```

As one can see, `ScryptHasher.Hash` will first generate a random salt of the
configured length. Then, it uses scrypt to generate a hash with the combined
key and salt using the specified configuration. Finally, it writes its own
hashid, configuration options, salt, and hash to a string, delimited by `$` and
returns it. This allows verifying a password to be as simple as examining the
hash output itself, reading which hasher produced the hash, using its
configuration options and salt, and checking to see if the hashes are
equivalent. No external configuration is necessary.

This strategy of storing password hash configuration in the output of the hash
came from the well written bcrypt paper[^bcrypt-paper]. This greatly reduces
complexity in updating configuration as password hash standards increase, and
has helped me simplify much of Governor's auth code.

[^bcrypt-paper]: Bcrypt paper https://www.openbsd.org/papers/bcrypt-paper.pdf

And thus ends Part 2.
