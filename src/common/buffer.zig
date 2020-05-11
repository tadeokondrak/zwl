const std = @import("std");
const RingBuffer = @import("ring_buffer.zig").RingBuffer;
const fd_t = std.os.fd_t;

pub const Buffer = struct {
    pub const Error = error{BufferFull};

    bytes: RingBuffer(u8, 4096),
    fds: RingBuffer(fd_t, 512),

    pub fn init() Buffer {
        return .{
            .bytes = RingBuffer(u8, 4096).init(),
            .fds = RingBuffer(fd_t, 512).init(),
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

    pub fn getInt(buf: *Buffer) ?i32 {
        if (buf.bytes.readable() < 4)
            return null;
        const bytes: [4]u8 align(4) = .{
            buf.bytes.popFront().?,
            buf.bytes.popFront().?,
            buf.bytes.popFront().?,
            buf.bytes.popFront().?,
        };
        return std.mem.bytesToValue(i32, &bytes);
    }

    pub fn getUint(buf: *Buffer) ?u32 {
        return @bitCast(u32, buf.getInt() orelse return null);
    }

    pub fn getFixed(buf: *Buffer) ?f64 {
        unreachable;
    }

    pub fn getString(buf: *Buffer) ?[]const u8 {
        unreachable;
    }

    pub fn getArray(buf: *Buffer) ?[]const u8 {
        unreachable;
    }

    pub fn getFd(buf: *Buffer) ?fd_t {
        return buf.fds.popFront();
    }
};

test "Buffer" {
    std.meta.refAllDecls(Buffer);
}
