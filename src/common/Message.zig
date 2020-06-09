const std = @import("std");
const fd_t = std.os.fd_t;

const Message = @This();

id: u32,
op: u16,
data: []const u8,

pub fn getInt(msg: *Message) i32 {
    unreachable;
}

pub fn getUInt(msg: *Message) u32 {
    unreachable;
}

pub fn getFixed(msg: *Message) f64 {
    unreachable;
}

pub fn getString(msg: *Message) []const u8 {
    unreachable;
}

pub fn getArray(msg: *Message) []const u8 {
    unreachable;
}

pub fn getFd(msg: *Message) fd_t {
    unreachable;
}

test "Message" {
    std.meta.refAllDecls(Message);
}
