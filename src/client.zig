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

pub const Object = struct {
    conn: *Connection,
    id: u32,
};

pub const Connection = struct {
    const ObjectData = struct {
        version: u32,
        handler: *const fn (conn: *Connection, msg: Message, fds: *Buffer) void,
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

        const display_data = try object_map.create(1);
        assert(display_data.id == 1);
        display_data.object.* = ObjectData{
            .version = 1,
            .handler = &displayHandler,
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

    fn displayHandler(conn: *Connection, msg: Message, fds: *Buffer) void {
        const event = wl.Display.Event.unmarshal(conn, msg, fds);
        const writer = std.io.getStdErr().writer();
        event._format("", .{}, writer) catch {};
        writer.writeByte('\n') catch {};
    }

    pub fn display(conn: *Connection) wl.Display {
        return wl.Display{
            .object = .{
                .conn = conn,
                .id = 1,
            },
        };
    }

    pub fn dispatch(conn: *Connection) !void {
        var fds = Buffer.init();
        while (conn.wire_conn.in.getMessage()) |msg| {
            const object_data = conn.object_map.get(msg.id);
            object_data.?.handler(conn, msg, &fds);
        }
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

fn outputHandler(conn: *Connection, msg: Message, fds: *Buffer) void {
    const event = wl.Output.Event.unmarshal(conn, msg, fds);
    const writer = std.io.getStdErr().writer();
    event._format("", .{}, writer) catch {};
    writer.writeByte('\n') catch {};
}

fn registryHandler(conn: *Connection, msg: Message, fds: *Buffer) void {
    const registry = wl.Registry{
        .object = .{
            .conn = conn,
            .id = msg.id,
        },
    };
    const event = wl.Registry.Event.unmarshal(conn, msg, fds);
    const writer = std.io.getStdErr().writer();
    event._format("", .{}, writer) catch {};
    writer.writeByte('\n') catch {};
    switch (event) {
        .global => |global| {
            if (std.mem.eql(u8, global.interface, wl.Output.interface)) {
                const output_data = conn.object_map.create(null) catch @panic("out of memory");
                output_data.object.* = Connection.ObjectData{
                    .version = 1,
                    .handler = &outputHandler,
                };
                const output = wl.Output{
                    .object = .{
                        .conn = conn,
                        .id = output_data.id,
                    },
                };
                const req = wl.Registry.Request.BindRequest{
                    .name = global.name,
                    .interface = global.interface,
                    .version = wl.Output.version,
                    .id = output.object,
                };
                req.marshal(registry.object.id, &conn.wire_conn.out) catch @panic("out of memory");
            }
        },
        else => {},
    }
}

test "Connection: request globals with struct" {
    var conn = try Connection.init(std.testing.allocator, null);
    defer conn.deinit();
    const display = conn.display();
    const registry_data = try conn.object_map.create(null);
    registry_data.object.* = Connection.ObjectData{
        .version = 1,
        .handler = &registryHandler,
    };
    const registry = wl.Registry{
        .object = .{
            .conn = &conn,
            .id = registry_data.id,
        },
    };
    const req = wl.Display.Request.GetRegistryRequest{ .registry = registry };
    try req.marshal(display.object.id, &conn.wire_conn.out);

    try conn.flush();
    try conn.read();
    try conn.dispatch();

    try conn.flush();
    try conn.read();
    try conn.dispatch();
}
