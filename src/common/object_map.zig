const std = @import("std");
const mem = std.mem;

pub const client_start = 0x00000001;
pub const client_end = 0xfeffffff;

pub const server_start = 0xff000000;
pub const server_end = 0xffffffff;

pub const Side = enum {
    server,
    client,
};

pub fn ObjectMap(comptime Object: type, comptime side: Side) type {
    return struct {
        const Self = @This();
        const FreeList = struct {
            const Elem = union(enum) {
                object: Object,
                free: u32,
            };

            array: std.ArrayList(Elem),
            next: u32,

            fn get(list: *FreeList, i: u32) ?*Object {
                if (i < list.array.items.len)
                    return null;
                switch (list.array.items[i]) {
                    .object => |*object| return object,
                    .free => unreachable,
                }
            }

            fn create(list: *FreeList, i: u32) !*Object {
                if (i < list.array.items.len) {
                    const elem = &list.array.items[i];
                    elem.* = Elem{ .object = undefined };
                    return &elem.object;
                } else if (i == list.array.items.len) {
                    const elem = try list.array.addOne();
                    elem.* = Elem{ .object = undefined };
                    list.next += 1;
                    return &elem.object;
                } else {
                    return error.NonSequentialObjectCreation;
                }
            }
        };

        allocator: *mem.Allocator,
        client: FreeList,
        server: FreeList,

        pub fn init(allocator: *mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .client = .{
                    .array = std.ArrayList(FreeList.Elem).init(allocator),
                    .next = 0,
                },
                .server = .{
                    .array = std.ArrayList(FreeList.Elem).init(allocator),
                    .next = 0,
                },
            };
        }

        pub fn deinit(map: *Self) void {
            map.client.array.deinit();
            map.server.array.deinit();
        }

        pub fn get(map: *Self, id: u32) ?*Object {
            return switch (id) {
                0 => unreachable,
                client_start...client_end => map.client.get(id - client_start),
                server_start...server_end => map.server.get(id - server_start),
            };
        }

        pub const NewObject = struct {
            object: *Object,
            id: u32,
        };

        pub fn create(map: *Self, id: ?u32) !NewObject {
            const new_id = id orelse switch (side) {
                .client => client_start + map.client.next,
                .server => server_start + map.server.next,
            };
            const object = switch (new_id) {
                0 => unreachable,
                client_start...client_end => try map.client.create(new_id - client_start),
                server_start...server_end => try map.server.create(new_id - server_start),
            };
            return NewObject{
                .object = object,
                .id = new_id,
            };
        }
    };
}

test "ObjectMap" {
    std.meta.refAllDecls(ObjectMap(u1, .server));
    std.meta.refAllDecls(ObjectMap(u1, .client));
}
