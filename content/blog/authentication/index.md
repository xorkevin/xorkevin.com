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

#### Symmetric Encryption

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

{{<core/img src="assets/Tux.jpg">}}

Original Tux Image[^tux-plaintext]

{{<core/img src="assets/Tux_ecb.jpg">}}

Encrypted Tux Image[^tux-encrypted]

[^colossus]: https://en.wikipedia.org/wiki/Colossus_computer
[^tux-plaintext]: https://upload.wikimedia.org/wikipedia/commons/5/56/Tux.jpg
[^tux-encrypted]: https://upload.wikimedia.org/wikipedia/commons/f/f0/Tux_ecb.jpg

Modern cryptographic algorithms circumvent these issues by mimicking a one-time
pad cipher with a stream cipher. Take, for example, AES-GCM[^cipher:aesgcm],
which itself is based on the secure AES block cipher to mimick a stream cipher.
Some initial value and a counter are run through AES repeatedly while
incrementing the counter, therefore producing a pseudo random stream of bits
similar to a one-time pad. These bits are then XOR'ed with each plaintext block
to produce the cipher text. The ciphertext then goes through a system to allow
the receiver to verify the integrity of the message, which is covered in more
detail in the MAC section of Cryptographic Hash Functions, later.

{{<core/img src="assets/GCM.png">}}

AES-GCM diagram[^gcmdiagram]

[^cipher:aesgcm]: https://en.wikipedia.org/wiki/Galois/Counter_Mode
[^gcmdiagram]: https://en.wikipedia.org/wiki/File:GCM-Galois_Counter_Mode_with_IV.svg

AES-GCM is now the de facto symmetric key algorithm. With a key size of 256
bits, it currently is not known to be cryptographically vulnerable for the
foreseeable future. Unfortunately, despite its security, its implementation in
machine code is slow without a speciallized instruction set, such as
AES-NI[^aes-ni]. This also makes it potentially vulnerable to side-channel
attacks while encrypting data, such as a timing attack[^timing-attack], on
machines without AES-NI. As a result, ChaCha20-Poly1305[^chacha20] is also
gaining traction, having recently been standardized by the IETF with Google's
support. ChaCha20 and her original sister cipher salsa20 are stream ciphers,
unlike the AES block cipher, and their implementations are fast on hardware
even without speciallized instructions.

[^aes-ni]: https://en.wikipedia.org/wiki/AES_instruction_set
[^timing-attack]: https://en.wikipedia.org/wiki/Timing_attack
[^chacha20]: https://tools.ietf.org/html/rfc7539

#### Asymmetric Encryption

Also known as public key cryptography, asymmetric encryption relies on two keys
in order to send and receive data.

However, asymmetric encryption is vulnerable to quantum attacks, such as Shor's
algorithm. Symmetric ciphers are not yet known to be vulnerable, where quantum
methods have only reduced their strength by a half.

### Key Exchange Algorithm

### Cryptographic Hash Function

MAC, AEAD

#### Password Hash Function
