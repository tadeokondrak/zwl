const std = @import("std");
const fd_t = std.os.fd_t;

const Message = @This();

id: u32,
op: u16,
data: []const u8,

pub fn getInt(msg: *Message) i32 {
    _ = msg;
    unreachable;
}

pub fn getUInt(msg: *Message) u32 {
    _ = msg;
    unreachable;
}

pub fn getFixed(msg: *Message) f64 {
    _ = msg;
    unreachable;
}

pub fn getString(msg: *Message) []const u8 {
    _ = msg;
    unreachable;
}

pub fn getArray(msg: *Message) []const u8 {
    _ = msg;
    unreachable;
}

pub fn getFd(msg: *Message) fd_t {
    _ = msg;
    unreachable;
}

test "Message" {
    std.testing.refAllDecls(Message);
}
