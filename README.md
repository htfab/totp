![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg)

# TOTP authenticator

This repository contains a silicon implementation of the TOTP algorithm used to generate two-factor
authentication codes compatible with popular apps like Google Authenticator, Aegis, Authy, Duo, FreeOTP etc.

It is a submission to the experimental [TinyTapeout 03p5](https://github.com/TinyTapeout/tinytapeout-03p5)
shuttle using the sky130 PDK and is aggressively optimized for space with a trade-off in clock cycles,
power usage and a peculiar input format.

[TOTP](https://www.rfc-editor.org/rfc/rfc6238) is based on [HOTP](https://www.rfc-editor.org/rfc/rfc4226)
which is based on [HMAC-SHA-1](https://www.rfc-editor.org/rfc/rfc2104) which is in turn based on
[SHA-1](https://www.rfc-editor.org/rfc/rfc3174).
There was a [previous implementation](https://platform.efabless.com/projects/151) of SHA-1
by Konrad Wilk in the MPW-2 shuttle but it was not optimized for space and would take a hypothetical
4x8 slot on TinyTapeout. In contrast, this version fits a 2x2 slot while also including the
HMAC & HOTP layers and storage for the key, timestamp and result.

## Overview of TOTP

When setting up two-factor authentication the website generates a secret key and sends it to the client
(using base32 encoding). The key is stored securely both on the server and in the client's authenticator app.
Every time a one-time password needs to be generated the TOTP algorithm is called with this key and the
current UNIX timestamp as arguments, returning the same (usually 6-digit) number on the server and in the authenticator.
The server also calculates the TOTP code for slightly off timestamps to account for some time drift.

For a particular key and timestamp, the key is zero-padded to 512 bits and each byte xor'ed with 0x36.
The timestamp is divided by the code rotation interval (usually 30 seconds) and appended to this string
as a 64-bit big-endian integer. The result is passed to SHA-1 which returns an _internal hash_.
In the second iteration the same padded key is xor'ed with 0x5c but this time the previously calculated
internal hash is appended to it and another invocation of SHA-1 yields the _external hash_.
Finally this hash is shortened by using the last 4 bits to determine which consecutive 31 bits to
extract from it and the result is taken modulo 1000000 to get a 6-digit number.

## Overview of SHA-1

The _digest_ value _H_ is initialized to a 160-bit magic constant. The input string is padded to a
multiple of 512 bits in a way that includes the original length and is processed in 512-bit chunks.
For each chunk a separate mixing round is performed that updates _H_. At the end the final value
of _H_ is returned as the hash.

The mixing rounds operate with a 512-bit linear feedback shift register _W_ initialized to the current
input chunk and five 32-bit registers _A_, _B_, _C_, _D_, _E_ set to the respective parts of _H_.
On each iteration of an 80-step loop the values _A_, _B_, _C_, _D_, _E_ are updated using
bitwise Boolean operations, 32-bit additions and bit rotations acting on the registers' previous values,
the next 32 bits from the shift register _W_ and a magic constant _K_. The Boolean operations and the magic
constant are changed every 20 steps. Finally each register is added back to the appropriate 32-bit part of _H_.

## Optimizations

To save on chip space, several tricks and hacks were used:

1. The [SHA-1 specification](https://www.rfc-editor.org/rfc/rfc3174) describes both _Method 1_ in which
the array _W_ is pre-calculated and _Method 2_ where it is calculated on demand with only as much history
kept as needed to continue the sequence. This implementation uses Method 2, reducing the space required
for _W_ from 2560 to 512 bits.

2. Padding values and string concatenations are never stored but calculated on the fly and streamed
to SHA-1 directly.

3. The same space is reused for the digest _H_, the internal hash and the external hash.
This is made possible by not actually initializing _H_ to the magic constant at the beginning of the
first round but initializing _A_, _B_, _C_, _D_, _E_ directly and then adding the magic constant to them
once again at the end of the round. When calculating the external hash, we load the internal hash into
_W_ before overwriting it with the new _H_ currently stored in _A_, _B_, _C_, _D_, _E_.

4. Instead of using bitwise Boolean operations and addition on 32-bit values, they are rotated in
place and the operations are performed one bit at a time. This results in a 32 times slowdown but
also a similar space reduction in the cells responsible for bitwise logic.

5. Reading the input key and timestamp into their on-chip storage registers also uses in-place
rotations instead of a mux structure. Not only does this reduce the space occupied by cells,
mux structures can easily become routing-constrained and routing a circular buffer is much easier.

6. Rotating a buffer all the time unconditionally saves half the cells compared to only rotating it
when needed since the conditional rotation would need to be applied to each bit separately.
It also increases power consumption and requires some sync logic, but fortunately TinyTapeout
gates the clock when the design is not in use making power consumption much less of an issue and the
sync logic uses way less space than what can be saved by making most buffers rotate perpetually.

7. We delegate some of the input preprocessing to the calling side. We need to use little-endian
integers in our internal streams to make carry propagation during addition work as expected,
but base32 decoded strings are naturally big-endian. We expect the calling party to send each
32-bit chunk reversed and also to send the timestamp already divided by 30. We could easily
implement either of these, but they would push us ever so slightly over the 2x2 tiles threshold.

## How to use

Starting from the base32-encoded key as given by most websites, translate each character to a
5-bit sequence using the table below:

| char | bits  | char | bits  | char | bits  | char | bits  |
|------|-------|------|-------|------|-------|------|-------|
| A    | 00000 | I    | 01000 | Q    | 10000 | Y    | 11000 |
| B    | 00001 | J    | 01001 | R    | 10001 | Z    | 11001 |
| C    | 00010 | K    | 01010 | S    | 10010 | 2    | 11010 |
| D    | 00011 | L    | 01011 | T    | 10011 | 3    | 11011 |
| E    | 00100 | M    | 01100 | U    | 10100 | 4    | 11100 |
| F    | 00101 | N    | 01101 | V    | 10101 | 5    | 11101 |
| G    | 00110 | O    | 01110 | W    | 10110 | 6    | 11110 |
| H    | 00111 | P    | 01111 | X    | 10111 | 7    | 11111 |

e.g. `EXAMPLEKEY` &rarr; `00100 10111 00000 01100 01111 01011 00100 01010 00100 11000`

Regroup into 32-bit units and reverse each of them:

    00100101110000001100011110101100 100010100010011000(00000000000000)
    00110101111000110000001110100100 00000000000000000110010001010001

Send each bit from left to right to the `data` pin, one bit per clock cycle while simultaneously
sending a `1` bit to the `key_en` pin. (Note that the current version of the chip can process keys of
up to 160 bits. This can be changed by setting `KEY_LEN` and re-hardening.)

Next, find the current UNIX timestamp. It's a machine-friendly time format counting the number of
seconds from a universally agreed starting point, specifically midnight on 1 Jan 1970 in the UTC time zone.
There are several alternative ways to find it:

- Look it up on a website like [unixtime.org](https://unixtime.org/)
- On desktop browsers, use F12 to open the developer console and enter `Date.now()/1000`
- On unix-like machines, run the command `date +%s`, or possibly, `echo $EPOCHSECONDS`

Divide this number by 30 and discard the fractional part. Write it as a 64-bit binary number
and once again reverse the 32-bit parts.

e.g. 19:00 UTC on 5 Jun 2023 &rarr; 1685991600 &rarr; 56199720 &rarr;

    00000000000000000000000000000000 00000011010110011000101000101000
    00000000000000000000000000000000 00010100010100011001101011000000

Send each bit from left to right to the `data` pin, one bit per clock cycle while simultaneously
sending a `1` bit to the `msg_en` pin.

Wait for at least 12512 clock cycles or until a `1` value appears on the `ready` pin
for the TOTP calculation to finish. An 8-digit code is generated. Most websites only use digits 0 to 5,
but we get the other two for free.

To query a particular digit, set the `sel` pins to the digit number (0 = least significant).
The `bcd` pins output the digit value in binary while the `segs` pins can be used to drive a
7-segment display.

## Pin mapping

Input pins:

- `data` key and timestamp entry
- `key_en` pull up while sending key
- `msg_en` pull up while sending timestamp
- `sel[0]` digit selector
- `sel[1]` digit selector
- `sel[2]` digit selector
- unused
- unused

Output pins:

- `seg[0]` segment `a`
- `seg[1]` segment `b`
- `seg[2]` segment `c`
- `seg[3]` segment `d`
- `seg[4]` segment `e`
- `seg[5]` segment `f`
- `seg[6]` segment `g`
- `ready` output is valid

Bidirectional pins (used for output):

- unused
- unused
- unused
- unused
- `bcd[0]` digit value
- `bcd[1]` digit value
- `bcd[2]` digit value
- `bcd[3]` digit value

