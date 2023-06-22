const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const scanner = b.addExecutable(.{
        .name = "zwl-scanner",
        .root_source_file = .{ .path = "scanner/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(scanner);

    var client_tests = b.addTest(.{
        .name = "client_tests",
        .root_source_file = .{ .path = "src/client.zig" },
    });

    var server_tests = b.addTest(.{
        .name = "server_tests",
        .root_source_file = .{ .path = "src/server.zig" },
    });

    const test_client_step = b.step("test-client", "Run client tests");
    test_client_step.dependOn(&client_tests.step);

    const test_server_step = b.step("test-server", "Run server tests");
    test_server_step.dependOn(&server_tests.step);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&client_tests.step);
    test_step.dependOn(&server_tests.step);
}
