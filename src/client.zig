const std = @import("std");
const WireConnection = @import("wire_connection.zig").WireConnection;
const mem = std.mem;
const os = std.os;
const fs = std.fs;
const net = std.net;

pub const Connection = struct {
    allocator: *mem.Allocator,
    wire_conn: WireConnection,

    pub fn init(allocator: *mem.Allocator, display: ?[]const u8) !Connection {
        const socket = blk: {
            if (os.getenv("WAYLAND_SOCKET")) |wayland_socket| {
                // TODO: set CLOEXEC
                // TODO: unset environment variable
                break :blk fs.File{
                    .handle = try std.fmt.parseInt(c_int, wayland_socket, 10),
                    .io_mode = std.io.mode,
                };
            }
            const display_name = display orelse os.getenv("WAYLAND_DISPLAY") orelse "wayland-0";
            if (display_name.len > 0 and display_name[0] == '/') {
                break :blk try net.connectUnixSocket(display_name);
            } else {
                const runtime_dir = os.getenv("XDG_RUNTIME_DIR") orelse
                    return error.XdgRuntimeDirNotSet;
                var buf: [os.PATH_MAX]u8 = undefined;
                var bufalloc = std.heap.FixedBufferAllocator.init(&buf);
                const path = fs.path.joinPosix(&bufalloc.allocator, &[_][]const u8{
                    runtime_dir, display_name,
                }) catch |err| switch (err) {
                    error.OutOfMemory => {
                        return error.PathTooLong;
                    },
                };
                break :blk try net.connectUnixSocket(path);
            }
        };
        return Connection{
            .allocator = allocator,
            .wire_conn = WireConnection.init(socket),
        };
    }

    pub fn deinit(conn: *Connection) void {
        conn.wire_conn.socket.close();
    }

    pub fn read(conn: *Connection) !void {
        try conn.wire_conn.read();
    }

    pub fn flush(conn: *Connection) !void {
        try conn.wire_conn.flush();
    }
};

test "Connection" {
    std.meta.refAllDecls(Connection);
}

test "Connection: raw request globals" {
    var conn = try Connection.init(std.testing.allocator, null);
    try conn.wire_conn.out.putUint(1);
    try conn.wire_conn.out.putUint((12 << 16) | 1);
    try conn.wire_conn.out.putUint(2);
    try conn.flush();
    try conn.read();
}
