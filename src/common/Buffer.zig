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
    if (buf.bytes.readable() < 8)
        return null;

    const id_data: [4]u8 align(4) = .{
        buf.bytes.data[buf.bytes.head +% 0],
        buf.bytes.data[buf.bytes.head +% 1],
        buf.bytes.data[buf.bytes.head +% 2],
        buf.bytes.data[buf.bytes.head +% 3],
    };
    const id = std.mem.bytesToValue(u32, &id_data);

    const op_len_data: [4]u8 align(4) = .{
        buf.bytes.data[buf.bytes.head +% 4],
        buf.bytes.data[buf.bytes.head +% 5],
        buf.bytes.data[buf.bytes.head +% 6],
        buf.bytes.data[buf.bytes.head +% 7],
    };
    const op_len = std.mem.bytesToValue(u32, &op_len_data);

    const len = @intCast(u12, op_len >> 16);
    const op = @intCast(u16, op_len & 0xffff);

    if (buf.bytes.readable() < len)
        return null;

    buf.bytes.ensureContiguous(len);

    const data = buf.bytes.readSlices()[0][8..len];
    buf.bytes.head +%= len;

    return Message{
        .id = id,
        .op = op,
        .data = data,
    };
}

pub fn putInt(buf: *Buffer, int: i32) Error!void {
    try buf.bytes.extendBack(std.mem.asBytes(&int));
}

pub fn putUint(buf: *Buffer, uint: u32) Error!void {
    try buf.putInt(@bitCast(i32, uint));
}

pub fn putFixed(buf: *Buffer, fixed: f64) Error!void {
    unreachable;
}

pub fn putString(buf: *Buffer, string: []const u8) Error!void {
    unreachable;
}

pub fn putArray(buf: *Buffer, array: []const u8) Error!void {
    unreachable;
}

pub fn putFd(buf: *Buffer, fd: fd_t) Error!void {
    try buf.fds.pushBack(fd);
}

test "Buffer" {
    std.meta.refAllDecls(Buffer);
}
