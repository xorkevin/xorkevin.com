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

[^torvalds:bugs]: https://lkml.org/lkml/2017/11/17/767

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

[^xorkevin:governor]: https://github.com/hackform/governor

### Cryptography in a smaller nutshell

First, it's important to understand the differences among cryptographic
algorithms and the wide array of terminology used, so that it is clear what to
use in certain situations.

### Encryption

Encryption algorithms take a key and some plaintext data, to produce ciphertext
data. The plaintext data is encoded in the ciphertext, but only those with
knowledge of the key are able to decrypt the ciphertext and reproduce the
original plaintext. It is important to note that encryption, as an algorithm,
is designed to be reversible (for those with knowledge of the key). Modern
encryption algorithms do not rely on "security through obscurity", i.e. their
designs are public, and their security does not rely on keeping their
implementations a secret. Encryption algorithms are instead secure due to the
immense size of their key space. With most keys at about 256 bits in size
(known as 256 bit security), breaking a secure encryption algorithm would, on
average, require attempting 2<sup>255</sup> key guesses, which would take most
state level actors years, even with optimizations, to brute force.

### Symmetric Encryption

Symmetric encryption, as its name implies, uses the same key for encryption as
it does for decryption. The most secure encryption algorithm, symmetric or
otherwise, is a one-time pad cipher[^cipher:otp]. It is also extremely simple
to implement:

1. generate a list of *truly* random bits longer than the plaintext input
   string, called the "key"
2. XOR the plaintext with the key, to produce the ciphertext
3. decrypt the ciphertext by XORing it with the key to produce the plaintext
4. discard the key after it has been used, and do not reuse it for any future
   communication

One-time pads are symmetric encryption (since they share the same key to
encrypt and decrypt), and they are invulnerable to all cryptanalysis due to the
equal distribution between 1's and 0's of the XOR function and the key, i.e.
from a potential attacker's perspective, literally any string with a length
less than or equal to the ciphertext could have been the plaintext. It is
important to remember step 4, however. Key reuse can lead to a situation where
an attacker can XOR two ciphertexts to remove the key, since `(plaintext1 XOR
key) XOR (plaintext2 XOR key) = (plaintext1 XOR plaintext2)`. This would allow
the resulting string to be decrypted via frequency analysis and similar tools,
without the attacker needing to know the key.

[^cipher:otp]: https://en.wikipedia.org/wiki/One-time_pad

One-time pads have a downside however: the key must be at least as long as the
plaintext. This makes encrypting files that are on the order of megabytes in
size impractical, since the key must be millions of bits long. There are other
symmetric encryption algorithms, however, which can be broadly categorized into
stream and block ciphers. Their names suggest, correctly, that stream ciphers
encrypt plaintext on a character by character level (e.g. the Lorenz
cipher[^cipher:lorenz] used in WWII), while block ciphers encrypt entire
"blocks" of data (which may vary in size) independently (e.g.
AES[^cipher:aes]).

[^cipher:lorenz]: https://en.wikipedia.org/wiki/Lorenz_cipher
[^cipher:aes]: https://en.wikipedia.org/wiki/Advanced_Encryption_Standard

Unfortunately, both of these types of algorithms, in their earliest forms, had
their own glaring weaknesses. Simple stream ciphers, operating at a character
level, were often weak to cryptanalysis. Provided enough ciphertext, an
attacker may be able to guess what the key and the state of the encryption
machine is, which British cryptographers at Bletchley Park were able to do to
the Lorenz cipher with the aid of Colossus[^colossus]. Simple block ciphers,
while they strongly encrypt messages that are under a block in size, suffer
from potentially outputting the same ciphertext block for the same plaintext
block within the same message, since they encrypt blocks of data independently.
Using the following images as an example, one can see that regions of the image
with the same color encrypt to the same ciphertext in a naively applied block
cipher. This is, by definition, weak to frequency analysis.

<div class="contentrow inset">
{{<core/img src="assets/Tux.jpg">}}
{{<core/img src="assets/Tux_ecb.jpg">}}
</div>

{{<core/caption cap="Left: [Original Tux Image](https://upload.wikimedia.org/wikipedia/commons/5/56/Tux.jpg), Right: [Encrypted Tux Image](https://upload.wikimedia.org/wikipedia/commons/f/f0/Tux_ecb.jpg)">}}

[^colossus]: https://en.wikipedia.org/wiki/Colossus_computer

Modern cryptographic algorithms circumvent these issues by mimicking a one-time
pad cipher with a stream cipher. Take, for example, AES-GCM[^cipher:aesgcm],
which itself is based on the secure AES block cipher to mimick a stream cipher.
Some initial value, key, and counter are run through AES repeatedly while
incrementing the counter, therefore producing a pseudorandom stream of bits
similar to a one-time pad. These bits are then XOR'ed with each plaintext block
to produce the cipher text. The ciphertext then goes through a system to allow
the receiver to verify the integrity of the message, which is covered in more
detail in the MAC section of Cryptographic Hash Functions, later.

{{<core/img class="inset" src="assets/GCM.png">}}

{{<core/caption cap="[Advanced Encryption Standard - Galois Counter Mode](https://en.wikipedia.org/wiki/File:GCM-Galois_Counter_Mode_with_IV.svg)">}}

[^cipher:aesgcm]: https://en.wikipedia.org/wiki/Galois/Counter_Mode

AES-GCM is now the de facto symmetric key algorithm. With a key size of 256
bits, it currently is not known to be cryptographically vulnerable for the
foreseeable future. Unfortunately, despite its security, its implementation in
machine code is slow without a specialized instruction set, such as
AES-NI[^aes-ni]. This also makes it potentially vulnerable to side-channel
attacks while encrypting data, such as a timing attack[^timing-attack], on
machines without a specialized instruction set. As a result,
ChaCha20-Poly1305[^chacha20] is also gaining traction, having recently been
standardized by the IETF with Google's support. ChaCha20 and her original
sister cipher Salsa20 are stream ciphers, unlike the AES block cipher, and
their implementations are *consistently* fast on hardware even without
specialized instructions.

[^aes-ni]: https://en.wikipedia.org/wiki/AES_instruction_set
[^timing-attack]: https://en.wikipedia.org/wiki/Timing_attack
[^chacha20]: https://tools.ietf.org/html/rfc7539

Nevertheless, symmetric encryption algorithms offer many benefits. They are,
compared to other encryption algorithms, relatively fast to execute due to
their design; an indefinitely long pseudorandom string of bits may be
efficiently generated to encrypt arbitrarily large files. Symmetric encryption
algorithms are also quantum resistant. Using Grover's algorithm[^grover-alg],
the security of a symmetric cipher such as AES or ChaCha20 only quadratically
decreases with a quantum computer, i.e. AES-256 would only have 128 bits of
security instead of 256. These issues can be easily resolved by doubling the
key size.

[^grover-alg]: https://en.wikipedia.org/wiki/Grover%27s_algorithm

The only major downside to symmetric encryption is that both communicating
parties must know the key. When it is impossible for these parties to
physically meet, this can lead to a chicken and egg problem, i.e. there is no
secure means to send the secret key to the other party since no shared secret
key has been shared. The two main approaches to deal with this issue are key
exchange, discussed in its own later section, and asymmetric encryption.

### Asymmetric Encryption

Also known as public key cryptography, asymmetric encryption relies on two
separate keys in order to send and receive data. One of these is called the
"public" key, and the other, the "private" key. These two keys form what is
known as a "key pair". A sender may securely send information to a designated
receiver by using an asymmetric encryption algorithm along with the receiver's
public key to generate the ciphertext. It is important to note that the public
key is, in fact, public knowledge. Only the receiver, who knows what the secret
key is, may decrypt the ciphertext to obtain the original plaintext. Asymmetric
encryption has the added benefit over symmetric encryption that one does not
need to generate a new key for every new party one wants to communicate with.
With symmetric encryption, sharing the same key could lead to every party with
the shared key decrypting each other's messages. In asymmetric encryption,
different keys are used for encrypting and decrypting messages, thus the
encrypting "public" key can be shared amongst everyone.

The first asymmetric cryptographic encryption algorithm was discovered by the
British GCHQ, who classified it as top-secret to prevent it from being used by
others. Much to their surprise, the algorithm was independently rediscovered by
Rivest, Shamir, and Adleman based off the work of Diffie and Hellman[^rsa]. Now
known as RSA, the algorithm works by exploiting Euler's totient function, which
is easy to calculate for a number if one knows its prime factorization, and
difficult otherwise. This property of the totient function, makes it a trapdoor
function, a function that computationally difficult, unless one knows special
information, in this case the prime factorization. RSA chooses a semiprime
number for this, because semiprime numbers are the most difficult to factor for
their size. RSA is presently secure, because factoring is an NP problem.

[^rsa]: [https://en.wikipedia.org/wiki/RSA\_(cryptosystem)](https://en.wikipedia.org/wiki/RSA_(cryptosystem))

It seems then that asymmetric encryption should always be used, however it has
some caveats. RSA itself is computationally expensive compared to a strong
symmetric encryption algorithm such as AES. Encrypting a file on the order of
megabytes in size would take far longer than AES. Furthermore, since RSA uses
prime numbers, the frequency of prime numbers affect the number of bits of
entropy within an RSA key, i.e. unlike in AES, not all 2<sup>N</sup> possible
keys are valid, because not all are semiprime. As a result, RSA needs a 15360
bit key to have approximately the same strength as AES-256. RSA itself is also
completely vulnerable to quantum attacks using Shor's algorithm[^shor-alg] to
factor numbers in polynomial time. Unlike with AES, where the key size can be
increased, there is no remedy for this type of attack.

[^shor-alg]: https://en.wikipedia.org/wiki/Shor%27s_algorithm

Fortunately, while RSA has been the mainstay of public key cryptography, some
of these issues are being addressed by other asymmetric encryption algorithms.
Elliptic curve cryptography has become more popular, in recent years. ECC is
based on the difficulty of the more general discrete logarithm problem. ECC
maps an elliptic curve onto a finite (Galois) field, where the operations of
multiplication and addition are redefined. Because ECC does not rely on prime
numbers, it has much smaller key sizes. An ECC key of 521 bits is approximately
equal in strength to AES-256. Unfortunately, again, ECC is vulnerable to
quantum attacks via Shor's algorithm. As a result, new systems such as
lattice-based cryptography[^lattice-crypto] are currently being developed, which have not yet
been found to have a quantum weakness.

[^lattice-crypto]: https://en.wikipedia.org/wiki/Lattice-based_cryptography

Asymmetric and symmetric cryptography also do not have to be used mutually
exclusively. Software such as GPG can symmetrically encrypt a large file, e.g.
with AES, then encrypt the symmetric key with an asymmetric algorithm, e.g.
with RSA. While the strength of the encryption will only be as strong as the
weaker of the two keys (most likely RSA), this allows the sending of data
without having to physically meet and share a secret key.

Public key cryptography has other interesting applications such as signing
content with the private key that can be verified with the public key, but this
is discussed in the later section of signing algorithms.

### Key Exchange Algorithm

### Hash Function

### Password Hash Function

### Signing Data

MAC, AEAD, RSA ECC Signing
