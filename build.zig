const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const scanner = b.addExecutable("zig-wayland-scanner", "scanner/main.zig");
    scanner.setBuildMode(mode);
    scanner.install();

    var client_tests = b.addTest("src/client.zig");
    client_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&client_tests.step);
}
