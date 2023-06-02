import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles
import struct

def sha1(msg):
    h = (0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0)
    l = len(msg)
    msg_pad = msg + b'\x80' + b'\0' * ((-l-9) % 64) + struct.pack('>Q', l*8)
    for chunk in struct.iter_unpack('>16L', msg_pad):
        w = list(chunk) + [0] * 64
        for i in range(16, 80):
            w[i] = w[i-3] ^ w[i-8] ^ w[i-14] ^ w[i-16]
            w[i] = (w[i] << 1 | w[i] >> 31) & 0xffffffff
        a, b, c, d, e = h
        for i in range(80):
            if i < 20:
                k, f = 0x5a827999, b & c | ~b & d
            elif i < 40:
                k, f = 0x6ed9eba1, b ^ c ^ d
            elif i < 60:
                k, f = 0x8f1bbcdc, b & c | b & d | c & d
            else:
                k, f = 0xca62c1d6, b ^ c ^ d
            a, b, c, d, e = (
                ((a << 5 | a >> 27) + f + e + k + w[i]) & 0xffffffff,
                a,
                (b << 30 | b >> 2) & 0xffffffff,
                c,
                d)
        h = tuple((u + v) & 0xffffffff for u, v in zip(h, (a, b, c, d, e)))
    return struct.pack('>5L', *h)

def hmac(key, msg):
    if len(key) > 64:
        key = sha1(key)
    key_pad = key.ljust(64, b'\0')
    key_ipad = bytes(c ^ 0x36 for c in key_pad)
    key_opad = bytes(c ^ 0x5c for c in key_pad)
    return sha1(key_opad + sha1(key_ipad + msg))

def b32decode(s):
    s = s.rstrip('=')
    l, b, v = len(s)*5//8, b'', 0
    for i, c in enumerate(s.lower() + 'a'*7):
        v = v << 5 | 'abcdefghijklmnopqrstuvwxyz234567'.index(c)
        if i % 8 == 7:
            b += struct.pack('>Q', v)[3:]
            v = 0
    return b[:l]

def hotp(seed, counter, length=6):
    key = b32decode(seed)
    msg = struct.pack('>Q', counter)
    h = hmac(key, msg)
    o = h[19] & 15
    h = (struct.unpack('>I', h[o:o+4])[0] & 0x7fffffff) % (10 ** length)
    return str(h).rjust(length, '0')

segments = [ 63, 6, 91, 79, 102, 109, 125, 7, 127, 111 ]

@cocotb.test()
async def test_totp(dut):
    dut._log.info("start")
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    seed = "TESTTEST"
    key = b32decode(seed)
    counter = 0x35918cc
    totp = hotp(seed, counter, 8)

    dut._log.info("reset")
    dut.rst_n.value = 0
    dut.data.value = 0
    dut.key_en.value = 0
    dut.msg_en.value = 0
    dut.sel.value = 0
    dut.alt_sel.value = 0
    dut.dir_sel.value = 0
    dut.hotp_rst_n.value = 0
    dut.hotp_in.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    for i in range(160):
        dut.data.value = key[i//8] >> 7-i%8 & 1 if i < 5*len(seed) else 0
        dut.key_en.value = 1
        await ClockCycles(dut.clk, 1)
    dut.key_en.value = 0

    for i in range(64):
        dut.data.value = counter >> 63-i & 1
        dut.msg_en.value = 1
        await ClockCycles(dut.clk, 1)
    dut.msg_en.value = 0

    await ClockCycles(dut.clk, 15000)

    res = ''
    for i in reversed(range(8)):
        dut.sel.value = i
        await ClockCycles(dut.clk, 10)
        res += str(int(dut.bcd.value))
        assert int(dut.segs.value) == segments[dut.bcd.value]

    assert res == totp

