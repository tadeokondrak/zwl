const std = @import("std");

pub fn eql(escaped: []const u8, unescaped: []const u8) bool {
    var unescaper = Unescape.init(escaped);
    for (unescaped) |c|
        if ((unescaper.next() orelse return false) != c)
            return false;
    return true;
}

pub fn append(list: *std.ArrayList(u8), escaped: []const u8) !void {
    var unescaper = Unescape.init(escaped);
    while (unescaper.next()) |c|
        try list.append(c);
}

pub fn dupe(allocator: *std.mem.Allocator, escaped: []const u8) ![]u8 {
    var string = std.ArrayList(u8).init(allocator);
    try append(&string, escaped);
    return string.toOwnedSlice();
}

pub const Unescape = struct {
    escaped: []const u8,

    pub fn init(escaped: []const u8) Unescape {
        return .{ .escaped = escaped };
    }

    pub fn next(u: *Unescape) ?u8 {
        if (u.escaped.len == 0)
            return null;
        const c = u.escaped[0];
        u.escaped = u.escaped[1..];
        if (c == '&') {
            if (u.accept("lt;"))
                return '<'
            else if (u.accept("gt;"))
                return '>'
            else if (u.accept("amp;"))
                return '&'
            else if (u.accept("apos;"))
                return '\''
            else if (u.accept("quot;"))
                return '"'; // "
        }
        return c;
    }

    fn accept(u: *Unescape, str: []const u8) bool {
        if (str.len < u.escaped.len and std.mem.startsWith(u8, u.escaped, str)) {
            u.escaped = u.escaped[str.len..];
            return true;
        }
        return false;
    }
};

pub const Parser = struct {
    doc: []const u8,
    state: union(enum) {
        normal,
        attrs: struct { tag: []const u8, self_closing: bool },
    },

    pub const Event = union(enum) {
        open: []const u8,
        attr: struct { name: []const u8, value: []const u8 },
        text: []const u8,
        close: []const u8,
    };

    pub fn init(doc: []const u8) Parser {
        return .{ .doc = doc, .state = .normal };
    }

    pub fn next(p: *Parser) ?Event {
        switch (p.state) {
            .normal => switch (p.peekChar() orelse return null) {
                ' ', '\t', '\n', '\r' => {
                    p.advance(1);
                    return p.next();
                },
                '<' => {
                    p.advance(1);
                    switch (p.peekChar() orelse return null) {
                        '?' => {
                            _ = p.skipTo(">");
                            p.advance(1);
                            return p.next();
                        },
                        '/' => {
                            p.advance(1);
                            const tag = p.skipTo(">");
                            p.advance(1);
                            return Event{ .close = tag };
                        },
                        '!' => {
                            p.advance(1);
                            switch (p.peekChar() orelse return null) {
                                '-' => {
                                    _ = p.skipTo("-->");
                                    p.advance(3);
                                    return p.next();
                                },
                                '[' => {
                                    _ = p.skipTo("CDATA[");
                                    p.advance(6);
                                    const text = p.skipTo("]]>");
                                    p.advance(3);
                                    return Event{ .text = text };
                                },
                                else => return null,
                            }
                        },
                        else => {
                            const end = p.indexOf(">") orelse return null;
                            const self_closing = p.doc[end - 1] == '/';
                            if (p.indexOf(" ")) |space| blk: {
                                if (space > end)
                                    break :blk;
                                const tag = p.skipTo(" ");
                                p.state = .{ .attrs = .{ .tag = tag, .self_closing = self_closing } };
                                return Event{ .open = tag };
                            }
                            const tag = p.skipTo(if (self_closing) "/" else ">");
                            p.state = .{ .attrs = .{ .tag = tag, .self_closing = self_closing } };
                            return Event{ .open = tag };
                        },
                    }
                },
                else => return Event{ .text = p.skipTo("<") },
            },
            .attrs => |s| {
                switch (p.peekChar() orelse return null) {
                    ' ', '\t', '\n', '\r', '/' => {
                        p.advance(1);
                        return p.next();
                    },
                    '>' => {
                        p.advance(1);
                        p.state = .normal;
                        if (s.self_closing) {
                            return Event{ .close = s.tag };
                        } else {
                            return p.next();
                        }
                    },
                    else => {
                        const name = p.skipTo("=");
                        p.advance(2);
                        const value = p.skipTo("\"");
                        p.advance(1);
                        return Event{ .attr = .{ .name = name, .value = value } };
                    },
                }
            },
        }
    }

    fn peekChar(p: *Parser) ?u8 {
        return if (p.doc.len > 0) p.doc[0] else null;
    }

    fn indexOf(p: *Parser, pat: []const u8) ?usize {
        return std.mem.indexOf(u8, p.doc, pat);
    }

    fn advance(p: *Parser, n: usize) void {
        if (p.doc.len >= n)
            p.doc = p.doc[n..];
    }

    fn skipTo(p: *Parser, pat: []const u8) []const u8 {
        const end = p.indexOf(pat) orelse return "";
        const match = p.doc[0..end];
        p.doc = p.doc[end..];
        return match;
    }
};
