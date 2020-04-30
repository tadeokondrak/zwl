const std = @import("std");
const WireConnection = @import("common/wire_connection.zig").WireConnection;
const ObjectMap = @import("common/object_map.zig").ObjectMap;
const mem = std.mem;
const os = std.os;
const fs = std.fs;
const net = std.net;

pub const Object = struct {
    conn: *Connection,
    id: u32,
};

pub const Connection = struct {
    allocator: *mem.Allocator,
    wire_conn: WireConnection,
    object_map: ObjectMap(Object, .client),

    pub fn init(allocator: *mem.Allocator, display_name: ?[]const u8) !Connection {
        const socket = blk: {
            if (os.getenv("WAYLAND_SOCKET")) |wayland_socket| {
                // TODO: set CLOEXEC
                // TODO: unset environment variable
                break :blk fs.File{
                    .handle = try std.fmt.parseInt(c_int, wayland_socket, 10),
                    .io_mode = std.io.mode,
                };
            }
            const display_option = display_name orelse os.getenv("WAYLAND_DISPLAY") orelse "wayland-0";
            if (display_option.len > 0 and display_option[0] == '/') {
                break :blk try net.connectUnixSocket(display_option);
            } else {
                const runtime_dir = os.getenv("XDG_RUNTIME_DIR") orelse
                    return error.XdgRuntimeDirNotSet;
                var buf: [os.PATH_MAX]u8 = undefined;
                var bufalloc = std.heap.FixedBufferAllocator.init(&buf);
                const path = fs.path.joinPosix(&bufalloc.allocator, &[_][]const u8{
                    runtime_dir, display_option,
                }) catch |err| switch (err) {
                    error.OutOfMemory => {
                        return error.PathTooLong;
                    },
                };
                break :blk try net.connectUnixSocket(path);
            }
        };
        var object_map = ObjectMap(Object, .client).init(allocator);
        _ = try object_map.create(1);
        return Connection{
            .allocator = allocator,
            .wire_conn = WireConnection.init(socket),
            .object_map = object_map,
        };
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

    pub fn display(conn: *Connection) Object {
        return .{
            .conn = conn,
            .id = 1,
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
