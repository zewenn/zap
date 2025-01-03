const std = @import("std");
const Allocator = @import("std").mem.Allocator;

pub const builtin = @import("builtin");
pub const os = std.os;
pub const target = builtin.target;
pub const BUILD_MODE = builtin.mode;

pub const libs = @import("./.codegen/libs.zig");

pub const rl = libs.foreign.rl;
pub const uuid = libs.foreign.uuid;

pub const Vector2 = rl.Vector2;
pub const Vector3 = rl.Vector3;
pub const Vector4 = rl.Vector4;
pub const Rectangle = rl.Rectangle;

pub const Transform = libs.ecs.components.Transform;
pub const Display = libs.ecs.components.Display;
pub const DisplayCache = libs.ecs.components.DisplayCache;
pub const Renderer = libs.ecs.components.Renderer;
pub const Collider = libs.ecs.components.Collider;
pub const ColliderBehaviour = libs.ecs.components.ColliderBehaviour;

pub const Instance = libs.eventloop.Instance;

const global_allocators = struct {
    pub var gpa: AllocatorInstance(std.heap.GeneralPurposeAllocator(.{})) = .{};
    pub var arena: AllocatorInstance(std.heap.ArenaAllocator) = .{};
    pub var page: Allocator = std.heap.page_allocator;

    pub const types = enum {
        /// Generic allocator, warns at program exit if a memory leak happened.
        gpa,
        /// Global arena allocator, everything allocated will be freed at program end.
        arena,
        /// Shorthand for `std.heap.page_allocator`.
        page,
        /// If `eventloop` has an instance loaded, this is a shorthand for
        /// `zap.libs.eventloop.active_instance.allocator()`, otherwise this is the
        /// same as arena.
        instance,
        /// Shorthand for `std.heap.c_allocator`
        c,
        /// Shorthand for `std.heap.raw_c_allocator`
        raw_c,
    };
};

pub const SharedPointer = libs.SharedPointer.SharedPointer;
pub fn SharetPtr(value: anytype) !*SharedPointer(@TypeOf(value)) {
    const ptr = try getAllocator(.gpa).create(SharedPointer(@TypeOf(value)));
    ptr.* = try SharedPointer(@TypeOf(value)).init(getAllocator(.gpa), value);
    return ptr;
}

pub const WrappedArray = libs.WrappedArray.WrappedArray;
pub const WrappedArrayOptions = libs.WrappedArray.WrappedArrayOptions;
pub const array = libs.WrappedArray.array;
pub const arrayAdvanced = libs.WrappedArray.arrayAdvanced;

pub const String = libs.strings.String;
pub const string = libs.strings.string;

pub const ecs = libs.ecs;
pub const Store = libs.ecs.Store;
pub const Behaviour = libs.behaviour.Behaviour;

pub const time = libs.time;

var loop_running = false;
pub inline fn isLoopRunning() bool {
    return loop_running;
}

pub fn init() !void {
    if (BUILD_MODE == .Debug) {
        libs.WrappedArray.ENG_HealthCheck();
        libs.strings.ENG_HealthCheck() catch @panic("HealthCheck failiure!");
    }

    rl.initWindow(1280, 720, ".zap");

    libs.time.init();
    try libs.eventloop.init();

    libs.display.init();

    try libs.eventloop.setActive("engine");
}

pub fn loop() void {
    if (libs.eventloop.active_instance == null) {
        try useInstance("default");
    }

    while (!rl.windowShouldClose()) {
        if (!loop_running)
            loop_running = true;

        libs.time.update();

        libs.display.reset();

        libs.eventloop.execute() catch {
            std.log.warn("eventloop.execute() failed!", .{});
        };

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        libs.display.render();
    }
}

pub fn deinit() void {
    defer if (global_allocators.gpa.interface) |*intf| {
        const state = intf.deinit();
        switch (state) {
            .ok => std.log.info("GPA exited without memory leaks!", .{}),
            .leak => std.log.warn("GPA exited with a memory leak!", .{}),
        }
    };

    defer if (global_allocators.arena.interface) |*intf| {
        intf.deinit();
    };

    libs.eventloop.deinit();
    libs.display.deinit();
    rl.closeWindow();

    libs.assets.deinit();
}

pub inline fn changeType(comptime T: type, value: anytype) ?T {
    const value_info = @typeInfo(@TypeOf(value));
    return switch (@typeInfo(T)) {
        .Int, .ComptimeInt => switch (value_info) {
            .Int, .ComptimeInt => @as(T, @intCast(value)),
            .Float, .ComptimeFloat => @as(T, @intFromFloat(@round(value))),
            .Bool => @as(T, @intFromBool(value)),
            .Enum => @as(T, @intFromEnum(value)),
            else => null,
        },
        .Float, .ComptimeFloat => switch (value_info) {
            .Int, .ComptimeInt => @as(T, @floatFromInt(value)),
            .Float, .ComptimeFloat => @as(T, @floatCast(value)),
            .Bool => @as(T, @floatFromInt(@intFromBool(value))),
            .Enum => @as(T, @floatFromInt(@intFromEnum(value))),
            else => null,
        },
        .Bool => switch (value_info) {
            .Int, .ComptimeInt => value != 0,
            .Float, .ComptimeFloat => @as(isize, @intFromFloat(@round(value))) != 0,
            .Bool => value,
            .Enum => @as(isize, @intFromEnum(value)) != 0,
            else => null,
        },
        .Enum => switch (value_info) {
            .Int, .ComptimeInt => @enumFromInt(value),
            .Float, .ComptimeFloat => @enumFromInt(@as(isize, @intFromFloat(@round(value)))),
            .Bool => @enumFromInt(@intFromBool(value)),
            .Enum => @enumFromInt(@as(isize, @intFromEnum(value))),
            else => null,
        },
        else => Catch: {
            std.log.warn(
                "cannot change type of \"{any}\" to type \"{any}\"! (zap.changeType())",
                .{ value, T },
            );
            break :Catch null;
        },
    };
}

pub inline fn tof32(value: anytype) f32 {
    return changeType(f32, value) orelse 0;
}

pub fn toi32(value: anytype) i32 {
    return changeType(i32, value) orelse 0;
}

pub fn Vec2(x: anytype, y: anytype) Vector2 {
    return Vector2{
        .x = tof32(x),
        .y = tof32(y),
    };
}

pub fn Vec3(x: anytype, y: anytype, z: anytype) Vector3 {
    return Vector3{
        .x = tof32(x),
        .y = tof32(y),
        .z = tof32(z),
    };
}

pub fn Vec4(x: anytype, y: anytype, z: anytype, w: anytype) Vector4 {
    return Vector4{
        .x = tof32(x),
        .y = tof32(y),
        .z = tof32(z),
        .w = tof32(w),
    };
}

pub fn Rect(x: anytype, y: anytype, width: anytype, height: anytype) Rectangle {
    return Rectangle{
        .x = tof32(x),
        .y = tof32(y),
        .width = tof32(width),
        .height = tof32(height),
    };
}

pub fn cloneToOwnedSlice(comptime T: type, list: std.ArrayList(T)) ![]T {
    var cloned = try list.clone();
    defer cloned.deinit();

    return try cloned.toOwnedSlice();
}

pub fn AllocatorInstance(comptime T: type) type {
    return struct {
        interface: ?T = null,
        allocator: ?Allocator = null,
    };
}

pub inline fn getAllocator(comptime T: global_allocators.types) Allocator {
    return switch (T) {
        .gpa => global_allocators.gpa.allocator orelse Blk: {
            global_allocators.gpa.interface = std.heap.GeneralPurposeAllocator(.{}){};
            global_allocators.gpa.allocator = global_allocators.gpa.interface.?.allocator();

            break :Blk global_allocators.gpa.allocator.?;
        },
        .arena => global_allocators.arena.allocator orelse Blk: {
            global_allocators.arena.interface = std.heap.ArenaAllocator.init(getAllocator(.gpa));
            global_allocators.arena.allocator = global_allocators.arena.interface.?.allocator();

            break :Blk global_allocators.arena.allocator.?;
        },
        .page => global_allocators.page,
        .instance => Blk: {
            const active_instance = libs.eventloop.active_instance orelse break :Blk getAllocator(.arena);
            break :Blk active_instance.allocator();
        },
        .c => std.heap.c_allocator,
        .raw_c => std.heap.raw_c_allocator,
    };
}

pub fn assert(title: []const u8, statement: bool) void {
    if (statement) {
        logTest("\"\x1b[2m{s}\x1b[0m\" \x1b[32m\x1b[1mpassed\x1b[0m successfully", .{title});
        return;
    }

    logTest("\"\x1b[2m{s}\x1b[0m\" \x1b[31m\x1b[1mfailed\x1b[0m", .{title});
    @panic("ASSERTON FAILIURE");
}

pub fn assertTitle(text: []const u8) void {
    logTest("\n\n\n[ASSERT SECTION] {s}\n", .{text});
}

pub fn logTest(comptime text: []const u8, fmt: anytype) void {
    const formatted = std.fmt.allocPrint(getAllocator(.gpa), text, fmt) catch "";
    defer getAllocator(.gpa).free(formatted);
    std.debug.print("test: {s}\n", .{formatted});
}

pub fn useInstance(id: []const u8) !void {
    try libs.eventloop.setActive(id);
}

pub inline fn activeInstance() *Instance {
    return libs.eventloop.active_instance orelse panic("No Instance is loaded!", .{});
}

/// Creates a new store with the given identifier and component tuple.
///
/// This function calls the `newStore` method on the singleton instance and returns a pointer to the newly created store.
///
/// - Parameters:
///   - id: A constant byte slice representing the identifier for the new store.
///   - component_tuple: A tuple containing the components for the new store.
/// - Returns: A pointer to the newly created `Store` instance.
/// - Throws: An error if the store creation fails.
pub inline fn newStore(id: []const u8, component_tuple: anytype) !*Store {
    return try activeInstance().newStore(id, component_tuple);
}

pub const CacheCast = Behaviour.CacheCast;

pub fn UUIDV7() u128 {
    return uuid.v7.new();
}

pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print(fmt ++ "\n", args);
    @panic("ENGINE PANIC!");
}
