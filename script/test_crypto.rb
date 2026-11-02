require "openssl"
require "base64"

key = OpenSSL::PKey.generate_key("ED25519")
pub_bytes = key.raw_public_key
priv_bytes = key.raw_private_key
sig = key.sign(nil, "sample test message")

# Verify with pub key reconstructed from raw bytes
pub_key = OpenSSL::PKey.read(key.public_to_der)
valid1 = pub_key.verify(nil, sig, "sample test message")

# Also test recreating public key directly from raw bytes using new_raw_public_key
raw_pub = OpenSSL::PKey.new_raw_public_key("ED25519", pub_bytes)
valid2 = raw_pub.verify(nil, sig, "sample test message")

puts "SUCCESS: valid1=#{valid1}, valid2=#{valid2}, pub_bytes=#{pub_bytes.bytesize}, priv_bytes=#{priv_bytes.bytesize}"
