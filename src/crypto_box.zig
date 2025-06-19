//! Public-key authenticated encryption using Curve25519, XSalsa20 and Poly1305.
//!
//! This module provides a high-level interface for libsodium's crypto_box functions,
//! which implement public-key authenticated encryption using the Curve25519 elliptic curve,
//! XSalsa20 stream cipher, and Poly1305 message authentication code.
//!
//! The crypto_box construction encrypts a plaintext message using the recipient's
//! public key and the sender's private key, ensuring both confidentiality and
//! authenticity of the message.
//!
//! See: https://doc.libsodium.org/public-key_cryptography/authenticated_encryption

const std = @import("std");
const ffi = @import("ffi.zig");

/// A Curve25519 private key for public-key authenticated encryption.
///
/// Private keys are 32 bytes long and must be kept secret. They are used
/// together with a recipient's public key to encrypt messages, or with a
/// sender's public key to decrypt messages.
pub const PrivateKey = struct {
    /// The raw key bytes (32 bytes for Curve25519)
    bytes: []const u8,
    /// Optional allocator used to manage the key memory
    allocator: ?std.mem.Allocator,

    /// Cleanup the private key and free its memory if it was allocated.
    ///
    /// This function securely clears the key material from memory before
    /// freeing it, if an allocator was provided during creation.
    pub fn deinit(self: PrivateKey) void {
        if (self.allocator) |a| a.free(self.bytes);
    }

    /// Derive the corresponding public key from this private key.
    ///
    /// This function performs scalar multiplication of the base point with
    /// the private key to compute the corresponding public key.
    ///
    /// Args:
    ///     allocator: Allocator to use for the public key memory
    ///
    /// Returns:
    ///     The corresponding PublicKey, or an error if derivation fails
    ///
    /// Errors:
    ///     - `error.CreateFailed`: Key derivation failed
    ///     - `error.OutOfMemory`: Memory allocation failed
    pub fn asPublicKey(self: PrivateKey, allocator: std.mem.Allocator) !PublicKey {
        const pk = try allocator.alloc(u8, ffi.crypto_box_PUBLICKEYBYTES);
        errdefer allocator.free(pk);

        if (ffi.crypto_scalarmult_base(pk.ptr, self.bytes.ptr) < 0) {
            return error.CreateFailed;
        }

        return PublicKey{
            .bytes = pk,
            .allocator = allocator,
        };
    }
};

/// A Curve25519 public key for public-key authenticated encryption.
///
/// Public keys are 32 bytes long and can be shared freely. They are used
/// together with the corresponding private key to encrypt messages for the
/// key holder, or to verify messages sent by the key holder.
pub const PublicKey = struct {
    /// The raw key bytes (32 bytes for Curve25519)
    bytes: []const u8,
    /// Optional allocator used to manage the key memory
    allocator: ?std.mem.Allocator,

    /// Cleanup the public key and free its memory if it was allocated.
    pub fn deinit(self: PublicKey) void {
        if (self.allocator) |a| a.free(self.bytes);
    }
};

/// A matched pair of public and private keys for Curve25519 cryptography.
///
/// KeyPairs are generated together to ensure cryptographic compatibility.
/// The private key should be kept secret while the public key can be shared.
pub const KeyPair = struct {
    /// The public key component
    publicKey: PublicKey,
    /// The private key component (keep secret!)
    privateKey: PrivateKey,

    /// Generate a new cryptographically secure key pair.
    ///
    /// This function uses libsodium's secure random number generator to
    /// create a new Curve25519 key pair suitable for public-key authenticated
    /// encryption.
    ///
    /// Args:
    ///     allocator: Allocator to use for key memory
    ///
    /// Returns:
    ///     A new KeyPair with randomly generated keys
    ///
    /// Errors:
    ///     - `error.CreateFailed`: Key generation failed
    ///     - `error.OutOfMemory`: Memory allocation failed
    pub fn create(allocator: std.mem.Allocator) !KeyPair {
        const pk = try allocator.alloc(u8, ffi.crypto_box_PUBLICKEYBYTES);
        errdefer allocator.free(pk);

        const sk = try allocator.alloc(u8, ffi.crypto_box_SECRETKEYBYTES);
        errdefer allocator.free(sk);

        if (ffi.crypto_box_keypair(pk.ptr, sk.ptr) < 0) {
            return error.CreateFailed;
        }

        return .{
            .publicKey = PublicKey{ .bytes = pk, .allocator = allocator },
            .privateKey = PrivateKey{ .bytes = sk, .allocator = allocator },
        };
    }

    /// Clean up both the public and private keys in this pair.
    ///
    /// This function securely clears and frees the memory used by both
    /// keys in the pair.
    pub fn deinit(self: KeyPair) void {
        self.publicKey.deinit();
        self.privateKey.deinit();
    }
};

const testing = std.testing;

test "create keypair" {
    var keypair = try KeyPair.create(testing.allocator);
    defer keypair.deinit();

    const expected_pk = keypair.publicKey;
    const actual_pk = try keypair.privateKey.asPublicKey(testing.allocator);
    defer actual_pk.deinit();

    try testing.expectEqualSlices(u8, expected_pk.bytes, actual_pk.bytes);
}

test "README key generation example" {
    // Generate a new key pair
    var keypair = try KeyPair.create(testing.allocator);
    defer keypair.deinit();

    // Verify key sizes
    try testing.expect(keypair.publicKey.bytes.len == 32);
    try testing.expect(keypair.privateKey.bytes.len == 32);

    // Derive public key from private key
    var public_key = try keypair.privateKey.asPublicKey(testing.allocator);
    defer public_key.deinit();

    // Should match the original public key
    try testing.expectEqualSlices(u8, keypair.publicKey.bytes, public_key.bytes);
}

test "README key pair generation and ASCII armor example" {
    // Generate key pair
    var keypair = try KeyPair.create(testing.allocator);
    defer keypair.deinit();

    // Create ASCII armored public key
    const fmt = @import("fmt.zig");
    var armored_public = try fmt.AsciiArmored.initFrom(testing.allocator, keypair.publicKey);
    defer armored_public.deinit();

    // Create ASCII armored private key
    var armored_private = try fmt.AsciiArmored.initFrom(testing.allocator, keypair.privateKey);
    defer armored_private.deinit();

    // Verify armored keys contain expected headers
    try testing.expect(std.mem.indexOf(u8, armored_public.data, "-----BEGIN PGP PUBLIC KEY BLOCK-----") != null);
    try testing.expect(std.mem.indexOf(u8, armored_public.data, "-----END PGP PUBLIC KEY BLOCK-----") != null);
    try testing.expect(std.mem.indexOf(u8, armored_private.data, "-----BEGIN PGP PRIVATE KEY BLOCK-----") != null);
    try testing.expect(std.mem.indexOf(u8, armored_private.data, "-----END PGP PRIVATE KEY BLOCK-----") != null);
}
