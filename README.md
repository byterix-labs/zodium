# Zodium

A Zig binding for the libsodium cryptographic library.

## Overview

Zodium provides Zig bindings for libsodium cryptographic functions. The library offers high-level abstractions over libsodium's C API.

**Note**: This library is a work in progress. Currently implemented bindings cover basic cryptographic operations, with more being added over time.

## Features

- Public-key authenticated encryption (crypto_box)
- Random number generation
- ASCII armored key formatting
- Secure memory allocation
- Memory management with automatic cleanup
- Standard Zig error handling

## Requirements

- Zig 0.14.1 or later (managed via mise)

The libsodium library is automatically built from source using Zig's dependency system - no system installation required.

## Installation

### Using Zig Package Manager

Add to your project:

```bash
zig fetch --save git+https://github.com/byterix-labs/zodium.git
```

Then in your `build.zig`:

```zig
const zodium = b.dependency("zodium", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zodium", zodium.module("zodium"));
```

### Development Tools

This project uses [mise](https://mise.jdx.dev/) for tool management:

```bash
# Install mise if you haven't already
curl https://mise.run | sh

# Install project tools (zig, zls, pre-commit, zlint)
mise install
```

Or install tools manually:
- Zig 0.14.1
- ZLS 0.14.0  
- pre-commit (for development)
- zlint (for linting)

## Quick Start

```zig
const std = @import("std");
const zodium = @import("zodium");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize (required once per program)
    try zodium.init();

    // Generate a key pair
    var keypair = try zodium.crypto_box.KeyPair.create(allocator);
    defer keypair.deinit();

    // Generate random data
    var random_buffer: [32]u8 = undefined;
    zodium.random.bytes(&random_buffer);

    std.debug.print("Generated {} bytes of random data\n", .{random_buffer.len});
}
```

## API Reference

### Core Functions

#### Initialization

```zig
try zodium.init();
```

Initialize libsodium. Must be called once before using other functions. Safe to call multiple times.

### Public-Key Cryptography (`crypto_box`)

#### Key Generation

```zig
// Generate a new key pair
var keypair = try zodium.crypto_box.KeyPair.create(allocator);
defer keypair.deinit();

// Derive public key from private key
var public_key = try private_key.asPublicKey(allocator);
defer public_key.deinit();
```

#### ASCII Armored Keys

```zig
const armored = try zodium.fmt.AsciiArmored.initFrom(allocator, keypair.publicKey);
defer armored.deinit();

std.debug.print("Public key:\n{s}\n", .{armored.data});
```

### Random Number Generation

```zig
// Generate random bytes
var buffer: [16]u8 = undefined;
zodium.random.bytes(&buffer);

// Generate single random u32
const value = zodium.random.random();

// Generate uniform random number in range [0, n)
const num = zodium.random.randomUniform(100); // 0-99

// Use with Zig's Random interface
const value = zodium.random.int(u32);
const float_val = zodium.random.float(f64);
```

### Secure Memory Allocation

```zig
// Allocate sensitive data using secure allocator
const secret = try zodium.secure_allocator.alloc(u8, 32);
defer zodium.secure_allocator.free(secret);

// Memory is:
// - Locked in RAM (won't swap to disk)
// - Protected from unauthorized access
// - Automatically cleared when freed
```

## Benchmarks

Performance benchmarks on Apple M1 Pro (10 cores, 32GB RAM):

```
benchmark              runs     total time     time/run (avg ± σ)     (min ... max)                p75        p99        p995
-----------------------------------------------------------------------------------------------------------------------------
std.crypto.random      5942     1.939s         326.408us ± 22.573us   (312.333us ... 922.625us)    327.834us  411.708us  428.583us
rb_buf (Sodium)        814      2.012s         2.471ms ± 189.517us    (2.21ms ... 4.403ms)         2.554ms    3.118ms    3.29ms
rb_buf_deterministic ( 74       2.025s         27.373ms ± 5.082ms     (26.132ms ... 69.626ms)      26.874ms   69.626ms   69.626ms
```

Run benchmarks with `zig build bench`.

## Development

### Building

```bash
zig build
```

### Testing

```bash
zig build test
```

### Documentation

Generate HTML documentation:

```bash
zig build docs
```

Documentation will be available in `zig-out/docs/`.

### Benchmarking

```bash
zig build bench
```

### Code Formatting

```bash
zig fmt src/
```

## Examples

### Key Pair Generation and ASCII Armor

```zig
const std = @import("std");
const zodium = @import("zodium");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try zodium.init();

    // Generate key pair
    var keypair = try zodium.crypto_box.KeyPair.create(allocator);
    defer keypair.deinit();

    // Create ASCII armored public key
    var armored_public = try zodium.fmt.AsciiArmored.initFrom(allocator, keypair.publicKey);
    defer armored_public.deinit();

    // Create ASCII armored private key
    var armored_private = try zodium.fmt.AsciiArmored.initFrom(allocator, keypair.privateKey);
    defer armored_private.deinit();

    std.debug.print("Public Key:\n{s}\n", .{armored_public.data});
    std.debug.print("Private Key:\n{s}\n", .{armored_private.data});
}
```

### Secure Random Data Generation

```zig
const std = @import("std");
const zodium = @import("zodium");

pub fn generateSecureToken(allocator: std.mem.Allocator) ![]u8 {
    try zodium.init();

    // Generate 32 bytes of secure random data
    const token = try allocator.alloc(u8, 32);
    zodium.random.bytes(token);

    return token;
}
```

## Contributing

Contributions are welcome! Please ensure:

1. All tests pass: `zig build test`
2. Code is properly formatted: `zig fmt src/`
3. Documentation is updated for new features
4. Security-sensitive changes are thoroughly reviewed

## License

MIT License - see LICENSE file for details.

## Security

For security-related issues, please email security@byterix-labs.com instead of filing a public issue.

## Acknowledgments

- The libsodium team
- The Zig community
- All contributors

## Implementation Status

### Completed
- [x] `crypto_box` - Public-key authenticated encryption (Curve25519 + XSalsa20 + Poly1305)
- [x] `randombytes` - Cryptographically secure random number generation
- [x] Memory utilities - Secure memory allocation with libsodium allocators
- [x] ASCII armored key formatting - PGP-style key encoding

### TODO - Planned Bindings
- [ ] `crypto_secretbox` - Secret-key authenticated encryption
- [ ] `crypto_auth` - Message authentication (HMAC-SHA512-256)
- [ ] `crypto_hash` - Hashing (SHA-256, SHA-512)
- [ ] `crypto_sign` - Digital signatures (Ed25519)
- [ ] `crypto_kdf` - Key derivation functions
- [ ] `crypto_pwhash` - Password hashing (Argon2)
- [ ] `crypto_stream` - Stream ciphers (XSalsa20, ChaCha20)
- [ ] `crypto_aead` - Authenticated encryption with additional data
- [ ] `crypto_scalarmult` - Scalar multiplication
- [ ] `crypto_generichash` - Generic hashing (BLAKE2b)
- [ ] `crypto_shorthash` - Short-input hashing (SipHash)
- [ ] `crypto_onetimeauth` - One-time authentication (Poly1305)
- [ ] `crypto_secretstream` - Streaming AEAD
- [ ] `crypto_kx` - Key exchange
- [ ] Advanced memory utilities
- [ ] Constant-time utilities

Contributions implementing any of these bindings are welcome!

## Resources

- [libsodium Documentation](https://doc.libsodium.org/)
- [Zig Language Reference](https://ziglang.org/documentation/master/)
- [Cryptography Engineering](https://www.schneier.com/books/cryptography_engineering/) - Recommended reading