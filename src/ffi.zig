//! Foreign Function Interface (FFI) bindings for libsodium.
//!
//! This module provides direct access to the libsodium C library functions
//! and constants. It uses Zig's @cImport to automatically generate bindings
//! from the sodium.h header file.
//!
//! All libsodium functions, constants, and types are re-exported through
//! this module. Higher-level Zig wrappers should prefer using the safe
//! wrappers in other modules rather than calling these FFI functions directly.
//!
//! The libsodium library must be linked to your program for these bindings
//! to work. See the build.zig file for proper linking configuration.
//!
//! See: https://doc.libsodium.org/

pub usingnamespace @cImport({
    @cInclude("sodium.h");
});
