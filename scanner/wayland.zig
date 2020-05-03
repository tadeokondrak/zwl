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
    requests: []Request,
    events: []Event,
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

pub const Request = struct {
    name: []u8,
    destructor: bool,
    since: u32,
    description: ?Description,
    args: []Arg,
    allocator: *mem.Allocator,

    pub fn deinit(req: *Request) void {
        req.allocator.free(req.name);
        if (req.description) |*description|
            description.deinit();
        for (req.args) |*arg|
            arg.deinit();
        req.allocator.free(req.args);
    }
};

pub const Event = struct {
    name: []u8,
    since: u32,
    description: ?Description,
    args: []Arg,
    allocator: *mem.Allocator,

    pub fn deinit(evt: *Event) void {
        evt.allocator.free(evt.name);
        if (evt.description) |*description|
            description.deinit();
        for (evt.args) |*arg|
            arg.deinit();
        evt.allocator.free(evt.args);
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
    summary: []u8,
    interface: []u8,
    allow_null: bool,
    @"enum": []u8,
    allocator: *mem.Allocator,

    pub fn deinit(arg: *Arg) void {
        arg.allocator.free(arg.name);
        arg.allocator.free(arg.summary);
        arg.allocator.free(arg.interface);
        arg.allocator.free(arg.@"enum");
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
        .open => |tag| {
            if (mem.eql(u8, tag, "protocol")) {
                return try parseProtocol(allocator, &parser);
            } else {
                return error.UnexpectedOpen;
            }
        },
        .attr => |attr| {
            return error.UnexpectedEvent;
        },
        .text => |text| {
            return error.UnexpectedEvent;
        },
        .close => |tag| {
            return error.NoProtocol;
        },
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
        .open => |tag| {
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
            } else {
                return error.UnexpectedOpen;
            }
        },
        .attr => |attr| {
            if (mem.eql(u8, attr.name, "name")) {
                if (name != null)
                    return error.DuplicateName;
                name = try xml.dupe(allocator, attr.value);
            } else {
                return error.UnexpectedAttr;
            }
        },
        .text => |text| {
            return error.UnexpectedText;
        },
        .close => |tag| {
            if (mem.eql(u8, tag, "protocol")) {
                return Protocol{
                    .name = name orelse return error.ProtocolNameMissing,
                    .copyright = copyright,
                    .description = description,
                    .interfaces = interfaces.toOwnedSlice(),
                    .allocator = allocator,
                };
            } else {
                return error.UnexpectedClose;
            }
        },
    };
    return error.UnexpectedEof;
}

fn parseCopyright(allocator: *mem.Allocator, parser: *xml.Parser) !Copyright {
    var content = std.ArrayList(u8).init(allocator);
    errdefer content.deinit();
    while (parser.next()) |ev| switch (ev) {
        .open => |tag| {
            return error.UnexpectedOpen;
        },
        .attr => |attr| {
            return error.UnexpectedAttr;
        },
        .text => |text| {
            try xml.append(&content, text);
        },
        .close => |tag| {
            if (mem.eql(u8, tag, "copyright")) {
                return Copyright{
                    .content = content.toOwnedSlice(),
                    .allocator = allocator,
                };
            } else {
                return error.UnexpectedClose;
            }
        },
    };
    return error.UnexpectedEof;
}

fn parseInterface(allocator: *mem.Allocator, parser: *xml.Parser) !Interface {
    var name: ?[]u8 = null;
    errdefer if (name) |n| allocator.free(n);
    var version: u32 = 1;
    var description: ?Description = null;
    errdefer if (description) |*d| d.deinit();
    var requests = std.ArrayList(Request).init(allocator);
    errdefer requests.deinit();
    var events = std.ArrayList(Event).init(allocator);
    errdefer events.deinit();
    var enums = std.ArrayList(Enum).init(allocator);
    errdefer enums.deinit();
    while (parser.next()) |ev| switch (ev) {
        .open => |tag| {
            if (mem.eql(u8, tag, "description")) {
                if (description != null)
                    return error.DuplicateDescription;
                description = try parseDescription(allocator, parser);
            } else if (mem.eql(u8, tag, "request")) {
                var req = try parseRequest(allocator, parser);
                errdefer req.deinit();
                try requests.append(req);
            } else if (mem.eql(u8, tag, "event")) {
                var evt = try parseEvent(allocator, parser);
                errdefer evt.deinit();
                try events.append(evt);
            } else if (mem.eql(u8, tag, "enum")) {
                var enm = try parseEnum(allocator, parser);
                errdefer enm.deinit();
                try enums.append(enm);
            } else {
                return error.UnexpectedElem;
            }
        },
        .attr => |attr| {
            if (mem.eql(u8, attr.name, "name")) {
                if (name != null)
                    return error.DuplicateName;
                name = try xml.dupe(allocator, attr.value);
            } else if (mem.eql(u8, attr.name, "version")) {
                version = try std.fmt.parseInt(u32, attr.value, 10);
            } else {
                return error.UnexpectedAttr;
            }
        },
        .text => |text| {
            return error.UnexpectedText;
        },
        .close => |tag| {
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
            } else {
                return error.UnexpectedClose;
            }
        },
    };
    return error.UnexpectedEof;
}

fn parseRequest(allocator: *mem.Allocator, parser: *xml.Parser) !Request {
    var name: ?[]u8 = null;
    errdefer if (name) |n| allocator.free(n);
    var destructor: bool = false;
    var since: u32 = 1;
    var description: ?Description = null;
    errdefer if (description) |*d| d.deinit();
    var args = std.ArrayList(Arg).init(allocator);
    errdefer args.deinit();
    while (parser.next()) |ev| switch (ev) {
        .open => |tag| {
            if (mem.eql(u8, tag, "description")) {
                if (description != null)
                    return error.DuplicateDescription;
                description = try parseDescription(allocator, parser);
            } else if (mem.eql(u8, tag, "arg")) {
                var arg = try parseArg(allocator, parser);
                errdefer arg.deinit();
                try args.append(arg);
            } else {
                return error.UnexpectedOpen;
            }
        },
        .attr => |attr| {
            if (mem.eql(u8, attr.name, "name")) {
                if (name != null)
                    return error.DuplicateName;
                name = try xml.dupe(allocator, attr.value);
            } else if (mem.eql(u8, attr.name, "type")) {
                if (mem.eql(u8, attr.value, "destructor")) {
                    destructor = true;
                } else {
                    return error.InvalidRequestType;
                }
            } else if (mem.eql(u8, attr.name, "since")) {
                since = try std.fmt.parseInt(u32, attr.value, 10);
            } else {
                return error.UnexpectedAttr;
            }
        },
        .text => |text| {
            return error.UnexpectedText;
        },
        .close => |tag| {
            if (mem.eql(u8, tag, "request")) {
                return Request{
                    .name = name orelse return error.RequestNameMissing,
                    .description = description,
                    .destructor = destructor,
                    .since = since,
                    .args = args.toOwnedSlice(),
                    .allocator = allocator,
                };
            } else {
                return error.UnexpectedClose;
            }
        },
    };
    return error.UnexpectedEof;
}

fn parseEvent(allocator: *mem.Allocator, parser: *xml.Parser) !Event {
    var name: ?[]u8 = null;
    errdefer if (name) |n| allocator.free(n);
    var since: ?u32 = null;
    var description: ?Description = null;
    errdefer if (description) |*d| d.deinit();
    var args = std.ArrayList(Arg).init(allocator);
    errdefer args.deinit();
    while (parser.next()) |ev| switch (ev) {
        .open => |tag| {
            if (mem.eql(u8, tag, "description")) {
                if (description != null)
                    return error.DuplicateDescription;
                description = try parseDescription(allocator, parser);
            } else if (mem.eql(u8, tag, "arg")) {
                var arg = try parseArg(allocator, parser);
                errdefer arg.deinit();
                try args.append(arg);
            } else {
                return error.UnexpectedOpen;
            }
        },
        .attr => |attr| {
            if (mem.eql(u8, attr.name, "name")) {
                if (name != null)
                    return error.DuplicateName;
                name = try xml.dupe(allocator, attr.value);
            } else if (mem.eql(u8, attr.name, "since")) {
                if (since != null)
                    return error.DuplicateSince;
                since = try std.fmt.parseInt(u32, attr.value, 10);
            } else {
                return error.UnexpectedAttr;
            }
        },
        .text => |text| {
            return error.UnexpectedText;
        },
        .close => |tag| {
            if (mem.eql(u8, tag, "event")) {
                return Event{
                    .name = name orelse return error.EventNameMissing,
                    .since = since orelse 1,
                    .description = description,
                    .args = args.toOwnedSlice(),
                    .allocator = allocator,
                };
            } else {
                return error.UnexpectedClose;
            }
        },
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
        .open => |tag| {
            if (mem.eql(u8, tag, "description")) {
                if (description != null)
                    return error.DuplicateDescription;
                description = try parseDescription(allocator, parser);
            } else if (mem.eql(u8, tag, "entry")) {
                var ent = try parseEntry(allocator, parser);
                errdefer ent.deinit();
                try entries.append(ent);
            } else {
                return error.UnexpectedOpen;
            }
        },
        .attr => |attr| {
            if (mem.eql(u8, attr.name, "name")) {
                name = try xml.dupe(allocator, attr.value);
            } else if (mem.eql(u8, attr.name, "since")) {
                since = try std.fmt.parseInt(u32, attr.value, 10);
            } else if (mem.eql(u8, attr.name, "bitfield")) {
                if (mem.eql(u8, attr.value, "true")) {
                    bitfield = true;
                } else if (mem.eql(u8, attr.value, "false")) {
                    bitfield = false;
                } else {
                    return error.InvalidBool;
                }
            } else {
                return error.UnexpectedAttr;
            }
        },
        .text => |text| {
            return error.UnexpectedText;
        },
        .close => |tag| {
            if (mem.eql(u8, tag, "enum")) {
                return Enum{
                    .name = name orelse return error.EnumNameMissing,
                    .since = since,
                    .bitfield = bitfield,
                    .description = description,
                    .entries = entries.toOwnedSlice(),
                    .allocator = allocator,
                };
            } else {
                return error.UnexpectedClose;
            }
        },
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
        .open => |tag| {
            return error.UnexpectedOpen;
        },
        .attr => |attr| {
            if (mem.eql(u8, attr.name, "name")) {
                if (name != null)
                    return error.DuplicateName;
                name = try xml.dupe(allocator, attr.value);
            } else if (mem.eql(u8, attr.name, "value")) {
                // TODO: parse value
            } else if (mem.eql(u8, attr.name, "summary")) {
                if (summary != null)
                    return error.DuplicateSummary;
                summary = try xml.dupe(allocator, attr.value);
            } else if (mem.eql(u8, attr.name, "since")) {
                since = try std.fmt.parseInt(u32, attr.value, 10);
            } else {
                return error.UnexpectedAttr;
            }
        },
        .text => |text| {
            return error.UnexpectedText;
        },
        .close => |tag| {
            if (mem.eql(u8, tag, "entry")) {
                return Entry{
                    .name = name orelse return error.EntryNameMissing,
                    .value = value,
                    .summary = summary orelse "",
                    .since = since,
                    .description = description,
                    .allocator = allocator,
                };
            } else {
                return error.UnexpectedClose;
            }
        },
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
    var name = std.ArrayList(u8).init(allocator);
    errdefer name.deinit();
    var kind: ArgKind = .new_id;
    var summary = std.ArrayList(u8).init(allocator);
    errdefer summary.deinit();
    var interface = std.ArrayList(u8).init(allocator);
    errdefer interface.deinit();
    var allow_null = false;
    var @"enum" = std.ArrayList(u8).init(allocator);
    errdefer @"enum".deinit();
    while (parser.next()) |ev| switch (ev) {
        .open => |tag| {
            return error.UnexpectedOpen;
        },
        .attr => |attr| {
            if (mem.eql(u8, attr.name, "name")) {
                try xml.append(&name, attr.value);
            } else if (mem.eql(u8, attr.name, "type")) {
                kind = try parseArgKind(attr.value);
            } else if (mem.eql(u8, attr.name, "summary")) {
                try xml.append(&summary, attr.value);
            } else if (mem.eql(u8, attr.name, "interface")) {
                try xml.append(&interface, attr.value);
            } else if (mem.eql(u8, attr.name, "allow-null")) {
                if (mem.eql(u8, attr.value, "true")) {
                    allow_null = true;
                } else if (!mem.eql(u8, attr.value, "false")) {
                    return error.InvalidBool;
                }
            } else if (mem.eql(u8, attr.name, "enum")) {
                try xml.append(&@"enum", attr.value);
            } else {
                return error.UnexpectedAttr;
            }
        },
        .text => |text| {
            return error.UnexpectedText;
        },
        .close => |tag| {
            if (mem.eql(u8, tag, "arg")) {
                return Arg{
                    .name = name.toOwnedSlice(),
                    .kind = kind,
                    .summary = summary.toOwnedSlice(),
                    .interface = interface.toOwnedSlice(),
                    .allow_null = allow_null,
                    .@"enum" = @"enum".toOwnedSlice(),
                    .allocator = allocator,
                };
            } else {
                return error.UnexpectedClose;
            }
        },
    };
    return error.UnexpectedEof;
}

fn parseDescription(allocator: *mem.Allocator, parser: *xml.Parser) !Description {
    var summary: ?[]u8 = null;
    errdefer if (summary) |s| allocator.free(s);
    var content = std.ArrayList(u8).init(allocator);
    errdefer content.deinit();
    while (parser.next()) |ev| switch (ev) {
        .open => |tag| {
            return error.UnexpectedOpen;
        },
        .attr => |attr| {
            if (mem.eql(u8, attr.name, "summary")) {
                summary = try xml.dupe(allocator, attr.value);
            } else {
                return error.UnexpectedAttr;
            }
        },
        .text => |text| {
            try xml.append(&content, text);
        },
        .close => |tag| {
            if (mem.eql(u8, tag, "description")) {
                return Description{
                    .summary = summary orelse return error.DescriptionSummaryMissing,
                    .content = content.toOwnedSlice(),
                    .allocator = allocator,
                };
            } else {
                return error.UnexpectedClose;
            }
        },
    };
    return error.UnexpectedEof;
}
