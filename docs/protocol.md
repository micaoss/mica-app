# Mica BLE management protocol, version 1

The contract between mica-app (the phone) and `mica-bled` (the device). It carries mica-apid
requests for the device's network settings over Bluetooth Low Energy, after both ends have proved
they share a secret: the device's Bluetooth PIN, or a credential the device issued to this phone.

The phone is party **A** of SPAKE2, the device is party **B**. "MUST" and friends are used in the
sense of RFC 2119.

## 1. Advertising and GATT

The device advertises, connectable, the service UUID below and its name (`bluetooth.alias`, or the
hostname) in the scan response.

| item | UUID | properties |
|------|------|------------|
| service | `ab725d4b-fef6-4311-99ec-a26c3139fc13` | primary |
| `rx` (phone to device) | `95468405-fe96-45be-9ea0-769fc0e27237` | write, write without response |
| `tx` (device to phone) | `29358014-0d71-4c66-9a54-49c3943742ea` | notify |

The phone requests the largest MTU it can and writes chunks of at most `MTU - 3` bytes. The
device notifies chunks of at most `MTU - 3` bytes. One connection carries one session; the device
serves one connection at a time and refuses a second.

## 2. Framing

Each direction is a byte stream cut into chunks at arbitrary points. A **message** on the stream
is a 4-byte big-endian length followed by that many bytes. The length MUST be at least 1 and at
most 65536; a peer that sees anything else closes the connection.

Before the session is established the message bytes are UTF-8 JSON. After it, they are sealed
(section 5) and the plaintext is UTF-8 JSON.

## 3. Hello

```
A -> B  {"t":"hello","v":1}
B -> A  {"t":"hello","v":1,"device":"<device id>","name":"<name>","pinSet":true}
```

- `device` is micad's device id (lowercase hex). It is SPAKE2's identity B.
- `pinSet` is false while the PIN is `000000` (section 6).
- A device that does not speak `v` answers `{"t":"error","code":"bad-version"}` and closes.

## 4. Authentication: SPAKE2

Ciphersuite **SPAKE2-P256-SHA256-HKDF-HMAC** of RFC 9382, with its M and N for P-256, uncompressed
SEC1 points, and AAD `mica-ble/1`.

Two kinds of secret:

| kind | identity A | secret |
|------|------------|--------|
| `pin` | `pin` | the PIN, six ASCII digits |
| `phone` | `phone:<phone id>` | the 32-byte credential issued at enrollment (section 7) |

The password scalar:

```
w = OS2IP(SHA-512(len(label) || label || len(B) || B || len(secret) || secret)) mod n
label = "mica-ble/1 w"
```

`len()` is the 8-byte little-endian length of RFC 9382, `B` is the device id, `n` is the order of
P-256. The 512-bit hash leaves no usable bias after the reduction.

Flow:

```
A -> B  {"t":"auth","kind":"pin","pA":"<base64 pA>"}
        {"t":"auth","kind":"phone","phone":"<phone id>","pA":"<base64 pA>"}
B -> A  {"t":"auth","pB":"<base64 pB>"}
A -> B  {"t":"confirm","cA":"<base64 cA>"}
B -> A  {"t":"confirm","cB":"<base64 cB>","scope":"full"}
```

- Each side MUST check that the peer's point is 65 bytes, starts with `0x04`, has coordinates below
  the field prime and lies on the curve. Anything else is `bad-request` and closes the connection.
- x and y are fresh for every attempt and never reused.
- B checks cA before sending cB. A wrong cA is `auth-failed`; B sends no cB.
- A checks cB. A wrong cB means the peer is not the device it claims; A closes and MUST NOT send
  anything sealed.
- `scope` is `full`, or `pin-change` while the PIN is unset (section 6).
- base64 is the standard alphabet with padding.

Failed attempts: the device counts consecutive failures across all connections and kinds and,
after the n-th, refuses the next attempt for `min(2^(n-1), 300)` seconds, apid's login curve.
A refused attempt is `{"t":"error","code":"backoff","retryAfter":<seconds>}`. A success resets the
count. An unknown phone id is `auth-failed` and counts as a failure.

## 5. Session

From SPAKE2's Ke (16 bytes):

```
kA = HKDF-SHA256(ikm = Ke, salt = nil, info = "mica-ble/1 phone->device", L = 32)
kB = HKDF-SHA256(ikm = Ke, salt = nil, info = "mica-ble/1 device->phone", L = 32)
```

Every message after `confirm` is ChaCha20-Poly1305 (RFC 8439) with the sender's key, nonce
`0x00000000 || counter` (8-byte big-endian), and no associated data. The counter starts at 0 in
each direction and increases by one per message. A message that fails to open closes the
connection; there is no resynchronisation.

## 6. The PIN

- The PIN is `bluetooth.pin` in the device's settings: six ASCII digits.
- The default is `000000`. While the PIN is `000000` it is **unset**: a `pin` session gets scope
  `pin-change`, in which the device answers only `PUT /ble/pin` and refuses everything else with
  403 `pin-unset`. After a successful `PUT /ble/pin` the session's scope becomes `full`.
- `PUT /ble/pin` refuses `000000` and anything that is not six digits with 400 `bad-pin`.
- Changing the PIN does not end sessions or revoke phone credentials.

## 7. Requests

Inside the session the phone sends requests and the device answers each one:

```
A -> B  {"t":"req","id":7,"method":"GET","path":"/v1/network/status"}
A -> B  {"t":"req","id":8,"method":"PUT","path":"/v1/wifi/client","body":{...}}
B -> A  {"t":"res","id":7,"status":200,"body":{...}}
```

`id` is chosen by the phone and echoed. `body` is any JSON value and is omitted when empty. The
device answers in any order.

### 7.1 Forwarded to mica-apid

The device forwards these, and only these, to mica-apid on the device and returns apid's status and
JSON body unchanged. Anything else is 403 `not-allowed`.

| method | path |
|--------|------|
| GET | `/v1/system/info` |
| GET | `/v1/network/status` |
| GET, PUT | `/v1/network` |
| PUT, DELETE | `/v1/network/{iface}` |
| GET, PUT | `/v1/wifi/client` |
| GET, POST | `/v1/wifi/client/networks` |
| PUT, DELETE | `/v1/wifi/client/networks/{ssid}` |
| POST | `/v1/wifi/client/scan` |
| GET, PUT | `/v1/wifi/ap` |

### 7.2 Answered by the device itself

| method | path | body | answer |
|--------|------|------|--------|
| PUT | `/ble/pin` | `{"pin":"123456"}` | 204 |
| POST | `/ble/phones` | `{"name":"<phone model>"}` | 201 `{"phone":"<id>","secret":"<base64, 32 bytes>"}` |
| GET | `/ble/phones` | | 200 `[{"phone":"<id>","name":"..","created":<unix s>,"current":true}]` |
| DELETE | `/ble/phones/{id}` | | 204 |

A phone enrolls once, after its first `pin` session, and stores `phone` and `secret` in its
keystore; later connections authenticate with kind `phone`. Deleting a phone's credential ends that
phone's open session.

### 7.3 Errors

Before the session: `{"t":"error","code":"<code>","message":"<text>"}`, then the device closes,
except for `backoff`, after which the phone may try again on the same connection.

Inside the session: a `res` with a 4xx or 5xx status and body `{"code":"<code>","message":"<text>"}`.

| code | meaning |
|------|---------|
| `bad-version` | protocol version not spoken |
| `bad-request` | malformed message or point |
| `auth-failed` | wrong PIN, unknown phone or wrong credential |
| `backoff` | too many failures; `retryAfter` seconds |
| `busy` | another phone is connected |
| `pin-unset` | the PIN is still `000000`; only `PUT /ble/pin` is answered |
| `bad-pin` | the new PIN is not six digits, or is `000000` |
| `not-allowed` | the path is not on the list in 7.1 or 7.2 |

## 8. Test vectors

The SPAKE2 core is checked against RFC 9382 appendix B. The protocol's own derivations (w,
session keys, a sealed message) are in `test/protocol/vectors.json`; `mica-bled` checks the same
file.
