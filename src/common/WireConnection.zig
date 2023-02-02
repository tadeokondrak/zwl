const std = @import("std");
const os = std.os;
const Buffer = @import("Buffer.zig");

const WireConnection = @This();

socket: std.net.Stream,
in: Buffer,
out: Buffer,

pub fn init(socket: std.net.Stream) WireConnection {
    return .{
        .socket = socket,
        .in = Buffer.init(),
        .out = Buffer.init(),
    };
}

pub fn read(conn: *WireConnection) !void {
    if (conn.in.bytes.writableLength() == 0)
        return error.BufferFull;
    const write_slices = conn.in.bytes.writableSlices();
    // TODO: next line should be const not var
    var vecs = [2]os.iovec{
        .{ .iov_base = write_slices[0].ptr, .iov_len = write_slices[0].len },
        .{ .iov_base = write_slices[1].ptr, .iov_len = write_slices[1].len },
    };
    const vec_slice = if (write_slices[1].len == 0)
        vecs[0..1]
    else
        vecs[0..2];
    var msghdr = std.os.msghdr{
        .name = null,
        .namelen = 0,
        .iov = vec_slice.ptr,
        .iovlen = @intCast(i32, vec_slice.len),
        .control = null,
        .controllen = 0,
        .flags = 0,
    };
    switch (try recvmsg(conn.socket.handle, &msghdr, std.os.MSG.DONTWAIT | std.os.MSG.CMSG_CLOEXEC)) {
        0 => return error.Disconnected,
        else => |n| {
            conn.in.bytes.head +%= @intCast(u12, n);
        },
    }
}

pub fn flush(conn: *WireConnection) !void {
    if (conn.out.bytes.readableLength() == 0)
        return;
    const read_slices = conn.out.bytes.readableSlices();
    // TODO: next line should be const not var
    var vecs: [2]os.iovec_const = .{
        .{ .iov_base = read_slices[0].ptr, .iov_len = read_slices[0].len },
        .{ .iov_base = read_slices[1].ptr, .iov_len = read_slices[1].len },
    };
    const vec_slice = if (read_slices[1].len == 0) vecs[0..1] else vecs[0..2];
    const MAX_FDS = 28;
    const SCM_RIGHTS = 1;
    const Cmsg = extern struct {
        cmsg_len: usize,
        cmsg_level: i32,
        cmsg_type: i32,
        fds: [MAX_FDS]std.os.fd_t,
    };
    var cmsg = Cmsg{
        .cmsg_len = @sizeOf(usize) + @sizeOf(i32) + @sizeOf(i32),
        .cmsg_level = std.os.SOL.SOCKET,
        .cmsg_type = SCM_RIGHTS,
        .fds = undefined,
    };
    var fds_added: usize = 0;
    while (conn.out.fds.readableLength() > 0 and fds_added < 28) {
        cmsg.cmsg_len += @sizeOf(std.os.fd_t);
        cmsg.fds[fds_added] = conn.out.fds.pop().?;
        fds_added += 1;
    }
    const msghdr = std.os.msghdr_const{
        .name = null,
        .namelen = 0,
        .iov = vec_slice.ptr,
        .iovlen = @intCast(i32, vec_slice.len),
        .control = &cmsg,
        .controllen = if (fds_added > 0) @intCast(u32, cmsg.cmsg_len) else 0,
        .flags = 0,
    };
    switch (try std.os.sendmsg(conn.socket.handle, &msghdr, std.os.MSG.DONTWAIT | std.os.MSG.CMSG_CLOEXEC)) {
        0 => return error.Disconnected,
        else => |n| {
            conn.out.bytes.tail +%= @intCast(u12, n);
        },
    }
}

test "WireConnection" {
    std.testing.refAllDecls(WireConnection);
}

// TODO: this should be upstream (with windows support and errors)
fn recvmsg(sockfd: std.os.socket_t, msg: *std.os.msghdr, flags: u32) !usize {
    while (true) {
        const rc = std.os.system.recvmsg(sockfd, msg, flags);
        return switch (std.os.errno(rc)) {
            .SUCCESS => return @intCast(usize, rc),
            .AGAIN => continue,
            else => |err| return std.os.unexpectedErrno(err),
        };
    }
}
