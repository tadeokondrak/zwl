pub const client = @import("client.zig");
pub const server = @import("server.zig");
pub const Buffer = @import("common/buffer.zig").Buffer;
pub const Message = @import("common/message.zig").Message;

comptime {
    _ = @import("client.zig");
    _ = @import("server.zig");
    _ = @import("common/buffer.zig");
    _ = @import("common/message.zig");
}
