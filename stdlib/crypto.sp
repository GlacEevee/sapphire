# stdlib/crypto.sp — Hashing and encoding utilities

fn sha256(data)  { return Crypto.sha256(data) }
fn sha512(data)  { return Crypto.sha512(data) }
fn md5(data)     { return Crypto.md5(data) }
fn sha1(data)    { return Crypto.sha1(data) }

fn base64_encode(data)  { return Crypto.base64_encode(data) }
fn base64_decode(data)  { return Crypto.base64_decode(data) }

fn hex_encode(data)     { return Crypto.hex_encode(data) }
fn hex_decode(data)     { return Crypto.hex_decode(data) }

fn hmac(key, data)      { return Crypto.hmac_sha256(key, data) }

fn random_bytes(n)      { return Crypto.random_bytes(n) }
fn random_hex(n)        { return Crypto.random_hex(n) }
fn uuid()               { return Crypto.uuid() }

fn verify(data, hash)   { return Crypto.sha256(data) == hash }
