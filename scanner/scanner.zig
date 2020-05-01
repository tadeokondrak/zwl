const std = @import("std");
const xml = @import("xml.zig");

const mem = std.mem;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const stdin = std.io.getStdIn().inStream();
    const input = try stdin.readAllAlloc(allocator, std.math.maxInt(usize));
    var parser = xml.Parser.init(input);
    const protocol = blk: {
        while (parser.next()) |ev| switch (ev) {
            .open => |tag| if (mem.eql(u8, tag, "protocol"))
                break :blk try Protocol.parse(&parser),
            .attr => return error.UnexpectedEvent,
            .text => return error.UnexpectedEvent,
            .close => return error.NoProtocol,
        };
        return error.NoProtocol;
    };
}

const Protocol = struct {
    name: []const u8 = "",
    copyright: ?Copyright = null,
    description: ?Description = null,
    interface: Interface = Interface{},

    fn parse(parser: *xml.Parser) !Protocol {
        var proto = Protocol{};
        while (parser.next()) |ev| switch (ev) {
            .open => |tag| if (mem.eql(u8, tag, "copyright")) {
                proto.copyright = try Copyright.parse(parser);
            } else if (mem.eql(u8, tag, "description")) {
                proto.description = try Description.parse(parser);
            } else if (mem.eql(u8, tag, "interface")) {
                std.debug.warn("interface\n", .{});
                proto.interface = try Interface.parse(parser);
            },
            .attr => |attr| if (mem.eql(u8, attr.name, "name")) {
                proto.name = attr.value;
            },
            .text => |text| {},
            .close => |tag| if (mem.eql(u8, tag, "protocol")) return proto,
        };
        return error.UnexpectedEof;
    }
};

const Copyright = struct {
    fn parse(parser: *xml.Parser) !Copyright {
        var copy = Copyright{};
        while (parser.next()) |ev| switch (ev) {
            .open => |tag| {},
            .attr => |attr| {},
            .text => |text| {},
            .close => |tag| if (mem.eql(u8, tag, "copyright")) return copy,
        };
        return error.UnexpectedEof;
    }
};

const Description = struct {
    fn parse(parser: *xml.Parser) !Description {
        var desc = Description{};
        while (parser.next()) |ev| switch (ev) {
            .open => |tag| {},
            .attr => |attr| {},
            .text => |text| {},
            .close => |tag| if (mem.eql(u8, tag, "description")) return desc,
        };
        return error.UnexpectedEof;
    }
};

const Interface = struct {
    fn parse(parser: *xml.Parser) !Interface {
        var iface = Interface{};
        while (parser.next()) |ev| switch (ev) {
            .open => |tag| {},
            .attr => |attr| {},
            .text => |text| {},
            .close => |tag| if (mem.eql(u8, tag, "interface")) return iface,
        };
        return error.UnexpectedEof;
    }
};
