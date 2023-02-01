const wayland = @import("wayland");
const std = @import("std");

const Globals = struct {
    shm: ?wayland.protocol.WlShm = null,
    compositor: ?wayland.protocol.WlCompositor = null,
    xdg_wm_base: ?wayland.protocol.XdgWmBase = null,
};

fn wlRegistryHandler(
    conn: *wayland.Connection,
    registry: wayland.protocol.WlRegistry,
    event: wayland.protocol.WlRegistryEvent,
    globals: *Globals,
) void {
    switch (event) {
        .global => |global| {
            if (std.mem.eql(u8, global.interface, "wl_shm")) {
                globals.shm = registry.bind(conn, global.name, wayland.protocol.WlShm, 1, *const void, wlShmHandler, &{}) catch unreachable;
            } else if (std.mem.eql(u8, global.interface, "wl_compositor")) {
                globals.compositor = registry.bind(conn, global.name, wayland.protocol.WlCompositor, 1, *const void, wlCompositorHandler, &{}) catch unreachable;
            } else if (std.mem.eql(u8, global.interface, "xdg_wm_base")) {
                globals.xdg_wm_base = registry.bind(conn, global.name, wayland.protocol.XdgWmBase, 1, *const void, xdgWmBaseHandler, &{}) catch unreachable;
            }
        },
        .global_remove => {},
    }
}

fn wlShmHandler(
    conn: *wayland.Connection,
    registry: wayland.protocol.WlShm,
    event: wayland.protocol.WlShmEvent,
    _: *const void,
) void {
    _ = conn;
    _ = registry;
    _ = event;
}

fn wlShmPoolHandler(
    conn: *wayland.Connection,
    registry: wayland.protocol.WlShmPool,
    event: wayland.protocol.WlShmPoolEvent,
    _: *const void,
) void {
    _ = conn;
    _ = registry;
    _ = event;
}

fn wlBufferHandler(
    conn: *wayland.Connection,
    registry: wayland.protocol.WlBuffer,
    event: wayland.protocol.WlBufferEvent,
    _: *const void,
) void {
    _ = conn;
    _ = registry;
    _ = event;
}

fn wlCompositorHandler(
    conn: *wayland.Connection,
    registry: wayland.protocol.WlCompositor,
    event: wayland.protocol.WlCompositorEvent,
    _: *const void,
) void {
    _ = conn;
    _ = registry;
    _ = event;
}

fn wlSurfaceHandler(
    conn: *wayland.Connection,
    registry: wayland.protocol.WlSurface,
    event: wayland.protocol.WlSurfaceEvent,
    _: *const void,
) void {
    _ = conn;
    _ = registry;
    _ = event;
}

fn xdgWmBaseHandler(
    conn: *wayland.Connection,
    registry: wayland.protocol.XdgWmBase,
    event: wayland.protocol.XdgWmBaseEvent,
    _: *const void,
) void {
    _ = conn;
    _ = registry;
    _ = event;
}

fn xdgSurfaceHandler(
    conn: *wayland.Connection,
    xdg_surface: wayland.protocol.XdgSurface,
    event: wayland.protocol.XdgSurfaceEvent,
    _: *const void,
) void {
    switch (event) {
        .configure => |configure| {
            xdg_surface.ackConfigure(conn, configure.serial) catch unreachable;
        },
    }
}

fn xdgToplevelHandler(
    conn: *wayland.Connection,
    registry: wayland.protocol.XdgToplevel,
    event: wayland.protocol.XdgToplevelEvent,
    _: *const void,
) void {
    _ = conn;
    _ = registry;
    _ = event;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var conn = try wayland.Connection.init(gpa.allocator(), null);
    defer conn.deinit();
    var globals = Globals{};
    _ = try conn.getRegistry(*Globals, wlRegistryHandler, &globals);
    try conn.flush();
    try conn.read();
    try conn.dispatch();
    const shm = globals.shm.?;
    const compositor = globals.compositor.?;
    const xdg_wm_base = globals.xdg_wm_base.?;
    const width = 1024;
    const height = 1024;
    const stride = width * 4;
    const memfd = try std.os.memfd_createZ("thing", 0);
    const memfd_len = stride * height;
    try std.os.ftruncate(memfd, memfd_len);
    const mapped = try std.os.mmap(null, memfd_len, std.os.PROT.READ | std.os.PROT.WRITE, std.os.MAP.SHARED, memfd, 0);
    const surface = try compositor.createSurface(&conn, *const void, wlSurfaceHandler, &{});
    const xdg_surface = try xdg_wm_base.getXdgSurface(&conn, *const void, xdgSurfaceHandler, &{}, surface);
    const xdg_toplevel = try xdg_surface.getToplevel(&conn, *const void, xdgToplevelHandler, &{});
    const pool = try shm.createPool(&conn, *const void, wlShmPoolHandler, &{}, memfd, memfd_len);
    const buffer = try pool.createBuffer(&conn, *const void, wlBufferHandler, &{}, 0, width, height, stride, 0);
    try surface.commit(&conn);
    try conn.flush();
    try conn.read();
    try conn.dispatch();
    try surface.attach(&conn, buffer, 0, 0);
    try surface.commit(&conn);
    var i: usize = 0;
    var rand = std.rand.SplitMix64.init(0);
    while (i < memfd_len - 4) : (i += 4) {
        mapped[i + 0] = @truncate(u8, rand.next());
        mapped[i + 1] = @truncate(u8, rand.next());
        mapped[i + 2] = @truncate(u8, rand.next());
        mapped[i + 3] = 0xff;
    }
    _ = xdg_toplevel;
    while (true) {
        try conn.flush();
        try conn.read();
        try conn.dispatch();
    }
}
