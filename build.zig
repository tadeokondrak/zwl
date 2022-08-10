const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const scanner = b.addExecutable("zwl-scanner", "scanner/main.zig");
    scanner.use_stage1 = false;
    scanner.setBuildMode(mode);
    scanner.install();

    var client_tests = b.addTest("src/client.zig");
    client_tests.use_stage1 = false;
    client_tests.setBuildMode(mode);

    var server_tests = b.addTest("src/server.zig");
    server_tests.use_stage1 = false;
    server_tests.setBuildMode(mode);

    const test_client_step = b.step("test-client", "Run client tests");
    test_client_step.dependOn(&client_tests.step);

    const test_server_step = b.step("test-server", "Run server tests");
    test_server_step.dependOn(&server_tests.step);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&client_tests.step);
    test_step.dependOn(&server_tests.step);
}
