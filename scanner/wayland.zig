pub const std = @import("std");
pub const xml = @import("xml.zig");

pub const mem = std.mem;

pub const Protocol = struct {
    name: []u8,
    copyright: ?Copyright,
    description: ?Description,
    interfaces: []Interface,
    allocator: *mem.Allocator,

    pub fn deinit(proto: *Protocol) void {
        proto.allocator.free(proto.name);
        if (proto.copyright) |*copyright|
            copyright.deinit();
        if (proto.description) |*description|
            description.deinit();
        for (proto.interfaces) |*iface|
            iface.deinit();
        proto.allocator.free(proto.interfaces);
    }
};

pub const Copyright = struct {
    content: []u8,
    allocator: *mem.Allocator,

    pub fn deinit(copy: *Copyright) void {
        copy.allocator.free(copy.content);
    }
};

pub const Interface = struct {
    name: []u8,
    version: u32,
    description: ?Description,
    requests: []Message,
    events: []Message,
    enums: []Enum,
    allocator: *mem.Allocator,

    pub fn deinit(iface: *Interface) void {
        iface.allocator.free(iface.name);
        if (iface.description) |*description|
            description.deinit();
        for (iface.requests) |*request|
            request.deinit();
        iface.allocator.free(iface.requests);
        for (iface.events) |*event|
            event.deinit();
        iface.allocator.free(iface.events);
        for (iface.enums) |*enm|
            enm.deinit();
        iface.allocator.free(iface.enums);
    }
};

pub const Message = struct {
    name: []u8,
    is_destructor: bool,
    since: u32,
    description: ?Description,
    args: []Arg,
    allocator: *mem.Allocator,

    pub fn deinit(msg: *Message) void {
        msg.allocator.free(msg.name);
        if (msg.description) |*description|
            description.deinit();
        for (msg.args) |*arg|
            arg.deinit();
        msg.allocator.free(msg.args);
    }
};

pub const Enum = struct {
    name: []u8,
    since: u32,
    bitfield: bool,
    description: ?Description,
    entries: []Entry,
    allocator: *mem.Allocator,

    pub fn deinit(enm: *Enum) void {
        enm.allocator.free(enm.name);
        if (enm.description) |*description|
            description.deinit();
        for (enm.entries) |*entry|
            entry.deinit();
        enm.allocator.free(enm.entries);
    }
};

pub const Entry = struct {
    name: []u8,
    value: u32,
    summary: ?[]u8,
    since: u32,
    description: ?Description,
    allocator: *mem.Allocator,

    pub fn deinit(ent: *Entry) void {
        ent.allocator.free(ent.name);
        if (ent.summary) |s|
            ent.allocator.free(s);
        if (ent.description) |*desc|
            desc.deinit();
    }
};

pub const Arg = struct {
    name: []u8,
    kind: ArgKind,
    summary: ?[]u8,
    interface: ?[]u8,
    allow_null: bool,
    @"enum": ?[]u8,
    allocator: *mem.Allocator,

    pub fn deinit(arg: *Arg) void {
        arg.allocator.free(arg.name);
        if (arg.summary) |s| arg.allocator.free(s);
        if (arg.interface) |i| arg.allocator.free(i);
        if (arg.@"enum") |e| arg.allocator.free(e);
    }
};

pub const ArgKind = enum {
    new_id,
    int,
    uint,
    fixed,
    string,
    object,
    array,
    fd,
};

pub const Description = struct {
    summary: []u8,
    content: []u8,
    allocator: *mem.Allocator,

    pub fn deinit(desc: *Description) void {
        desc.allocator.free(desc.summary);
        desc.allocator.free(desc.content);
    }
};

pub fn parseFile(allocator: *mem.Allocator, file: []const u8) !Protocol {
    var parser = xml.Parser.init(file);
    while (parser.next()) |ev| switch (ev) {
        .open_tag => |tag| {
            if (mem.eql(u8, tag, "protocol")) {
                return try parseProtocol(allocator, &parser);
            }
        },
        else => {},
    };
    return error.NoProtocol;
}

fn parseProtocol(allocator: *mem.Allocator, parser: *xml.Parser) !Protocol {
    var name: ?[]u8 = null;
    errdefer if (name) |n| allocator.free(n);
    var copyright: ?Copyright = null;
    errdefer if (copyright) |*c| c.deinit();
    var description: ?Description = null;
    errdefer if (description) |*d| d.deinit();
    var interfaces = std.ArrayList(Interface).init(allocator);
    errdefer interfaces.deinit();
    while (parser.next()) |ev| switch (ev) {
        .open_tag => |tag| {
            if (mem.eql(u8, tag, "copyright")) {
                if (copyright != null)
                    return error.DuplicateCopyright;
                copyright = try parseCopyright(allocator, parser);
            } else if (mem.eql(u8, tag, "description")) {
                if (description != null)
                    return error.DuplicateDescription;
                description = try parseDescription(allocator, parser);
            } else if (mem.eql(u8, tag, "interface")) {
                var iface = try parseInterface(allocator, parser);
                errdefer iface.deinit();
                try interfaces.append(iface);
            }
        },
        .attribute => |attr| {
            if (mem.eql(u8, attr.name, "name")) {
                if (name != null)
                    return error.DuplicateName;
                name = try attr.dupeValue(allocator);
            }
        },
        .close_tag => |tag| {
            if (mem.eql(u8, tag, "protocol")) {
                return Protocol{
                    .name = name orelse return error.ProtocolNameMissing,
                    .copyright = copyright,
                    .description = description,
                    .interfaces = interfaces.toOwnedSlice(),
                    .allocator = allocator,
                };
            }
        },
        else => {},
    };
    return error.UnexpectedEof;
}

fn parseCopyright(allocator: *mem.Allocator, parser: *xml.Parser) !Copyright {
    var content = std.ArrayList(u8).init(allocator);
    errdefer content.deinit();
    while (parser.next()) |ev| switch (ev) {
        .character_data => |text| {
            try content.appendSlice(text);
        },
        .close_tag => |tag| {
            if (mem.eql(u8, tag, "copyright")) {
                return Copyright{
                    .content = content.toOwnedSlice(),
                    .allocator = allocator,
                };
            }
        },
        else => {},
    };
    return error.UnexpectedEof;
}

fn parseInterface(allocator: *mem.Allocator, parser: *xml.Parser) !Interface {
    var name: ?[]u8 = null;
    errdefer if (name) |n| allocator.free(n);
    var version: u32 = 1;
    var description: ?Description = null;
    errdefer if (description) |*d| d.deinit();
    var requests = std.ArrayList(Message).init(allocator);
    errdefer requests.deinit();
    var events = std.ArrayList(Message).init(allocator);
    errdefer events.deinit();
    var enums = std.ArrayList(Enum).init(allocator);
    errdefer enums.deinit();
    while (parser.next()) |ev| switch (ev) {
        .open_tag => |tag| {
            if (mem.eql(u8, tag, "description")) {
                if (description != null)
                    return error.DuplicateDescription;
                description = try parseDescription(allocator, parser);
            } else if (mem.eql(u8, tag, "request")) {
                var req = try parseMessage(allocator, parser);
                errdefer req.deinit();
                try requests.append(req);
            } else if (mem.eql(u8, tag, "event")) {
                var evt = try parseMessage(allocator, parser);
                errdefer evt.deinit();
                try events.append(evt);
            } else if (mem.eql(u8, tag, "enum")) {
                var enm = try parseEnum(allocator, parser);
                errdefer enm.deinit();
                try enums.append(enm);
            }
        },
        .attribute => |attr| {
            if (mem.eql(u8, attr.name, "name")) {
                if (name != null)
                    return error.DuplicateName;
                name = try attr.dupeValue(allocator);
            } else if (mem.eql(u8, attr.name, "version")) {
                const value = try attr.dupeValue(allocator);
                defer allocator.free(value);
                version = try std.fmt.parseInt(u32, value, 10);
            }
        },
        .close_tag => |tag| {
            if (mem.eql(u8, tag, "interface")) {
                return Interface{
                    .name = name orelse return error.InterfaceNameMissing,
                    .version = version,
                    .description = description,
                    .requests = requests.toOwnedSlice(),
                    .events = events.toOwnedSlice(),
                    .enums = enums.toOwnedSlice(),
                    .allocator = allocator,
                };
            }
        },
        else => {},
    };
    return error.UnexpectedEof;
}

fn parseMessage(allocator: *mem.Allocator, parser: *xml.Parser) !Message {
    var name: ?[]u8 = null;
    errdefer if (name) |n| allocator.free(n);
    var is_destructor: bool = false;
    var since: u32 = 1;
    var description: ?Description = null;
    errdefer if (description) |*d| d.deinit();
    var args = std.ArrayList(Arg).init(allocator);
    errdefer args.deinit();
    while (parser.next()) |ev| switch (ev) {
        .open_tag => |tag| {
            if (mem.eql(u8, tag, "description")) {
                if (description != null)
                    return error.DuplicateDescription;
                description = try parseDescription(allocator, parser);
            } else if (mem.eql(u8, tag, "arg")) {
                var arg = try parseArg(allocator, parser);
                errdefer arg.deinit();
                try args.append(arg);
            }
        },
        .attribute => |attr| {
            if (mem.eql(u8, attr.name, "name")) {
                if (name != null)
                    return error.DuplicateName;
                name = try attr.dupeValue(allocator);
            } else if (mem.eql(u8, attr.name, "type")) {
                if (attr.valueEql("destructor")) {
                    is_destructor = true;
                } else {
                    return error.InvalidMessageType;
                }
            } else if (mem.eql(u8, attr.name, "since")) {
                const value = try attr.dupeValue(allocator);
                errdefer allocator.free(value);
                since = try std.fmt.parseInt(u32, value, 10);
            }
        },
        .close_tag => |tag| {
            if (mem.eql(u8, tag, "request") or mem.eql(u8, tag, "event")) {
                return Message{
                    .name = name orelse return error.MessageNameMissing,
                    .description = description,
                    .is_destructor = is_destructor,
                    .since = since,
                    .args = args.toOwnedSlice(),
                    .allocator = allocator,
                };
            }
        },
        else => {},
    };
    return error.UnexpectedEof;
}

fn parseEnum(allocator: *mem.Allocator, parser: *xml.Parser) !Enum {
    var name: ?[]u8 = null;
    errdefer if (name) |n| allocator.free(n);
    var since: u32 = 1;
    var bitfield: bool = false;
    var description: ?Description = null;
    errdefer if (description) |*d| d.deinit();
    var entries = std.ArrayList(Entry).init(allocator);
    errdefer entries.deinit();
    while (parser.next()) |ev| switch (ev) {
        .open_tag => |tag| {
            if (mem.eql(u8, tag, "description")) {
                if (description != null)
                    return error.DuplicateDescription;
                description = try parseDescription(allocator, parser);
            } else if (mem.eql(u8, tag, "entry")) {
                var ent = try parseEntry(allocator, parser);
                errdefer ent.deinit();
                try entries.append(ent);
            }
        },
        .attribute => |attr| {
            if (mem.eql(u8, attr.name, "name")) {
                name = try attr.dupeValue(allocator);
            } else if (mem.eql(u8, attr.name, "since")) {
                const value = try attr.dupeValue(allocator);
                defer allocator.free(value);
                since = try std.fmt.parseInt(u32, value, 10);
            } else if (mem.eql(u8, attr.name, "bitfield")) {
                if (attr.valueEql("true")) {
                    bitfield = true;
                } else if (attr.valueEql("false")) {
                    bitfield = false;
                } else {
                    return error.InvalidBool;
                }
            }
        },
        .close_tag => |tag| {
            if (mem.eql(u8, tag, "enum")) {
                return Enum{
                    .name = name orelse return error.EnumNameMissing,
                    .since = since,
                    .bitfield = bitfield,
                    .description = description,
                    .entries = entries.toOwnedSlice(),
                    .allocator = allocator,
                };
            }
        },
        else => {},
    };
    return error.UnexpectedEof;
}

fn parseEntry(allocator: *mem.Allocator, parser: *xml.Parser) !Entry {
    var name: ?[]u8 = null;
    errdefer if (name) |n| allocator.free(n);
    var value: u32 = 0;
    var summary: ?[]u8 = null;
    errdefer if (summary) |s| allocator.free(s);
    var since: u32 = 1;
    var description: ?Description = null;
    while (parser.next()) |ev| switch (ev) {
        .attribute => |attr| {
            if (mem.eql(u8, attr.name, "name")) {
                if (name != null)
                    return error.DuplicateName;
                name = try attr.dupeValue(allocator);
            } else if (mem.eql(u8, attr.name, "value")) {
                const attrvalue = try attr.dupeValue(allocator);
                defer allocator.free(attrvalue);
                if (attr.valueStartsWith("0x"))
                    value = try std.fmt.parseInt(u32, attrvalue[2..], 16)
                else
                    value = try std.fmt.parseInt(u32, attrvalue, 10);
            } else if (mem.eql(u8, attr.name, "summary")) {
                if (summary != null)
                    return error.DuplicateSummary;
                summary = try attr.dupeValue(allocator);
            } else if (mem.eql(u8, attr.name, "since")) {
                const attrvalue = try attr.dupeValue(allocator);
                defer allocator.free(attrvalue);
                since = try std.fmt.parseInt(u32, attrvalue, 10);
            }
        },
        .close_tag => |tag| {
            if (mem.eql(u8, tag, "entry")) {
                return Entry{
                    .name = name orelse return error.EntryNameMissing,
                    .value = value,
                    .summary = summary orelse "",
                    .since = since,
                    .description = description,
                    .allocator = allocator,
                };
            }
        },
        else => {},
    };
    return error.UnexpectedEof;
}

fn parseArgKind(string: []const u8) !ArgKind {
    if (mem.eql(u8, string, "new_id")) {
        return .new_id;
    } else if (mem.eql(u8, string, "int")) {
        return .int;
    } else if (mem.eql(u8, string, "uint")) {
        return .uint;
    } else if (mem.eql(u8, string, "fixed")) {
        return .fixed;
    } else if (mem.eql(u8, string, "string")) {
        return .string;
    } else if (mem.eql(u8, string, "object")) {
        return .object;
    } else if (mem.eql(u8, string, "array")) {
        return .array;
    } else if (mem.eql(u8, string, "fd")) {
        return .fd;
    } else {
        return error.InvalidArgKind;
    }
}

fn parseArg(allocator: *mem.Allocator, parser: *xml.Parser) !Arg {
    var name: ?[]u8 = null;
    errdefer if (name) |n| allocator.free(n);
    var kind: ArgKind = .new_id;
    var summary: ?[]u8 = null;
    errdefer if (summary) |s| allocator.free(s);
    var interface: ?[]u8 = null;
    errdefer if (interface) |i| allocator.free(i);
    var allow_null = false;
    var @"enum": ?[]u8 = null;
    errdefer if (@"enum") |e| allocator.free(e);
    while (parser.next()) |ev| switch (ev) {
        .attribute => |attr| {
            if (mem.eql(u8, attr.name, "name")) {
                if (name != null)
                    return error.DuplicateName;
                name = try attr.dupeValue(allocator);
            } else if (mem.eql(u8, attr.name, "type")) {
                const value = try attr.dupeValue(allocator);
                defer allocator.free(value);
                kind = try parseArgKind(value);
            } else if (mem.eql(u8, attr.name, "summary")) {
                if (summary != null)
                    return error.DuplicateSummary;
                summary = try attr.dupeValue(allocator);
            } else if (mem.eql(u8, attr.name, "interface")) {
                if (interface != null)
                    return error.DuplicateInterface;
                interface = try attr.dupeValue(allocator);
            } else if (mem.eql(u8, attr.name, "allow-null")) {
                if (attr.valueEql("true")) {
                    allow_null = true;
                } else if (!attr.valueEql("false")) {
                    return error.InvalidBool;
                }
            } else if (mem.eql(u8, attr.name, "enum")) {
                if (@"enum" != null)
                    return error.DuplicateEnum;
                @"enum" = try attr.dupeValue(allocator);
            }
        },
        .close_tag => |tag| {
            if (mem.eql(u8, tag, "arg")) {
                return Arg{
                    .name = name orelse return error.ArgNameMissing,
                    .kind = kind,
                    .summary = summary,
                    .interface = interface,
                    .allow_null = allow_null,
                    .@"enum" = @"enum",
                    .allocator = allocator,
                };
            }
        },
        else => {},
    };
    return error.UnexpectedEof;
}

fn parseDescription(allocator: *mem.Allocator, parser: *xml.Parser) !Description {
    var summary: ?[]u8 = null;
    errdefer if (summary) |s| allocator.free(s);
    var content = std.ArrayList(u8).init(allocator);
    errdefer content.deinit();
    while (parser.next()) |ev| switch (ev) {
        .attribute => |attr| {
            if (mem.eql(u8, attr.name, "summary")) {
                summary = try attr.dupeValue(allocator);
            }
        },
        .character_data => |text| {
            try content.appendSlice(text);
        },
        .close_tag => |tag| {
            if (mem.eql(u8, tag, "description")) {
                return Description{
                    .summary = summary orelse return error.DescriptionSummaryMissing,
                    .content = content.toOwnedSlice(),
                    .allocator = allocator,
                };
            }
        },
        else => {},
    };
    return error.UnexpectedEof;
}
