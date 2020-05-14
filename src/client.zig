const std = @import("std");
const mem = std.mem;
const os = std.os;
const fs = std.fs;
const net = std.net;
const fd_t = os.fd_t;
const assert = std.debug.assert;

const wl = @import("wl.zig");
const WireConnection = @import("common/wire_connection.zig").WireConnection;
const ObjectMap = @import("common/object_map.zig").ObjectMap;

pub const Object = struct {
    conn: *Connection,
    id: u32,
};

pub const Connection = struct {
    const ObjectData = struct {
        version: u32,
        listener: usize,
    };

    wire_conn: WireConnection,
    object_map: ObjectMap(ObjectData, .client),
    allocator: *mem.Allocator,

    pub fn init(allocator: *mem.Allocator, display_name: ?[]const u8) !Connection {
        const socket = blk: {
            if (os.getenv("WAYLAND_SOCKET")) |wayland_socket| {
                // TODO: set CLOEXEC and unset environment variable
                break :blk fs.File{
                    .handle = try std.fmt.parseInt(c_int, wayland_socket, 10),
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
            const path = fs.path.joinPosix(&bufalloc.allocator, &[_][]const u8{
                runtime_dir, display_option,
            }) catch |err| switch (err) {
                error.OutOfMemory => return error.PathTooLong,
            };
            break :blk try net.connectUnixSocket(path);
        };

        var object_map = ObjectMap(ObjectData, .client).init(allocator);
        errdefer object_map.deinit();

        const display_data = try object_map.create(1);
        assert(display_data.id == 1);
        display_data.object.* = ObjectData{
            .version = 1,
            .listener = 0,
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

    pub fn display(conn: *Connection) wl.Display {
        return wl.Display{
            .object = .{
                .conn = conn,
                .id = 1,
            },
        };
    }
};

test "Connection" {
    std.meta.refAllDecls(Connection);
}

test "Connection: raw request globals" {
    var conn = try Connection.init(std.testing.allocator, null);
    defer conn.deinit();
    try conn.wire_conn.out.putUint(1);
    try conn.wire_conn.out.putUint((12 << 16) | 1);
    try conn.wire_conn.out.putUint(2);
    try conn.flush();
    try conn.read();
}
