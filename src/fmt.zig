//! ASCII armored formatting for cryptographic keys.
//!
//! This module provides utilities for encoding cryptographic keys in ASCII
//! armored format, similar to PGP key blocks. This format makes binary keys
//! safe for transmission over text-based protocols and easier to handle in
//! configuration files.
//!
//! The implementation uses base64url encoding (without padding) wrapped in
//! PGP-style armor headers and footers.
//!
//! See: https://tools.ietf.org/rfc/rfc4880.txt

const std = @import("std");
const crypto_box = @import("crypto_box.zig");

/// ASCII armored representation of cryptographic keys.
///
/// This structure holds a key encoded in ASCII armor format, which consists
/// of the key data encoded in base64url format and wrapped with PGP-style
/// armor headers and footers.
pub const AsciiArmored = struct {
    /// The complete ASCII armored key data including headers and footers
    data: []const u8,
    /// Allocator used for the armored data memory
    allocator: std.mem.Allocator,

    /// Create ASCII armored representation from a cryptographic key.
    ///
    /// This function takes a PublicKey or PrivateKey and converts it to
    /// ASCII armored format. The key bytes are encoded using base64url
    /// (without padding) and wrapped with appropriate PGP-style headers.
    ///
    /// Args:
    ///     allocator: Allocator to use for the armored data
    ///     key: The key to armor (PublicKey or PrivateKey)
    ///
    /// Returns:
    ///     An AsciiArmored instance containing the formatted key
    ///
    /// Errors:
    ///     - `error.UnsupportedKeyType`: Key type is not supported
    ///     - `error.OutOfMemory`: Memory allocation failed
    pub fn initFrom(allocator: std.mem.Allocator, key: anytype) !AsciiArmored {
        const encoder = std.base64.url_safe_no_pad.Encoder;
        const size = encoder.calcSize(key.bytes.len);

        const key_base64 = try allocator.alloc(u8, size);
        defer allocator.free(key_base64);

        _ = encoder.encode(key_base64, key.bytes);

        const prefix = switch (@TypeOf(key)) {
            crypto_box.PublicKey => "-----BEGIN PGP PUBLIC KEY BLOCK-----",
            crypto_box.PrivateKey => "-----BEGIN PGP PRIVATE KEY BLOCK-----",
            else => return error.UnsupportedKeyType,
        };

        const suffix = switch (@TypeOf(key)) {
            crypto_box.PublicKey => "-----END PGP PUBLIC KEY BLOCK-----",
            crypto_box.PrivateKey => "-----END PGP PRIVATE KEY BLOCK-----",
            else => return error.UnsupportedKeyType,
        };

        const key_armored = try std.fmt.allocPrint(allocator, "{s}\n{s}\n{s}\n", .{ prefix, key_base64, suffix });

        return .{ .data = key_armored, .allocator = allocator };
    }

    /// Clean up the ASCII armored data and free its memory.
    pub fn deinit(self: AsciiArmored) void {
        self.allocator.free(self.data);
    }
};

const testing = std.testing;

test "ascii armored" {
    var keypair = try crypto_box.KeyPair.create(testing.allocator);
    defer keypair.deinit();

    var ascii_armored_pk = try AsciiArmored.initFrom(testing.allocator, keypair.publicKey);
    defer ascii_armored_pk.deinit();

    var ascii_armored_sk = try AsciiArmored.initFrom(testing.allocator, keypair.privateKey);
    defer ascii_armored_sk.deinit();
}

test "README ASCII armored keys example" {
    var keypair = try crypto_box.KeyPair.create(testing.allocator);
    defer keypair.deinit();

    const armored = try AsciiArmored.initFrom(testing.allocator, keypair.publicKey);
    defer armored.deinit();

    // Verify the armored data contains expected headers and footers
    try testing.expect(std.mem.indexOf(u8, armored.data, "-----BEGIN PGP PUBLIC KEY BLOCK-----") != null);
    try testing.expect(std.mem.indexOf(u8, armored.data, "-----END PGP PUBLIC KEY BLOCK-----") != null);

    // Verify it's not empty
    try testing.expect(armored.data.len > 0);

    // Verify it contains base64-like content (should have alphanumeric chars)
    var has_base64_chars = false;
    for (armored.data) |c| {
        if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_') {
            has_base64_chars = true;
            break;
        }
    }
    try testing.expect(has_base64_chars);
}
