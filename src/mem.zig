//! Zig wrapper of libsodium's secure memory allocators.
//!
//! See docs at https://doc.libsodium.org/memory_management

const std = @import("std");
const ffi = @import("ffi.zig");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

/// Allocator using libsodium secure memory API's
pub const SecureAllocator = struct {
    pub fn init() Allocator {
        return Allocator{
            // SAFETY: context is not required
            .ptr = undefined,
            .vtable = &secure_allocator_vtable,
        };
    }

    fn getHeader(ptr: [*]u8) *[*]u8 {
        return @ptrFromInt(@intFromPtr(ptr) - @sizeOf(usize));
    }

    fn alignedAlloc(len: usize, log2_align: mem.Alignment) ?[*]u8 {
        _ = log2_align;

        const alignment = @alignOf(usize);
        const size: usize = len + alignment - 1 + @sizeOf(usize);

        // Thin wrapper around sodium_malloc, overallocate to account for
        // alignment padding and store the original malloc()'ed pointer before
        // the aligned address.
        const unaligned_ptr: [*]u8 = @ptrCast(ffi.sodium_malloc(size) orelse return null);
        const unaligned_addr = @intFromPtr(unaligned_ptr);
        const aligned_addr = std.mem.alignForward(usize, unaligned_addr + @sizeOf(usize), alignment);
        const aligned_ptr = unaligned_ptr + (aligned_addr - unaligned_addr);
        getHeader(aligned_ptr).* = unaligned_ptr;

        return aligned_ptr;
    }

    fn alignedFree(ptr: [*]u8) void {
        const unaligned_ptr = getHeader(ptr).*;
        ffi.sodium_free(unaligned_ptr);
    }

    fn alloc(_: *anyopaque, len: usize, log2_align: mem.Alignment, return_address: usize) ?[*]u8 {
        _ = return_address;
        assert(len > 0);
        return alignedAlloc(len, log2_align);
    }

    fn resize(_: *anyopaque, buf: []u8, log2_buf_align: mem.Alignment, new_len: usize, return_address: usize) bool {
        _ = log2_buf_align;
        _ = return_address;
        if (new_len <= buf.len) {
            return true;
        }
        return false;
    }

    fn free(_: *anyopaque, buf: []u8, log2_buf_align: mem.Alignment, return_address: usize) void {
        _ = log2_buf_align;
        _ = return_address;
        alignedFree(buf.ptr);
    }
};

/// Supports the Allocator interface, including alignment.
pub const secure_allocator = SecureAllocator.init();

const secure_allocator_vtable = Allocator.VTable{
    .alloc = SecureAllocator.alloc,
    .resize = SecureAllocator.resize,
    .free = SecureAllocator.free,
    .remap = Allocator.noRemap,
};

const testing = std.testing;

test "create" {
    _ = ffi.sodium_init();

    const TestStruct = struct {
        name: []const u8,
        age: u32,
    };

    const test_var = try secure_allocator.create(TestStruct);
    defer secure_allocator.destroy(test_var);

    test_var.* = .{
        .name = "Alice",
        .age = 42,
    };

    try testing.expectEqualStrings("Alice", test_var.name);
    try testing.expectEqual(42, test_var.age);
}

test "alloc" {
    _ = ffi.sodium_init();

    const count = 1;

    const buf = try secure_allocator.alloc(u8, count);
    defer secure_allocator.free(buf);

    for (0..count) |i| {
        buf[i] = @intCast(i);
    }

    try testing.expectEqual(count, buf.len);

    for (0..count) |i| {
        try testing.expectEqual(i, buf[i]);
    }
}
