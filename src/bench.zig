const std = @import("std");
const zbench = @import("zbench");
const random = @import("random.zig");

pub fn main() !void {
    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();

    try bench.add("std.crypto.random", benchZigCrypto, .{});
    try bench.add("rb_buf (Sodium)", benchSodiumRandomBytesBuf, .{});
    try bench.add("rb_buf_deterministic (Sodium)", benchSodiumRandomBytesBufDeterministic, .{});
    // try bench.add("randombytes_buf_deterministic (Sodium)", benchSodiumRandomBytesBuf, .{});
    try bench.run(std.io.getStdOut().writer());
}

pub fn benchmarkRng(
    rng: std.Random,
) void {
    const buffer_size_bytes = 1024 * 1024; // 4MB buffer
    var buffer_bytes: [buffer_size_bytes]u8 = undefined;
    rng.bytes(&buffer_bytes); // Fill the entire buffer
}

fn benchZigCrypto(_: std.mem.Allocator) void {
    benchmarkRng(std.crypto.random);
}

fn benchSodiumRandomBytesBuf(_: std.mem.Allocator) void {
    benchmarkRng(random.interface);
}

fn benchSodiumRandomBytesBufDeterministic(_: std.mem.Allocator) void {
    const seed = [random.DeterministicCsPrng.seed_len]u8{
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
    };

    var prng = random.DeterministicCsPrng.init(seed);

    benchmarkRng(prng.random());
}
