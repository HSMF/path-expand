const std = @import("std");
const main = @import("./main.zig");
const expect = std.testing.expect;
const eql = std.testing.expectEqualStrings;
const allocator = std.testing.allocator;

test "path-join" {
    var buf = try allocator.alloc(u8, 1024);
    defer allocator.free(buf);
    try eql("hell/o/", main.join("hell/", "o/", buf));
    try eql("hell/o/", main.join("hell", "o/", buf));
    try eql("hell/o/", main.join("hell/", "/o/", buf));
    try eql("hell/o/", main.join("hell", "/o/", buf));
    try eql("hell/o/", main.join("hell/////", "///o/", buf));
}
