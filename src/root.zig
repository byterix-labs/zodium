//! Zodium: A comprehensive Zig binding for the libsodium cryptographic library.
//!
//! Zodium provides safe, idiomatic Zig wrappers around libsodium's cryptographic
//! functions, including public-key cryptography, secret-key cryptography,
//! digital signatures, key derivation, and secure random number generation.
//!
//! The library focuses on providing memory-safe abstractions while maintaining
//! the performance and security guarantees of the underlying libsodium library.
//! All cryptographic operations use libsodium's battle-tested implementations.
//!
//! ## Features
//!
//! - **Public-key authenticated encryption** (crypto_box): Curve25519 + XSalsa20 + Poly1305
//! - **Cryptographically secure random number generation**: Fork-safe CSPRNG
//! - **ASCII armored key formatting**: PGP-style key encoding
//! - **Secure memory allocation**: Memory-safe allocators using libsodium's secure malloc
//! - **Memory-safe APIs**: Automatic cleanup and secure memory handling
//!
//! ## Quick Start
//!
//! ```zig
//! const zodium = @import("zodium");
//!
//! // Initialize the library (call once at program start)
//! try zodium.init();
//!
//! // Generate a key pair for public-key cryptography
//! var keypair = try zodium.crypto_box.KeyPair.create(allocator);
//! defer keypair.deinit();
//!
//! // Generate secure random data
//! var buffer: [32]u8 = undefined;
//! zodium.random.bytes(&buffer);
//! ```
//!
//! ## Safety and Security
//!
//! Zodium follows Zig's philosophy of explicit error handling and memory safety.
//! All allocations are tracked and automatically cleaned up through RAII-style
//! `deinit()` methods. Sensitive key material is securely cleared from memory
//! when possible.
//!
//! For detailed documentation of individual cryptographic primitives, see:
//! - https://doc.libsodium.org/
//! - Individual module documentation in this library
const std = @import("std");
const ffi = @import("ffi.zig");

pub const crypto_box = @import("crypto_box.zig");
pub const fmt = @import("fmt.zig");
pub const random = @import("random.zig").interface;

/// Errors that can occur during libsodium operations.
pub const SodiumErrors = error{
    /// Generic failure from libsodium functions
    Failed,
};

/// Initialize the libsodium library.
///
/// This function must be called once before using any other zodium functions.
/// It's safe to call multiple times, but only the first call has any effect.
///
/// The initialization sets up libsodium's internal state, including:
/// - Random number generator seeding
/// - CPU feature detection for optimized implementations
/// - Platform-specific security hardening
///
/// Returns:
///     `SodiumErrors.Failed` if initialization fails
///
/// Example:
/// ```zig
/// const zodium = @import("zodium");
///
/// pub fn main() !void {
///     try zodium.init();
///     // Now safe to use other zodium functions
/// }
/// ```
pub fn init() !void {
    if (ffi.sodium_init() < 0) {
        return SodiumErrors.Failed;
    }
}

/// A memory allocator that uses libsodium's secure memory allocation functions.
///
/// This allocator provides the following security benefits:
/// - Memory pages are locked in RAM (won't be swapped to disk)
/// - Memory is protected against unauthorized access
/// - Memory is automatically cleared when freed
/// - Guard pages can help detect buffer overflows
///
/// Use this allocator for storing sensitive cryptographic material like
/// private keys, passwords, or intermediate values during cryptographic
/// operations.
///
/// Example:
/// ```zig
/// const private_key = try zodium.secure_allocator.alloc(u8, 32);
/// defer zodium.secure_allocator.free(private_key);
/// // private_key memory is securely managed
/// ```
pub const secure_allocator = @import("mem.zig").secure_allocator;

// Tests for README examples
test "README quick start example" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize (required once per program)
    try init();

    // Generate a key pair
    var keypair = try crypto_box.KeyPair.create(allocator);
    defer keypair.deinit();

    // Generate random data
    var random_buffer: [32]u8 = undefined;
    random.bytes(&random_buffer);

    // Verify that we got some data (not all zeros)
    const all_zeros = std.mem.allEqual(u8, &random_buffer, 0);
    try std.testing.expect(!all_zeros);
}

test "README initialization example" {
    // This should not fail
    try init();

    // Safe to call multiple times
    try init();
    try init();
}

test "README secure memory allocation example" {
    try init();

    // Allocate sensitive data using secure allocator
    const secret = try secure_allocator.alloc(u8, 32);
    defer secure_allocator.free(secret);

    // Verify allocation worked
    try std.testing.expect(secret.len == 32);
}

test "README generateSecureToken example" {
    const generateSecureToken = struct {
        fn call(allocator: std.mem.Allocator) ![]u8 {
            try init();

            // Generate 32 bytes of secure random data
            const token = try allocator.alloc(u8, 32);
            random.bytes(token);

            return token;
        }
    }.call;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const token = try generateSecureToken(allocator);
    defer allocator.free(token);

    try std.testing.expect(token.len == 32);

    // Verify it's not all zeros
    const all_zeros = std.mem.allEqual(u8, token, 0);
    try std.testing.expect(!all_zeros);
}

test {
    std.testing.refAllDecls(@This());
}
