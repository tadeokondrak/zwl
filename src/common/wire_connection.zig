const std = @import("std");
const os = std.os;
const Buffer = @import("buffer.zig").Buffer;

pub const WireConnection = struct {
    socket: std.fs.File,
    in: Buffer,
    out: Buffer,

    pub fn init(socket: std.fs.File) WireConnection {
        return .{
            .socket = socket,
            .in = Buffer.init(),
            .out = Buffer.init(),
        };
    }

    pub fn read(conn: *WireConnection) !void {
        if (conn.in.bytes.writable() == 0)
            return error.BufferFull;
        const write_slices = conn.in.bytes.writeSlices();
        const vecs = [2]os.iovec{
            .{ .iov_base = write_slices[0].ptr, .iov_len = write_slices[0].len },
            .{ .iov_base = write_slices[1].ptr, .iov_len = write_slices[1].len },
        };
        const vec_slice = if (write_slices[1].len == 0)
            vecs[0..1]
        else
            vecs[0..2];
        switch (try conn.socket.readv(vec_slice)) {
            0 => return error.Disconnected,
            else => |n| {
                conn.in.bytes.tail +%= @intCast(u12, n);
            },
        }
    }

    pub fn flush(conn: *WireConnection) !void {
        if (conn.out.bytes.readable() == 0)
            return;
        const read_slices = conn.out.bytes.readSlices();
        const vecs: [2]os.iovec_const = .{
            .{ .iov_base = read_slices[0].ptr, .iov_len = read_slices[0].len },
            .{ .iov_base = read_slices[1].ptr, .iov_len = read_slices[1].len },
        };
        const vec_slice = if (read_slices[1].len == 0)
            vecs[0..1]
        else
            vecs[0..2];
        switch (try conn.socket.writev(vec_slice)) {
            0 => return error.Disconnected,
            else => |n| {
                conn.out.bytes.head +%= @intCast(u12, n);
            },
        }
    }
};

test "WireConnection" {
    std.meta.refAllDecls(WireConnection);
}
