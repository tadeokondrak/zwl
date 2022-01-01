const std = @import("std");
const xml = @import("xml.zig");
const wayland = @import("wayland.zig");
const mem = std.mem;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const stdin = std.io.getStdIn().reader();
    const input = try stdin.readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var protocol = try wayland.parseFile(allocator, input);
    defer protocol.deinit();

    var cx = Context{
        .prefix = "wl_",
        .out = std.ArrayList(u8).init(allocator),
        .allocator = allocator,
    };
    try cx.emitProtocol(protocol);
    try std.io.getStdOut().writer().print("{s}", .{cx.out.items});
}

const MessageKind = enum {
    request,
    event,

    pub fn nameLower(kind: MessageKind) []const u8 {
        return switch (kind) {
            .request => "request",
            .event => "event",
        };
    }

    pub fn nameUpper(kind: MessageKind) []const u8 {
        return switch (kind) {
            .request => "Request",
            .event => "Event",
        };
    }
};

fn isValidZigIdentifier(name: []const u8) bool {
    for (name) |c, i| switch (c) {
        '_', 'a'...'z', 'A'...'Z' => {},
        '0'...'9' => if (i == 0) return false,
        else => return false,
    };
    return std.zig.Token.getKeyword(name) == null;
}

const Context = struct {
    prefix: []const u8,
    out: std.ArrayList(u8),
    allocator: mem.Allocator,

    fn print(cx: *Context, comptime fmt: []const u8, args: anytype) !void {
        return cx.out.writer().print(fmt, args);
    }

    fn trimPrefix(cx: *Context, input: []const u8) []const u8 {
        var name = input;
        if (mem.startsWith(u8, input, cx.prefix))
            name = input[cx.prefix.len..];
        return name;
    }

    fn recase(cx: *Context, name: []const u8, comptime initial: bool) ![]const u8 {
        var new = std.ArrayList(u8).init(cx.allocator);
        var upper = initial;
        for (name) |c| {
            if (c == '_') {
                upper = true;
            } else if (upper) {
                try new.append(std.ascii.toUpper(c));
                upper = false;
            } else {
                try new.append(c);
            }
        }
        return new.toOwnedSlice();
    }

    fn identifier(cx: *Context, name: []const u8) ![]const u8 {
        if (std.mem.eql(u8, name, "class_"))
            return "class";
        if (!isValidZigIdentifier(name))
            return try std.fmt.allocPrint(cx.allocator, "@\"{s}\"", .{name});
        return name;
    }

    fn snakeCase(cx: *Context, name: []const u8) ![]const u8 {
        return try cx.identifier(name);
    }

    fn camelCase(cx: *Context, name: []const u8) ![]const u8 {
        return try cx.identifier(try cx.recase(name, false));
    }

    fn pascalCase(cx: *Context, name: []const u8) ![]const u8 {
        return try cx.identifier(try cx.recase(name, true));
    }

    fn argType(_: *Context, arg: wayland.Arg) ![]const u8 {
        return switch (arg.kind) {
            .int => "i32",
            .uint => "u32",
            .fixed => "f64",
            .string => if (arg.allow_null) "?[:0]const u8" else "[:0]const u8",
            .array => if (arg.allow_null) "?[]const u8" else "[]const u8",
            .fd => "std.os.fd_t",
            else => unreachable, // special
        };
    }

    fn emitProtocol(cx: *Context, proto: wayland.Protocol) !void {
        try cx.print(
            \\const std = @import("std");
            \\const wayland = @import("wayland.zig");
        , .{});
        for (proto.interfaces) |iface|
            try cx.emitInterface(iface);
    }

    fn emitInterface(cx: *Context, iface: wayland.Interface) !void {
        const trimmed = cx.trimPrefix(iface.name);
        const type_name = try cx.pascalCase(trimmed);
        try cx.print(
            \\pub const {s} = struct {{
            \\    object: wayland.client.Object,
            \\    pub const interface = "{s}";
            \\    pub const version = {};
        , .{
            type_name,
            iface.name,
            iface.version,
        });
        try cx.emitDefaultHandler(iface);
        try cx.emitMethods(iface, iface.requests, .request);
        try cx.emitEnums(iface.enums);
        try cx.emitMessages(iface, iface.requests, .request);
        try cx.emitMessages(iface, iface.events, .event);
        try cx.print(
            \\}};
        , .{});
    }

    fn emitDefaultHandler(cx: *Context, iface: wayland.Interface) !void {
        try cx.print(
            \\pub fn defaultHandler(
            \\    conn: *wayland.client.Connection,
            \\    msg: wayland.Message,
            \\    fds: *wayland.Buffer,
            \\) void {{
            \\    _ = conn;
            \\    _ = msg;
            \\    _ = fds;
        , .{});
        if (iface.events.len != 0) {
            try cx.print(
                \\std.debug.print("{{}}\n", .{{Event.unmarshal(conn, msg, fds)}});
            , .{});
        }
        try cx.print(
            \\}}
        , .{});
    }

    fn emitMethods(cx: *Context, iface: wayland.Interface, msgs: []wayland.Message, kind: MessageKind) !void {
        for (msgs) |msg|
            try cx.emitMethod(iface, msg, kind);
    }

    fn emitMethod(cx: *Context, iface: wayland.Interface, msg: wayland.Message, kind: MessageKind) !void {
        try cx.print(
            \\pub fn req{s}(
            \\    {s}: {s},
        , .{
            try cx.pascalCase(msg.name),
            try cx.snakeCase(cx.trimPrefix(iface.name)),
            try cx.pascalCase(cx.trimPrefix(iface.name)),
        });
        var return_expr: []const u8 = "";
        var return_type: []const u8 = "void";
        var extra_errors: []const u8 = "";
        for (msg.args) |arg| {
            switch (arg.kind) {
                .int, .uint, .fixed, .string, .array, .fd => {
                    try cx.print(
                        \\arg_{s}: {s},
                    , .{
                        try cx.snakeCase(arg.name),
                        try cx.argType(arg),
                    });
                },
                .new_id => {
                    if (arg.interface) |iface_name| {
                        return_type = try cx.pascalCase(cx.trimPrefix(iface_name));
                    } else {
                        try cx.print(
                            \\comptime T: anytype,
                            \\arg_{s}_version: u32,
                        , .{
                            try cx.snakeCase(arg.name),
                        });
                        return_type = "T";
                    }
                    extra_errors = ",OutOfMemory";
                    return_expr = try std.fmt.allocPrint(cx.allocator, "arg_{s}", .{try cx.snakeCase(arg.name)});
                },
                .object => {
                    if (arg.interface) |iface_name| {
                        try cx.print("arg_{s}: {s}{s},", .{
                            try cx.snakeCase(arg.name),
                            if (arg.allow_null) @as([]const u8, "?") else @as([]const u8, ""),
                            cx.pascalCase(cx.trimPrefix(iface_name)),
                        });
                    } else {
                        try cx.print("arg_{s}: {s}wayland.client.Object,", .{
                            try cx.snakeCase(arg.name),
                            if (arg.allow_null) @as([]const u8, "?") else @as([]const u8, ""),
                        });
                    }
                },
            }
        }
        try cx.print(
            \\) error{{BufferFull{s}}}!{s} {{
        , .{ extra_errors, return_type });
        for (msg.args) |arg| {
            switch (arg.kind) {
                .new_id => {
                    if (arg.interface) |iface_name| {
                        try cx.print(
                            \\const arg_{0s}_data = try {1s}.object.conn.object_map.create();
                            \\arg_{0s}_data.object.* = wayland.client.Connection.ObjectData{{
                            \\    .version = 1,
                            \\    .handler = {2s}.defaultHandler,
                            \\}};
                            \\const arg_{0s} = {2s}{{
                            \\    .object = wayland.client.Object{{
                            \\        .conn = {1s}.object.conn,
                            \\        .id = arg_{0s}_data.id,
                            \\    }},
                            \\}};
                        , .{
                            try cx.snakeCase(arg.name),
                            try cx.snakeCase(cx.trimPrefix(iface.name)),
                            try cx.pascalCase(cx.trimPrefix(iface_name)),
                        });
                    } else {
                        try cx.print(
                            \\const arg_{0s}_data = try {1s}.object.conn.object_map.create();
                            \\arg_{0s}_data.object.* = wayland.client.Connection.ObjectData{{
                            \\    .version = arg_{0s}_version,
                            \\    .handler = defaultHandler,
                            \\}};
                            \\const arg_{0s} = wayland.client.Object{{
                            \\    .conn = {1s}.object.conn,
                            \\    .id = arg_{0s}_data.id,
                            \\}};
                        , .{
                            try cx.snakeCase(arg.name),
                            try cx.snakeCase(cx.trimPrefix(iface.name)),
                        });
                    }
                },
                else => {},
            }
        }
        try cx.print(
            \\const {s} = {s}.{s}{s}{{
        , .{
            kind.nameLower(),
            kind.nameUpper(),
            try cx.pascalCase(msg.name),
            kind.nameUpper(),
        });
        for (msg.args) |arg| {
            try cx.print(
                \\.{s} = arg_{s},
            , .{
                try cx.snakeCase(arg.name),
                try cx.snakeCase(arg.name),
            });
        }
        try cx.print(
            \\}};
            \\try request.marshal({s}.object.id, &{s}.object.conn.wire_conn.out);
        , .{
            try cx.snakeCase(cx.trimPrefix(iface.name)),
            try cx.snakeCase(cx.trimPrefix(iface.name)),
        });
        if (return_expr.len != 0) {
            try cx.print(
                \\return {s};
            , .{return_expr});
        }
        try cx.print(
            \\}}
        , .{});
    }

    fn emitMessages(cx: *Context, iface: wayland.Interface, msgs: []wayland.Message, kind: MessageKind) !void {
        try cx.emitMessageUnion(iface, msgs, kind);
        try cx.emitMessageEnum(msgs, kind);
    }

    fn emitMessageEnum(cx: *Context, msgs: []wayland.Message, kind: MessageKind) !void {
        if (msgs.len == 0)
            return;
        try cx.print(
            \\pub const {s}Opcode = enum(u16) {{
        , .{kind.nameUpper()});
        for (msgs) |msg, i| {
            try cx.print(
                \\{s} = {},
            , .{
                try cx.snakeCase(msg.name),
                i,
            });
        }
        try cx.print(
            \\}};
        , .{});
    }

    fn emitMessageUnion(cx: *Context, _: wayland.Interface, msgs: []wayland.Message, kind: MessageKind) !void {
        if (msgs.len == 0)
            return;
        try cx.print(
            \\pub const {0s} = union({0s}Opcode) {{
        , .{kind.nameUpper()});
        for (msgs) |msg| {
            try cx.print(
                \\{s}: {s}{s},
            , .{
                try cx.snakeCase(msg.name),
                try cx.pascalCase(msg.name),
                kind.nameUpper(),
            });
        }
        for (msgs) |msg|
            try cx.emitMessageStruct(msg, kind);
        try cx.print(
            \\pub fn marshal(
            \\    {0s}: {1s},
            \\    id: u32,
            \\    buf: *wayland.Buffer
            \\) error{{BufferFull}}!void {{
            \\    return switch ({0s}) {{
        , .{
            kind.nameLower(),
            kind.nameUpper(),
        });
        for (msgs) |msg| {
            try cx.print(
                \\.{0s} => |{0s}| {0s}.marshal(id, buf),
            , .{
                try cx.snakeCase(msg.name),
            });
        }
        try cx.print(
            \\    }};
            \\}}
        , .{});
        try cx.print(
            \\pub fn unmarshal(
            \\    conn: *wayland.client.Connection,
            \\    msg: wayland.Message,
            \\    fds: *wayland.Buffer,
            \\) {0s} {{
            \\    return switch (@intToEnum(std.meta.Tag({0s}), msg.op)) {{
        , .{
            kind.nameUpper(),
        });
        for (msgs) |msg| {
            try cx.print(
                \\.{s} => {s}{{ .{s} = {s}{s}.unmarshal(conn, msg, fds) }},
            , .{
                try cx.snakeCase(msg.name),
                kind.nameUpper(),
                try cx.snakeCase(msg.name),
                try cx.pascalCase(msg.name),
                kind.nameUpper(),
            });
        }
        try cx.print(
            \\    }};
            \\}}
            \\}};
        , .{});
    }

    fn emitMessageStruct(cx: *Context, msg: wayland.Message, kind: MessageKind) !void {
        try cx.print(
            \\pub const {s}{s} = struct {{
        , .{ try cx.pascalCase(msg.name), kind.nameUpper() });
        for (msg.args) |arg| {
            switch (arg.kind) {
                .int, .uint, .fixed, .string, .array, .fd => {
                    try cx.print(
                        \\{s}: {s},
                    , .{
                        try cx.snakeCase(arg.name),
                        try cx.argType(arg),
                    });
                },
                .new_id => {
                    if (arg.interface) |iface_name| {
                        try cx.print("{s}: {s},", .{
                            try cx.snakeCase(arg.name),
                            cx.pascalCase(cx.trimPrefix(iface_name)),
                        });
                    } else {
                        try cx.print("interface: []const u8, version: u32, {s}: wayland.client.Object,", .{
                            try cx.snakeCase(arg.name),
                        });
                    }
                },
                .object => {
                    if (arg.interface) |iface_name| {
                        try cx.print("{s}: {s}{s},", .{
                            try cx.snakeCase(arg.name),
                            if (arg.allow_null) @as([]const u8, "?") else @as([]const u8, ""),
                            cx.pascalCase(cx.trimPrefix(iface_name)),
                        });
                    } else {
                        try cx.print("{s}: {s}wayland.client.Object,", .{
                            try cx.snakeCase(arg.name),
                            if (arg.allow_null) @as([]const u8, "?") else @as([]const u8, ""),
                        });
                    }
                },
            }
        }
        try cx.emitMarshal(msg, kind);
        try cx.emitUnmarshal(msg, kind);
        try cx.print(
            \\}};
        , .{});
    }

    fn emitEnums(cx: *Context, enums: []wayland.Enum) !void {
        try cx.print(
            \\pub const Enum = struct {{
        , .{});
        for (enums) |@"enum"| {
            if (@"enum".bitfield)
                try cx.emitBitfield(@"enum")
            else
                try cx.emitEnum(@"enum");
        }
        try cx.print(
            \\}};
        , .{});
    }

    fn emitBitfield(cx: *Context, bitfield: wayland.Enum) !void {
        try cx.print(
            \\pub const {s} = packed struct {{
        , .{
            try cx.pascalCase(bitfield.name),
        });
        for (bitfield.entries) |entry| {
            try cx.print(
                \\{s}: bool = false,
            , .{
                try cx.snakeCase(entry.name),
            });
        }
        try cx.print(
            \\pub fn toInt({s}: {s}) u32 {{
            \\    var result: u32 = 0;
        , .{
            try cx.snakeCase(bitfield.name),
            try cx.pascalCase(bitfield.name),
        });
        for (bitfield.entries) |entry| {
            try cx.print(
                \\if ({s}.{s})
                \\    result &= {};
            , .{
                try cx.snakeCase(bitfield.name),
                try cx.snakeCase(entry.name),
                entry.value,
            });
        }
        try cx.print(
            \\    return result;
            \\}}
        , .{});
        try cx.print(
            \\pub fn fromInt(int: u32) {s} {{
            \\    return {s}{{
        , .{
            try cx.pascalCase(bitfield.name),
            try cx.pascalCase(bitfield.name),
        });
        for (bitfield.entries) |entry| {
            try cx.print(
                \\.{s} = (int & {}) != 0,
            , .{
                try cx.snakeCase(entry.name),
                entry.value,
            });
        }
        try cx.print(
            \\}};
            \\}}
        , .{});
        try cx.print(
            \\}};
        , .{});
    }

    fn emitEnum(cx: *Context, @"enum": wayland.Enum) !void {
        try cx.print(
            \\pub const {s} = enum(u32) {{
        , .{
            try cx.pascalCase(@"enum".name),
        });
        for (@"enum".entries) |entry| {
            try cx.print(
                \\{s} = {},
            , .{
                try cx.snakeCase(entry.name),
                entry.value,
            });
        }
        try cx.print(
            \\    pub fn toInt({s}: {s}) u32 {{
            \\        return @enumToInt({s});
            \\    }}
            \\    pub fn fromInt(int: u32) {s} {{
            \\        return @intToEnum({s}, int);
            \\    }}
            \\}};
        , .{
            try cx.snakeCase(@"enum".name),
            try cx.pascalCase(@"enum".name),
            try cx.snakeCase(@"enum".name),
            try cx.pascalCase(@"enum".name),
            try cx.pascalCase(@"enum".name),
        });
    }

    fn emitMarshal(cx: *Context, msg: wayland.Message, kind: MessageKind) !void {
        try cx.print(
            \\pub fn marshal(
            \\    {0s}: {1s}{2s},
            \\    id: u32,
            \\    buf: *wayland.Buffer,
            \\) error{{BufferFull}}!void {{
        , .{
            if (msg.args.len != 0) (try cx.snakeCase(msg.name)) else "_",
            try cx.pascalCase(msg.name),
            kind.nameUpper(),
        });
        var size_bytes: u32 = 8;
        var size_fds: u32 = 0;
        var extra = std.ArrayList(u8).init(cx.allocator);
        for (msg.args) |arg| switch (arg.kind) {
            .new_id => {
                if (arg.interface == null) {
                    size_bytes += 12;
                    try extra.writer().print("+ (({s}.interface.len + 3) / 4 * 4)", .{
                        try cx.snakeCase(msg.name),
                    });
                } else {
                    size_bytes += 4;
                }
            },
            .int, .uint, .fixed, .object => {
                size_bytes += 4;
            },
            .string, .array => {
                size_bytes += 4;
                if (arg.allow_null) {
                    try extra.writer().print("+ (if ({s}.{s}) |_arg| ((_arg.len + 3) / 4 * 4) else 0)", .{
                        try cx.snakeCase(msg.name),
                        try cx.snakeCase(arg.name),
                    });
                } else {
                    try extra.writer().print("+ (({s}.{s}.len + 3) / 4 * 4)", .{
                        try cx.snakeCase(msg.name),
                        try cx.snakeCase(arg.name),
                    });
                }
            },
            .fd => {
                size_fds += 1;
            },
        };
        try cx.print(
            \\const len: usize = {0}{1s};
            \\if (buf.bytes.writableLength() < len)
            \\    return error.BufferFull;
            \\if (buf.fds.writableLength() < {2})
            \\    return error.BufferFull;
            \\buf.putUInt(id) catch unreachable;
            \\buf.putUInt(@intCast(u32, len << 16) | @enumToInt({3s}Opcode.{4s})) catch unreachable;
        , .{
            size_bytes,
            extra.items,
            size_fds,
            kind.nameUpper(),
            try cx.snakeCase(msg.name),
        });
        for (msg.args) |arg| {
            switch (arg.kind) {
                .new_id, .object => {
                    if (arg.kind == .new_id and arg.interface == null) {
                        try cx.print(
                            \\buf.putString({0s}.interface) catch unreachable;
                            \\buf.putUInt({0s}.version) catch unreachable;
                            \\buf.putUInt({0s}.{1s}.id) catch unreachable;
                        , .{
                            try cx.snakeCase(msg.name),
                            try cx.snakeCase(arg.name),
                        });
                    } else if (arg.allow_null) {
                        try cx.print(
                            \\buf.putUInt(if ({s}.{s}) |_obj| _obj.object.id else 0) catch unreachable;
                        , .{
                            try cx.snakeCase(msg.name),
                            try cx.snakeCase(arg.name),
                        });
                    } else {
                        try cx.print(
                            \\buf.putUInt({s}.{s}.object.id) catch unreachable;
                        , .{
                            try cx.snakeCase(msg.name),
                            try cx.snakeCase(arg.name),
                        });
                    }
                },
                .int => {
                    try cx.print(
                        \\buf.putInt({s}.{s}) catch unreachable;
                    , .{
                        try cx.snakeCase(msg.name),
                        try cx.snakeCase(arg.name),
                    });
                },
                .uint => {
                    try cx.print(
                        \\buf.putUInt({s}.{s}) catch unreachable;
                    , .{
                        try cx.snakeCase(msg.name),
                        try cx.snakeCase(arg.name),
                    });
                },
                .fixed => {
                    try cx.print(
                        \\buf.putFixed({s}.{s}) catch unreachable;
                    , .{
                        try cx.snakeCase(msg.name),
                        try cx.snakeCase(arg.name),
                    });
                },
                .string => {
                    try cx.print(
                        \\buf.putString({s}.{s}) catch unreachable;
                    , .{
                        try cx.snakeCase(msg.name),
                        try cx.snakeCase(arg.name),
                    });
                },
                .array => {
                    try cx.print(
                        \\buf.putArray({s}.{s}) catch unreachable;
                    , .{
                        try cx.snakeCase(msg.name),
                        try cx.snakeCase(arg.name),
                    });
                },
                .fd => {
                    try cx.print(
                        \\buf.putFd({s}.{s}) catch unreachable;
                    , .{
                        try cx.snakeCase(msg.name),
                        try cx.snakeCase(arg.name),
                    });
                },
            }
        }
        try cx.print(
            \\}}
        , .{});
    }

    fn emitUnmarshal(cx: *Context, msg: wayland.Message, kind: MessageKind) !void {
        var conn_arg_name: []const u8 = "_";
        var msg_arg_name: []const u8 = "_";
        var fd_arg_name: []const u8 = "_";
        if (msg.args.len != 0)
            msg_arg_name = "msg";
        for (msg.args) |arg| {
            if (arg.kind == .new_id or arg.kind == .object)
                conn_arg_name = "conn";
            if (arg.kind == .fd)
                fd_arg_name = "fds";
        }
        try cx.print(
            \\pub fn unmarshal(
            \\    {s}: *wayland.client.Connection,
            \\    {s}: wayland.Message,
            \\    {s}: *wayland.Buffer,
            \\) {s}{s} {{
        , .{
            conn_arg_name,
            msg_arg_name,
            fd_arg_name,
            try cx.pascalCase(msg.name),
            kind.nameUpper(),
        });
        if (msg.args.len != 0) {
            try cx.print(
                \\var i: usize = 0;
            , .{});
        }
        try cx.print(
            \\return {s}{s}{{
        , .{
            try cx.pascalCase(msg.name),
            kind.nameUpper(),
        });
        for (msg.args) |arg| {
            try cx.print(
                \\.{s} = blk: {{
            , .{
                try cx.snakeCase(arg.name),
            });
            switch (arg.kind) {
                .new_id, .object => {
                    if (arg.kind == .new_id and arg.interface == null) {
                        try cx.print(
                            \\_ = conn;
                            \\break :blk undefined;
                        , .{});
                    } else if (arg.allow_null) {
                        try cx.print(
                            \\const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                            \\i += 4;
                            \\break :blk wayland.client.Object {{ .conn = conn, .id = arg_id }};
                        , .{});
                    } else {
                        try cx.print(
                            \\const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                            \\i += 4;
                            \\break :blk wayland.client.Object {{ .conn = conn, .id = arg_id }};
                        , .{});
                    }
                },
                .int => {
                    try cx.print(
                        \\const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        \\i += 4;
                        \\break :blk arg;
                    , .{});
                },
                .uint => {
                    try cx.print(
                        \\const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        \\i += 4;
                        \\break :blk arg;
                    , .{});
                },
                .fixed => {
                    try cx.print(
                        \\const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        \\i += 4;
                        \\break :blk arg;
                    , .{});
                },
                .string => {
                    try cx.print(
                        \\const arg_len = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        \\const arg_padded_len = (arg_len + 3) / 4 * 4;
                        \\const arg = msg.data[i + 4.. i + 4 + arg_len - 1 :0];
                        \\i += 4 + arg_padded_len;
                        \\break :blk arg;
                    , .{});
                },
                .array => {
                    try cx.print(
                        \\const arg_len = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        \\const arg_padded_len = (arg_len + 3) / 4 * 4;
                        \\const arg = msg.data[i + 4.. i + 4 + arg_len];
                        \\i += 4 + arg_padded_len;
                        \\break :blk arg;
                    , .{});
                },
                .fd => {
                    try cx.print(
                        \\_ = fds;
                        \\break :blk undefined;
                    , .{});
                },
            }
            try cx.print(
                \\}},
            , .{});
        }
        try cx.print(
            \\}};
            \\}}
        , .{});
    }
};
