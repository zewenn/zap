const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const Action = @import("Action.zig");
const zap = @import("../../main.zig");

pub const EventEnumTarget = isize;
const EventActions = std.ArrayList(Action);
const EventMapType = std.AutoHashMap(EventEnumTarget, EventActions);
var event_map: ?EventMapType = null;

pub const Callback = *const fn () anyerror!void;

var alloc: Allocator = undefined;

pub const SceneEvents = enum(EventEnumTarget) {
    awake = 0,
    init = 1,
    deinit = 2,
    update = 3,
    tick = 4,
};

pub const EngineEvents = enum(EventEnumTarget) {
    awake = -50,
    init = -51,
    deinit = -52,
    update = -53,
    tick = -54,
};

pub fn init(allocator: Allocator) !void {
    alloc = allocator;
    event_map = EventMapType.init(alloc);
}

pub fn deinit() void {
    const emap = &(event_map orelse return);

    var entries = emap.iterator();
    while (entries.next()) |entry| {
        entry.value_ptr.deinit();
    }

    emap.clearAndFree();
    emap.deinit();
}

fn makeGet(event: anytype) !*EventActions {
    const emap: *EventMapType = &(event_map orelse @panic("event_map wasn't initalised! Call eventloop.init()!"));

    const key = zap.changeType(EventEnumTarget, event) orelse -1;

    if (!emap.contains(key)) {
        try emap.put(key, EventActions.init(alloc));
    }

    return emap.getPtr(key).?;
}

pub fn on(event: anytype, action: Action) !void {
    const ptr = try makeGet(event);

    try ptr.append(action);
}

pub fn call(event: anytype) !void {
    const ptr = try makeGet(event);

    const items = try zap.cloneToOwnedSlice(Action, ptr.*);
    defer ptr.allocator.free(items);

    for (items) |action| {
        action.fn_ptr() catch switch (action.on_fail) {
            .ignore => {
                std.log.warn("Ignored function failiure!", .{});
            },
            .remove => {
                std.log.warn("Removed function failiure!", .{});
                for (ptr.items, 0..) |item, index| {
                    if (!std.meta.eql(item, action)) continue;

                    _ = ptr.swapRemove(index);
                    break;
                }
            },
            .panic => @panic("Critical eventloop action failiure!"),
        };
    }
}

pub fn SceneAwake(callback: Callback) !void {
    try on(SceneEvents.awake, Action{
        .fn_ptr = callback,
        .on_fail = .ignore,
    });
}

pub fn SceneAwakeRemove(callback: Callback) !void {
    try on(SceneEvents.awake, Action{
        .fn_ptr = callback,
        .on_fail = .remove,
    });
}

pub fn SceneAwakePanic(callback: Callback) !void {
    try on(SceneEvents.awake, Action{
        .fn_ptr = callback,
        .on_fail = .panic,
    });
}

pub fn SceneInit(callback: Callback) !void {
    try on(SceneEvents.init, Action{
        .fn_ptr = callback,
        .on_fail = .ignore,
    });
}

pub fn SceneInitRemove(callback: Callback) !void {
    try on(SceneEvents.init, Action{
        .fn_ptr = callback,
        .on_fail = .remove,
    });
}

pub fn SceneInitPanic(callback: Callback) !void {
    try on(SceneEvents.init, Action{
        .fn_ptr = callback,
        .on_fail = .panic,
    });
}

pub fn SceneUpdate(callback: Callback) !void {
    try on(SceneEvents.update, Action{
        .fn_ptr = callback,
        .on_fail = .panic,
    });
}

pub fn SceneUpdateRemove(callback: Callback) !void {
    try on(SceneEvents.update, Action{
        .fn_ptr = callback,
        .on_fail = .remove,
    });
}

pub fn SceneUpdatePanic(callback: Callback) !void {
    try on(SceneEvents.update, Action{
        .fn_ptr = callback,
        .on_fail = .panic,
    });
}

pub fn SceneTick(callback: Callback) !void {
    try on(SceneEvents.tick, Action{
        .fn_ptr = callback,
        .on_fail = .ignore,
    });
}

pub fn SceneTickRemove(callback: Callback) !void {
    try on(SceneEvents.tick, Action{
        .fn_ptr = callback,
        .on_fail = .remove,
    });
}

pub fn SceneTickPanic(callback: Callback) !void {
    try on(SceneEvents.tick, Action{
        .fn_ptr = callback,
        .on_fail = .panic,
    });
}