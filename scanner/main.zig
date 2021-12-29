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
            .string, .array => if (arg.allow_null) "?[]const u8" else "[]const u8",
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
        try cx.emitMessages(iface, iface.requests, .request);
        try cx.emitMessages(iface, iface.events, .event);
        try cx.emitEnums(iface.enums);
        try cx.print(
            \\}};
        , .{});
    }

    fn emitMessages(cx: *Context, iface: wayland.Interface, msgs: []wayland.Message, kind: MessageKind) !void {
        try cx.emitMessageEnum(msgs, kind);
        try cx.emitMessageUnion(iface, msgs, kind);
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
            \\    _,
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
            \\pub fn marshal(_{0s}: {1s}, _id: u32, _buf: *wayland.Buffer)
            \\    error{{ BytesBufferFull, FdsBufferFull }}!void {{
            \\    _ = _{0s};
            \\    _ = _id;
            \\    _ = _buf;
            \\    return switch (_{0s}) {{
        , .{
            kind.nameLower(),
            kind.nameUpper(),
        });
        for (msgs) |msg| {
            try cx.print(
                \\.{0s} => |{0s}| {0s}.marshal(_id, _buf),
            , .{
                try cx.snakeCase(msg.name),
            });
        }
        try cx.print(
            \\        _ => unreachable,
            \\    }};
            \\}}
        , .{});
        try cx.print(
            \\pub fn unmarshal(_msg: *wayland.Message, _fds: *wayland.Buffer) {0s} {{
            \\    _ = _msg;
            \\    _ = _fds;
            \\    return switch (@intToEnum({0s}, _msg.op)) {{
        , .{
            kind.nameUpper(),
        });
        for (msgs) |msg| {
            try cx.print(
                \\.{s} => {s}{s}.unmarshal(_msg, _fds),
            , .{
                try cx.snakeCase(msg.name),
                try cx.pascalCase(msg.name),
                kind.nameUpper(),
            });
        }
        try cx.print(
            \\        _ => unreachable,
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
        for (enums) |@"enum"| {
            if (@"enum".bitfield)
                try cx.emitBitfield(@"enum")
            else
                try cx.emitEnum(@"enum");
        }
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
            \\    var _result: u32 = 0;
        , .{
            try cx.snakeCase(bitfield.name),
            try cx.pascalCase(bitfield.name),
        });
        for (bitfield.entries) |entry| {
            try cx.print(
                \\if ({s}.{s})
                \\    _result &= {};
            , .{
                try cx.snakeCase(bitfield.name),
                try cx.snakeCase(entry.name),
                entry.value,
            });
        }
        try cx.print(
            \\    return _result;
            \\}}
        , .{});
        try cx.print(
            \\pub fn fromInt(_int: u32) {s} {{
            \\    return {s}{{
        , .{
            try cx.pascalCase(bitfield.name),
            try cx.pascalCase(bitfield.name),
        });
        for (bitfield.entries) |entry| {
            try cx.print(
                \\.{s} = (_int & {}) != 0,
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
            \\    pub fn fromInt(_int: u32) {s} {{
            \\        return @intToEnum({s}, _int);
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
            \\pub fn marshal({0s}: {1s}{2s}, _id: u32, _buf: *wayland.Buffer)
            \\    error{{ BytesBufferFull, FdsBufferFull }}!void {{
            \\    _ = {0s};
            \\    _ = _id;
            \\    _ = _buf;
        , .{
            try cx.snakeCase(msg.name),
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
            \\if (_buf.bytes.writableLength() < ({0}{1s}))
            \\    return error.BytesBufferFull;
            \\if (_buf.fds.writableLength() < ({2}))
            \\    return error.FdsBufferFull;
            \\_buf.putUInt(_id) catch unreachable;
            \\_buf.putUInt(@intCast(u32, @as(usize, ({0}{1s}) << 16)) | @enumToInt({3s}Opcode.{4s})) catch unreachable;
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
                            \\_buf.putString({0s}.interface) catch unreachable;
                            \\_buf.putUInt({0s}.version) catch unreachable;
                            \\_buf.putUInt({0s}.{1s}.id) catch unreachable;
                        , .{
                            try cx.snakeCase(msg.name),
                            try cx.snakeCase(arg.name),
                        });
                    } else if (arg.allow_null) {
                        try cx.print(
                            \\_buf.putUInt(if ({s}.{s}) |_obj| _obj.object.id else 0) catch unreachable;
                        , .{
                            try cx.snakeCase(msg.name),
                            try cx.snakeCase(arg.name),
                        });
                    } else {
                        try cx.print(
                            \\_buf.putUInt({s}.{s}.object.id) catch unreachable;
                        , .{
                            try cx.snakeCase(msg.name),
                            try cx.snakeCase(arg.name),
                        });
                    }
                },
                .int => {
                    try cx.print(
                        \\_buf.putInt({s}.{s}) catch unreachable;
                    , .{
                        try cx.snakeCase(msg.name),
                        try cx.snakeCase(arg.name),
                    });
                },
                .uint => {
                    try cx.print(
                        \\_buf.putUInt({s}.{s}) catch unreachable;
                    , .{
                        try cx.snakeCase(msg.name),
                        try cx.snakeCase(arg.name),
                    });
                },
                .fixed => {
                    try cx.print(
                        \\_buf.putFixed({s}.{s}) catch unreachable;
                    , .{
                        try cx.snakeCase(msg.name),
                        try cx.snakeCase(arg.name),
                    });
                },
                .string => {
                    try cx.print(
                        \\_buf.putString({s}.{s}) catch unreachable;
                    , .{
                        try cx.snakeCase(msg.name),
                        try cx.snakeCase(arg.name),
                    });
                },
                .array => {
                    try cx.print(
                        \\_buf.putArray({s}.{s}) catch unreachable;
                    , .{
                        try cx.snakeCase(msg.name),
                        try cx.snakeCase(arg.name),
                    });
                },
                .fd => {
                    try cx.print(
                        \\_buf.putFd({s}.{s}) catch unreachable;
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

    fn emitUnmarshal(cx: *Context, message: wayland.Message, kind: MessageKind) !void {
        try cx.print(
            \\pub fn unmarshal(_msg: *wayland.Message, _fds: *wayland.Buffer) {s}{s} {{
            \\    _ = _msg;
            \\    _ = _fds;
        , .{
            try cx.pascalCase(message.name),
            kind.nameUpper(),
        });
        // TODO: assert opcode is correct
        try cx.print(
            \\}}
        , .{});
    }
};
