const std = @import("std");

/// A fixed size ring buffer designed for use with scatter/gather I/O.
///
/// `size` must be a power of two greater than one.
pub fn RingBuffer(comptime T: type, comptime size: usize) type {
    if (size < 2 or !std.math.isPowerOfTwo(size))
        @compileError("size must be a power of two greater than one");

    return struct {
        const Self = @This();

        /// The integer type capable of holding an index into the buffer.
        pub const Index = std.meta.IntType(false, std.math.log2_int(usize, size));

        /// The error returned from functions that write to the buffer.
        pub const Error = error{BufferFull};

        /// The storage for the buffer.
        data: [size]T,

        /// The index where the next element will be written.
        head: Index,

        /// The index where the next element will be read from.
        tail: Index,

        /// Creates an empty `RingBuffer`.
        pub fn init() Self {
            return .{
                .data = undefined,
                .head = 0,
                .tail = 0,
            };
        }

        /// Returns the number of elements that can be read.
        pub fn readable(rb: Self) Index {
            return rb.head -% rb.tail;
        }

        /// Returns the number of elements that can be written.
        pub fn writable(rb: Self) Index {
            return rb.tail -% rb.head -% 1;
        }

        /// Returns the first element of the buffer, if any.
        pub fn popFront(rb: *Self) ?T {
            if (rb.readable() == 0)
                return null;

            const item = rb.data[rb.tail];
            rb.tail +%= 1;
            return item;
        }

        /// Returns the last element of the buffer, if any.
        pub fn popBack(rb: *Self) ?T {
            if (rb.readable() == 0)
                return null;

            rb.head -%= 1;
            return rb.data[rb.head];
        }

        /// Prepends an element to the buffer, if there is space.
        pub fn pushFront(rb: *Self, item: T) Error!void {
            if (rb.writable() == 0)
                return error.BufferFull;

            rb.tail -%= 1;
            rb.data[rb.tail] = item;
        }

        /// Appends an element to the buffer, if there is space.
        pub fn pushBack(rb: *Self, item: T) Error!void {
            if (rb.writable() == 0)
                return error.BufferFull;

            rb.data[rb.head] = item;
            rb.head +%= 1;
        }

        /// Copies elements to the front of the buffer, if there is space.
        /// Note that this is not the same as pushing each, so extending
        /// {4, 5, 6} with {1, 2, 3} would yield {1, 2, 3, 4, 5, 6}.
        pub fn extendFront(rb: *Self, items: []const T) Error!void {
            if (items.len > rb.writable())
                return error.BufferFull;

            const len = @intCast(Index, items.len);
            const start = rb.tail -% len;
            if (start <= rb.tail) {
                std.mem.copy(T, rb.data[start..], items);
            } else {
                const split = size - start;
                std.mem.copy(T, rb.data[0..], items[split..]);
                std.mem.copy(T, rb.data[start..], items[0..split]);
            }
            rb.tail -%= len;
        }

        /// Copies elements to the back of the buffer, if there is space.
        pub fn extendBack(rb: *Self, items: []const T) Error!void {
            if (items.len > rb.writable())
                return error.BufferFull;

            const len = @intCast(Index, items.len);
            if (rb.head + len <= size) {
                std.mem.copy(T, rb.data[rb.head..], items);
            } else {
                const split = size - rb.head;
                std.mem.copy(T, rb.data[rb.head..], items[0..split]);
                std.mem.copy(T, rb.data[0..], items[split..]);
            }
            rb.head +%= len;
        }

        /// Ensures that the next `n` readable items are stored contiguously
        /// in the buffer, which means the first slice returned from readSlices()
        /// is guaranteed to be at least `n` items long.
        /// `n` must be less than or equal to readable().
        pub fn ensureContiguous(rb: *Self, n: usize) void {
            std.debug.assert(n <= rb.readable());
            if (size - rb.tail < n) {
                var buf: [size / 2]T = undefined;
                const difference = @intCast(Index, n - (size - rb.tail));
                std.mem.copy(T, buf[0..difference], rb.data[0..difference]);
                std.mem.copy(T, rb.data[0..], rb.data[difference..]);
                std.mem.copy(T, rb.data[size - difference ..], buf[0..difference]);
                rb.tail -%= difference;
                rb.head -%= difference;
            }
        }

        /// Returns two slices, which in order comprise the readable buffer contents.
        /// The first slice is zero length if the buffer is empty.
        /// The second slice is zero length if the readable elements are contiguous.
        /// To discard elements once read, use a wrapping add on `head`.
        pub fn readSlices(rb: Self) [2][]const T {
            if (rb.tail <= rb.head) {
                return .{
                    rb.data[rb.tail..rb.head],
                    rb.data[0..0],
                };
            } else {
                return .{
                    rb.data[rb.tail..size],
                    rb.data[0..rb.head],
                };
            }
        }

        /// Returns two slices, which in order comprise the unused space in the buffer.
        /// To add elements once written, use a wrapping add on `tail`.
        pub fn writeSlices(rb: *Self) [2][]T {
            if (rb.head < rb.tail) {
                return .{
                    rb.data[rb.head .. rb.tail -% 1],
                    rb.data[0..0],
                };
            } else if (rb.tail == 0) {
                return .{
                    rb.data[rb.head .. size -% 1],
                    rb.data[0..0],
                };
            } else {
                return .{
                    rb.data[rb.head..size],
                    rb.data[0 .. rb.tail -% 1],
                };
            }
        }
    };
}

test "RingBuffer" {
    const expect = std.testing.expect;
    const expectError = std.testing.expectError;
    const expectEqual = std.testing.expectEqual;
    {
        const Rb = RingBuffer(u8, 2);
        var rb = Rb.init();
        {
            expectEqual(@as(Rb.Index, 0), rb.readable());
            expectEqual(@as(Rb.Index, 1), rb.writable());
            expectEqual(@as(usize, 0), rb.readSlices()[0].len);
            expectEqual(@as(usize, 0), rb.readSlices()[1].len);
            expectEqual(@as(usize, 1), rb.writeSlices()[0].len);
            expectEqual(@as(usize, 0), rb.writeSlices()[1].len);
        }
        try rb.pushBack(0);
        {
            expectEqual(@as(Rb.Index, 1), rb.readable());
            expectEqual(@as(Rb.Index, 0), rb.writable());
            expectEqual(@as(usize, 1), rb.readSlices()[0].len);
            expectEqual(@as(usize, 0), rb.readSlices()[1].len);
            expectEqual(@as(usize, 0), rb.writeSlices()[0].len);
            expectEqual(@as(usize, 0), rb.writeSlices()[1].len);
            expectEqual(@as(u8, 0), rb.readSlices()[0][0]);
        }
        expectError(error.BufferFull, rb.pushBack(1));
        {
            expectEqual(@as(Rb.Index, 1), rb.readable());
            expectEqual(@as(Rb.Index, 0), rb.writable());
            expectEqual(@as(usize, 1), rb.readSlices()[0].len);
            expectEqual(@as(usize, 0), rb.readSlices()[1].len);
            expectEqual(@as(usize, 0), rb.writeSlices()[0].len);
            expectEqual(@as(usize, 0), rb.writeSlices()[1].len);
            expectEqual(@as(u8, 0), rb.readSlices()[0][0]);
        }
        expectEqual(@as(?u8, 0), rb.popFront());
        {
            expectEqual(@as(Rb.Index, 0), rb.readable());
            expectEqual(@as(Rb.Index, 1), rb.writable());
            expectEqual(@as(usize, 0), rb.readSlices()[0].len);
            expectEqual(@as(usize, 0), rb.readSlices()[1].len);
            expectEqual(@as(usize, 1), rb.writeSlices()[0].len);
            expectEqual(@as(usize, 0), rb.writeSlices()[1].len);
        }
        try rb.pushBack(1);
        {
            expectEqual(@as(Rb.Index, 1), rb.readable());
            expectEqual(@as(Rb.Index, 0), rb.writable());
            expectEqual(@as(usize, 1), rb.readSlices()[0].len);
            expectEqual(@as(usize, 0), rb.readSlices()[1].len);
            expectEqual(@as(usize, 0), rb.writeSlices()[0].len);
            expectEqual(@as(usize, 0), rb.writeSlices()[1].len);
            expectEqual(@as(u8, 1), rb.readSlices()[0][0]);
        }
        expectEqual(@as(?u8, 1), rb.popFront());
        {
            expectEqual(@as(Rb.Index, 0), rb.readable());
            expectEqual(@as(Rb.Index, 1), rb.writable());
            expectEqual(@as(usize, 0), rb.readSlices()[0].len);
            expectEqual(@as(usize, 0), rb.readSlices()[1].len);
            expectEqual(@as(usize, 1), rb.writeSlices()[0].len);
            expectEqual(@as(usize, 0), rb.writeSlices()[1].len);
        }
        try rb.pushFront(2);
        {
            expectEqual(@as(Rb.Index, 1), rb.readable());
            expectEqual(@as(Rb.Index, 0), rb.writable());
            expectEqual(@as(usize, 1), rb.readSlices()[0].len);
            expectEqual(@as(usize, 0), rb.readSlices()[1].len);
            expectEqual(@as(usize, 0), rb.writeSlices()[0].len);
            expectEqual(@as(usize, 0), rb.writeSlices()[1].len);
            expectEqual(@as(u8, 2), rb.readSlices()[0][0]);
        }
    }

    {
        const Rb = RingBuffer(u8, 16);
        var rb = Rb.init();

        try rb.extendBack(&[_]u8{ 7, 8, 9 });
        try rb.extendFront(&[_]u8{ 4, 5, 6 });
        try rb.extendFront(&[_]u8{ 1, 2, 3 });

        rb.ensureContiguous(9);

        expectEqual(@as(usize, 9), rb.readSlices()[0].len);
        expectEqual(@as(usize, 0), rb.readSlices()[1].len);
        expectEqual(@as(?u8, 9), rb.popBack());
        expectEqual(@as(?u8, 8), rb.popBack());
        expectEqual(@as(?u8, 7), rb.popBack());

        expectEqual(@as(?u8, 1), rb.popFront());
        expectEqual(@as(?u8, 2), rb.popFront());
        expectEqual(@as(?u8, 3), rb.popFront());

        rb.ensureContiguous(3);
        expectEqual(@as(usize, 3), rb.readSlices()[0].len);
        expectEqual(@as(usize, 0), rb.readSlices()[1].len);
        expectEqual(@as(usize, 4), rb.readSlices()[0][0]);
        expectEqual(@as(usize, 5), rb.readSlices()[0][1]);
        expectEqual(@as(usize, 6), rb.readSlices()[0][2]);
    }
    {
        const Rb = RingBuffer(u8, 4096);
        var rb = Rb.init();
        {
            expectEqual(@as(Rb.Index, 0), rb.readable());
            expectEqual(@as(Rb.Index, 4095), rb.writable());
            expectEqual(@as(usize, 0), rb.readSlices()[0].len);
            expectEqual(@as(usize, 0), rb.readSlices()[1].len);
            expectEqual(@as(usize, 4095), rb.writeSlices()[0].len);
            expectEqual(@as(usize, 0), rb.writeSlices()[1].len);
        }
        var i: u8 = 0;
        while (i < 255) {
            try rb.pushBack(i);
            i += 1;
            {
                expectEqual(@as(Rb.Index, 0) + i, rb.readable());
                expectEqual(@as(Rb.Index, 4095) - i, rb.writable());
                expectEqual(@as(usize, 0) + i, rb.readSlices()[0].len);
                expectEqual(@as(usize, 0), rb.readSlices()[1].len);
                expectEqual(@as(usize, 4095) - i, rb.writeSlices()[0].len);
                expectEqual(@as(usize, 0), rb.writeSlices()[1].len);
            }
        }
        i = 0;
        while (i < 255) {
            expectEqual(@as(?u8, i), rb.popFront());
            i += 1;
            {
                expectEqual(@as(Rb.Index, 255) - i, rb.readable());
                expectEqual(@as(Rb.Index, 3840) + i, rb.writable());
                expectEqual(@as(usize, 255) - i, rb.readSlices()[0].len);
                expectEqual(@as(usize, 0), rb.readSlices()[1].len);
                if (i == 1) {
                    expectEqual(@as(usize, 3841), rb.writeSlices()[0].len);
                    expectEqual(@as(usize, 0), rb.writeSlices()[1].len);
                } else {
                    expectEqual(@as(usize, 3841), rb.writeSlices()[0].len);
                    expectEqual(@as(usize, i) - 1, rb.writeSlices()[1].len);
                }
            }
        }
        expectEqual(@as(?u8, null), rb.popFront());
    }
}
