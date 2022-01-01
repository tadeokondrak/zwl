const std = @import("std");
const mem = std.mem;
const os = std.os;
const fs = std.fs;
const net = std.net;
const fd_t = os.fd_t;
const assert = std.debug.assert;

const wl = @import("wl.zig");
const WireConnection = @import("common/WireConnection.zig");
const Buffer = @import("common/Buffer.zig");
const Message = @import("common/Message.zig");
const ObjectMap = @import("common/object_map.zig").ObjectMap;

pub const Connection = struct {
    // TODO: make this not public
    pub const ObjectData = struct {
        version: u32,
        handler: fn (conn: *Connection, msg: Message, fds: *Buffer) void,
        user_data: usize,
    };

    wire_conn: WireConnection,
    object_map: ObjectMap(ObjectData, .client),
    allocator: mem.Allocator,

    // TODO: explicit error set

    pub fn init(allocator: mem.Allocator, display_name: ?[]const u8) !Connection {
        const socket = blk: {
            if (os.getenv("WAYLAND_SOCKET")) |wayland_socket| {
                // TODO: unset environment variable
                const fd = try std.fmt.parseInt(c_int, wayland_socket, 10);
                const flags = try std.os.fcntl(fd, std.os.F.GETFD, 0);
                _ = try std.os.fcntl(fd, std.os.F.SETFD, flags | std.os.FD_CLOEXEC);
                break :blk net.Stream{
                    .handle = fd,
                };
            }

            const display_option = display_name orelse
                os.getenv("WAYLAND_DISPLAY") orelse "wayland-0";
            if (display_option.len > 0 and display_option[0] == '/') {
                break :blk try net.connectUnixSocket(display_option);
            }

            const runtime_dir = os.getenv("XDG_RUNTIME_DIR") orelse
                return error.XdgRuntimeDirNotSet;

            var buf: [os.PATH_MAX]u8 = undefined;
            var bufalloc = std.heap.FixedBufferAllocator.init(&buf);
            const path = fs.path.join(bufalloc.allocator(), &[_][]const u8{
                runtime_dir, display_option,
            }) catch |err| switch (err) {
                error.OutOfMemory => return error.PathTooLong,
            };
            break :blk try net.connectUnixSocket(path);
        };

        var object_map = ObjectMap(ObjectData, .client).init(allocator);
        errdefer object_map.deinit();

        const display_data = try object_map.createId(1);
        assert(display_data.id == 1);
        display_data.object.* = ObjectData{
            .version = 1,
            .handler = wl.Display.defaultHandler,
            .user_data = 0,
        };

        const conn = Connection{
            .wire_conn = WireConnection.init(socket),
            .object_map = object_map,
            .allocator = allocator,
        };

        return conn;
    }

    pub fn deinit(conn: *Connection) void {
        conn.object_map.deinit();
        conn.wire_conn.socket.close();
    }

    pub fn read(conn: *Connection) !void {
        try conn.wire_conn.read();
    }

    pub fn flush(conn: *Connection) !void {
        try conn.wire_conn.flush();
    }

    pub fn dispatch(conn: *Connection) !void {
        var fds = Buffer.init();
        while (conn.wire_conn.in.getMessage()) |msg| {
            const object_data = conn.object_map.get(msg.id);
            object_data.?.handler(conn, msg, &fds);
        }
    }

    pub fn getRegistry(conn: *Connection) !wl.Registry {
        const display = wl.Display{ .id = 1 };
        return display.getRegistry(conn);
    }
};

test "Connection" {
    std.testing.refAllDecls(Connection);
}

test "Connection: raw request globals" {
    var conn = try Connection.init(std.testing.allocator, null);
    defer conn.deinit();
    try conn.wire_conn.out.putUInt(1);
    try conn.wire_conn.out.putUInt((12 << 16) | 1);
    try conn.wire_conn.out.putUInt(2);
    try conn.flush();
    try conn.read();
}

test "Connection: request globals with struct" {
    var conn = try Connection.init(std.testing.allocator, null);
    defer conn.deinit();
    const registry_data = try conn.object_map.create();
    registry_data.object.* = Connection.ObjectData{
        .version = 1,
        .handler = wl.Registry.defaultHandler,
        .user_data = 0,
    };
    const registry = wl.Registry{ .id = registry_data.id };
    const req = wl.Display.Request.GetRegistry{ .registry = registry };
    const display_id = 1;
    try req.marshal(display_id, &conn.wire_conn.out);
    try conn.flush();
    try conn.read();
    try conn.dispatch();
}

test "Connection: request globals with method" {
    var conn = try Connection.init(std.testing.allocator, null);
    defer conn.deinit();
    _ = try conn.getRegistry();
    try conn.flush();
    try conn.read();
    try conn.dispatch();
}
