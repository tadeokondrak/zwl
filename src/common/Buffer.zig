const std = @import("std");
const RingBuffer = @import("ring_buffer.zig").RingBuffer;
const Message = @import("Message.zig");
const fd_t = std.os.fd_t;

const Buffer = @This();

pub const Error = error{BufferFull};

bytes: RingBuffer(u8, 4096),
fds: RingBuffer(fd_t, 512),

pub fn init() Buffer {
    return .{
        .bytes = RingBuffer(u8, 4096).init(),
        .fds = RingBuffer(fd_t, 512).init(),
    };
}

pub fn getMessage(buf: *Buffer) ?Message {
    if (buf.bytes.readableLength() < 8)
        return null;

    const id = @bitCast(u32, [4]u8{
        buf.bytes.data[buf.bytes.tail +% 0],
        buf.bytes.data[buf.bytes.tail +% 1],
        buf.bytes.data[buf.bytes.tail +% 2],
        buf.bytes.data[buf.bytes.tail +% 3],
    });

    const op_len = @bitCast(u32, [4]u8{
        buf.bytes.data[buf.bytes.tail +% 4],
        buf.bytes.data[buf.bytes.tail +% 5],
        buf.bytes.data[buf.bytes.tail +% 6],
        buf.bytes.data[buf.bytes.tail +% 7],
    });

    const op = @intCast(u16, op_len & 0xffff);
    const len = @intCast(u12, op_len >> 16);

    if (buf.bytes.readableLength() < len)
        return null;

    buf.bytes.ensureContiguous(len);

    const data = buf.bytes.readableSlices()[0][8..len];
    buf.bytes.tail +%= len;

    return Message{
        .id = id,
        .op = op,
        .data = data,
    };
}

pub fn putInt(buf: *Buffer, int: i32) Error!void {
    try buf.bytes.appendSlice(std.mem.asBytes(&int));
}

pub fn putUInt(buf: *Buffer, uint: u32) Error!void {
    try buf.putInt(@bitCast(i32, uint));
}

pub fn putFixed(buf: *Buffer, fixed: f64) Error!void {
    try buf.putInt(@floatToInt(i32, fixed * 256));
}

pub fn putString(buf: *Buffer, string: ?[]const u8) Error!void {
    if (string) |_string| {
        const len = @intCast(u32, _string.len) + 1;
        const padded = (len + 3) / 4 * 4;
        const zeroes = [4]u8{ 0, 0, 0, 0 };
        try buf.putUInt(len);
        try buf.bytes.appendSlice(_string);
        try buf.bytes.appendSlice(zeroes[0 .. padded - len + 1]);
    } else {
        try buf.putUInt(0);
    }
}

pub fn putArray(buf: *Buffer, array: ?[]const u8) Error!void {
    if (array) |_array| {
        const len = @intCast(u32, _array.len);
        const padded = (len + 3) / 4 * 4;
        const zeroes = [4]u8{ 0, 0, 0, 0 };
        try buf.putUInt(len);
        try buf.bytes.appendSlice(_array);
        try buf.bytes.appendSlice(zeroes[0 .. padded - len]);
    } else {
        try buf.putUInt(0);
    }
}

pub fn putFd(buf: *Buffer, fd: fd_t) Error!void {
    try buf.fds.append(fd);
}

test "Buffer" {
    std.meta.refAllDecls(Buffer);
}
