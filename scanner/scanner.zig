const std = @import("std");
const xml = @import("xml.zig");
const wayland = @import("wayland.zig");
const mem = std.mem;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const stdin = std.io.getStdIn().inStream();
    const input = try stdin.readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(input);

    var protocol = try wayland.parseFile(allocator, input);
    defer protocol.deinit();

    var cx = Context{
        .prefix = "wl_",
        .out = std.ArrayList(u8).init(allocator),
        .allocator = allocator,
    };
    defer cx.deinit();
    try cx.emitProtocol(protocol);

    var tree = try std.zig.parse(allocator, cx.out.items);
    defer tree.deinit();

    _ = try std.zig.render(allocator, std.io.getStdOut().outStream(), tree);
}

const Context = struct {
    prefix: []const u8,
    out: std.ArrayList(u8),
    allocator: *mem.Allocator,

    fn deinit(cx: *Context) void {
        cx.out.deinit();
    }

    fn print(cx: *Context, comptime fmt: []const u8, args: var) !void {
        return cx.out.outStream().print(fmt, args);
    }

    fn trim(cx: *Context, name: []const u8) []const u8 {
        var name_ = name;
        if (mem.startsWith(u8, name_, cx.prefix)) {
            name_ = name_[cx.prefix.len..];
        }
        return name_;
    }

    fn recase(cx: *Context, name: []const u8, comptime initial: bool) ![]u8 {
        var new = std.ArrayList(u8).init(cx.allocator);
        errdefer new.deinit();
        var upper = initial;
        for (name) |c, i| {
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

    fn fnName(cx: *Context, name: []const u8) ![]u8 {
        return cx.recase(name, false);
    }

    fn typeName(cx: *Context, name: []const u8) ![]u8 {
        return cx.recase(name, true);
    }

    fn emitProtocol(cx: *Context, proto: wayland.Protocol) !void {
        try cx.print(
            \\pub const wayland = @import("wayland.zig");
            \\
            \\
        , .{});
        for (proto.interfaces) |iface| {
            try cx.emitInterface(iface);
        }
    }

    fn emitInterface(cx: *Context, iface: wayland.Interface) !void {
        const var_name = cx.trim(iface.name);
        const type_name = try cx.typeName(var_name);
        defer cx.allocator.free(type_name);
        try cx.print(
            \\pub const {1} = struct {{
            \\    proxy: wayland.client.Proxy,
            \\
            \\    const interface = "{2}";
            \\    const version = {3};
            \\
            \\    pub fn version({0}: *{1}) u32 {{
            \\        return {0}.proxy.id();
            \\    }}
            \\
            \\
        , .{
            var_name,
            type_name,
            iface.name,
            iface.version,
        });
        try cx.emitMessages(iface.requests, "Request");
        try cx.emitMessages(iface.events, "Event");
        try cx.print(
            \\}};
            \\
            \\
        , .{});
    }

    fn emitMessages(cx: *Context, msgs: var, kind: []const u8) !void {
        try cx.emitMessageEnum(msgs, kind);
        try cx.emitMessageUnion(msgs, kind);
    }

    fn emitMessageEnum(cx: *Context, msgs: var, kind: []const u8) !void {
        try cx.print(
            \\pub const {}Id = enum(u32) {{
        , .{kind});
        for (msgs) |msg, i| {
            try cx.print(
                \\@"{}" = {},
            , .{ msg.name, i });
        }
        try cx.print(
            \\}};
            \\
            \\
        , .{});
    }

    fn emitMessageUnion(cx: *Context, msgs: var, kind: []const u8) !void {
        try cx.print(
            \\pub const {} = union(MessageId) {{
        , .{kind});
        for (msgs) |msg| {
            const type_name = try cx.typeName(msg.name);
            defer cx.allocator.free(type_name);
            try cx.print(
                \\@"{}": {},
            , .{ msg.name, type_name });
        }
        try cx.print("\n\n", .{});
        for (msgs) |msg|
            try cx.emitMessageStruct(msg);
        try cx.print(
            \\}};
            \\
            \\
        , .{});
    }

    fn emitMessageStruct(cx: *Context, msg: var) !void {
        const type_name = try cx.typeName(msg.name);
        defer cx.allocator.free(type_name);
        try cx.print(
            \\pub const {}= struct {{
        , .{type_name});
        for (msg.args) |arg| {
            try cx.print(
                \\@"{}": void,
            , .{arg.name});
        }
        try cx.print(
            \\}};
            \\
            \\
        , .{});
    }
};
