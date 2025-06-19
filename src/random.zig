//! Cryptographically secure random number generation using libsodium.
//!
//! This module provides access to libsodium's cryptographically secure
//! pseudo-random number generator (CSPRNG), which is suitable for generating
//! keys, nonces, salts, and other security-critical random values.
//!
//! The underlying implementation uses the system's best available entropy
//! source and is fork-safe on Unix systems.
//!
//! See: https://doc.libsodium.org/generating_random_data

const std = @import("std");
const ffi = @import("ffi.zig");

/// Generate a single random u32.
///
/// Returns:
///     A cryptographically secure random u32 (0 to 0xffffffff inclusive)
pub fn random() u32 {
    return ffi.randombytes_random();
}

/// Generate a random number uniformly distributed between 0 and upper_bound (exclusive).
///
/// This function avoids modulo bias that can occur with naive approaches
/// like `random() % upper_bound`. It uses rejection sampling to ensure
/// perfect uniformity.
///
/// Args:
///     upper_bound: Exclusive upper bound (must be > 0)
///
/// Returns:
///     A random number in the range [0, upper_bound)
pub fn randomUniform(upper_bound: u32) u32 {
    return ffi.randombytes_uniform(upper_bound);
}

/// Fill a buffer with cryptographically secure random bytes.
///
/// This is the most common function for generating random data. It fills
/// the provided buffer with unpredictable bytes suitable for cryptographic
/// purposes.
///
/// Args:
///     buf: Buffer to fill with random bytes
pub fn randomBytes(buf: []u8) void {
    ffi.randombytes_buf(buf.ptr, buf.len);
}

/// Fill a buffer with deterministic pseudo-random bytes from a seed.
///
/// This function generates reproducible pseudo-random data from a given seed.
/// The same seed will always produce the same output. This is useful for
/// testing or when you need reproducible randomness.
///
/// Note: This function is NOT suitable for generating cryptographic keys
/// or other security-critical values in production systems.
///
/// Args:
///     buf: Buffer to fill with pseudo-random bytes
///     seed: 32-byte seed value for deterministic generation
pub fn randomBytesDeterministic(buf: []u8, seed: [ffi.randombytes_SEEDBYTES]u8) void {
    ffi.randombytes_buf_deterministic(buf.ptr, buf.len, @ptrCast(&seed));
}

/// A cryptographically secure pseudo-random number generator using libsodium.
///
/// This structure implements Zig's Random interface using libsodium's
/// secure random number generation functions. It provides access to
/// libsodium's CSPRNG through Zig's standard Random API.
pub const DefaultCsPrng = struct {
    pub fn random(self: *@This()) std.Random {
        return std.Random.init(self, fill);
    }

    /// Fill callback for the Random interface.
    ///
    /// This function is called by Zig's Random implementation to fill
    /// buffers with random data.
    ///
    /// Args:
    ///     buf: Buffer to fill with random bytes
    pub fn fill(_: *@This(), buf: []u8) void {
        randomBytes(buf);
    }
};

/// A deterministic pseudo-random number generator for testing and reproducible results.
///
/// This PRNG generates reproducible pseudo-random sequences from a seed value.
/// It implements Zig's Random interface but is NOT cryptographically secure
/// for production use.
///
/// Use this for testing scenarios where you need reproducible random sequences.
pub const DeterministicCsPrng = struct {
    /// Length of the seed in bytes (32 bytes)
    pub const seed_len = ffi.randombytes_SEEDBYTES;

    /// The seed used for deterministic generation
    seed: [seed_len]u8,

    /// Initialize a deterministic PRNG with the given seed.
    ///
    /// Args:
    ///     seed: 32-byte seed for reproducible generation
    ///
    /// Returns:
    ///     A new DeterministicCsPrng instance
    pub fn init(seed: [ffi.randombytes_SEEDBYTES]u8) DeterministicCsPrng {
        return DeterministicCsPrng{ .seed = seed };
    }

    pub fn random(self: *@This()) std.Random {
        return std.Random.init(self, fill);
    }

    /// Fill callback for the Random interface using deterministic generation.
    ///
    /// Args:
    ///     buf: Buffer to fill with deterministic pseudo-random bytes
    pub fn fill(self: *@This(), buf: []u8) void {
        randomBytesDeterministic(buf, self.seed);
    }
};

/// Global instance of the default CSPRNG
var default_prng = DefaultCsPrng{};

/// Default cryptographically secure random interface.
///
/// This provides a convenient global Random instance backed by libsodium's
/// CSPRNG. Use this for most random number generation needs.
///
/// Example:
/// ```zig
/// const random = @import("zodium").random;
/// const value = random.int(u32);
/// ```
pub const interface = default_prng.random();

const testing = std.testing;

test interface {
    var buf = std.mem.zeroes([16]u8);
    interface.bytes(&buf);

    try testing.expect(!std.mem.eql(u8, &std.mem.zeroes([16]u8), &buf));

    _ = interface.boolean();

    const rand_float = interface.float(f32);
    try testing.expect(rand_float >= 0);
    try testing.expect(rand_float <= 1.0);
}

test "README random number generation examples" {
    // Generate random bytes
    var buffer: [16]u8 = undefined;
    randomBytes(&buffer);

    // Verify not all zeros
    const all_zeros = std.mem.allEqual(u8, &buffer, 0);
    try testing.expect(!all_zeros);

    // Generate single random u32
    const u32_val = random();
    _ = u32_val; // Just verify it compiles and runs

    // Generate uniform random number in range [0, n)
    const num = randomUniform(100); // 0-99
    try testing.expect(num < 100);

    // Use with Zig's Random interface
    const int_val = interface.int(u32);
    _ = int_val; // Just verify it compiles and runs

    const float_val = interface.float(f64);
    try testing.expect(float_val >= 0.0);
    try testing.expect(float_val <= 1.0);
}

test "README random interface usage" {
    // Test the interface as shown in README
    var buffer: [16]u8 = undefined;
    interface.bytes(&buffer);

    // Verify not all zeros
    const all_zeros = std.mem.allEqual(u8, &buffer, 0);
    try testing.expect(!all_zeros);

    // Test other interface methods
    _ = interface.boolean();
    const int_val = interface.int(u32);
    _ = int_val;

    const float_val = interface.float(f64);
    try testing.expect(float_val >= 0.0);
    try testing.expect(float_val <= 1.0);
}
