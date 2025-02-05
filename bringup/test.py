from ttboard.demoboard import DemoBoard, Pins
import time
import struct

# set the secret seed here
seed = "TESTTEST"

# timezone correction in case micropython's time.gmtime() is not in UTC
timestamp_offset = -3600

# use a fixed unix timestamp for debugging (set to nonzero)
timestamp_override = 0

tt = DemoBoard()

tt.clock_project_stop()
tt.shuttle.tt_um_htfab_totp.enable()
for i in range(4, 8):
    tt.bidirs[i].mode = Pins.IN
tt.reset_project(True)
tt.clock_project_once()
tt.reset_project(False)

# utility function to read/write integer values to a group of pins
def multibit(bits):
    def call(value=None):
        if value is None:
            value = 0
            for bit in reversed(bits):
                value <<= 1
                value |= bit()
            return value
        else:
            for bit in bits:
                bit(value & 1)
                value >>= 1
    return call
   
# set pin aliases
data = tt.inputs[0]
key_en = tt.inputs[1]
msg_en = tt.inputs[2]
sel = multibit([tt.inputs[i] for i in range(3, 6)])
segs = multibit([tt.outputs[i] for i in range(7)])
ready = tt.outputs[7]
bcd = multibit([tt.bidirs[i] for i in range(4, 8)])

# prepare key
seed_padded = (seed + 32*'A')[:32]
base32_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
key_bits = []
for char in seed_padded:
    value = base32_chars.index(char.upper())
    for i in range(5):
        key_bits.append((value >> 4) & 1)
        value <<= 1
for i in range(5):
    key_bits[i*32:(i+1)*32] = list(reversed(key_bits[i*32:(i+1)*32]))

# send key
for bit in key_bits:
    data(bit)
    key_en(1)
    tt.clock_project_once()
key_en(0)

# prepare timestamp
timestamp = time.time() + timestamp_offset
if timestamp_override:
    timestamp = timestamp_override
counter = timestamp // 30
msg_bits = [0] * 32
for i in range(32):
    msg_bits.append(counter & 1)
    counter >>= 1

# send timestamp
for bit in msg_bits:
    data(bit)
    msg_en(1)
    tt.clock_project_once()
msg_en(0)

# wait for calculation to complete
tt.clock_project_PWM(1e6)
time.sleep_ms(50)
tt.clock_project_stop()
assert ready()

# get reply
res = ""
for i in reversed(range(6)):
    sel(i)
    tt.clock_project_once()
    res += str(int(bcd()))

# print output
time_str = "{:04d}-{:02d}-{:02d} {:02d}:{:02d}:{:02d} UTC".format(*time.gmtime(timestamp))
print(f"{time_str} => {res}")
