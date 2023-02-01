const std = @import("std");
const xml = @import("xml.zig");
const wayland = @import("wayland.zig");
const mem = std.mem;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var cx = Context{
        .prefix = "",
        .out = std.ArrayList(u8).init(allocator),
        .allocator = allocator,
    };

    if (std.os.argv.len > 1) {
        var protocols = try std.ArrayList(wayland.Protocol).initCapacity(allocator, std.os.argv.len - 1);
        defer {
            for (protocols.items) |*protocol| protocol.deinit();
            protocols.deinit();
        }
        for (std.os.argv[1..]) |arg| {
            const f = try std.fs.cwd().openFileZ(arg, .{});
            defer f.close();
            const input = try f.reader().readAllAlloc(allocator, std.math.maxInt(usize));
            defer allocator.free(input);
            var protocol = try wayland.parseFile(allocator, input);
            protocols.appendAssumeCapacity(protocol);
        }
        try cx.emitProtocols(protocols.items);
    } else {
        const stdin = std.io.getStdIn().reader();
        const input = try stdin.readAllAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(input);
        var protocol = try wayland.parseFile(allocator, input);
        defer protocol.deinit();
        try cx.emitProtocols(&[_]wayland.Protocol{protocol});
    }
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
        return try new.toOwnedSlice();
    }

    fn identifier(cx: *Context, name: []const u8) ![]const u8 {
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

    fn emitProtocols(cx: *Context, protos: []wayland.Protocol) !void {
        try cx.print(
            \\const wl = @This();
            \\const std = @import("std");
            \\const wayland = @import("wayland.zig");
        , .{});
        for (protos) |proto|
            for (proto.interfaces) |iface|
                try cx.emitInterface(iface);
    }

    fn emitInterface(cx: *Context, iface: wayland.Interface) !void {
        const type_name = try cx.pascalCase(cx.trimPrefix(iface.name));
        try cx.print(
            \\pub const {s} = struct {{
            \\    id: u32,
            \\    pub const interface = "{s}";
            \\    pub const version = {};
            \\    pub const Request = {0s}Request;
            \\    pub const Event = {0s}Event;
        , .{
            type_name,
            iface.name,
            iface.version,
        });
        try cx.emitMethods(iface, iface.requests, .request);
        try cx.print(
            \\}};
        , .{});
        try cx.emitMessageUnion(iface, iface.requests, .request);
        try cx.emitMessageUnion(iface, iface.events, .event);
        try cx.emitEnums(iface);
    }

    fn emitMethods(cx: *Context, iface: wayland.Interface, msgs: []wayland.Message, kind: MessageKind) !void {
        for (msgs) |msg|
            try cx.emitMethod(iface, msg, kind);
    }

    fn emitMethod(cx: *Context, iface: wayland.Interface, msg: wayland.Message, kind: MessageKind) !void {
        try cx.print(
            \\pub fn {s}(
            \\    self: @This(),
            \\    conn: *wayland.client.Connection,
        , .{
            try cx.camelCase(msg.name),
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
                        return_expr = try std.fmt.allocPrint(
                            cx.allocator,
                            "arg_{s}",
                            .{try cx.snakeCase(arg.name)},
                        );
                        try cx.print(
                            \\comptime HandlerData: type,
                            \\comptime handler: fn(conn: *wayland.client.Connection, {s}: {s}, event: {s}Event, data: HandlerData) void,
                            \\handler_data: HandlerData,
                        , .{
                            try cx.snakeCase(cx.trimPrefix(iface_name)),
                            try cx.pascalCase(cx.trimPrefix(iface_name)),
                            try cx.pascalCase(cx.trimPrefix(iface_name)),
                        });
                    } else {
                        try cx.print(
                            \\comptime T: anytype,
                            \\arg_{s}_version: u32,
                            \\comptime HandlerData: type,
                            \\comptime handler: fn(conn: *wayland.client.Connection, iface: T, event: T.Event, data: HandlerData) void,
                            \\handler_data: HandlerData,
                        , .{
                            try cx.snakeCase(arg.name),
                        });
                        return_type = "T";
                        return_expr = try std.fmt.allocPrint(
                            cx.allocator,
                            "T{{ .id = arg_{s} }}",
                            .{
                                try cx.snakeCase(arg.name),
                            },
                        );
                    }
                    extra_errors = ",OutOfMemory";
                },
                .object => {
                    if (arg.interface) |iface_name| {
                        try cx.print("arg_{s}: {s},", .{
                            try cx.snakeCase(arg.name),
                            try cx.pascalCase(cx.trimPrefix(iface_name)),
                        });
                    } else {
                        try cx.print("arg_{s}: u32,", .{
                            try cx.snakeCase(arg.name),
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
                            \\const handlerWrapperStruct = struct {{
                            \\    pub fn handlerWrapper(
                            \\        h_conn: *wayland.client.Connection,
                            \\        h_msg: wayland.Message,
                            \\        h_fds: *wayland.Buffer,
                            \\    ) void {{
                            \\        // kind of a hack to tell if we're dealing with an interface with no events
                            \\        if (@typeInfo({1s}Event) != .Struct) {{
                            \\          const h_event = {1s}Event.unmarshal(h_conn, h_msg, h_fds);
                            \\          const h_object = {1s}{{ .id = h_msg.id }};
                            \\          const h_object_data = h_conn.object_map.get(h_msg.id) orelse unreachable;
                            \\          const h_handler_data = @intToPtr(HandlerData, h_object_data.user_data);
                            \\          handler(h_conn, h_object, h_event, h_handler_data);
                            \\        }}
                            \\    }}
                            \\}};
                            \\const arg_{0s}_data = try conn.object_map.create();
                            \\arg_{0s}_data.object.* = wayland.client.Connection.ObjectData{{
                            \\    .version = 1,
                            \\    .handler = handlerWrapperStruct.handlerWrapper,
                            \\    .user_data = @ptrToInt(handler_data),
                            \\}};
                            \\const arg_{0s} = {1s}{{
                            \\    .id = arg_{0s}_data.id,
                            \\}};
                        , .{
                            try cx.snakeCase(arg.name),
                            try cx.pascalCase(cx.trimPrefix(iface_name)),
                        });
                    } else {
                        try cx.print(
                            \\const handlerWrapperStruct = struct {{
                            \\    pub fn handlerWrapper(
                            \\        h_conn: *wayland.client.Connection,
                            \\        h_msg: wayland.Message,
                            \\        h_fds: *wayland.Buffer,
                            \\    ) void {{
                            \\        // kind of a hack to tell if we're dealing with an interface with no events
                            \\        if (@typeInfo(T.Event) != .Struct) {{
                            \\            const h_event = T.Event.unmarshal(h_conn, h_msg, h_fds);
                            \\            const h_object = T{{ .id = h_msg.id }};
                            \\            const h_object_data = h_conn.object_map.get(h_msg.id) orelse unreachable;
                            \\            const h_handler_data = @intToPtr(HandlerData, h_object_data.user_data);
                            \\            handler(h_conn, h_object, h_event, h_handler_data);
                            \\        }}
                            \\    }}
                            \\}};
                            \\const arg_{0s}_data = try conn.object_map.create();
                            \\arg_{0s}_data.object.* = wayland.client.Connection.ObjectData{{
                            \\    .version = arg_{0s}_version,
                            \\    .handler = handlerWrapperStruct.handlerWrapper,
                            \\    .user_data = @ptrToInt(handler_data),
                            \\}};
                            \\const arg_{0s} = arg_{0s}_data.id;
                        , .{
                            try cx.snakeCase(arg.name),
                        });
                    }
                },
                else => {},
            }
        }
        try cx.print(
            \\const {s} = {s}{s}.{s}{{
        , .{
            kind.nameLower(),
            try cx.pascalCase(cx.trimPrefix(iface.name)),
            kind.nameUpper(),
            try cx.pascalCase(msg.name),
        });
        for (msg.args) |arg| {
            switch (arg.kind) {
                .new_id => {
                    if (arg.interface) |_| {} else {
                        try cx.print(
                            \\.interface = T.interface,
                            \\.version = arg_{0s}_version,
                        , .{
                            try cx.snakeCase(arg.name),
                        });
                    }
                },
                else => {},
            }
            try cx.print(
                \\.{0s} = arg_{0s},
            , .{
                try cx.snakeCase(arg.name),
            });
        }
        try cx.print(
            \\}};
            \\try request.marshal(self.id, &conn.wire_conn.out);
        , .{});
        if (return_expr.len != 0) {
            try cx.print(
                \\return {s};
            , .{return_expr});
        }
        try cx.print(
            \\}}
        , .{});
    }

    fn emitMessageUnion(cx: *Context, iface: wayland.Interface, msgs: []wayland.Message, kind: MessageKind) !void {
        if (msgs.len == 0) {
            try cx.print(
                \\pub const {s}{s} = struct {{}};
            , .{
                try cx.pascalCase(cx.trimPrefix(iface.name)),
                kind.nameUpper(),
            });
            return;
        }

        try cx.print(
            \\pub const {s}{s} = union(enum(u16)) {{
            \\    pub const Opcode = std.meta.Tag(@This());
        , .{
            try cx.pascalCase(cx.trimPrefix(iface.name)),
            kind.nameUpper(),
        });
        for (msgs) |msg| {
            try cx.print(
                \\{s}: @This().{s},
            , .{
                try cx.snakeCase(msg.name),
                try cx.pascalCase(msg.name),
            });
        }
        for (msgs) |msg|
            try cx.emitMessageStruct(iface, msg, kind);
        try cx.print(
            \\pub fn marshal(
            \\    self: @This(),
            \\    id: u32,
            \\    buf: *wayland.Buffer
            \\) error{{BufferFull}}!void {{
            \\    return switch (self) {{
        , .{});
        for (msgs) |msg| {
            try cx.print(
                \\.{0s} => |msg| msg.marshal(id, buf),
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
            \\) @This() {{
            \\    return switch (@intToEnum(std.meta.Tag(@This()), msg.op)) {{
        , .{});
        for (msgs) |msg| {
            try cx.print(
                \\.{s} => @This(){{ .{s} = @This().{s}.unmarshal(conn, msg, fds) }},
            , .{
                try cx.snakeCase(msg.name),
                try cx.snakeCase(msg.name),
                try cx.pascalCase(msg.name),
            });
        }
        try cx.print(
            \\    }};
            \\}}
        , .{});
        try cx.print(
            \\pub fn format(
            \\    self: @This(),
            \\    comptime fmt: []const u8,
            \\    options: std.fmt.FormatOptions,
            \\    writer: anytype,
            \\) !void {{
            \\    return switch (self) {{
        , .{});
        for (msgs) |msg| {
            try cx.print(
                \\.{0s} => |msg| @TypeOf(msg).format(msg, fmt, options, writer),
            , .{
                try cx.snakeCase(msg.name),
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

    fn emitMessageStruct(cx: *Context, iface: wayland.Interface, msg: wayland.Message, kind: MessageKind) !void {
        try cx.print(
            \\pub const {s} = struct {{
        , .{try cx.pascalCase(msg.name)});
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
                        try cx.print("{s}: wl.{s},", .{
                            try cx.snakeCase(arg.name),
                            try cx.pascalCase(cx.trimPrefix(iface_name)),
                        });
                    } else {
                        try cx.print("interface: []const u8, version: u32, {s}: u32,", .{
                            try cx.snakeCase(arg.name),
                        });
                    }
                },
                .object => {
                    if (arg.interface) |iface_name| {
                        try cx.print("{s}: wl.{s},", .{
                            try cx.snakeCase(arg.name),
                            try cx.pascalCase(cx.trimPrefix(iface_name)),
                        });
                    } else {
                        try cx.print("{s}: u32,", .{
                            try cx.snakeCase(arg.name),
                        });
                    }
                },
            }
        }
        try cx.emitMarshal(msg, kind);
        try cx.emitUnmarshal(msg, kind);
        try cx.emitFormat(iface, msg, kind);
        try cx.print(
            \\}};
        , .{});
    }

    fn emitEnums(cx: *Context, iface: wayland.Interface) !void {
        if (iface.enums.len != 0) {
            try cx.print(
                \\pub const {s}Enum = struct {{
            , .{
                try cx.pascalCase(cx.trimPrefix(iface.name)),
            });
            for (iface.enums) |@"enum"| {
                if (@"enum".bitfield)
                    try cx.emitBitfield(@"enum")
                else
                    try cx.emitEnum(@"enum");
            }
            try cx.print(
                \\}};
            , .{});
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

    fn emitMarshal(cx: *Context, msg: wayland.Message, _: MessageKind) !void {
        const self_name = if (msg.args.len == 0) "_" else "self";
        try cx.print(
            \\pub fn marshal(
            \\    {s}: @This(),
            \\    id: u32,
            \\    buf: *wayland.Buffer,
            \\) error{{BufferFull}}!void {{
        , .{self_name});
        var size_bytes: u32 = 8;
        var size_fds: u32 = 0;
        var extra = std.ArrayList(u8).init(cx.allocator);
        for (msg.args) |arg| switch (arg.kind) {
            .new_id => {
                if (arg.interface == null) {
                    size_bytes += 12;
                    try extra.writer().print(" + ((self.interface.len + 3) / 4 * 4)", .{});
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
                    try extra.writer().print(" + (if (self.{s}) |_arg| ((_arg.len + 3) / 4 * 4) else 0)", .{
                        try cx.snakeCase(arg.name),
                    });
                } else {
                    try extra.writer().print(" + ((self.{s}.len + 3) / 4 * 4)", .{
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
            \\buf.putUInt(@intCast(u32, len << 16) | @enumToInt(Opcode.{3s})) catch unreachable;
        , .{
            size_bytes,
            extra.items,
            size_fds,
            try cx.snakeCase(msg.name),
        });
        for (msg.args) |arg| {
            switch (arg.kind) {
                .new_id, .object => {
                    if (arg.kind == .new_id and arg.interface == null) {
                        try cx.print(
                            \\buf.putString(self.interface) catch unreachable;
                            \\buf.putUInt(self.version) catch unreachable;
                            \\buf.putUInt(self.{s}) catch unreachable;
                        , .{
                            try cx.snakeCase(arg.name),
                        });
                    } else {
                        try cx.print(
                            \\buf.putUInt(self.{s}.id) catch unreachable;
                        , .{
                            try cx.snakeCase(arg.name),
                        });
                    }
                },
                .int => {
                    try cx.print(
                        \\buf.putInt(self.{s}) catch unreachable;
                    , .{try cx.snakeCase(arg.name)});
                },
                .uint => {
                    try cx.print(
                        \\buf.putUInt(self.{s}) catch unreachable;
                    , .{try cx.snakeCase(arg.name)});
                },
                .fixed => {
                    try cx.print(
                        \\buf.putFixed(self.{s}) catch unreachable;
                    , .{try cx.snakeCase(arg.name)});
                },
                .string => {
                    try cx.print(
                        \\buf.putString(self.{s}) catch unreachable;
                    , .{try cx.snakeCase(arg.name)});
                },
                .array => {
                    try cx.print(
                        \\buf.putArray(self.{s}) catch unreachable;
                    , .{try cx.snakeCase(arg.name)});
                },
                .fd => {
                    try cx.print(
                        \\buf.putFd(self.{s}) catch unreachable;
                    , .{try cx.snakeCase(arg.name)});
                },
            }
        }
        try cx.print(
            \\}}
        , .{});
    }

    fn emitUnmarshal(cx: *Context, msg: wayland.Message, _: MessageKind) !void {
        var msg_arg_name: []const u8 = "_";
        var fd_arg_name: []const u8 = "_";
        if (msg.args.len != 0)
            msg_arg_name = "msg";
        for (msg.args) |arg| {
            if (arg.kind == .fd)
                fd_arg_name = "fds";
        }
        try cx.print(
            \\pub fn unmarshal(
            \\    {s}: *wayland.client.Connection,
            \\    {s}: wayland.Message,
            \\    {s}: *wayland.Buffer,
            \\) @This() {{
        , .{
            "_",
            msg_arg_name,
            fd_arg_name,
        });
        if (msg.args.len != 0) {
            try cx.print(
                \\var i: usize = 0;
            , .{});
        }
        try cx.print(
            \\return @This(){{
        , .{});
        for (msg.args) |arg| {
            try cx.print(
                \\.{s} = blk: {{
            , .{
                try cx.snakeCase(arg.name),
            });
            switch (arg.kind) {
                .new_id, .object => {
                    // todo clean this up
                    if (arg.interface) |interface| {
                        try cx.print(
                            \\const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                            \\i += 4;
                            \\break :blk {s}{{ .id = arg_id }};
                        , .{
                            try cx.pascalCase(cx.trimPrefix(interface)),
                        });
                    } else {
                        try cx.print(
                            \\break :blk undefined;
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

    fn emitFormat(cx: *Context, iface: wayland.Interface, msg: wayland.Message, kind: MessageKind) !void {
        const arrow = switch (kind) {
            .request => "->",
            .event => "<-",
        };
        const self_name = if (msg.args.len == 0) "_" else "self";
        try cx.print(
            \\pub fn format(
            \\    {s}: @This(),
            \\    comptime _: []const u8,
            \\    _: std.fmt.FormatOptions,
            \\    writer: anytype,
            \\) !void {{
            \\    try writer.print("{s} {s}.{s}(", .{{}});
        , .{
            self_name,
            arrow,
            iface.name,
            msg.name,
        });
        for (msg.args) |arg, i| {
            switch (arg.kind) {
                .new_id => {
                    try cx.print(
                        \\try writer.print("{0s} {1s}: {{}}", .{{self.{1s}}});
                    , .{ @tagName(arg.kind), arg.name });
                },
                .int, .uint => {
                    try cx.print(
                        \\try writer.print("{0s} {1s}: {{}}", .{{self.{1s}}});
                    , .{ @tagName(arg.kind), arg.name });
                },
                .fixed => {
                    try cx.print(
                        \\try writer.print("{0s} {1s}: {{}}", .{{self.{1s}}});
                    , .{ @tagName(arg.kind), arg.name });
                },
                .string => {
                    try cx.print(
                        \\try writer.print("{0s} {1s}: \"{{s}}\"", .{{self.{1s}}});
                    , .{ @tagName(arg.kind), arg.name });
                },
                .object => {
                    try cx.print(
                        \\try writer.print("{0s} {1s}: {{}}", .{{self.{1s}}});
                    , .{ @tagName(arg.kind), arg.name });
                },
                .array => {
                    try cx.print(
                        \\try writer.print("{0s} {1s}: {{}}", .{{self.{1s}}});
                    , .{ @tagName(arg.kind), arg.name });
                },
                .fd => {
                    try cx.print(
                        \\try writer.print("{0s} {1s}: {{}}", .{{self.{1s}}});
                    , .{ @tagName(arg.kind), arg.name });
                },
            }
            if (i != msg.args.len - 1) {
                try cx.print(
                    \\try writer.print(", ", .{{}});
                , .{});
            }
        }
        try cx.print(
            \\    try writer.print(")", .{{}});
            \\}}
        , .{});
    }
};
