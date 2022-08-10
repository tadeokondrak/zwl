const std = @import("std");
const wayland = @import("wayland.zig");
pub const Display = struct {
    object: wayland.client.Object,
    pub const interface = "wl_display";
    pub const version = 1;
    pub usingnamespace struct {
        pub fn sync() error{BufferFull}!void {}
        pub fn getRegistry() error{BufferFull}!void {}
    };
    pub const Enum = struct {
        pub const Error = enum(u32) {
            invalid_object = 0,
            invalid_method = 1,
            no_memory = 2,
            implementation = 3,
            pub fn toInt(@"error": Error) u32 {
                return @enumToInt(@"error");
            }
            pub fn fromInt(int: u32) Error {
                return @intToEnum(Error, int);
            }
        };
    };
    pub const Request = union(enum(u16)) {
        sync: SyncRequest = 0,
        get_registry: GetRegistryRequest = 1,
        pub const SyncRequest = struct {
            callback: Callback,
            pub fn marshal(
                sync: SyncRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(sync.callback.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SyncRequest {
                var i: usize = 0;
                return SyncRequest{
                    .callback = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                sync: SyncRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_display.sync(");
                try writer.writeAll("callback: ");
                try writer.print("{any}", .{sync.callback});
                try writer.writeAll(")");
            }
        };
        pub const GetRegistryRequest = struct {
            registry: Registry,
            pub fn marshal(
                get_registry: GetRegistryRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(get_registry.registry.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) GetRegistryRequest {
                var i: usize = 0;
                return GetRegistryRequest{
                    .registry = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                get_registry: GetRegistryRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_display.get_registry(");
                try writer.writeAll("registry: ");
                try writer.print("{any}", .{get_registry.registry});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .sync => |sync| sync.marshal(id, buf),
                .get_registry => |get_registry| get_registry.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .sync => Request{ .sync = SyncRequest.unmarshal(conn, msg, fds) },
                .get_registry => Request{ .get_registry = GetRegistryRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .sync => |sync| sync._format(fmt, options, writer),
                .get_registry => |get_registry| get_registry._format(fmt, options, writer),
            };
        }
    };
    pub const Event = union(enum(u16)) {
        @"error": ErrorEvent = 0,
        delete_id: DeleteIdEvent = 1,
        pub const ErrorEvent = struct {
            object_id: ?wayland.client.Object,
            code: u32,
            message: [:0]const u8,
            pub fn marshal(
                @"error": ErrorEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 20 + ((@"error".message.len + 3) / 4 * 4);
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(@"error".object_id.object.id) catch unreachable;
                buf.putUInt(@"error".code) catch unreachable;
                buf.putString(@"error".message) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) ErrorEvent {
                var i: usize = 0;
                return ErrorEvent{
                    .object_id = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .code = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .message = blk: {
                        const arg_len = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        const arg_padded_len = (arg_len + 3) / 4 * 4;
                        const arg = msg.data[i + 4 .. i + 4 + arg_len - 1 :0];
                        i += 4 + arg_padded_len;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                @"error": ErrorEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_display.error(");
                try writer.writeAll("object_id: ");
                try writer.print("{any}", .{@"error".object_id});
                try writer.writeAll(", ");
                try writer.writeAll("code: ");
                try writer.print("{any}u", .{@"error".code});
                try writer.writeAll(", ");
                try writer.writeAll("message: ");
                try writer.print("\"{}\"", .{@import("std").zig.fmtEscapes(@"error".message)});
                try writer.writeAll(")");
            }
        };
        pub const DeleteIdEvent = struct {
            id: u32,
            pub fn marshal(
                delete_id: DeleteIdEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(delete_id.id) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) DeleteIdEvent {
                var i: usize = 0;
                return DeleteIdEvent{
                    .id = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                delete_id: DeleteIdEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_display.delete_id(");
                try writer.writeAll("id: ");
                try writer.print("{any}u", .{delete_id.id});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(event: Event, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (event) {
                .@"error" => |@"error"| @"error".marshal(id, buf),
                .delete_id => |delete_id| delete_id.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Event {
            return switch (@intToEnum(std.meta.Tag(Event), msg.op)) {
                .@"error" => Event{ .@"error" = ErrorEvent.unmarshal(conn, msg, fds) },
                .delete_id => Event{ .delete_id = DeleteIdEvent.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            event: Event,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (event) {
                .@"error" => |@"error"| @"error"._format(fmt, options, writer),
                .delete_id => |delete_id| delete_id._format(fmt, options, writer),
            };
        }
    };
};
pub const Registry = struct {
    object: wayland.client.Object,
    pub const interface = "wl_registry";
    pub const version = 1;
    pub usingnamespace struct {
        pub fn bind() error{BufferFull}!void {}
    };
    pub const Enum = struct {};
    pub const Request = union(enum(u16)) {
        bind: BindRequest = 0,
        pub const BindRequest = struct {
            name: u32,
            interface: []const u8,
            version: u32,
            id: wayland.client.Object,
            pub fn marshal(
                bind: BindRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 24 + ((bind.interface.len + 3) / 4 * 4);
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(bind.name) catch unreachable;
                buf.putString(bind.interface) catch unreachable;
                buf.putUInt(bind.version) catch unreachable;
                buf.putUInt(bind.id.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) BindRequest {
                var i: usize = 0;
                return BindRequest{
                    .name = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .id = blk: {
                        _ = conn;
                        break :blk undefined;
                    },
                };
            }
            pub fn _format(
                bind: BindRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_registry.bind(");
                try writer.writeAll("name: ");
                try writer.print("{any}u", .{bind.name});
                try writer.writeAll(", ");
                try writer.writeAll("id: ");
                try writer.print("{any} {any} {any}", .{ bind.interface, bind.version, bind.id });
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .bind => |bind| bind.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .bind => Request{ .bind = BindRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .bind => |bind| bind._format(fmt, options, writer),
            };
        }
    };
    pub const Event = union(enum(u16)) {
        global: GlobalEvent = 0,
        global_remove: GlobalRemoveEvent = 1,
        pub const GlobalEvent = struct {
            name: u32,
            interface: [:0]const u8,
            version: u32,
            pub fn marshal(
                global: GlobalEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 20 + ((global.interface.len + 3) / 4 * 4);
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(global.name) catch unreachable;
                buf.putString(global.interface) catch unreachable;
                buf.putUInt(global.version) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) GlobalEvent {
                var i: usize = 0;
                return GlobalEvent{
                    .name = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .interface = blk: {
                        const arg_len = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        const arg_padded_len = (arg_len + 3) / 4 * 4;
                        const arg = msg.data[i + 4 .. i + 4 + arg_len - 1 :0];
                        i += 4 + arg_padded_len;
                        break :blk arg;
                    },
                    .version = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                global: GlobalEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_registry.global(");
                try writer.writeAll("name: ");
                try writer.print("{any}u", .{global.name});
                try writer.writeAll(", ");
                try writer.writeAll("interface: ");
                try writer.print("\"{}\"", .{@import("std").zig.fmtEscapes(global.interface)});
                try writer.writeAll(", ");
                try writer.writeAll("version: ");
                try writer.print("{any}u", .{global.version});
                try writer.writeAll(")");
            }
        };
        pub const GlobalRemoveEvent = struct {
            name: u32,
            pub fn marshal(
                global_remove: GlobalRemoveEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(global_remove.name) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) GlobalRemoveEvent {
                var i: usize = 0;
                return GlobalRemoveEvent{
                    .name = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                global_remove: GlobalRemoveEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_registry.global_remove(");
                try writer.writeAll("name: ");
                try writer.print("{any}u", .{global_remove.name});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(event: Event, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (event) {
                .global => |global| global.marshal(id, buf),
                .global_remove => |global_remove| global_remove.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Event {
            return switch (@intToEnum(std.meta.Tag(Event), msg.op)) {
                .global => Event{ .global = GlobalEvent.unmarshal(conn, msg, fds) },
                .global_remove => Event{ .global_remove = GlobalRemoveEvent.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            event: Event,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (event) {
                .global => |global| global._format(fmt, options, writer),
                .global_remove => |global_remove| global_remove._format(fmt, options, writer),
            };
        }
    };
};
pub const Callback = struct {
    object: wayland.client.Object,
    pub const interface = "wl_callback";
    pub const version = 1;
    pub usingnamespace struct {};
    pub const Enum = struct {};
    pub const Event = union(enum(u16)) {
        done: DoneEvent = 0,
        pub const DoneEvent = struct {
            callback_data: u32,
            pub fn marshal(
                done: DoneEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(done.callback_data) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) DoneEvent {
                var i: usize = 0;
                return DoneEvent{
                    .callback_data = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                done: DoneEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_callback.done(");
                try writer.writeAll("callback_data: ");
                try writer.print("{any}u", .{done.callback_data});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(event: Event, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (event) {
                .done => |done| done.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Event {
            return switch (@intToEnum(std.meta.Tag(Event), msg.op)) {
                .done => Event{ .done = DoneEvent.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            event: Event,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (event) {
                .done => |done| done._format(fmt, options, writer),
            };
        }
    };
};
pub const Compositor = struct {
    object: wayland.client.Object,
    pub const interface = "wl_compositor";
    pub const version = 4;
    pub usingnamespace struct {
        pub fn createSurface() error{BufferFull}!void {}
        pub fn createRegion() error{BufferFull}!void {}
    };
    pub const Enum = struct {};
    pub const Request = union(enum(u16)) {
        create_surface: CreateSurfaceRequest = 0,
        create_region: CreateRegionRequest = 1,
        pub const CreateSurfaceRequest = struct {
            id: Surface,
            pub fn marshal(
                create_surface: CreateSurfaceRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(create_surface.id.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) CreateSurfaceRequest {
                var i: usize = 0;
                return CreateSurfaceRequest{
                    .id = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                create_surface: CreateSurfaceRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_compositor.create_surface(");
                try writer.writeAll("id: ");
                try writer.print("{any}", .{create_surface.id});
                try writer.writeAll(")");
            }
        };
        pub const CreateRegionRequest = struct {
            id: Region,
            pub fn marshal(
                create_region: CreateRegionRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(create_region.id.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) CreateRegionRequest {
                var i: usize = 0;
                return CreateRegionRequest{
                    .id = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                create_region: CreateRegionRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_compositor.create_region(");
                try writer.writeAll("id: ");
                try writer.print("{any}", .{create_region.id});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .create_surface => |create_surface| create_surface.marshal(id, buf),
                .create_region => |create_region| create_region.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .create_surface => Request{ .create_surface = CreateSurfaceRequest.unmarshal(conn, msg, fds) },
                .create_region => Request{ .create_region = CreateRegionRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .create_surface => |create_surface| create_surface._format(fmt, options, writer),
                .create_region => |create_region| create_region._format(fmt, options, writer),
            };
        }
    };
};
pub const ShmPool = struct {
    object: wayland.client.Object,
    pub const interface = "wl_shm_pool";
    pub const version = 1;
    pub usingnamespace struct {
        pub fn createBuffer() error{BufferFull}!void {}
        pub fn destroy() error{BufferFull}!void {}
        pub fn resize() error{BufferFull}!void {}
    };
    pub const Enum = struct {};
    pub const Request = union(enum(u16)) {
        create_buffer: CreateBufferRequest = 0,
        destroy: DestroyRequest = 1,
        resize: ResizeRequest = 2,
        pub const CreateBufferRequest = struct {
            id: Buffer,
            offset: i32,
            width: i32,
            height: i32,
            stride: i32,
            format: u32,
            pub fn marshal(
                create_buffer: CreateBufferRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 32;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(create_buffer.id.object.id) catch unreachable;
                buf.putInt(create_buffer.offset) catch unreachable;
                buf.putInt(create_buffer.width) catch unreachable;
                buf.putInt(create_buffer.height) catch unreachable;
                buf.putInt(create_buffer.stride) catch unreachable;
                buf.putUInt(create_buffer.format) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) CreateBufferRequest {
                var i: usize = 0;
                return CreateBufferRequest{
                    .id = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .offset = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .width = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .height = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .stride = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .format = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                create_buffer: CreateBufferRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shm_pool.create_buffer(");
                try writer.writeAll("id: ");
                try writer.print("{any}", .{create_buffer.id});
                try writer.writeAll(", ");
                try writer.writeAll("offset: ");
                try writer.print("{any}i", .{create_buffer.offset});
                try writer.writeAll(", ");
                try writer.writeAll("width: ");
                try writer.print("{any}i", .{create_buffer.width});
                try writer.writeAll(", ");
                try writer.writeAll("height: ");
                try writer.print("{any}i", .{create_buffer.height});
                try writer.writeAll(", ");
                try writer.writeAll("stride: ");
                try writer.print("{any}i", .{create_buffer.stride});
                try writer.writeAll(", ");
                try writer.writeAll("format: ");
                try writer.print("{any}u", .{create_buffer.format});
                try writer.writeAll(")");
            }
        };
        pub const DestroyRequest = struct {
            pub fn marshal(
                _: DestroyRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) DestroyRequest {
                return DestroyRequest{};
            }
            pub fn _format(
                _: DestroyRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shm_pool.destroy(");
                try writer.writeAll(")");
            }
        };
        pub const ResizeRequest = struct {
            size: i32,
            pub fn marshal(
                resize: ResizeRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 2) catch unreachable;
                buf.putInt(resize.size) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) ResizeRequest {
                var i: usize = 0;
                return ResizeRequest{
                    .size = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                resize: ResizeRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shm_pool.resize(");
                try writer.writeAll("size: ");
                try writer.print("{any}i", .{resize.size});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .create_buffer => |create_buffer| create_buffer.marshal(id, buf),
                .destroy => |destroy| destroy.marshal(id, buf),
                .resize => |resize| resize.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .create_buffer => Request{ .create_buffer = CreateBufferRequest.unmarshal(conn, msg, fds) },
                .destroy => Request{ .destroy = DestroyRequest.unmarshal(conn, msg, fds) },
                .resize => Request{ .resize = ResizeRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .create_buffer => |create_buffer| create_buffer._format(fmt, options, writer),
                .destroy => |destroy| destroy._format(fmt, options, writer),
                .resize => |resize| resize._format(fmt, options, writer),
            };
        }
    };
};
pub const Shm = struct {
    object: wayland.client.Object,
    pub const interface = "wl_shm";
    pub const version = 1;
    pub usingnamespace struct {
        pub fn createPool() error{BufferFull}!void {}
    };
    pub const Enum = struct {
        pub const Error = enum(u32) {
            invalid_format = 0,
            invalid_stride = 1,
            invalid_fd = 2,
            pub fn toInt(@"error": Error) u32 {
                return @enumToInt(@"error");
            }
            pub fn fromInt(int: u32) Error {
                return @intToEnum(Error, int);
            }
        };
        pub const Format = enum(u32) {
            argb8888 = 0,
            xrgb8888 = 1,
            c8 = 538982467,
            rgb332 = 943867730,
            bgr233 = 944916290,
            xrgb4444 = 842093144,
            xbgr4444 = 842089048,
            rgbx4444 = 842094674,
            bgrx4444 = 842094658,
            argb4444 = 842093121,
            abgr4444 = 842089025,
            rgba4444 = 842088786,
            bgra4444 = 842088770,
            xrgb1555 = 892424792,
            xbgr1555 = 892420696,
            rgbx5551 = 892426322,
            bgrx5551 = 892426306,
            argb1555 = 892424769,
            abgr1555 = 892420673,
            rgba5551 = 892420434,
            bgra5551 = 892420418,
            rgb565 = 909199186,
            bgr565 = 909199170,
            rgb888 = 875710290,
            bgr888 = 875710274,
            xbgr8888 = 875709016,
            rgbx8888 = 875714642,
            bgrx8888 = 875714626,
            abgr8888 = 875708993,
            rgba8888 = 875708754,
            bgra8888 = 875708738,
            xrgb2101010 = 808669784,
            xbgr2101010 = 808665688,
            rgbx1010102 = 808671314,
            bgrx1010102 = 808671298,
            argb2101010 = 808669761,
            abgr2101010 = 808665665,
            rgba1010102 = 808665426,
            bgra1010102 = 808665410,
            yuyv = 1448695129,
            yvyu = 1431918169,
            uyvy = 1498831189,
            vyuy = 1498765654,
            ayuv = 1448433985,
            nv12 = 842094158,
            nv21 = 825382478,
            nv16 = 909203022,
            nv61 = 825644622,
            yuv410 = 961959257,
            yvu410 = 961893977,
            yuv411 = 825316697,
            yvu411 = 825316953,
            yuv420 = 842093913,
            yvu420 = 842094169,
            yuv422 = 909202777,
            yvu422 = 909203033,
            yuv444 = 875713881,
            yvu444 = 875714137,
            r8 = 538982482,
            r16 = 540422482,
            rg88 = 943212370,
            gr88 = 943215175,
            rg1616 = 842221394,
            gr1616 = 842224199,
            xrgb16161616f = 1211388504,
            xbgr16161616f = 1211384408,
            argb16161616f = 1211388481,
            abgr16161616f = 1211384385,
            xyuv8888 = 1448434008,
            vuy888 = 875713878,
            vuy101010 = 808670550,
            y210 = 808530521,
            y212 = 842084953,
            y216 = 909193817,
            y410 = 808531033,
            y412 = 842085465,
            y416 = 909194329,
            xvyu2101010 = 808670808,
            xvyu12_16161616 = 909334104,
            xvyu16161616 = 942954072,
            y0l0 = 810299481,
            x0l0 = 810299480,
            y0l2 = 843853913,
            x0l2 = 843853912,
            yuv420_8bit = 942691673,
            yuv420_10bit = 808539481,
            xrgb8888_a8 = 943805016,
            xbgr8888_a8 = 943800920,
            rgbx8888_a8 = 943806546,
            bgrx8888_a8 = 943806530,
            rgb888_a8 = 943798354,
            bgr888_a8 = 943798338,
            rgb565_a8 = 943797586,
            bgr565_a8 = 943797570,
            nv24 = 875714126,
            nv42 = 842290766,
            p210 = 808530512,
            p010 = 808530000,
            p012 = 842084432,
            p016 = 909193296,
            axbxgxrx106106106106 = 808534593,
            nv15 = 892425806,
            q410 = 808531025,
            q401 = 825242705,
            pub fn toInt(format: Format) u32 {
                return @enumToInt(format);
            }
            pub fn fromInt(int: u32) Format {
                return @intToEnum(Format, int);
            }
        };
    };
    pub const Request = union(enum(u16)) {
        create_pool: CreatePoolRequest = 0,
        pub const CreatePoolRequest = struct {
            id: ShmPool,
            fd: std.os.fd_t,
            size: i32,
            pub fn marshal(
                create_pool: CreatePoolRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 16;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 1)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(create_pool.id.object.id) catch unreachable;
                buf.putFd(create_pool.fd) catch unreachable;
                buf.putInt(create_pool.size) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                fds: *wayland.Buffer,
            ) CreatePoolRequest {
                var i: usize = 0;
                return CreatePoolRequest{
                    .id = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .fd = blk: {
                        _ = fds;
                        break :blk undefined;
                    },
                    .size = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                create_pool: CreatePoolRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shm.create_pool(");
                try writer.writeAll("id: ");
                try writer.print("{any}", .{create_pool.id});
                try writer.writeAll(", ");
                try writer.writeAll("fd: ");
                try writer.print("{any}", .{create_pool.fd});
                try writer.writeAll(", ");
                try writer.writeAll("size: ");
                try writer.print("{any}i", .{create_pool.size});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .create_pool => |create_pool| create_pool.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .create_pool => Request{ .create_pool = CreatePoolRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .create_pool => |create_pool| create_pool._format(fmt, options, writer),
            };
        }
    };
    pub const Event = union(enum(u16)) {
        format: FormatEvent = 0,
        pub const FormatEvent = struct {
            format: u32,
            pub fn marshal(
                format: FormatEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(format.format) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) FormatEvent {
                var i: usize = 0;
                return FormatEvent{
                    .format = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                format: FormatEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shm.format(");
                try writer.writeAll("format: ");
                try writer.print("{any}u", .{format.format});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(event: Event, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (event) {
                .format => |format| format.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Event {
            return switch (@intToEnum(std.meta.Tag(Event), msg.op)) {
                .format => Event{ .format = FormatEvent.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            event: Event,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (event) {
                .format => |format| format._format(fmt, options, writer),
            };
        }
    };
};
pub const Buffer = struct {
    object: wayland.client.Object,
    pub const interface = "wl_buffer";
    pub const version = 1;
    pub usingnamespace struct {
        pub fn destroy() error{BufferFull}!void {}
    };
    pub const Enum = struct {};
    pub const Request = union(enum(u16)) {
        destroy: DestroyRequest = 0,
        pub const DestroyRequest = struct {
            pub fn marshal(
                _: DestroyRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) DestroyRequest {
                return DestroyRequest{};
            }
            pub fn _format(
                _: DestroyRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_buffer.destroy(");
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .destroy => |destroy| destroy.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .destroy => Request{ .destroy = DestroyRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .destroy => |destroy| destroy._format(fmt, options, writer),
            };
        }
    };
    pub const Event = union(enum(u16)) {
        release: ReleaseEvent = 0,
        pub const ReleaseEvent = struct {
            pub fn marshal(
                _: ReleaseEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) ReleaseEvent {
                return ReleaseEvent{};
            }
            pub fn _format(
                _: ReleaseEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_buffer.release(");
                try writer.writeAll(")");
            }
        };
        pub fn marshal(event: Event, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (event) {
                .release => |release| release.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Event {
            return switch (@intToEnum(std.meta.Tag(Event), msg.op)) {
                .release => Event{ .release = ReleaseEvent.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            event: Event,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (event) {
                .release => |release| release._format(fmt, options, writer),
            };
        }
    };
};
pub const DataOffer = struct {
    object: wayland.client.Object,
    pub const interface = "wl_data_offer";
    pub const version = 3;
    pub usingnamespace struct {
        pub fn accept() error{BufferFull}!void {}
        pub fn receive() error{BufferFull}!void {}
        pub fn destroy() error{BufferFull}!void {}
        pub fn finish() error{BufferFull}!void {}
        pub fn setActions() error{BufferFull}!void {}
    };
    pub const Enum = struct {
        pub const Error = enum(u32) {
            invalid_finish = 0,
            invalid_action_mask = 1,
            invalid_action = 2,
            invalid_offer = 3,
            pub fn toInt(@"error": Error) u32 {
                return @enumToInt(@"error");
            }
            pub fn fromInt(int: u32) Error {
                return @intToEnum(Error, int);
            }
        };
    };
    pub const Request = union(enum(u16)) {
        accept: AcceptRequest = 0,
        receive: ReceiveRequest = 1,
        destroy: DestroyRequest = 2,
        finish: FinishRequest = 3,
        set_actions: SetActionsRequest = 4,
        pub const AcceptRequest = struct {
            serial: u32,
            mime_type: ?[:0]const u8,
            pub fn marshal(
                accept: AcceptRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 16 + (if (accept.mime_type) |_arg| ((_arg.len + 3) / 4 * 4) else 0);
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(accept.serial) catch unreachable;
                buf.putString(accept.mime_type) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) AcceptRequest {
                var i: usize = 0;
                return AcceptRequest{
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .mime_type = blk: {
                        const arg_len = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        const arg_padded_len = (arg_len + 3) / 4 * 4;
                        const arg = msg.data[i + 4 .. i + 4 + arg_len - 1 :0];
                        i += 4 + arg_padded_len;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                accept: AcceptRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_offer.accept(");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{accept.serial});
                try writer.writeAll(", ");
                try writer.writeAll("mime_type: ");
                try writer.print("\"{}\"", .{@import("std").zig.fmtEscapes(accept.mime_type)});
                try writer.writeAll(")");
            }
        };
        pub const ReceiveRequest = struct {
            mime_type: [:0]const u8,
            fd: std.os.fd_t,
            pub fn marshal(
                receive: ReceiveRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12 + ((receive.mime_type.len + 3) / 4 * 4);
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 1)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putString(receive.mime_type) catch unreachable;
                buf.putFd(receive.fd) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                fds: *wayland.Buffer,
            ) ReceiveRequest {
                var i: usize = 0;
                return ReceiveRequest{
                    .mime_type = blk: {
                        const arg_len = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        const arg_padded_len = (arg_len + 3) / 4 * 4;
                        const arg = msg.data[i + 4 .. i + 4 + arg_len - 1 :0];
                        i += 4 + arg_padded_len;
                        break :blk arg;
                    },
                    .fd = blk: {
                        _ = fds;
                        break :blk undefined;
                    },
                };
            }
            pub fn _format(
                receive: ReceiveRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_offer.receive(");
                try writer.writeAll("mime_type: ");
                try writer.print("\"{}\"", .{@import("std").zig.fmtEscapes(receive.mime_type)});
                try writer.writeAll(", ");
                try writer.writeAll("fd: ");
                try writer.print("{any}", .{receive.fd});
                try writer.writeAll(")");
            }
        };
        pub const DestroyRequest = struct {
            pub fn marshal(
                _: DestroyRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 2) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) DestroyRequest {
                return DestroyRequest{};
            }
            pub fn _format(
                _: DestroyRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_offer.destroy(");
                try writer.writeAll(")");
            }
        };
        pub const FinishRequest = struct {
            pub fn marshal(
                _: FinishRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 3) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) FinishRequest {
                return FinishRequest{};
            }
            pub fn _format(
                _: FinishRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_offer.finish(");
                try writer.writeAll(")");
            }
        };
        pub const SetActionsRequest = struct {
            dnd_actions: u32,
            preferred_action: u32,
            pub fn marshal(
                set_actions: SetActionsRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 16;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 4) catch unreachable;
                buf.putUInt(set_actions.dnd_actions) catch unreachable;
                buf.putUInt(set_actions.preferred_action) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SetActionsRequest {
                var i: usize = 0;
                return SetActionsRequest{
                    .dnd_actions = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .preferred_action = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                set_actions: SetActionsRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_offer.set_actions(");
                try writer.writeAll("dnd_actions: ");
                try writer.print("{any}u", .{set_actions.dnd_actions});
                try writer.writeAll(", ");
                try writer.writeAll("preferred_action: ");
                try writer.print("{any}u", .{set_actions.preferred_action});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .accept => |accept| accept.marshal(id, buf),
                .receive => |receive| receive.marshal(id, buf),
                .destroy => |destroy| destroy.marshal(id, buf),
                .finish => |finish| finish.marshal(id, buf),
                .set_actions => |set_actions| set_actions.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .accept => Request{ .accept = AcceptRequest.unmarshal(conn, msg, fds) },
                .receive => Request{ .receive = ReceiveRequest.unmarshal(conn, msg, fds) },
                .destroy => Request{ .destroy = DestroyRequest.unmarshal(conn, msg, fds) },
                .finish => Request{ .finish = FinishRequest.unmarshal(conn, msg, fds) },
                .set_actions => Request{ .set_actions = SetActionsRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .accept => |accept| accept._format(fmt, options, writer),
                .receive => |receive| receive._format(fmt, options, writer),
                .destroy => |destroy| destroy._format(fmt, options, writer),
                .finish => |finish| finish._format(fmt, options, writer),
                .set_actions => |set_actions| set_actions._format(fmt, options, writer),
            };
        }
    };
    pub const Event = union(enum(u16)) {
        offer: OfferEvent = 0,
        source_actions: SourceActionsEvent = 1,
        action: ActionEvent = 2,
        pub const OfferEvent = struct {
            mime_type: [:0]const u8,
            pub fn marshal(
                offer: OfferEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12 + ((offer.mime_type.len + 3) / 4 * 4);
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putString(offer.mime_type) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) OfferEvent {
                var i: usize = 0;
                return OfferEvent{
                    .mime_type = blk: {
                        const arg_len = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        const arg_padded_len = (arg_len + 3) / 4 * 4;
                        const arg = msg.data[i + 4 .. i + 4 + arg_len - 1 :0];
                        i += 4 + arg_padded_len;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                offer: OfferEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_offer.offer(");
                try writer.writeAll("mime_type: ");
                try writer.print("\"{}\"", .{@import("std").zig.fmtEscapes(offer.mime_type)});
                try writer.writeAll(")");
            }
        };
        pub const SourceActionsEvent = struct {
            source_actions: u32,
            pub fn marshal(
                source_actions: SourceActionsEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(source_actions.source_actions) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SourceActionsEvent {
                var i: usize = 0;
                return SourceActionsEvent{
                    .source_actions = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                source_actions: SourceActionsEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_offer.source_actions(");
                try writer.writeAll("source_actions: ");
                try writer.print("{any}u", .{source_actions.source_actions});
                try writer.writeAll(")");
            }
        };
        pub const ActionEvent = struct {
            dnd_action: u32,
            pub fn marshal(
                action: ActionEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 2) catch unreachable;
                buf.putUInt(action.dnd_action) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) ActionEvent {
                var i: usize = 0;
                return ActionEvent{
                    .dnd_action = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                action: ActionEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_offer.action(");
                try writer.writeAll("dnd_action: ");
                try writer.print("{any}u", .{action.dnd_action});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(event: Event, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (event) {
                .offer => |offer| offer.marshal(id, buf),
                .source_actions => |source_actions| source_actions.marshal(id, buf),
                .action => |action| action.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Event {
            return switch (@intToEnum(std.meta.Tag(Event), msg.op)) {
                .offer => Event{ .offer = OfferEvent.unmarshal(conn, msg, fds) },
                .source_actions => Event{ .source_actions = SourceActionsEvent.unmarshal(conn, msg, fds) },
                .action => Event{ .action = ActionEvent.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            event: Event,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (event) {
                .offer => |offer| offer._format(fmt, options, writer),
                .source_actions => |source_actions| source_actions._format(fmt, options, writer),
                .action => |action| action._format(fmt, options, writer),
            };
        }
    };
};
pub const DataSource = struct {
    object: wayland.client.Object,
    pub const interface = "wl_data_source";
    pub const version = 3;
    pub usingnamespace struct {
        pub fn offer() error{BufferFull}!void {}
        pub fn destroy() error{BufferFull}!void {}
        pub fn setActions() error{BufferFull}!void {}
    };
    pub const Enum = struct {
        pub const Error = enum(u32) {
            invalid_action_mask = 0,
            invalid_source = 1,
            pub fn toInt(@"error": Error) u32 {
                return @enumToInt(@"error");
            }
            pub fn fromInt(int: u32) Error {
                return @intToEnum(Error, int);
            }
        };
    };
    pub const Request = union(enum(u16)) {
        offer: OfferRequest = 0,
        destroy: DestroyRequest = 1,
        set_actions: SetActionsRequest = 2,
        pub const OfferRequest = struct {
            mime_type: [:0]const u8,
            pub fn marshal(
                offer: OfferRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12 + ((offer.mime_type.len + 3) / 4 * 4);
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putString(offer.mime_type) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) OfferRequest {
                var i: usize = 0;
                return OfferRequest{
                    .mime_type = blk: {
                        const arg_len = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        const arg_padded_len = (arg_len + 3) / 4 * 4;
                        const arg = msg.data[i + 4 .. i + 4 + arg_len - 1 :0];
                        i += 4 + arg_padded_len;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                offer: OfferRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_source.offer(");
                try writer.writeAll("mime_type: ");
                try writer.print("\"{}\"", .{@import("std").zig.fmtEscapes(offer.mime_type)});
                try writer.writeAll(")");
            }
        };
        pub const DestroyRequest = struct {
            pub fn marshal(
                _: DestroyRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) DestroyRequest {
                return DestroyRequest{};
            }
            pub fn _format(
                _: DestroyRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_source.destroy(");
                try writer.writeAll(")");
            }
        };
        pub const SetActionsRequest = struct {
            dnd_actions: u32,
            pub fn marshal(
                set_actions: SetActionsRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 2) catch unreachable;
                buf.putUInt(set_actions.dnd_actions) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SetActionsRequest {
                var i: usize = 0;
                return SetActionsRequest{
                    .dnd_actions = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                set_actions: SetActionsRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_source.set_actions(");
                try writer.writeAll("dnd_actions: ");
                try writer.print("{any}u", .{set_actions.dnd_actions});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .offer => |offer| offer.marshal(id, buf),
                .destroy => |destroy| destroy.marshal(id, buf),
                .set_actions => |set_actions| set_actions.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .offer => Request{ .offer = OfferRequest.unmarshal(conn, msg, fds) },
                .destroy => Request{ .destroy = DestroyRequest.unmarshal(conn, msg, fds) },
                .set_actions => Request{ .set_actions = SetActionsRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .offer => |offer| offer._format(fmt, options, writer),
                .destroy => |destroy| destroy._format(fmt, options, writer),
                .set_actions => |set_actions| set_actions._format(fmt, options, writer),
            };
        }
    };
    pub const Event = union(enum(u16)) {
        target: TargetEvent = 0,
        send: SendEvent = 1,
        cancelled: CancelledEvent = 2,
        dnd_drop_performed: DndDropPerformedEvent = 3,
        dnd_finished: DndFinishedEvent = 4,
        action: ActionEvent = 5,
        pub const TargetEvent = struct {
            mime_type: ?[:0]const u8,
            pub fn marshal(
                target: TargetEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12 + (if (target.mime_type) |_arg| ((_arg.len + 3) / 4 * 4) else 0);
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putString(target.mime_type) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) TargetEvent {
                var i: usize = 0;
                return TargetEvent{
                    .mime_type = blk: {
                        const arg_len = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        const arg_padded_len = (arg_len + 3) / 4 * 4;
                        const arg = msg.data[i + 4 .. i + 4 + arg_len - 1 :0];
                        i += 4 + arg_padded_len;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                target: TargetEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_source.target(");
                try writer.writeAll("mime_type: ");
                try writer.print("\"{}\"", .{@import("std").zig.fmtEscapes(target.mime_type)});
                try writer.writeAll(")");
            }
        };
        pub const SendEvent = struct {
            mime_type: [:0]const u8,
            fd: std.os.fd_t,
            pub fn marshal(
                send: SendEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12 + ((send.mime_type.len + 3) / 4 * 4);
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 1)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putString(send.mime_type) catch unreachable;
                buf.putFd(send.fd) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                fds: *wayland.Buffer,
            ) SendEvent {
                var i: usize = 0;
                return SendEvent{
                    .mime_type = blk: {
                        const arg_len = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        const arg_padded_len = (arg_len + 3) / 4 * 4;
                        const arg = msg.data[i + 4 .. i + 4 + arg_len - 1 :0];
                        i += 4 + arg_padded_len;
                        break :blk arg;
                    },
                    .fd = blk: {
                        _ = fds;
                        break :blk undefined;
                    },
                };
            }
            pub fn _format(
                send: SendEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_source.send(");
                try writer.writeAll("mime_type: ");
                try writer.print("\"{}\"", .{@import("std").zig.fmtEscapes(send.mime_type)});
                try writer.writeAll(", ");
                try writer.writeAll("fd: ");
                try writer.print("{any}", .{send.fd});
                try writer.writeAll(")");
            }
        };
        pub const CancelledEvent = struct {
            pub fn marshal(
                _: CancelledEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 2) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) CancelledEvent {
                return CancelledEvent{};
            }
            pub fn _format(
                _: CancelledEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_source.cancelled(");
                try writer.writeAll(")");
            }
        };
        pub const DndDropPerformedEvent = struct {
            pub fn marshal(
                _: DndDropPerformedEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 3) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) DndDropPerformedEvent {
                return DndDropPerformedEvent{};
            }
            pub fn _format(
                _: DndDropPerformedEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_source.dnd_drop_performed(");
                try writer.writeAll(")");
            }
        };
        pub const DndFinishedEvent = struct {
            pub fn marshal(
                _: DndFinishedEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 4) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) DndFinishedEvent {
                return DndFinishedEvent{};
            }
            pub fn _format(
                _: DndFinishedEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_source.dnd_finished(");
                try writer.writeAll(")");
            }
        };
        pub const ActionEvent = struct {
            dnd_action: u32,
            pub fn marshal(
                action: ActionEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 5) catch unreachable;
                buf.putUInt(action.dnd_action) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) ActionEvent {
                var i: usize = 0;
                return ActionEvent{
                    .dnd_action = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                action: ActionEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_source.action(");
                try writer.writeAll("dnd_action: ");
                try writer.print("{any}u", .{action.dnd_action});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(event: Event, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (event) {
                .target => |target| target.marshal(id, buf),
                .send => |send| send.marshal(id, buf),
                .cancelled => |cancelled| cancelled.marshal(id, buf),
                .dnd_drop_performed => |dnd_drop_performed| dnd_drop_performed.marshal(id, buf),
                .dnd_finished => |dnd_finished| dnd_finished.marshal(id, buf),
                .action => |action| action.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Event {
            return switch (@intToEnum(std.meta.Tag(Event), msg.op)) {
                .target => Event{ .target = TargetEvent.unmarshal(conn, msg, fds) },
                .send => Event{ .send = SendEvent.unmarshal(conn, msg, fds) },
                .cancelled => Event{ .cancelled = CancelledEvent.unmarshal(conn, msg, fds) },
                .dnd_drop_performed => Event{ .dnd_drop_performed = DndDropPerformedEvent.unmarshal(conn, msg, fds) },
                .dnd_finished => Event{ .dnd_finished = DndFinishedEvent.unmarshal(conn, msg, fds) },
                .action => Event{ .action = ActionEvent.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            event: Event,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (event) {
                .target => |target| target._format(fmt, options, writer),
                .send => |send| send._format(fmt, options, writer),
                .cancelled => |cancelled| cancelled._format(fmt, options, writer),
                .dnd_drop_performed => |dnd_drop_performed| dnd_drop_performed._format(fmt, options, writer),
                .dnd_finished => |dnd_finished| dnd_finished._format(fmt, options, writer),
                .action => |action| action._format(fmt, options, writer),
            };
        }
    };
};
pub const DataDevice = struct {
    object: wayland.client.Object,
    pub const interface = "wl_data_device";
    pub const version = 3;
    pub usingnamespace struct {
        pub fn startDrag() error{BufferFull}!void {}
        pub fn setSelection() error{BufferFull}!void {}
        pub fn release() error{BufferFull}!void {}
    };
    pub const Enum = struct {
        pub const Error = enum(u32) {
            role = 0,
            pub fn toInt(@"error": Error) u32 {
                return @enumToInt(@"error");
            }
            pub fn fromInt(int: u32) Error {
                return @intToEnum(Error, int);
            }
        };
    };
    pub const Request = union(enum(u16)) {
        start_drag: StartDragRequest = 0,
        set_selection: SetSelectionRequest = 1,
        release: ReleaseRequest = 2,
        pub const StartDragRequest = struct {
            source: ?DataSource,
            origin: ?Surface,
            icon: ?Surface,
            serial: u32,
            pub fn marshal(
                start_drag: StartDragRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 24;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(if (start_drag.source) |_obj| _obj.object.id else 0) catch unreachable;
                buf.putUInt(start_drag.origin.object.id) catch unreachable;
                buf.putUInt(if (start_drag.icon) |_obj| _obj.object.id else 0) catch unreachable;
                buf.putUInt(start_drag.serial) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) StartDragRequest {
                var i: usize = 0;
                return StartDragRequest{
                    .source = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .origin = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .icon = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                start_drag: StartDragRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_device.start_drag(");
                try writer.writeAll("source: ");
                try writer.print("{any}", .{start_drag.source});
                try writer.writeAll(", ");
                try writer.writeAll("origin: ");
                try writer.print("{any}", .{start_drag.origin});
                try writer.writeAll(", ");
                try writer.writeAll("icon: ");
                try writer.print("{any}", .{start_drag.icon});
                try writer.writeAll(", ");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{start_drag.serial});
                try writer.writeAll(")");
            }
        };
        pub const SetSelectionRequest = struct {
            source: ?DataSource,
            serial: u32,
            pub fn marshal(
                set_selection: SetSelectionRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 16;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(if (set_selection.source) |_obj| _obj.object.id else 0) catch unreachable;
                buf.putUInt(set_selection.serial) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SetSelectionRequest {
                var i: usize = 0;
                return SetSelectionRequest{
                    .source = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                set_selection: SetSelectionRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_device.set_selection(");
                try writer.writeAll("source: ");
                try writer.print("{any}", .{set_selection.source});
                try writer.writeAll(", ");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{set_selection.serial});
                try writer.writeAll(")");
            }
        };
        pub const ReleaseRequest = struct {
            pub fn marshal(
                _: ReleaseRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 2) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) ReleaseRequest {
                return ReleaseRequest{};
            }
            pub fn _format(
                _: ReleaseRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_device.release(");
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .start_drag => |start_drag| start_drag.marshal(id, buf),
                .set_selection => |set_selection| set_selection.marshal(id, buf),
                .release => |release| release.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .start_drag => Request{ .start_drag = StartDragRequest.unmarshal(conn, msg, fds) },
                .set_selection => Request{ .set_selection = SetSelectionRequest.unmarshal(conn, msg, fds) },
                .release => Request{ .release = ReleaseRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .start_drag => |start_drag| start_drag._format(fmt, options, writer),
                .set_selection => |set_selection| set_selection._format(fmt, options, writer),
                .release => |release| release._format(fmt, options, writer),
            };
        }
    };
    pub const Event = union(enum(u16)) {
        data_offer: DataOfferEvent = 0,
        enter: EnterEvent = 1,
        leave: LeaveEvent = 2,
        motion: MotionEvent = 3,
        drop: DropEvent = 4,
        selection: SelectionEvent = 5,
        pub const DataOfferEvent = struct {
            id: DataOffer,
            pub fn marshal(
                data_offer: DataOfferEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(data_offer.id.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) DataOfferEvent {
                var i: usize = 0;
                return DataOfferEvent{
                    .id = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                data_offer: DataOfferEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_device.data_offer(");
                try writer.writeAll("id: ");
                try writer.print("{any}", .{data_offer.id});
                try writer.writeAll(")");
            }
        };
        pub const EnterEvent = struct {
            serial: u32,
            surface: ?Surface,
            x: f64,
            y: f64,
            id: ?DataOffer,
            pub fn marshal(
                enter: EnterEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 28;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(enter.serial) catch unreachable;
                buf.putUInt(enter.surface.object.id) catch unreachable;
                buf.putFixed(enter.x) catch unreachable;
                buf.putFixed(enter.y) catch unreachable;
                buf.putUInt(if (enter.id) |_obj| _obj.object.id else 0) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) EnterEvent {
                var i: usize = 0;
                return EnterEvent{
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .surface = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .x = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .y = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .id = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                enter: EnterEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_device.enter(");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{enter.serial});
                try writer.writeAll(", ");
                try writer.writeAll("surface: ");
                try writer.print("{any}", .{enter.surface});
                try writer.writeAll(", ");
                try writer.writeAll("x: ");
                try writer.print("{any}f", .{enter.x});
                try writer.writeAll(", ");
                try writer.writeAll("y: ");
                try writer.print("{any}f", .{enter.y});
                try writer.writeAll(", ");
                try writer.writeAll("id: ");
                try writer.print("{any}", .{enter.id});
                try writer.writeAll(")");
            }
        };
        pub const LeaveEvent = struct {
            pub fn marshal(
                _: LeaveEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 2) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) LeaveEvent {
                return LeaveEvent{};
            }
            pub fn _format(
                _: LeaveEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_device.leave(");
                try writer.writeAll(")");
            }
        };
        pub const MotionEvent = struct {
            time: u32,
            x: f64,
            y: f64,
            pub fn marshal(
                motion: MotionEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 20;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 3) catch unreachable;
                buf.putUInt(motion.time) catch unreachable;
                buf.putFixed(motion.x) catch unreachable;
                buf.putFixed(motion.y) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) MotionEvent {
                var i: usize = 0;
                return MotionEvent{
                    .time = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .x = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .y = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                motion: MotionEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_device.motion(");
                try writer.writeAll("time: ");
                try writer.print("{any}u", .{motion.time});
                try writer.writeAll(", ");
                try writer.writeAll("x: ");
                try writer.print("{any}f", .{motion.x});
                try writer.writeAll(", ");
                try writer.writeAll("y: ");
                try writer.print("{any}f", .{motion.y});
                try writer.writeAll(")");
            }
        };
        pub const DropEvent = struct {
            pub fn marshal(
                _: DropEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 4) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) DropEvent {
                return DropEvent{};
            }
            pub fn _format(
                _: DropEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_device.drop(");
                try writer.writeAll(")");
            }
        };
        pub const SelectionEvent = struct {
            id: ?DataOffer,
            pub fn marshal(
                selection: SelectionEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 5) catch unreachable;
                buf.putUInt(if (selection.id) |_obj| _obj.object.id else 0) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SelectionEvent {
                var i: usize = 0;
                return SelectionEvent{
                    .id = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                selection: SelectionEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_device.selection(");
                try writer.writeAll("id: ");
                try writer.print("{any}", .{selection.id});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(event: Event, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (event) {
                .data_offer => |data_offer| data_offer.marshal(id, buf),
                .enter => |enter| enter.marshal(id, buf),
                .leave => |leave| leave.marshal(id, buf),
                .motion => |motion| motion.marshal(id, buf),
                .drop => |drop| drop.marshal(id, buf),
                .selection => |selection| selection.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Event {
            return switch (@intToEnum(std.meta.Tag(Event), msg.op)) {
                .data_offer => Event{ .data_offer = DataOfferEvent.unmarshal(conn, msg, fds) },
                .enter => Event{ .enter = EnterEvent.unmarshal(conn, msg, fds) },
                .leave => Event{ .leave = LeaveEvent.unmarshal(conn, msg, fds) },
                .motion => Event{ .motion = MotionEvent.unmarshal(conn, msg, fds) },
                .drop => Event{ .drop = DropEvent.unmarshal(conn, msg, fds) },
                .selection => Event{ .selection = SelectionEvent.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            event: Event,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (event) {
                .data_offer => |data_offer| data_offer._format(fmt, options, writer),
                .enter => |enter| enter._format(fmt, options, writer),
                .leave => |leave| leave._format(fmt, options, writer),
                .motion => |motion| motion._format(fmt, options, writer),
                .drop => |drop| drop._format(fmt, options, writer),
                .selection => |selection| selection._format(fmt, options, writer),
            };
        }
    };
};
pub const DataDeviceManager = struct {
    object: wayland.client.Object,
    pub const interface = "wl_data_device_manager";
    pub const version = 3;
    pub usingnamespace struct {
        pub fn createDataSource() error{BufferFull}!void {}
        pub fn getDataDevice() error{BufferFull}!void {}
    };
    pub const Enum = struct {
        pub const DndAction = packed struct {
            none: bool = false,
            copy: bool = false,
            move: bool = false,
            ask: bool = false,
            pub fn toInt(dnd_action: DndAction) u32 {
                var result: u32 = 0;
                if (dnd_action.none)
                    result &= 0;
                if (dnd_action.copy)
                    result &= 1;
                if (dnd_action.move)
                    result &= 2;
                if (dnd_action.ask)
                    result &= 4;
                return result;
            }
            pub fn fromInt(int: u32) DndAction {
                return DndAction{
                    .none = (int & 0) != 0,
                    .copy = (int & 1) != 0,
                    .move = (int & 2) != 0,
                    .ask = (int & 4) != 0,
                };
            }
        };
    };
    pub const Request = union(enum(u16)) {
        create_data_source: CreateDataSourceRequest = 0,
        get_data_device: GetDataDeviceRequest = 1,
        pub const CreateDataSourceRequest = struct {
            id: DataSource,
            pub fn marshal(
                create_data_source: CreateDataSourceRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(create_data_source.id.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) CreateDataSourceRequest {
                var i: usize = 0;
                return CreateDataSourceRequest{
                    .id = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                create_data_source: CreateDataSourceRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_device_manager.create_data_source(");
                try writer.writeAll("id: ");
                try writer.print("{any}", .{create_data_source.id});
                try writer.writeAll(")");
            }
        };
        pub const GetDataDeviceRequest = struct {
            id: DataDevice,
            seat: ?Seat,
            pub fn marshal(
                get_data_device: GetDataDeviceRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 16;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(get_data_device.id.object.id) catch unreachable;
                buf.putUInt(get_data_device.seat.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) GetDataDeviceRequest {
                var i: usize = 0;
                return GetDataDeviceRequest{
                    .id = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .seat = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                get_data_device: GetDataDeviceRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_data_device_manager.get_data_device(");
                try writer.writeAll("id: ");
                try writer.print("{any}", .{get_data_device.id});
                try writer.writeAll(", ");
                try writer.writeAll("seat: ");
                try writer.print("{any}", .{get_data_device.seat});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .create_data_source => |create_data_source| create_data_source.marshal(id, buf),
                .get_data_device => |get_data_device| get_data_device.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .create_data_source => Request{ .create_data_source = CreateDataSourceRequest.unmarshal(conn, msg, fds) },
                .get_data_device => Request{ .get_data_device = GetDataDeviceRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .create_data_source => |create_data_source| create_data_source._format(fmt, options, writer),
                .get_data_device => |get_data_device| get_data_device._format(fmt, options, writer),
            };
        }
    };
};
pub const Shell = struct {
    object: wayland.client.Object,
    pub const interface = "wl_shell";
    pub const version = 1;
    pub usingnamespace struct {
        pub fn getShellSurface() error{BufferFull}!void {}
    };
    pub const Enum = struct {
        pub const Error = enum(u32) {
            role = 0,
            pub fn toInt(@"error": Error) u32 {
                return @enumToInt(@"error");
            }
            pub fn fromInt(int: u32) Error {
                return @intToEnum(Error, int);
            }
        };
    };
    pub const Request = union(enum(u16)) {
        get_shell_surface: GetShellSurfaceRequest = 0,
        pub const GetShellSurfaceRequest = struct {
            id: ShellSurface,
            surface: ?Surface,
            pub fn marshal(
                get_shell_surface: GetShellSurfaceRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 16;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(get_shell_surface.id.object.id) catch unreachable;
                buf.putUInt(get_shell_surface.surface.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) GetShellSurfaceRequest {
                var i: usize = 0;
                return GetShellSurfaceRequest{
                    .id = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .surface = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                get_shell_surface: GetShellSurfaceRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shell.get_shell_surface(");
                try writer.writeAll("id: ");
                try writer.print("{any}", .{get_shell_surface.id});
                try writer.writeAll(", ");
                try writer.writeAll("surface: ");
                try writer.print("{any}", .{get_shell_surface.surface});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .get_shell_surface => |get_shell_surface| get_shell_surface.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .get_shell_surface => Request{ .get_shell_surface = GetShellSurfaceRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .get_shell_surface => |get_shell_surface| get_shell_surface._format(fmt, options, writer),
            };
        }
    };
};
pub const ShellSurface = struct {
    object: wayland.client.Object,
    pub const interface = "wl_shell_surface";
    pub const version = 1;
    pub usingnamespace struct {
        pub fn pong() error{BufferFull}!void {}
        pub fn move() error{BufferFull}!void {}
        pub fn resize() error{BufferFull}!void {}
        pub fn setToplevel() error{BufferFull}!void {}
        pub fn setTransient() error{BufferFull}!void {}
        pub fn setFullscreen() error{BufferFull}!void {}
        pub fn setPopup() error{BufferFull}!void {}
        pub fn setMaximized() error{BufferFull}!void {}
        pub fn setTitle() error{BufferFull}!void {}
        pub fn setClass() error{BufferFull}!void {}
    };
    pub const Enum = struct {
        pub const Resize = packed struct {
            none: bool = false,
            top: bool = false,
            bottom: bool = false,
            left: bool = false,
            top_left: bool = false,
            bottom_left: bool = false,
            right: bool = false,
            top_right: bool = false,
            bottom_right: bool = false,
            pub fn toInt(resize: Resize) u32 {
                var result: u32 = 0;
                if (resize.none)
                    result &= 0;
                if (resize.top)
                    result &= 1;
                if (resize.bottom)
                    result &= 2;
                if (resize.left)
                    result &= 4;
                if (resize.top_left)
                    result &= 5;
                if (resize.bottom_left)
                    result &= 6;
                if (resize.right)
                    result &= 8;
                if (resize.top_right)
                    result &= 9;
                if (resize.bottom_right)
                    result &= 10;
                return result;
            }
            pub fn fromInt(int: u32) Resize {
                return Resize{
                    .none = (int & 0) != 0,
                    .top = (int & 1) != 0,
                    .bottom = (int & 2) != 0,
                    .left = (int & 4) != 0,
                    .top_left = (int & 5) != 0,
                    .bottom_left = (int & 6) != 0,
                    .right = (int & 8) != 0,
                    .top_right = (int & 9) != 0,
                    .bottom_right = (int & 10) != 0,
                };
            }
        };
        pub const Transient = packed struct {
            inactive: bool = false,
            pub fn toInt(transient: Transient) u32 {
                var result: u32 = 0;
                if (transient.inactive)
                    result &= 1;
                return result;
            }
            pub fn fromInt(int: u32) Transient {
                return Transient{
                    .inactive = (int & 1) != 0,
                };
            }
        };
        pub const FullscreenMethod = enum(u32) {
            default = 0,
            scale = 1,
            driver = 2,
            fill = 3,
            pub fn toInt(fullscreen_method: FullscreenMethod) u32 {
                return @enumToInt(fullscreen_method);
            }
            pub fn fromInt(int: u32) FullscreenMethod {
                return @intToEnum(FullscreenMethod, int);
            }
        };
    };
    pub const Request = union(enum(u16)) {
        pong: PongRequest = 0,
        move: MoveRequest = 1,
        resize: ResizeRequest = 2,
        set_toplevel: SetToplevelRequest = 3,
        set_transient: SetTransientRequest = 4,
        set_fullscreen: SetFullscreenRequest = 5,
        set_popup: SetPopupRequest = 6,
        set_maximized: SetMaximizedRequest = 7,
        set_title: SetTitleRequest = 8,
        set_class: SetClassRequest = 9,
        pub const PongRequest = struct {
            serial: u32,
            pub fn marshal(
                pong: PongRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(pong.serial) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) PongRequest {
                var i: usize = 0;
                return PongRequest{
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                pong: PongRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shell_surface.pong(");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{pong.serial});
                try writer.writeAll(")");
            }
        };
        pub const MoveRequest = struct {
            seat: ?Seat,
            serial: u32,
            pub fn marshal(
                move: MoveRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 16;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(move.seat.object.id) catch unreachable;
                buf.putUInt(move.serial) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) MoveRequest {
                var i: usize = 0;
                return MoveRequest{
                    .seat = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                move: MoveRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shell_surface.move(");
                try writer.writeAll("seat: ");
                try writer.print("{any}", .{move.seat});
                try writer.writeAll(", ");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{move.serial});
                try writer.writeAll(")");
            }
        };
        pub const ResizeRequest = struct {
            seat: ?Seat,
            serial: u32,
            edges: u32,
            pub fn marshal(
                resize: ResizeRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 20;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 2) catch unreachable;
                buf.putUInt(resize.seat.object.id) catch unreachable;
                buf.putUInt(resize.serial) catch unreachable;
                buf.putUInt(resize.edges) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) ResizeRequest {
                var i: usize = 0;
                return ResizeRequest{
                    .seat = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .edges = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                resize: ResizeRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shell_surface.resize(");
                try writer.writeAll("seat: ");
                try writer.print("{any}", .{resize.seat});
                try writer.writeAll(", ");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{resize.serial});
                try writer.writeAll(", ");
                try writer.writeAll("edges: ");
                try writer.print("{any}u", .{resize.edges});
                try writer.writeAll(")");
            }
        };
        pub const SetToplevelRequest = struct {
            pub fn marshal(
                _: SetToplevelRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 3) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) SetToplevelRequest {
                return SetToplevelRequest{};
            }
            pub fn _format(
                _: SetToplevelRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shell_surface.set_toplevel(");
                try writer.writeAll(")");
            }
        };
        pub const SetTransientRequest = struct {
            parent: ?Surface,
            x: i32,
            y: i32,
            flags: u32,
            pub fn marshal(
                set_transient: SetTransientRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 24;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 4) catch unreachable;
                buf.putUInt(set_transient.parent.object.id) catch unreachable;
                buf.putInt(set_transient.x) catch unreachable;
                buf.putInt(set_transient.y) catch unreachable;
                buf.putUInt(set_transient.flags) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SetTransientRequest {
                var i: usize = 0;
                return SetTransientRequest{
                    .parent = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .x = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .y = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .flags = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                set_transient: SetTransientRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shell_surface.set_transient(");
                try writer.writeAll("parent: ");
                try writer.print("{any}", .{set_transient.parent});
                try writer.writeAll(", ");
                try writer.writeAll("x: ");
                try writer.print("{any}i", .{set_transient.x});
                try writer.writeAll(", ");
                try writer.writeAll("y: ");
                try writer.print("{any}i", .{set_transient.y});
                try writer.writeAll(", ");
                try writer.writeAll("flags: ");
                try writer.print("{any}u", .{set_transient.flags});
                try writer.writeAll(")");
            }
        };
        pub const SetFullscreenRequest = struct {
            method: u32,
            framerate: u32,
            output: ?Output,
            pub fn marshal(
                set_fullscreen: SetFullscreenRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 20;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 5) catch unreachable;
                buf.putUInt(set_fullscreen.method) catch unreachable;
                buf.putUInt(set_fullscreen.framerate) catch unreachable;
                buf.putUInt(if (set_fullscreen.output) |_obj| _obj.object.id else 0) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SetFullscreenRequest {
                var i: usize = 0;
                return SetFullscreenRequest{
                    .method = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .framerate = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .output = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                set_fullscreen: SetFullscreenRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shell_surface.set_fullscreen(");
                try writer.writeAll("method: ");
                try writer.print("{any}u", .{set_fullscreen.method});
                try writer.writeAll(", ");
                try writer.writeAll("framerate: ");
                try writer.print("{any}u", .{set_fullscreen.framerate});
                try writer.writeAll(", ");
                try writer.writeAll("output: ");
                try writer.print("{any}", .{set_fullscreen.output});
                try writer.writeAll(")");
            }
        };
        pub const SetPopupRequest = struct {
            seat: ?Seat,
            serial: u32,
            parent: ?Surface,
            x: i32,
            y: i32,
            flags: u32,
            pub fn marshal(
                set_popup: SetPopupRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 32;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 6) catch unreachable;
                buf.putUInt(set_popup.seat.object.id) catch unreachable;
                buf.putUInt(set_popup.serial) catch unreachable;
                buf.putUInt(set_popup.parent.object.id) catch unreachable;
                buf.putInt(set_popup.x) catch unreachable;
                buf.putInt(set_popup.y) catch unreachable;
                buf.putUInt(set_popup.flags) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SetPopupRequest {
                var i: usize = 0;
                return SetPopupRequest{
                    .seat = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .parent = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .x = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .y = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .flags = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                set_popup: SetPopupRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shell_surface.set_popup(");
                try writer.writeAll("seat: ");
                try writer.print("{any}", .{set_popup.seat});
                try writer.writeAll(", ");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{set_popup.serial});
                try writer.writeAll(", ");
                try writer.writeAll("parent: ");
                try writer.print("{any}", .{set_popup.parent});
                try writer.writeAll(", ");
                try writer.writeAll("x: ");
                try writer.print("{any}i", .{set_popup.x});
                try writer.writeAll(", ");
                try writer.writeAll("y: ");
                try writer.print("{any}i", .{set_popup.y});
                try writer.writeAll(", ");
                try writer.writeAll("flags: ");
                try writer.print("{any}u", .{set_popup.flags});
                try writer.writeAll(")");
            }
        };
        pub const SetMaximizedRequest = struct {
            output: ?Output,
            pub fn marshal(
                set_maximized: SetMaximizedRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 7) catch unreachable;
                buf.putUInt(if (set_maximized.output) |_obj| _obj.object.id else 0) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SetMaximizedRequest {
                var i: usize = 0;
                return SetMaximizedRequest{
                    .output = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                set_maximized: SetMaximizedRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shell_surface.set_maximized(");
                try writer.writeAll("output: ");
                try writer.print("{any}", .{set_maximized.output});
                try writer.writeAll(")");
            }
        };
        pub const SetTitleRequest = struct {
            title: [:0]const u8,
            pub fn marshal(
                set_title: SetTitleRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12 + ((set_title.title.len + 3) / 4 * 4);
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 8) catch unreachable;
                buf.putString(set_title.title) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SetTitleRequest {
                var i: usize = 0;
                return SetTitleRequest{
                    .title = blk: {
                        const arg_len = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        const arg_padded_len = (arg_len + 3) / 4 * 4;
                        const arg = msg.data[i + 4 .. i + 4 + arg_len - 1 :0];
                        i += 4 + arg_padded_len;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                set_title: SetTitleRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shell_surface.set_title(");
                try writer.writeAll("title: ");
                try writer.print("\"{}\"", .{@import("std").zig.fmtEscapes(set_title.title)});
                try writer.writeAll(")");
            }
        };
        pub const SetClassRequest = struct {
            class: [:0]const u8,
            pub fn marshal(
                set_class: SetClassRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12 + ((set_class.class.len + 3) / 4 * 4);
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 9) catch unreachable;
                buf.putString(set_class.class) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SetClassRequest {
                var i: usize = 0;
                return SetClassRequest{
                    .class = blk: {
                        const arg_len = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        const arg_padded_len = (arg_len + 3) / 4 * 4;
                        const arg = msg.data[i + 4 .. i + 4 + arg_len - 1 :0];
                        i += 4 + arg_padded_len;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                set_class: SetClassRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shell_surface.set_class(");
                try writer.writeAll("class_: ");
                try writer.print("\"{}\"", .{@import("std").zig.fmtEscapes(set_class.class_)});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .pong => |pong| pong.marshal(id, buf),
                .move => |move| move.marshal(id, buf),
                .resize => |resize| resize.marshal(id, buf),
                .set_toplevel => |set_toplevel| set_toplevel.marshal(id, buf),
                .set_transient => |set_transient| set_transient.marshal(id, buf),
                .set_fullscreen => |set_fullscreen| set_fullscreen.marshal(id, buf),
                .set_popup => |set_popup| set_popup.marshal(id, buf),
                .set_maximized => |set_maximized| set_maximized.marshal(id, buf),
                .set_title => |set_title| set_title.marshal(id, buf),
                .set_class => |set_class| set_class.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .pong => Request{ .pong = PongRequest.unmarshal(conn, msg, fds) },
                .move => Request{ .move = MoveRequest.unmarshal(conn, msg, fds) },
                .resize => Request{ .resize = ResizeRequest.unmarshal(conn, msg, fds) },
                .set_toplevel => Request{ .set_toplevel = SetToplevelRequest.unmarshal(conn, msg, fds) },
                .set_transient => Request{ .set_transient = SetTransientRequest.unmarshal(conn, msg, fds) },
                .set_fullscreen => Request{ .set_fullscreen = SetFullscreenRequest.unmarshal(conn, msg, fds) },
                .set_popup => Request{ .set_popup = SetPopupRequest.unmarshal(conn, msg, fds) },
                .set_maximized => Request{ .set_maximized = SetMaximizedRequest.unmarshal(conn, msg, fds) },
                .set_title => Request{ .set_title = SetTitleRequest.unmarshal(conn, msg, fds) },
                .set_class => Request{ .set_class = SetClassRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .pong => |pong| pong._format(fmt, options, writer),
                .move => |move| move._format(fmt, options, writer),
                .resize => |resize| resize._format(fmt, options, writer),
                .set_toplevel => |set_toplevel| set_toplevel._format(fmt, options, writer),
                .set_transient => |set_transient| set_transient._format(fmt, options, writer),
                .set_fullscreen => |set_fullscreen| set_fullscreen._format(fmt, options, writer),
                .set_popup => |set_popup| set_popup._format(fmt, options, writer),
                .set_maximized => |set_maximized| set_maximized._format(fmt, options, writer),
                .set_title => |set_title| set_title._format(fmt, options, writer),
                .set_class => |set_class| set_class._format(fmt, options, writer),
            };
        }
    };
    pub const Event = union(enum(u16)) {
        ping: PingEvent = 0,
        configure: ConfigureEvent = 1,
        popup_done: PopupDoneEvent = 2,
        pub const PingEvent = struct {
            serial: u32,
            pub fn marshal(
                ping: PingEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(ping.serial) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) PingEvent {
                var i: usize = 0;
                return PingEvent{
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                ping: PingEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shell_surface.ping(");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{ping.serial});
                try writer.writeAll(")");
            }
        };
        pub const ConfigureEvent = struct {
            edges: u32,
            width: i32,
            height: i32,
            pub fn marshal(
                configure: ConfigureEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 20;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(configure.edges) catch unreachable;
                buf.putInt(configure.width) catch unreachable;
                buf.putInt(configure.height) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) ConfigureEvent {
                var i: usize = 0;
                return ConfigureEvent{
                    .edges = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .width = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .height = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                configure: ConfigureEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shell_surface.configure(");
                try writer.writeAll("edges: ");
                try writer.print("{any}u", .{configure.edges});
                try writer.writeAll(", ");
                try writer.writeAll("width: ");
                try writer.print("{any}i", .{configure.width});
                try writer.writeAll(", ");
                try writer.writeAll("height: ");
                try writer.print("{any}i", .{configure.height});
                try writer.writeAll(")");
            }
        };
        pub const PopupDoneEvent = struct {
            pub fn marshal(
                _: PopupDoneEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 2) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) PopupDoneEvent {
                return PopupDoneEvent{};
            }
            pub fn _format(
                _: PopupDoneEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_shell_surface.popup_done(");
                try writer.writeAll(")");
            }
        };
        pub fn marshal(event: Event, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (event) {
                .ping => |ping| ping.marshal(id, buf),
                .configure => |configure| configure.marshal(id, buf),
                .popup_done => |popup_done| popup_done.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Event {
            return switch (@intToEnum(std.meta.Tag(Event), msg.op)) {
                .ping => Event{ .ping = PingEvent.unmarshal(conn, msg, fds) },
                .configure => Event{ .configure = ConfigureEvent.unmarshal(conn, msg, fds) },
                .popup_done => Event{ .popup_done = PopupDoneEvent.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            event: Event,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (event) {
                .ping => |ping| ping._format(fmt, options, writer),
                .configure => |configure| configure._format(fmt, options, writer),
                .popup_done => |popup_done| popup_done._format(fmt, options, writer),
            };
        }
    };
};
pub const Surface = struct {
    object: wayland.client.Object,
    pub const interface = "wl_surface";
    pub const version = 4;
    pub usingnamespace struct {
        pub fn destroy() error{BufferFull}!void {}
        pub fn attach() error{BufferFull}!void {}
        pub fn damage() error{BufferFull}!void {}
        pub fn frame() error{BufferFull}!void {}
        pub fn setOpaqueRegion() error{BufferFull}!void {}
        pub fn setInputRegion() error{BufferFull}!void {}
        pub fn commit() error{BufferFull}!void {}
        pub fn setBufferTransform() error{BufferFull}!void {}
        pub fn setBufferScale() error{BufferFull}!void {}
        pub fn damageBuffer() error{BufferFull}!void {}
    };
    pub const Enum = struct {
        pub const Error = enum(u32) {
            invalid_scale = 0,
            invalid_transform = 1,
            invalid_size = 2,
            pub fn toInt(@"error": Error) u32 {
                return @enumToInt(@"error");
            }
            pub fn fromInt(int: u32) Error {
                return @intToEnum(Error, int);
            }
        };
    };
    pub const Request = union(enum(u16)) {
        destroy: DestroyRequest = 0,
        attach: AttachRequest = 1,
        damage: DamageRequest = 2,
        frame: FrameRequest = 3,
        set_opaque_region: SetOpaqueRegionRequest = 4,
        set_input_region: SetInputRegionRequest = 5,
        commit: CommitRequest = 6,
        set_buffer_transform: SetBufferTransformRequest = 7,
        set_buffer_scale: SetBufferScaleRequest = 8,
        damage_buffer: DamageBufferRequest = 9,
        pub const DestroyRequest = struct {
            pub fn marshal(
                _: DestroyRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) DestroyRequest {
                return DestroyRequest{};
            }
            pub fn _format(
                _: DestroyRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_surface.destroy(");
                try writer.writeAll(")");
            }
        };
        pub const AttachRequest = struct {
            buffer: ?Buffer,
            x: i32,
            y: i32,
            pub fn marshal(
                attach: AttachRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 20;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(if (attach.buffer) |_obj| _obj.object.id else 0) catch unreachable;
                buf.putInt(attach.x) catch unreachable;
                buf.putInt(attach.y) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) AttachRequest {
                var i: usize = 0;
                return AttachRequest{
                    .buffer = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .x = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .y = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                attach: AttachRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_surface.attach(");
                try writer.writeAll("buffer: ");
                try writer.print("{any}", .{attach.buffer});
                try writer.writeAll(", ");
                try writer.writeAll("x: ");
                try writer.print("{any}i", .{attach.x});
                try writer.writeAll(", ");
                try writer.writeAll("y: ");
                try writer.print("{any}i", .{attach.y});
                try writer.writeAll(")");
            }
        };
        pub const DamageRequest = struct {
            x: i32,
            y: i32,
            width: i32,
            height: i32,
            pub fn marshal(
                damage: DamageRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 24;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 2) catch unreachable;
                buf.putInt(damage.x) catch unreachable;
                buf.putInt(damage.y) catch unreachable;
                buf.putInt(damage.width) catch unreachable;
                buf.putInt(damage.height) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) DamageRequest {
                var i: usize = 0;
                return DamageRequest{
                    .x = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .y = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .width = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .height = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                damage: DamageRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_surface.damage(");
                try writer.writeAll("x: ");
                try writer.print("{any}i", .{damage.x});
                try writer.writeAll(", ");
                try writer.writeAll("y: ");
                try writer.print("{any}i", .{damage.y});
                try writer.writeAll(", ");
                try writer.writeAll("width: ");
                try writer.print("{any}i", .{damage.width});
                try writer.writeAll(", ");
                try writer.writeAll("height: ");
                try writer.print("{any}i", .{damage.height});
                try writer.writeAll(")");
            }
        };
        pub const FrameRequest = struct {
            callback: Callback,
            pub fn marshal(
                frame: FrameRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 3) catch unreachable;
                buf.putUInt(frame.callback.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) FrameRequest {
                var i: usize = 0;
                return FrameRequest{
                    .callback = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                frame: FrameRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_surface.frame(");
                try writer.writeAll("callback: ");
                try writer.print("{any}", .{frame.callback});
                try writer.writeAll(")");
            }
        };
        pub const SetOpaqueRegionRequest = struct {
            region: ?Region,
            pub fn marshal(
                set_opaque_region: SetOpaqueRegionRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 4) catch unreachable;
                buf.putUInt(if (set_opaque_region.region) |_obj| _obj.object.id else 0) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SetOpaqueRegionRequest {
                var i: usize = 0;
                return SetOpaqueRegionRequest{
                    .region = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                set_opaque_region: SetOpaqueRegionRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_surface.set_opaque_region(");
                try writer.writeAll("region: ");
                try writer.print("{any}", .{set_opaque_region.region});
                try writer.writeAll(")");
            }
        };
        pub const SetInputRegionRequest = struct {
            region: ?Region,
            pub fn marshal(
                set_input_region: SetInputRegionRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 5) catch unreachable;
                buf.putUInt(if (set_input_region.region) |_obj| _obj.object.id else 0) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SetInputRegionRequest {
                var i: usize = 0;
                return SetInputRegionRequest{
                    .region = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                set_input_region: SetInputRegionRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_surface.set_input_region(");
                try writer.writeAll("region: ");
                try writer.print("{any}", .{set_input_region.region});
                try writer.writeAll(")");
            }
        };
        pub const CommitRequest = struct {
            pub fn marshal(
                _: CommitRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 6) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) CommitRequest {
                return CommitRequest{};
            }
            pub fn _format(
                _: CommitRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_surface.commit(");
                try writer.writeAll(")");
            }
        };
        pub const SetBufferTransformRequest = struct {
            transform: i32,
            pub fn marshal(
                set_buffer_transform: SetBufferTransformRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 7) catch unreachable;
                buf.putInt(set_buffer_transform.transform) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SetBufferTransformRequest {
                var i: usize = 0;
                return SetBufferTransformRequest{
                    .transform = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                set_buffer_transform: SetBufferTransformRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_surface.set_buffer_transform(");
                try writer.writeAll("transform: ");
                try writer.print("{any}i", .{set_buffer_transform.transform});
                try writer.writeAll(")");
            }
        };
        pub const SetBufferScaleRequest = struct {
            scale: i32,
            pub fn marshal(
                set_buffer_scale: SetBufferScaleRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 8) catch unreachable;
                buf.putInt(set_buffer_scale.scale) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SetBufferScaleRequest {
                var i: usize = 0;
                return SetBufferScaleRequest{
                    .scale = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                set_buffer_scale: SetBufferScaleRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_surface.set_buffer_scale(");
                try writer.writeAll("scale: ");
                try writer.print("{any}i", .{set_buffer_scale.scale});
                try writer.writeAll(")");
            }
        };
        pub const DamageBufferRequest = struct {
            x: i32,
            y: i32,
            width: i32,
            height: i32,
            pub fn marshal(
                damage_buffer: DamageBufferRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 24;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 9) catch unreachable;
                buf.putInt(damage_buffer.x) catch unreachable;
                buf.putInt(damage_buffer.y) catch unreachable;
                buf.putInt(damage_buffer.width) catch unreachable;
                buf.putInt(damage_buffer.height) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) DamageBufferRequest {
                var i: usize = 0;
                return DamageBufferRequest{
                    .x = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .y = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .width = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .height = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                damage_buffer: DamageBufferRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_surface.damage_buffer(");
                try writer.writeAll("x: ");
                try writer.print("{any}i", .{damage_buffer.x});
                try writer.writeAll(", ");
                try writer.writeAll("y: ");
                try writer.print("{any}i", .{damage_buffer.y});
                try writer.writeAll(", ");
                try writer.writeAll("width: ");
                try writer.print("{any}i", .{damage_buffer.width});
                try writer.writeAll(", ");
                try writer.writeAll("height: ");
                try writer.print("{any}i", .{damage_buffer.height});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .destroy => |destroy| destroy.marshal(id, buf),
                .attach => |attach| attach.marshal(id, buf),
                .damage => |damage| damage.marshal(id, buf),
                .frame => |frame| frame.marshal(id, buf),
                .set_opaque_region => |set_opaque_region| set_opaque_region.marshal(id, buf),
                .set_input_region => |set_input_region| set_input_region.marshal(id, buf),
                .commit => |commit| commit.marshal(id, buf),
                .set_buffer_transform => |set_buffer_transform| set_buffer_transform.marshal(id, buf),
                .set_buffer_scale => |set_buffer_scale| set_buffer_scale.marshal(id, buf),
                .damage_buffer => |damage_buffer| damage_buffer.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .destroy => Request{ .destroy = DestroyRequest.unmarshal(conn, msg, fds) },
                .attach => Request{ .attach = AttachRequest.unmarshal(conn, msg, fds) },
                .damage => Request{ .damage = DamageRequest.unmarshal(conn, msg, fds) },
                .frame => Request{ .frame = FrameRequest.unmarshal(conn, msg, fds) },
                .set_opaque_region => Request{ .set_opaque_region = SetOpaqueRegionRequest.unmarshal(conn, msg, fds) },
                .set_input_region => Request{ .set_input_region = SetInputRegionRequest.unmarshal(conn, msg, fds) },
                .commit => Request{ .commit = CommitRequest.unmarshal(conn, msg, fds) },
                .set_buffer_transform => Request{ .set_buffer_transform = SetBufferTransformRequest.unmarshal(conn, msg, fds) },
                .set_buffer_scale => Request{ .set_buffer_scale = SetBufferScaleRequest.unmarshal(conn, msg, fds) },
                .damage_buffer => Request{ .damage_buffer = DamageBufferRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .destroy => |destroy| destroy._format(fmt, options, writer),
                .attach => |attach| attach._format(fmt, options, writer),
                .damage => |damage| damage._format(fmt, options, writer),
                .frame => |frame| frame._format(fmt, options, writer),
                .set_opaque_region => |set_opaque_region| set_opaque_region._format(fmt, options, writer),
                .set_input_region => |set_input_region| set_input_region._format(fmt, options, writer),
                .commit => |commit| commit._format(fmt, options, writer),
                .set_buffer_transform => |set_buffer_transform| set_buffer_transform._format(fmt, options, writer),
                .set_buffer_scale => |set_buffer_scale| set_buffer_scale._format(fmt, options, writer),
                .damage_buffer => |damage_buffer| damage_buffer._format(fmt, options, writer),
            };
        }
    };
    pub const Event = union(enum(u16)) {
        enter: EnterEvent = 0,
        leave: LeaveEvent = 1,
        pub const EnterEvent = struct {
            output: ?Output,
            pub fn marshal(
                enter: EnterEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(enter.output.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) EnterEvent {
                var i: usize = 0;
                return EnterEvent{
                    .output = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                enter: EnterEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_surface.enter(");
                try writer.writeAll("output: ");
                try writer.print("{any}", .{enter.output});
                try writer.writeAll(")");
            }
        };
        pub const LeaveEvent = struct {
            output: ?Output,
            pub fn marshal(
                leave: LeaveEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(leave.output.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) LeaveEvent {
                var i: usize = 0;
                return LeaveEvent{
                    .output = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                leave: LeaveEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_surface.leave(");
                try writer.writeAll("output: ");
                try writer.print("{any}", .{leave.output});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(event: Event, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (event) {
                .enter => |enter| enter.marshal(id, buf),
                .leave => |leave| leave.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Event {
            return switch (@intToEnum(std.meta.Tag(Event), msg.op)) {
                .enter => Event{ .enter = EnterEvent.unmarshal(conn, msg, fds) },
                .leave => Event{ .leave = LeaveEvent.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            event: Event,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (event) {
                .enter => |enter| enter._format(fmt, options, writer),
                .leave => |leave| leave._format(fmt, options, writer),
            };
        }
    };
};
pub const Seat = struct {
    object: wayland.client.Object,
    pub const interface = "wl_seat";
    pub const version = 7;
    pub usingnamespace struct {
        pub fn getPointer() error{BufferFull}!void {}
        pub fn getKeyboard() error{BufferFull}!void {}
        pub fn getTouch() error{BufferFull}!void {}
        pub fn release() error{BufferFull}!void {}
    };
    pub const Enum = struct {
        pub const Capability = packed struct {
            pointer: bool = false,
            keyboard: bool = false,
            touch: bool = false,
            pub fn toInt(capability: Capability) u32 {
                var result: u32 = 0;
                if (capability.pointer)
                    result &= 1;
                if (capability.keyboard)
                    result &= 2;
                if (capability.touch)
                    result &= 4;
                return result;
            }
            pub fn fromInt(int: u32) Capability {
                return Capability{
                    .pointer = (int & 1) != 0,
                    .keyboard = (int & 2) != 0,
                    .touch = (int & 4) != 0,
                };
            }
        };
        pub const Error = enum(u32) {
            missing_capability = 0,
            pub fn toInt(@"error": Error) u32 {
                return @enumToInt(@"error");
            }
            pub fn fromInt(int: u32) Error {
                return @intToEnum(Error, int);
            }
        };
    };
    pub const Request = union(enum(u16)) {
        get_pointer: GetPointerRequest = 0,
        get_keyboard: GetKeyboardRequest = 1,
        get_touch: GetTouchRequest = 2,
        release: ReleaseRequest = 3,
        pub const GetPointerRequest = struct {
            id: Pointer,
            pub fn marshal(
                get_pointer: GetPointerRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(get_pointer.id.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) GetPointerRequest {
                var i: usize = 0;
                return GetPointerRequest{
                    .id = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                get_pointer: GetPointerRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_seat.get_pointer(");
                try writer.writeAll("id: ");
                try writer.print("{any}", .{get_pointer.id});
                try writer.writeAll(")");
            }
        };
        pub const GetKeyboardRequest = struct {
            id: Keyboard,
            pub fn marshal(
                get_keyboard: GetKeyboardRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(get_keyboard.id.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) GetKeyboardRequest {
                var i: usize = 0;
                return GetKeyboardRequest{
                    .id = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                get_keyboard: GetKeyboardRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_seat.get_keyboard(");
                try writer.writeAll("id: ");
                try writer.print("{any}", .{get_keyboard.id});
                try writer.writeAll(")");
            }
        };
        pub const GetTouchRequest = struct {
            id: Touch,
            pub fn marshal(
                get_touch: GetTouchRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 2) catch unreachable;
                buf.putUInt(get_touch.id.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) GetTouchRequest {
                var i: usize = 0;
                return GetTouchRequest{
                    .id = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                get_touch: GetTouchRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_seat.get_touch(");
                try writer.writeAll("id: ");
                try writer.print("{any}", .{get_touch.id});
                try writer.writeAll(")");
            }
        };
        pub const ReleaseRequest = struct {
            pub fn marshal(
                _: ReleaseRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 3) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) ReleaseRequest {
                return ReleaseRequest{};
            }
            pub fn _format(
                _: ReleaseRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_seat.release(");
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .get_pointer => |get_pointer| get_pointer.marshal(id, buf),
                .get_keyboard => |get_keyboard| get_keyboard.marshal(id, buf),
                .get_touch => |get_touch| get_touch.marshal(id, buf),
                .release => |release| release.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .get_pointer => Request{ .get_pointer = GetPointerRequest.unmarshal(conn, msg, fds) },
                .get_keyboard => Request{ .get_keyboard = GetKeyboardRequest.unmarshal(conn, msg, fds) },
                .get_touch => Request{ .get_touch = GetTouchRequest.unmarshal(conn, msg, fds) },
                .release => Request{ .release = ReleaseRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .get_pointer => |get_pointer| get_pointer._format(fmt, options, writer),
                .get_keyboard => |get_keyboard| get_keyboard._format(fmt, options, writer),
                .get_touch => |get_touch| get_touch._format(fmt, options, writer),
                .release => |release| release._format(fmt, options, writer),
            };
        }
    };
    pub const Event = union(enum(u16)) {
        capabilities: CapabilitiesEvent = 0,
        name: NameEvent = 1,
        pub const CapabilitiesEvent = struct {
            capabilities: u32,
            pub fn marshal(
                capabilities: CapabilitiesEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(capabilities.capabilities) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) CapabilitiesEvent {
                var i: usize = 0;
                return CapabilitiesEvent{
                    .capabilities = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                capabilities: CapabilitiesEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_seat.capabilities(");
                try writer.writeAll("capabilities: ");
                try writer.print("{any}u", .{capabilities.capabilities});
                try writer.writeAll(")");
            }
        };
        pub const NameEvent = struct {
            name: [:0]const u8,
            pub fn marshal(
                name: NameEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12 + ((name.name.len + 3) / 4 * 4);
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putString(name.name) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) NameEvent {
                var i: usize = 0;
                return NameEvent{
                    .name = blk: {
                        const arg_len = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        const arg_padded_len = (arg_len + 3) / 4 * 4;
                        const arg = msg.data[i + 4 .. i + 4 + arg_len - 1 :0];
                        i += 4 + arg_padded_len;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                name: NameEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_seat.name(");
                try writer.writeAll("name: ");
                try writer.print("\"{}\"", .{@import("std").zig.fmtEscapes(name.name)});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(event: Event, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (event) {
                .capabilities => |capabilities| capabilities.marshal(id, buf),
                .name => |name| name.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Event {
            return switch (@intToEnum(std.meta.Tag(Event), msg.op)) {
                .capabilities => Event{ .capabilities = CapabilitiesEvent.unmarshal(conn, msg, fds) },
                .name => Event{ .name = NameEvent.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            event: Event,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (event) {
                .capabilities => |capabilities| capabilities._format(fmt, options, writer),
                .name => |name| name._format(fmt, options, writer),
            };
        }
    };
};
pub const Pointer = struct {
    object: wayland.client.Object,
    pub const interface = "wl_pointer";
    pub const version = 7;
    pub usingnamespace struct {
        pub fn setCursor() error{BufferFull}!void {}
        pub fn release() error{BufferFull}!void {}
    };
    pub const Enum = struct {
        pub const Error = enum(u32) {
            role = 0,
            pub fn toInt(@"error": Error) u32 {
                return @enumToInt(@"error");
            }
            pub fn fromInt(int: u32) Error {
                return @intToEnum(Error, int);
            }
        };
        pub const ButtonState = enum(u32) {
            released = 0,
            pressed = 1,
            pub fn toInt(button_state: ButtonState) u32 {
                return @enumToInt(button_state);
            }
            pub fn fromInt(int: u32) ButtonState {
                return @intToEnum(ButtonState, int);
            }
        };
        pub const Axis = enum(u32) {
            vertical_scroll = 0,
            horizontal_scroll = 1,
            pub fn toInt(axis: Axis) u32 {
                return @enumToInt(axis);
            }
            pub fn fromInt(int: u32) Axis {
                return @intToEnum(Axis, int);
            }
        };
        pub const AxisSource = enum(u32) {
            wheel = 0,
            finger = 1,
            continuous = 2,
            wheel_tilt = 3,
            pub fn toInt(axis_source: AxisSource) u32 {
                return @enumToInt(axis_source);
            }
            pub fn fromInt(int: u32) AxisSource {
                return @intToEnum(AxisSource, int);
            }
        };
    };
    pub const Request = union(enum(u16)) {
        set_cursor: SetCursorRequest = 0,
        release: ReleaseRequest = 1,
        pub const SetCursorRequest = struct {
            serial: u32,
            surface: ?Surface,
            hotspot_x: i32,
            hotspot_y: i32,
            pub fn marshal(
                set_cursor: SetCursorRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 24;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(set_cursor.serial) catch unreachable;
                buf.putUInt(if (set_cursor.surface) |_obj| _obj.object.id else 0) catch unreachable;
                buf.putInt(set_cursor.hotspot_x) catch unreachable;
                buf.putInt(set_cursor.hotspot_y) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SetCursorRequest {
                var i: usize = 0;
                return SetCursorRequest{
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .surface = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .hotspot_x = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .hotspot_y = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                set_cursor: SetCursorRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_pointer.set_cursor(");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{set_cursor.serial});
                try writer.writeAll(", ");
                try writer.writeAll("surface: ");
                try writer.print("{any}", .{set_cursor.surface});
                try writer.writeAll(", ");
                try writer.writeAll("hotspot_x: ");
                try writer.print("{any}i", .{set_cursor.hotspot_x});
                try writer.writeAll(", ");
                try writer.writeAll("hotspot_y: ");
                try writer.print("{any}i", .{set_cursor.hotspot_y});
                try writer.writeAll(")");
            }
        };
        pub const ReleaseRequest = struct {
            pub fn marshal(
                _: ReleaseRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) ReleaseRequest {
                return ReleaseRequest{};
            }
            pub fn _format(
                _: ReleaseRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_pointer.release(");
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .set_cursor => |set_cursor| set_cursor.marshal(id, buf),
                .release => |release| release.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .set_cursor => Request{ .set_cursor = SetCursorRequest.unmarshal(conn, msg, fds) },
                .release => Request{ .release = ReleaseRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .set_cursor => |set_cursor| set_cursor._format(fmt, options, writer),
                .release => |release| release._format(fmt, options, writer),
            };
        }
    };
    pub const Event = union(enum(u16)) {
        enter: EnterEvent = 0,
        leave: LeaveEvent = 1,
        motion: MotionEvent = 2,
        button: ButtonEvent = 3,
        axis: AxisEvent = 4,
        frame: FrameEvent = 5,
        axis_source: AxisSourceEvent = 6,
        axis_stop: AxisStopEvent = 7,
        axis_discrete: AxisDiscreteEvent = 8,
        pub const EnterEvent = struct {
            serial: u32,
            surface: ?Surface,
            surface_x: f64,
            surface_y: f64,
            pub fn marshal(
                enter: EnterEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 24;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(enter.serial) catch unreachable;
                buf.putUInt(enter.surface.object.id) catch unreachable;
                buf.putFixed(enter.surface_x) catch unreachable;
                buf.putFixed(enter.surface_y) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) EnterEvent {
                var i: usize = 0;
                return EnterEvent{
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .surface = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .surface_x = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .surface_y = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                enter: EnterEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_pointer.enter(");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{enter.serial});
                try writer.writeAll(", ");
                try writer.writeAll("surface: ");
                try writer.print("{any}", .{enter.surface});
                try writer.writeAll(", ");
                try writer.writeAll("surface_x: ");
                try writer.print("{any}f", .{enter.surface_x});
                try writer.writeAll(", ");
                try writer.writeAll("surface_y: ");
                try writer.print("{any}f", .{enter.surface_y});
                try writer.writeAll(")");
            }
        };
        pub const LeaveEvent = struct {
            serial: u32,
            surface: ?Surface,
            pub fn marshal(
                leave: LeaveEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 16;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(leave.serial) catch unreachable;
                buf.putUInt(leave.surface.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) LeaveEvent {
                var i: usize = 0;
                return LeaveEvent{
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .surface = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                leave: LeaveEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_pointer.leave(");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{leave.serial});
                try writer.writeAll(", ");
                try writer.writeAll("surface: ");
                try writer.print("{any}", .{leave.surface});
                try writer.writeAll(")");
            }
        };
        pub const MotionEvent = struct {
            time: u32,
            surface_x: f64,
            surface_y: f64,
            pub fn marshal(
                motion: MotionEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 20;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 2) catch unreachable;
                buf.putUInt(motion.time) catch unreachable;
                buf.putFixed(motion.surface_x) catch unreachable;
                buf.putFixed(motion.surface_y) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) MotionEvent {
                var i: usize = 0;
                return MotionEvent{
                    .time = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .surface_x = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .surface_y = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                motion: MotionEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_pointer.motion(");
                try writer.writeAll("time: ");
                try writer.print("{any}u", .{motion.time});
                try writer.writeAll(", ");
                try writer.writeAll("surface_x: ");
                try writer.print("{any}f", .{motion.surface_x});
                try writer.writeAll(", ");
                try writer.writeAll("surface_y: ");
                try writer.print("{any}f", .{motion.surface_y});
                try writer.writeAll(")");
            }
        };
        pub const ButtonEvent = struct {
            serial: u32,
            time: u32,
            button: u32,
            state: u32,
            pub fn marshal(
                button: ButtonEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 24;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 3) catch unreachable;
                buf.putUInt(button.serial) catch unreachable;
                buf.putUInt(button.time) catch unreachable;
                buf.putUInt(button.button) catch unreachable;
                buf.putUInt(button.state) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) ButtonEvent {
                var i: usize = 0;
                return ButtonEvent{
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .time = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .button = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .state = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                button: ButtonEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_pointer.button(");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{button.serial});
                try writer.writeAll(", ");
                try writer.writeAll("time: ");
                try writer.print("{any}u", .{button.time});
                try writer.writeAll(", ");
                try writer.writeAll("button: ");
                try writer.print("{any}u", .{button.button});
                try writer.writeAll(", ");
                try writer.writeAll("state: ");
                try writer.print("{any}u", .{button.state});
                try writer.writeAll(")");
            }
        };
        pub const AxisEvent = struct {
            time: u32,
            axis: u32,
            value: f64,
            pub fn marshal(
                axis: AxisEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 20;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 4) catch unreachable;
                buf.putUInt(axis.time) catch unreachable;
                buf.putUInt(axis.axis) catch unreachable;
                buf.putFixed(axis.value) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) AxisEvent {
                var i: usize = 0;
                return AxisEvent{
                    .time = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .axis = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .value = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                axis: AxisEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_pointer.axis(");
                try writer.writeAll("time: ");
                try writer.print("{any}u", .{axis.time});
                try writer.writeAll(", ");
                try writer.writeAll("axis: ");
                try writer.print("{any}u", .{axis.axis});
                try writer.writeAll(", ");
                try writer.writeAll("value: ");
                try writer.print("{any}f", .{axis.value});
                try writer.writeAll(")");
            }
        };
        pub const FrameEvent = struct {
            pub fn marshal(
                _: FrameEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 5) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) FrameEvent {
                return FrameEvent{};
            }
            pub fn _format(
                _: FrameEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_pointer.frame(");
                try writer.writeAll(")");
            }
        };
        pub const AxisSourceEvent = struct {
            axis_source: u32,
            pub fn marshal(
                axis_source: AxisSourceEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 6) catch unreachable;
                buf.putUInt(axis_source.axis_source) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) AxisSourceEvent {
                var i: usize = 0;
                return AxisSourceEvent{
                    .axis_source = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                axis_source: AxisSourceEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_pointer.axis_source(");
                try writer.writeAll("axis_source: ");
                try writer.print("{any}u", .{axis_source.axis_source});
                try writer.writeAll(")");
            }
        };
        pub const AxisStopEvent = struct {
            time: u32,
            axis: u32,
            pub fn marshal(
                axis_stop: AxisStopEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 16;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 7) catch unreachable;
                buf.putUInt(axis_stop.time) catch unreachable;
                buf.putUInt(axis_stop.axis) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) AxisStopEvent {
                var i: usize = 0;
                return AxisStopEvent{
                    .time = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .axis = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                axis_stop: AxisStopEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_pointer.axis_stop(");
                try writer.writeAll("time: ");
                try writer.print("{any}u", .{axis_stop.time});
                try writer.writeAll(", ");
                try writer.writeAll("axis: ");
                try writer.print("{any}u", .{axis_stop.axis});
                try writer.writeAll(")");
            }
        };
        pub const AxisDiscreteEvent = struct {
            axis: u32,
            discrete: i32,
            pub fn marshal(
                axis_discrete: AxisDiscreteEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 16;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 8) catch unreachable;
                buf.putUInt(axis_discrete.axis) catch unreachable;
                buf.putInt(axis_discrete.discrete) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) AxisDiscreteEvent {
                var i: usize = 0;
                return AxisDiscreteEvent{
                    .axis = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .discrete = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                axis_discrete: AxisDiscreteEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_pointer.axis_discrete(");
                try writer.writeAll("axis: ");
                try writer.print("{any}u", .{axis_discrete.axis});
                try writer.writeAll(", ");
                try writer.writeAll("discrete: ");
                try writer.print("{any}i", .{axis_discrete.discrete});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(event: Event, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (event) {
                .enter => |enter| enter.marshal(id, buf),
                .leave => |leave| leave.marshal(id, buf),
                .motion => |motion| motion.marshal(id, buf),
                .button => |button| button.marshal(id, buf),
                .axis => |axis| axis.marshal(id, buf),
                .frame => |frame| frame.marshal(id, buf),
                .axis_source => |axis_source| axis_source.marshal(id, buf),
                .axis_stop => |axis_stop| axis_stop.marshal(id, buf),
                .axis_discrete => |axis_discrete| axis_discrete.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Event {
            return switch (@intToEnum(std.meta.Tag(Event), msg.op)) {
                .enter => Event{ .enter = EnterEvent.unmarshal(conn, msg, fds) },
                .leave => Event{ .leave = LeaveEvent.unmarshal(conn, msg, fds) },
                .motion => Event{ .motion = MotionEvent.unmarshal(conn, msg, fds) },
                .button => Event{ .button = ButtonEvent.unmarshal(conn, msg, fds) },
                .axis => Event{ .axis = AxisEvent.unmarshal(conn, msg, fds) },
                .frame => Event{ .frame = FrameEvent.unmarshal(conn, msg, fds) },
                .axis_source => Event{ .axis_source = AxisSourceEvent.unmarshal(conn, msg, fds) },
                .axis_stop => Event{ .axis_stop = AxisStopEvent.unmarshal(conn, msg, fds) },
                .axis_discrete => Event{ .axis_discrete = AxisDiscreteEvent.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            event: Event,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (event) {
                .enter => |enter| enter._format(fmt, options, writer),
                .leave => |leave| leave._format(fmt, options, writer),
                .motion => |motion| motion._format(fmt, options, writer),
                .button => |button| button._format(fmt, options, writer),
                .axis => |axis| axis._format(fmt, options, writer),
                .frame => |frame| frame._format(fmt, options, writer),
                .axis_source => |axis_source| axis_source._format(fmt, options, writer),
                .axis_stop => |axis_stop| axis_stop._format(fmt, options, writer),
                .axis_discrete => |axis_discrete| axis_discrete._format(fmt, options, writer),
            };
        }
    };
};
pub const Keyboard = struct {
    object: wayland.client.Object,
    pub const interface = "wl_keyboard";
    pub const version = 7;
    pub usingnamespace struct {
        pub fn release() error{BufferFull}!void {}
    };
    pub const Enum = struct {
        pub const KeymapFormat = enum(u32) {
            no_keymap = 0,
            xkb_v1 = 1,
            pub fn toInt(keymap_format: KeymapFormat) u32 {
                return @enumToInt(keymap_format);
            }
            pub fn fromInt(int: u32) KeymapFormat {
                return @intToEnum(KeymapFormat, int);
            }
        };
        pub const KeyState = enum(u32) {
            released = 0,
            pressed = 1,
            pub fn toInt(key_state: KeyState) u32 {
                return @enumToInt(key_state);
            }
            pub fn fromInt(int: u32) KeyState {
                return @intToEnum(KeyState, int);
            }
        };
    };
    pub const Request = union(enum(u16)) {
        release: ReleaseRequest = 0,
        pub const ReleaseRequest = struct {
            pub fn marshal(
                _: ReleaseRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) ReleaseRequest {
                return ReleaseRequest{};
            }
            pub fn _format(
                _: ReleaseRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_keyboard.release(");
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .release => |release| release.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .release => Request{ .release = ReleaseRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .release => |release| release._format(fmt, options, writer),
            };
        }
    };
    pub const Event = union(enum(u16)) {
        keymap: KeymapEvent = 0,
        enter: EnterEvent = 1,
        leave: LeaveEvent = 2,
        key: KeyEvent = 3,
        modifiers: ModifiersEvent = 4,
        repeat_info: RepeatInfoEvent = 5,
        pub const KeymapEvent = struct {
            format: u32,
            fd: std.os.fd_t,
            size: u32,
            pub fn marshal(
                keymap: KeymapEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 16;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 1)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(keymap.format) catch unreachable;
                buf.putFd(keymap.fd) catch unreachable;
                buf.putUInt(keymap.size) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                fds: *wayland.Buffer,
            ) KeymapEvent {
                var i: usize = 0;
                return KeymapEvent{
                    .format = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .fd = blk: {
                        _ = fds;
                        break :blk undefined;
                    },
                    .size = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                keymap: KeymapEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_keyboard.keymap(");
                try writer.writeAll("format: ");
                try writer.print("{any}u", .{keymap.format});
                try writer.writeAll(", ");
                try writer.writeAll("fd: ");
                try writer.print("{any}", .{keymap.fd});
                try writer.writeAll(", ");
                try writer.writeAll("size: ");
                try writer.print("{any}u", .{keymap.size});
                try writer.writeAll(")");
            }
        };
        pub const EnterEvent = struct {
            serial: u32,
            surface: ?Surface,
            keys: []const u8,
            pub fn marshal(
                enter: EnterEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 20 + ((enter.keys.len + 3) / 4 * 4);
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(enter.serial) catch unreachable;
                buf.putUInt(enter.surface.object.id) catch unreachable;
                buf.putArray(enter.keys) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) EnterEvent {
                var i: usize = 0;
                return EnterEvent{
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .surface = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .keys = blk: {
                        const arg_len = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        const arg_padded_len = (arg_len + 3) / 4 * 4;
                        const arg = msg.data[i + 4 .. i + 4 + arg_len];
                        i += 4 + arg_padded_len;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                enter: EnterEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_keyboard.enter(");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{enter.serial});
                try writer.writeAll(", ");
                try writer.writeAll("surface: ");
                try writer.print("{any}", .{enter.surface});
                try writer.writeAll(", ");
                try writer.writeAll("keys: ");
                try writer.print("{any}", .{enter.keys});
                try writer.writeAll(")");
            }
        };
        pub const LeaveEvent = struct {
            serial: u32,
            surface: ?Surface,
            pub fn marshal(
                leave: LeaveEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 16;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 2) catch unreachable;
                buf.putUInt(leave.serial) catch unreachable;
                buf.putUInt(leave.surface.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) LeaveEvent {
                var i: usize = 0;
                return LeaveEvent{
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .surface = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                leave: LeaveEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_keyboard.leave(");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{leave.serial});
                try writer.writeAll(", ");
                try writer.writeAll("surface: ");
                try writer.print("{any}", .{leave.surface});
                try writer.writeAll(")");
            }
        };
        pub const KeyEvent = struct {
            serial: u32,
            time: u32,
            key: u32,
            state: u32,
            pub fn marshal(
                key: KeyEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 24;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 3) catch unreachable;
                buf.putUInt(key.serial) catch unreachable;
                buf.putUInt(key.time) catch unreachable;
                buf.putUInt(key.key) catch unreachable;
                buf.putUInt(key.state) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) KeyEvent {
                var i: usize = 0;
                return KeyEvent{
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .time = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .key = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .state = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                key: KeyEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_keyboard.key(");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{key.serial});
                try writer.writeAll(", ");
                try writer.writeAll("time: ");
                try writer.print("{any}u", .{key.time});
                try writer.writeAll(", ");
                try writer.writeAll("key: ");
                try writer.print("{any}u", .{key.key});
                try writer.writeAll(", ");
                try writer.writeAll("state: ");
                try writer.print("{any}u", .{key.state});
                try writer.writeAll(")");
            }
        };
        pub const ModifiersEvent = struct {
            serial: u32,
            mods_depressed: u32,
            mods_latched: u32,
            mods_locked: u32,
            group: u32,
            pub fn marshal(
                modifiers: ModifiersEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 28;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 4) catch unreachable;
                buf.putUInt(modifiers.serial) catch unreachable;
                buf.putUInt(modifiers.mods_depressed) catch unreachable;
                buf.putUInt(modifiers.mods_latched) catch unreachable;
                buf.putUInt(modifiers.mods_locked) catch unreachable;
                buf.putUInt(modifiers.group) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) ModifiersEvent {
                var i: usize = 0;
                return ModifiersEvent{
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .mods_depressed = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .mods_latched = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .mods_locked = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .group = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                modifiers: ModifiersEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_keyboard.modifiers(");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{modifiers.serial});
                try writer.writeAll(", ");
                try writer.writeAll("mods_depressed: ");
                try writer.print("{any}u", .{modifiers.mods_depressed});
                try writer.writeAll(", ");
                try writer.writeAll("mods_latched: ");
                try writer.print("{any}u", .{modifiers.mods_latched});
                try writer.writeAll(", ");
                try writer.writeAll("mods_locked: ");
                try writer.print("{any}u", .{modifiers.mods_locked});
                try writer.writeAll(", ");
                try writer.writeAll("group: ");
                try writer.print("{any}u", .{modifiers.group});
                try writer.writeAll(")");
            }
        };
        pub const RepeatInfoEvent = struct {
            rate: i32,
            delay: i32,
            pub fn marshal(
                repeat_info: RepeatInfoEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 16;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 5) catch unreachable;
                buf.putInt(repeat_info.rate) catch unreachable;
                buf.putInt(repeat_info.delay) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) RepeatInfoEvent {
                var i: usize = 0;
                return RepeatInfoEvent{
                    .rate = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .delay = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                repeat_info: RepeatInfoEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_keyboard.repeat_info(");
                try writer.writeAll("rate: ");
                try writer.print("{any}i", .{repeat_info.rate});
                try writer.writeAll(", ");
                try writer.writeAll("delay: ");
                try writer.print("{any}i", .{repeat_info.delay});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(event: Event, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (event) {
                .keymap => |keymap| keymap.marshal(id, buf),
                .enter => |enter| enter.marshal(id, buf),
                .leave => |leave| leave.marshal(id, buf),
                .key => |key| key.marshal(id, buf),
                .modifiers => |modifiers| modifiers.marshal(id, buf),
                .repeat_info => |repeat_info| repeat_info.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Event {
            return switch (@intToEnum(std.meta.Tag(Event), msg.op)) {
                .keymap => Event{ .keymap = KeymapEvent.unmarshal(conn, msg, fds) },
                .enter => Event{ .enter = EnterEvent.unmarshal(conn, msg, fds) },
                .leave => Event{ .leave = LeaveEvent.unmarshal(conn, msg, fds) },
                .key => Event{ .key = KeyEvent.unmarshal(conn, msg, fds) },
                .modifiers => Event{ .modifiers = ModifiersEvent.unmarshal(conn, msg, fds) },
                .repeat_info => Event{ .repeat_info = RepeatInfoEvent.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            event: Event,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (event) {
                .keymap => |keymap| keymap._format(fmt, options, writer),
                .enter => |enter| enter._format(fmt, options, writer),
                .leave => |leave| leave._format(fmt, options, writer),
                .key => |key| key._format(fmt, options, writer),
                .modifiers => |modifiers| modifiers._format(fmt, options, writer),
                .repeat_info => |repeat_info| repeat_info._format(fmt, options, writer),
            };
        }
    };
};
pub const Touch = struct {
    object: wayland.client.Object,
    pub const interface = "wl_touch";
    pub const version = 7;
    pub usingnamespace struct {
        pub fn release() error{BufferFull}!void {}
    };
    pub const Enum = struct {};
    pub const Request = union(enum(u16)) {
        release: ReleaseRequest = 0,
        pub const ReleaseRequest = struct {
            pub fn marshal(
                _: ReleaseRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) ReleaseRequest {
                return ReleaseRequest{};
            }
            pub fn _format(
                _: ReleaseRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_touch.release(");
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .release => |release| release.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .release => Request{ .release = ReleaseRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .release => |release| release._format(fmt, options, writer),
            };
        }
    };
    pub const Event = union(enum(u16)) {
        down: DownEvent = 0,
        up: UpEvent = 1,
        motion: MotionEvent = 2,
        frame: FrameEvent = 3,
        cancel: CancelEvent = 4,
        shape: ShapeEvent = 5,
        orientation: OrientationEvent = 6,
        pub const DownEvent = struct {
            serial: u32,
            time: u32,
            surface: ?Surface,
            id: i32,
            x: f64,
            y: f64,
            pub fn marshal(
                down: DownEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 32;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putUInt(down.serial) catch unreachable;
                buf.putUInt(down.time) catch unreachable;
                buf.putUInt(down.surface.object.id) catch unreachable;
                buf.putInt(down.id) catch unreachable;
                buf.putFixed(down.x) catch unreachable;
                buf.putFixed(down.y) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) DownEvent {
                var i: usize = 0;
                return DownEvent{
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .time = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .surface = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .id = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .x = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .y = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                down: DownEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_touch.down(");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{down.serial});
                try writer.writeAll(", ");
                try writer.writeAll("time: ");
                try writer.print("{any}u", .{down.time});
                try writer.writeAll(", ");
                try writer.writeAll("surface: ");
                try writer.print("{any}", .{down.surface});
                try writer.writeAll(", ");
                try writer.writeAll("id: ");
                try writer.print("{any}i", .{down.id});
                try writer.writeAll(", ");
                try writer.writeAll("x: ");
                try writer.print("{any}f", .{down.x});
                try writer.writeAll(", ");
                try writer.writeAll("y: ");
                try writer.print("{any}f", .{down.y});
                try writer.writeAll(")");
            }
        };
        pub const UpEvent = struct {
            serial: u32,
            time: u32,
            id: i32,
            pub fn marshal(
                up: UpEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 20;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(up.serial) catch unreachable;
                buf.putUInt(up.time) catch unreachable;
                buf.putInt(up.id) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) UpEvent {
                var i: usize = 0;
                return UpEvent{
                    .serial = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .time = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .id = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                up: UpEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_touch.up(");
                try writer.writeAll("serial: ");
                try writer.print("{any}u", .{up.serial});
                try writer.writeAll(", ");
                try writer.writeAll("time: ");
                try writer.print("{any}u", .{up.time});
                try writer.writeAll(", ");
                try writer.writeAll("id: ");
                try writer.print("{any}i", .{up.id});
                try writer.writeAll(")");
            }
        };
        pub const MotionEvent = struct {
            time: u32,
            id: i32,
            x: f64,
            y: f64,
            pub fn marshal(
                motion: MotionEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 24;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 2) catch unreachable;
                buf.putUInt(motion.time) catch unreachable;
                buf.putInt(motion.id) catch unreachable;
                buf.putFixed(motion.x) catch unreachable;
                buf.putFixed(motion.y) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) MotionEvent {
                var i: usize = 0;
                return MotionEvent{
                    .time = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .id = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .x = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .y = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                motion: MotionEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_touch.motion(");
                try writer.writeAll("time: ");
                try writer.print("{any}u", .{motion.time});
                try writer.writeAll(", ");
                try writer.writeAll("id: ");
                try writer.print("{any}i", .{motion.id});
                try writer.writeAll(", ");
                try writer.writeAll("x: ");
                try writer.print("{any}f", .{motion.x});
                try writer.writeAll(", ");
                try writer.writeAll("y: ");
                try writer.print("{any}f", .{motion.y});
                try writer.writeAll(")");
            }
        };
        pub const FrameEvent = struct {
            pub fn marshal(
                _: FrameEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 3) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) FrameEvent {
                return FrameEvent{};
            }
            pub fn _format(
                _: FrameEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_touch.frame(");
                try writer.writeAll(")");
            }
        };
        pub const CancelEvent = struct {
            pub fn marshal(
                _: CancelEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 4) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) CancelEvent {
                return CancelEvent{};
            }
            pub fn _format(
                _: CancelEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_touch.cancel(");
                try writer.writeAll(")");
            }
        };
        pub const ShapeEvent = struct {
            id: i32,
            major: f64,
            minor: f64,
            pub fn marshal(
                shape: ShapeEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 20;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 5) catch unreachable;
                buf.putInt(shape.id) catch unreachable;
                buf.putFixed(shape.major) catch unreachable;
                buf.putFixed(shape.minor) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) ShapeEvent {
                var i: usize = 0;
                return ShapeEvent{
                    .id = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .major = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .minor = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                shape: ShapeEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_touch.shape(");
                try writer.writeAll("id: ");
                try writer.print("{any}i", .{shape.id});
                try writer.writeAll(", ");
                try writer.writeAll("major: ");
                try writer.print("{any}f", .{shape.major});
                try writer.writeAll(", ");
                try writer.writeAll("minor: ");
                try writer.print("{any}f", .{shape.minor});
                try writer.writeAll(")");
            }
        };
        pub const OrientationEvent = struct {
            id: i32,
            orientation: f64,
            pub fn marshal(
                orientation: OrientationEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 16;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 6) catch unreachable;
                buf.putInt(orientation.id) catch unreachable;
                buf.putFixed(orientation.orientation) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) OrientationEvent {
                var i: usize = 0;
                return OrientationEvent{
                    .id = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .orientation = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                orientation: OrientationEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_touch.orientation(");
                try writer.writeAll("id: ");
                try writer.print("{any}i", .{orientation.id});
                try writer.writeAll(", ");
                try writer.writeAll("orientation: ");
                try writer.print("{any}f", .{orientation.orientation});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(event: Event, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (event) {
                .down => |down| down.marshal(id, buf),
                .up => |up| up.marshal(id, buf),
                .motion => |motion| motion.marshal(id, buf),
                .frame => |frame| frame.marshal(id, buf),
                .cancel => |cancel| cancel.marshal(id, buf),
                .shape => |shape| shape.marshal(id, buf),
                .orientation => |orientation| orientation.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Event {
            return switch (@intToEnum(std.meta.Tag(Event), msg.op)) {
                .down => Event{ .down = DownEvent.unmarshal(conn, msg, fds) },
                .up => Event{ .up = UpEvent.unmarshal(conn, msg, fds) },
                .motion => Event{ .motion = MotionEvent.unmarshal(conn, msg, fds) },
                .frame => Event{ .frame = FrameEvent.unmarshal(conn, msg, fds) },
                .cancel => Event{ .cancel = CancelEvent.unmarshal(conn, msg, fds) },
                .shape => Event{ .shape = ShapeEvent.unmarshal(conn, msg, fds) },
                .orientation => Event{ .orientation = OrientationEvent.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            event: Event,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (event) {
                .down => |down| down._format(fmt, options, writer),
                .up => |up| up._format(fmt, options, writer),
                .motion => |motion| motion._format(fmt, options, writer),
                .frame => |frame| frame._format(fmt, options, writer),
                .cancel => |cancel| cancel._format(fmt, options, writer),
                .shape => |shape| shape._format(fmt, options, writer),
                .orientation => |orientation| orientation._format(fmt, options, writer),
            };
        }
    };
};
pub const Output = struct {
    object: wayland.client.Object,
    pub const interface = "wl_output";
    pub const version = 3;
    pub usingnamespace struct {
        pub fn release() error{BufferFull}!void {}
    };
    pub const Enum = struct {
        pub const Subpixel = enum(u32) {
            unknown = 0,
            none = 1,
            horizontal_rgb = 2,
            horizontal_bgr = 3,
            vertical_rgb = 4,
            vertical_bgr = 5,
            pub fn toInt(subpixel: Subpixel) u32 {
                return @enumToInt(subpixel);
            }
            pub fn fromInt(int: u32) Subpixel {
                return @intToEnum(Subpixel, int);
            }
        };
        pub const Transform = enum(u32) {
            normal = 0,
            @"90" = 1,
            @"180" = 2,
            @"270" = 3,
            flipped = 4,
            flipped_90 = 5,
            flipped_180 = 6,
            flipped_270 = 7,
            pub fn toInt(transform: Transform) u32 {
                return @enumToInt(transform);
            }
            pub fn fromInt(int: u32) Transform {
                return @intToEnum(Transform, int);
            }
        };
        pub const Mode = packed struct {
            current: bool = false,
            preferred: bool = false,
            pub fn toInt(mode: Mode) u32 {
                var result: u32 = 0;
                if (mode.current)
                    result &= 1;
                if (mode.preferred)
                    result &= 2;
                return result;
            }
            pub fn fromInt(int: u32) Mode {
                return Mode{
                    .current = (int & 1) != 0,
                    .preferred = (int & 2) != 0,
                };
            }
        };
    };
    pub const Request = union(enum(u16)) {
        release: ReleaseRequest = 0,
        pub const ReleaseRequest = struct {
            pub fn marshal(
                _: ReleaseRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) ReleaseRequest {
                return ReleaseRequest{};
            }
            pub fn _format(
                _: ReleaseRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_output.release(");
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .release => |release| release.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .release => Request{ .release = ReleaseRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .release => |release| release._format(fmt, options, writer),
            };
        }
    };
    pub const Event = union(enum(u16)) {
        geometry: GeometryEvent = 0,
        mode: ModeEvent = 1,
        done: DoneEvent = 2,
        scale: ScaleEvent = 3,
        pub const GeometryEvent = struct {
            x: i32,
            y: i32,
            physical_width: i32,
            physical_height: i32,
            subpixel: i32,
            make: [:0]const u8,
            model: [:0]const u8,
            transform: i32,
            pub fn marshal(
                geometry: GeometryEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 40 + ((geometry.make.len + 3) / 4 * 4) + ((geometry.model.len + 3) / 4 * 4);
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
                buf.putInt(geometry.x) catch unreachable;
                buf.putInt(geometry.y) catch unreachable;
                buf.putInt(geometry.physical_width) catch unreachable;
                buf.putInt(geometry.physical_height) catch unreachable;
                buf.putInt(geometry.subpixel) catch unreachable;
                buf.putString(geometry.make) catch unreachable;
                buf.putString(geometry.model) catch unreachable;
                buf.putInt(geometry.transform) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) GeometryEvent {
                var i: usize = 0;
                return GeometryEvent{
                    .x = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .y = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .physical_width = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .physical_height = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .subpixel = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .make = blk: {
                        const arg_len = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        const arg_padded_len = (arg_len + 3) / 4 * 4;
                        const arg = msg.data[i + 4 .. i + 4 + arg_len - 1 :0];
                        i += 4 + arg_padded_len;
                        break :blk arg;
                    },
                    .model = blk: {
                        const arg_len = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        const arg_padded_len = (arg_len + 3) / 4 * 4;
                        const arg = msg.data[i + 4 .. i + 4 + arg_len - 1 :0];
                        i += 4 + arg_padded_len;
                        break :blk arg;
                    },
                    .transform = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                geometry: GeometryEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_output.geometry(");
                try writer.writeAll("x: ");
                try writer.print("{any}i", .{geometry.x});
                try writer.writeAll(", ");
                try writer.writeAll("y: ");
                try writer.print("{any}i", .{geometry.y});
                try writer.writeAll(", ");
                try writer.writeAll("physical_width: ");
                try writer.print("{any}i", .{geometry.physical_width});
                try writer.writeAll(", ");
                try writer.writeAll("physical_height: ");
                try writer.print("{any}i", .{geometry.physical_height});
                try writer.writeAll(", ");
                try writer.writeAll("subpixel: ");
                try writer.print("{any}i", .{geometry.subpixel});
                try writer.writeAll(", ");
                try writer.writeAll("make: ");
                try writer.print("\"{}\"", .{@import("std").zig.fmtEscapes(geometry.make)});
                try writer.writeAll(", ");
                try writer.writeAll("model: ");
                try writer.print("\"{}\"", .{@import("std").zig.fmtEscapes(geometry.model)});
                try writer.writeAll(", ");
                try writer.writeAll("transform: ");
                try writer.print("{any}i", .{geometry.transform});
                try writer.writeAll(")");
            }
        };
        pub const ModeEvent = struct {
            flags: u32,
            width: i32,
            height: i32,
            refresh: i32,
            pub fn marshal(
                mode: ModeEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 24;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(mode.flags) catch unreachable;
                buf.putInt(mode.width) catch unreachable;
                buf.putInt(mode.height) catch unreachable;
                buf.putInt(mode.refresh) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) ModeEvent {
                var i: usize = 0;
                return ModeEvent{
                    .flags = blk: {
                        const arg = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .width = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .height = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .refresh = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                mode: ModeEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_output.mode(");
                try writer.writeAll("flags: ");
                try writer.print("{any}u", .{mode.flags});
                try writer.writeAll(", ");
                try writer.writeAll("width: ");
                try writer.print("{any}i", .{mode.width});
                try writer.writeAll(", ");
                try writer.writeAll("height: ");
                try writer.print("{any}i", .{mode.height});
                try writer.writeAll(", ");
                try writer.writeAll("refresh: ");
                try writer.print("{any}i", .{mode.refresh});
                try writer.writeAll(")");
            }
        };
        pub const DoneEvent = struct {
            pub fn marshal(
                _: DoneEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 2) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) DoneEvent {
                return DoneEvent{};
            }
            pub fn _format(
                _: DoneEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_output.done(");
                try writer.writeAll(")");
            }
        };
        pub const ScaleEvent = struct {
            factor: i32,
            pub fn marshal(
                scale: ScaleEvent,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 3) catch unreachable;
                buf.putInt(scale.factor) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) ScaleEvent {
                var i: usize = 0;
                return ScaleEvent{
                    .factor = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                scale: ScaleEvent,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_output.scale(");
                try writer.writeAll("factor: ");
                try writer.print("{any}i", .{scale.factor});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(event: Event, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (event) {
                .geometry => |geometry| geometry.marshal(id, buf),
                .mode => |mode| mode.marshal(id, buf),
                .done => |done| done.marshal(id, buf),
                .scale => |scale| scale.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Event {
            return switch (@intToEnum(std.meta.Tag(Event), msg.op)) {
                .geometry => Event{ .geometry = GeometryEvent.unmarshal(conn, msg, fds) },
                .mode => Event{ .mode = ModeEvent.unmarshal(conn, msg, fds) },
                .done => Event{ .done = DoneEvent.unmarshal(conn, msg, fds) },
                .scale => Event{ .scale = ScaleEvent.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            event: Event,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (event) {
                .geometry => |geometry| geometry._format(fmt, options, writer),
                .mode => |mode| mode._format(fmt, options, writer),
                .done => |done| done._format(fmt, options, writer),
                .scale => |scale| scale._format(fmt, options, writer),
            };
        }
    };
};
pub const Region = struct {
    object: wayland.client.Object,
    pub const interface = "wl_region";
    pub const version = 1;
    pub usingnamespace struct {
        pub fn destroy() error{BufferFull}!void {}
        pub fn add() error{BufferFull}!void {}
        pub fn subtract() error{BufferFull}!void {}
    };
    pub const Enum = struct {};
    pub const Request = union(enum(u16)) {
        destroy: DestroyRequest = 0,
        add: AddRequest = 1,
        subtract: SubtractRequest = 2,
        pub const DestroyRequest = struct {
            pub fn marshal(
                _: DestroyRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) DestroyRequest {
                return DestroyRequest{};
            }
            pub fn _format(
                _: DestroyRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_region.destroy(");
                try writer.writeAll(")");
            }
        };
        pub const AddRequest = struct {
            x: i32,
            y: i32,
            width: i32,
            height: i32,
            pub fn marshal(
                add: AddRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 24;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putInt(add.x) catch unreachable;
                buf.putInt(add.y) catch unreachable;
                buf.putInt(add.width) catch unreachable;
                buf.putInt(add.height) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) AddRequest {
                var i: usize = 0;
                return AddRequest{
                    .x = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .y = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .width = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .height = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                add: AddRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_region.add(");
                try writer.writeAll("x: ");
                try writer.print("{any}i", .{add.x});
                try writer.writeAll(", ");
                try writer.writeAll("y: ");
                try writer.print("{any}i", .{add.y});
                try writer.writeAll(", ");
                try writer.writeAll("width: ");
                try writer.print("{any}i", .{add.width});
                try writer.writeAll(", ");
                try writer.writeAll("height: ");
                try writer.print("{any}i", .{add.height});
                try writer.writeAll(")");
            }
        };
        pub const SubtractRequest = struct {
            x: i32,
            y: i32,
            width: i32,
            height: i32,
            pub fn marshal(
                subtract: SubtractRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 24;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 2) catch unreachable;
                buf.putInt(subtract.x) catch unreachable;
                buf.putInt(subtract.y) catch unreachable;
                buf.putInt(subtract.width) catch unreachable;
                buf.putInt(subtract.height) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SubtractRequest {
                var i: usize = 0;
                return SubtractRequest{
                    .x = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .y = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .width = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .height = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                subtract: SubtractRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_region.subtract(");
                try writer.writeAll("x: ");
                try writer.print("{any}i", .{subtract.x});
                try writer.writeAll(", ");
                try writer.writeAll("y: ");
                try writer.print("{any}i", .{subtract.y});
                try writer.writeAll(", ");
                try writer.writeAll("width: ");
                try writer.print("{any}i", .{subtract.width});
                try writer.writeAll(", ");
                try writer.writeAll("height: ");
                try writer.print("{any}i", .{subtract.height});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .destroy => |destroy| destroy.marshal(id, buf),
                .add => |add| add.marshal(id, buf),
                .subtract => |subtract| subtract.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .destroy => Request{ .destroy = DestroyRequest.unmarshal(conn, msg, fds) },
                .add => Request{ .add = AddRequest.unmarshal(conn, msg, fds) },
                .subtract => Request{ .subtract = SubtractRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .destroy => |destroy| destroy._format(fmt, options, writer),
                .add => |add| add._format(fmt, options, writer),
                .subtract => |subtract| subtract._format(fmt, options, writer),
            };
        }
    };
};
pub const Subcompositor = struct {
    object: wayland.client.Object,
    pub const interface = "wl_subcompositor";
    pub const version = 1;
    pub usingnamespace struct {
        pub fn destroy() error{BufferFull}!void {}
        pub fn getSubsurface() error{BufferFull}!void {}
    };
    pub const Enum = struct {
        pub const Error = enum(u32) {
            bad_surface = 0,
            pub fn toInt(@"error": Error) u32 {
                return @enumToInt(@"error");
            }
            pub fn fromInt(int: u32) Error {
                return @intToEnum(Error, int);
            }
        };
    };
    pub const Request = union(enum(u16)) {
        destroy: DestroyRequest = 0,
        get_subsurface: GetSubsurfaceRequest = 1,
        pub const DestroyRequest = struct {
            pub fn marshal(
                _: DestroyRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) DestroyRequest {
                return DestroyRequest{};
            }
            pub fn _format(
                _: DestroyRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_subcompositor.destroy(");
                try writer.writeAll(")");
            }
        };
        pub const GetSubsurfaceRequest = struct {
            id: Subsurface,
            surface: ?Surface,
            parent: ?Surface,
            pub fn marshal(
                get_subsurface: GetSubsurfaceRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 20;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putUInt(get_subsurface.id.object.id) catch unreachable;
                buf.putUInt(get_subsurface.surface.object.id) catch unreachable;
                buf.putUInt(get_subsurface.parent.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) GetSubsurfaceRequest {
                var i: usize = 0;
                return GetSubsurfaceRequest{
                    .id = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .surface = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                    .parent = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                get_subsurface: GetSubsurfaceRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_subcompositor.get_subsurface(");
                try writer.writeAll("id: ");
                try writer.print("{any}", .{get_subsurface.id});
                try writer.writeAll(", ");
                try writer.writeAll("surface: ");
                try writer.print("{any}", .{get_subsurface.surface});
                try writer.writeAll(", ");
                try writer.writeAll("parent: ");
                try writer.print("{any}", .{get_subsurface.parent});
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .destroy => |destroy| destroy.marshal(id, buf),
                .get_subsurface => |get_subsurface| get_subsurface.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .destroy => Request{ .destroy = DestroyRequest.unmarshal(conn, msg, fds) },
                .get_subsurface => Request{ .get_subsurface = GetSubsurfaceRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .destroy => |destroy| destroy._format(fmt, options, writer),
                .get_subsurface => |get_subsurface| get_subsurface._format(fmt, options, writer),
            };
        }
    };
};
pub const Subsurface = struct {
    object: wayland.client.Object,
    pub const interface = "wl_subsurface";
    pub const version = 1;
    pub usingnamespace struct {
        pub fn destroy() error{BufferFull}!void {}
        pub fn setPosition() error{BufferFull}!void {}
        pub fn placeAbove() error{BufferFull}!void {}
        pub fn placeBelow() error{BufferFull}!void {}
        pub fn setSync() error{BufferFull}!void {}
        pub fn setDesync() error{BufferFull}!void {}
    };
    pub const Enum = struct {
        pub const Error = enum(u32) {
            bad_surface = 0,
            pub fn toInt(@"error": Error) u32 {
                return @enumToInt(@"error");
            }
            pub fn fromInt(int: u32) Error {
                return @intToEnum(Error, int);
            }
        };
    };
    pub const Request = union(enum(u16)) {
        destroy: DestroyRequest = 0,
        set_position: SetPositionRequest = 1,
        place_above: PlaceAboveRequest = 2,
        place_below: PlaceBelowRequest = 3,
        set_sync: SetSyncRequest = 4,
        set_desync: SetDesyncRequest = 5,
        pub const DestroyRequest = struct {
            pub fn marshal(
                _: DestroyRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 0) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) DestroyRequest {
                return DestroyRequest{};
            }
            pub fn _format(
                _: DestroyRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_subsurface.destroy(");
                try writer.writeAll(")");
            }
        };
        pub const SetPositionRequest = struct {
            x: i32,
            y: i32,
            pub fn marshal(
                set_position: SetPositionRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 16;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 1) catch unreachable;
                buf.putInt(set_position.x) catch unreachable;
                buf.putInt(set_position.y) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) SetPositionRequest {
                var i: usize = 0;
                return SetPositionRequest{
                    .x = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                    .y = blk: {
                        const arg = @ptrCast(*align(1) const i32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk arg;
                    },
                };
            }
            pub fn _format(
                set_position: SetPositionRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_subsurface.set_position(");
                try writer.writeAll("x: ");
                try writer.print("{any}i", .{set_position.x});
                try writer.writeAll(", ");
                try writer.writeAll("y: ");
                try writer.print("{any}i", .{set_position.y});
                try writer.writeAll(")");
            }
        };
        pub const PlaceAboveRequest = struct {
            sibling: ?Surface,
            pub fn marshal(
                place_above: PlaceAboveRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 2) catch unreachable;
                buf.putUInt(place_above.sibling.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) PlaceAboveRequest {
                var i: usize = 0;
                return PlaceAboveRequest{
                    .sibling = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                place_above: PlaceAboveRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_subsurface.place_above(");
                try writer.writeAll("sibling: ");
                try writer.print("{any}", .{place_above.sibling});
                try writer.writeAll(")");
            }
        };
        pub const PlaceBelowRequest = struct {
            sibling: ?Surface,
            pub fn marshal(
                place_below: PlaceBelowRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 12;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 3) catch unreachable;
                buf.putUInt(place_below.sibling.object.id) catch unreachable;
            }
            pub fn unmarshal(
                conn: *wayland.client.Connection,
                msg: wayland.Message,
                _: *wayland.Buffer,
            ) PlaceBelowRequest {
                var i: usize = 0;
                return PlaceBelowRequest{
                    .sibling = blk: {
                        const arg_id = @ptrCast(*align(1) const u32, msg.data[i .. i + 4]).*;
                        i += 4;
                        break :blk wayland.client.Object{ .conn = conn, .id = arg_id };
                    },
                };
            }
            pub fn _format(
                place_below: PlaceBelowRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_subsurface.place_below(");
                try writer.writeAll("sibling: ");
                try writer.print("{any}", .{place_below.sibling});
                try writer.writeAll(")");
            }
        };
        pub const SetSyncRequest = struct {
            pub fn marshal(
                _: SetSyncRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 4) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) SetSyncRequest {
                return SetSyncRequest{};
            }
            pub fn _format(
                _: SetSyncRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_subsurface.set_sync(");
                try writer.writeAll(")");
            }
        };
        pub const SetDesyncRequest = struct {
            pub fn marshal(
                _: SetDesyncRequest,
                id: u32,
                buf: *wayland.Buffer,
            ) error{BufferFull}!void {
                const len: usize = 8;
                if (buf.bytes.writableLength() < len)
                    return error.BufferFull;
                if (buf.fds.writableLength() < 0)
                    return error.BufferFull;
                buf.putUInt(id) catch unreachable;
                buf.putUInt(@intCast(u32, len << 16) | 5) catch unreachable;
            }
            pub fn unmarshal(
                _: *wayland.client.Connection,
                _: wayland.Message,
                _: *wayland.Buffer,
            ) SetDesyncRequest {
                return SetDesyncRequest{};
            }
            pub fn _format(
                _: SetDesyncRequest,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                try writer.writeAll("wl_subsurface.set_desync(");
                try writer.writeAll(")");
            }
        };
        pub fn marshal(request: Request, id: u32, buf: *wayland.Buffer) error{BufferFull}!void {
            return switch (request) {
                .destroy => |destroy| destroy.marshal(id, buf),
                .set_position => |set_position| set_position.marshal(id, buf),
                .place_above => |place_above| place_above.marshal(id, buf),
                .place_below => |place_below| place_below.marshal(id, buf),
                .set_sync => |set_sync| set_sync.marshal(id, buf),
                .set_desync => |set_desync| set_desync.marshal(id, buf),
            };
        }
        pub fn unmarshal(
            conn: *wayland.client.Connection,
            msg: wayland.Message,
            fds: *wayland.Buffer,
        ) Request {
            return switch (@intToEnum(std.meta.Tag(Request), msg.op)) {
                .destroy => Request{ .destroy = DestroyRequest.unmarshal(conn, msg, fds) },
                .set_position => Request{ .set_position = SetPositionRequest.unmarshal(conn, msg, fds) },
                .place_above => Request{ .place_above = PlaceAboveRequest.unmarshal(conn, msg, fds) },
                .place_below => Request{ .place_below = PlaceBelowRequest.unmarshal(conn, msg, fds) },
                .set_sync => Request{ .set_sync = SetSyncRequest.unmarshal(conn, msg, fds) },
                .set_desync => Request{ .set_desync = SetDesyncRequest.unmarshal(conn, msg, fds) },
            };
        }
        pub fn _format(
            request: Request,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            return switch (request) {
                .destroy => |destroy| destroy._format(fmt, options, writer),
                .set_position => |set_position| set_position._format(fmt, options, writer),
                .place_above => |place_above| place_above._format(fmt, options, writer),
                .place_below => |place_below| place_below._format(fmt, options, writer),
                .set_sync => |set_sync| set_sync._format(fmt, options, writer),
                .set_desync => |set_desync| set_desync._format(fmt, options, writer),
            };
        }
    };
};
