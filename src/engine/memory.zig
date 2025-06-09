const std = @import("std");

// var persistent_buffer 

pub fn persistent () void
{
    // var gpa = std.heap.GeneralPurposeAllocator(.{});
    // const allocator = gpa.allocator();
}

pub fn kilobytesToBytes (comptime kb: usize) usize
{
    return kb * 1000;
}

pub fn megabytesToBytes (comptime mb: usize) usize
{
    return mb * 1000 * 1000;
}