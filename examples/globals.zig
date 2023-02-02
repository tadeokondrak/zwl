const wayland = @import("wayland");
const std = @import("std");

const Context = struct {
    gpa: std.heap.GeneralPurposeAllocator(.{}) = .{},
    conn: wayland.Connection = undefined,
    registry: wayland.protocol.WlRegistry = undefined,
    shm: ?wayland.protocol.WlShm = null,
    compositor: ?wayland.protocol.WlCompositor = null,
    xdg_wm_base: ?wayland.protocol.XdgWmBase = null,
    xdg_toplevel: ?wayland.protocol.XdgToplevel = null,
    surface: ?wayland.protocol.WlSurface = null,
    xdg_surface: ?wayland.protocol.XdgSurface = null,
    pool: ?wayland.protocol.WlShmPool = null,
    buffer: ?wayland.protocol.WlBuffer = null,
    pending_width: ?i32 = 0,
    pending_height: ?i32 = 0,
    pending_close: bool = false,
    width: u32 = 1024,
    height: u32 = 1024,
    stride: u32 = 1024 * 4,

    pub fn init(ctx: *Context) !void {
        ctx.conn = try wayland.Connection.init(ctx.gpa.allocator(), null);
        ctx.registry = try ctx.conn.getRegistry(*Context, wlRegistryHandler, ctx);
    }

    pub fn deinit(ctx: *Context) void {
        ctx.conn.deinit();
        _ = ctx.gpa.deinit();
    }

    pub fn run(ctx: *Context) !void {
        try ctx.conn.flush();
        try ctx.conn.read();
        try ctx.conn.dispatch();

        ctx.surface = try ctx.compositor.?.createSurface(&ctx.conn, *Context, wlSurfaceHandler, ctx);
        ctx.xdg_surface = try ctx.xdg_wm_base.?.getXdgSurface(&ctx.conn, *Context, xdgSurfaceHandler, ctx, ctx.surface.?);
        ctx.xdg_toplevel = try ctx.xdg_surface.?.getToplevel(&ctx.conn, *Context, xdgToplevelHandler, ctx);

        try ctx.surface.?.commit(&ctx.conn);
        try ctx.conn.flush();
        try ctx.conn.read();
        try ctx.conn.dispatch();

        try ctx.draw();

        while (!ctx.pending_close) {
            try ctx.conn.flush();
            try ctx.conn.read();
            try ctx.conn.dispatch();
        }
    }

    fn draw(ctx: *Context) !void {
        const size = ctx.height * ctx.stride;
        const memfd = try std.os.memfd_createZ("thing", 0);
        try std.os.ftruncate(memfd, size);
        std.debug.print("{}", .{.{ ctx.height, ctx.width, ctx.stride, size, memfd }});
        ctx.pool = try ctx.shm.?.createPool(&ctx.conn, *Context, wlShmPoolHandler, ctx, memfd, @intCast(i32, size));
        ctx.buffer = try ctx.pool.?.createBuffer(&ctx.conn, *Context, wlBufferHandler, ctx, 0, @intCast(i32, ctx.width), @intCast(i32, ctx.height), @intCast(i32, ctx.stride), 0);
        const mapped = try std.os.mmap(null, size, std.os.PROT.READ | std.os.PROT.WRITE, std.os.MAP.SHARED, memfd, 0);
        var rand = std.rand.SplitMix64.init(@intCast(u64, memfd) * 1000);
        var y: usize = 0;
        while (y < ctx.height) : (y += 1) {
            var x: usize = 0;
            while (x < ctx.width) : (x += 1) {
                const i = y * ctx.stride + x * 4;
                mapped[i + 0] = @truncate(u8, rand.next());
                mapped[i + 1] = @truncate(u8, rand.next());
                mapped[i + 2] = @truncate(u8, rand.next());
                mapped[i + 3] = @truncate(u8, 255);
            }
        }
        try ctx.surface.?.attach(&ctx.conn, ctx.buffer.?, 0, 0);
        try ctx.surface.?.commit(&ctx.conn);
        _ = try ctx.surface.?.frame(&ctx.conn, *Context, wlCallbackHandler, ctx);
        std.debug.print("drawn\n", .{});
        try ctx.surface.?.commit(&ctx.conn);
    }

    fn wlCallbackHandler(
        _: *wayland.Connection,
        _: wayland.protocol.WlCallback,
        _: wayland.protocol.WlCallbackEvent,
        ctx: *Context,
    ) void {
        std.debug.print("callback\n", .{});
        ctx.draw() catch unreachable;
    }

    fn wlRegistryHandler(
        conn: *wayland.Connection,
        registry: wayland.protocol.WlRegistry,
        event: wayland.protocol.WlRegistryEvent,
        ctx: *Context,
    ) void {
        switch (event) {
            .global => |global| {
                if (std.mem.eql(u8, global.interface, "wl_shm")) {
                    ctx.shm = registry.bind(conn, global.name, wayland.protocol.WlShm, 1, *Context, wlShmHandler, ctx) catch unreachable;
                } else if (std.mem.eql(u8, global.interface, "wl_compositor")) {
                    ctx.compositor = registry.bind(conn, global.name, wayland.protocol.WlCompositor, 1, *Context, wlCompositorHandler, ctx) catch unreachable;
                } else if (std.mem.eql(u8, global.interface, "xdg_wm_base")) {
                    ctx.xdg_wm_base = registry.bind(conn, global.name, wayland.protocol.XdgWmBase, 1, *Context, xdgWmBaseHandler, ctx) catch unreachable;
                }
            },
            .global_remove => {},
        }
    }

    fn wlShmHandler(_: *wayland.Connection, _: wayland.protocol.WlShm, _: wayland.protocol.WlShmEvent, _: *Context) void {}

    fn wlShmPoolHandler(_: *wayland.Connection, _: wayland.protocol.WlShmPool, _: wayland.protocol.WlShmPoolEvent, _: *Context) void {}

    fn wlBufferHandler(_: *wayland.Connection, _: wayland.protocol.WlBuffer, _: wayland.protocol.WlBufferEvent, _: *Context) void {}

    fn wlCompositorHandler(_: *wayland.Connection, _: wayland.protocol.WlCompositor, _: wayland.protocol.WlCompositorEvent, _: *Context) void {}

    fn wlSurfaceHandler(_: *wayland.Connection, _: wayland.protocol.WlSurface, _: wayland.protocol.WlSurfaceEvent, _: *Context) void {}

    fn xdgWmBaseHandler(
        conn: *wayland.Connection,
        xdg_wm_base: wayland.protocol.XdgWmBase,
        event: wayland.protocol.XdgWmBaseEvent,
        _: *Context,
    ) void {
        switch (event) {
            .ping => |ping| {
                xdg_wm_base.pong(conn, ping.serial) catch unreachable;
            },
        }
    }

    fn xdgSurfaceHandler(
        conn: *wayland.Connection,
        xdg_surface: wayland.protocol.XdgSurface,
        event: wayland.protocol.XdgSurfaceEvent,
        ctx: *Context,
    ) void {
        switch (event) {
            .configure => |configure| {
                ctx.width = @intCast(u32, ctx.pending_width.?);
                ctx.height = @intCast(u32, ctx.pending_height.?);
                ctx.stride = ctx.width * 4;
                xdg_surface.ackConfigure(conn, configure.serial) catch unreachable;
            },
        }
    }

    fn xdgToplevelHandler(
        _: *wayland.Connection,
        _: wayland.protocol.XdgToplevel,
        event: wayland.protocol.XdgToplevelEvent,
        ctx: *Context,
    ) void {
        switch (event) {
            .configure => |configure| {
                if (configure.width == 0 or configure.height == 0) {
                    ctx.pending_width = 1024;
                    ctx.pending_height = 1024;
                } else {
                    ctx.pending_width = configure.width;
                    ctx.pending_height = configure.height;
                }
            },
            .close => {
                ctx.pending_close = true;
            },
            .configure_bounds => {},
        }
    }
};

pub fn main() !void {
    var ctx = Context{};
    try ctx.init();
    defer ctx.deinit();
    try ctx.run();
}
