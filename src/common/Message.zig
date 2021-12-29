const std = @import("std");
const Message = @This();

id: u32,
op: u16,
data: []const u8,
