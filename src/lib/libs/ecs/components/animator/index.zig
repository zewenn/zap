const std = @import("std");
const Allocator = @import("std").mem.Allocator;

const fyr = @import("../../../../main.zig");

pub const t = @import("./types.zig");

pub const Animation = t.Animation;
pub const KeyFrame = t.KeyFrame;

pub const Animator = struct {
    const Self = @This();

    alloc: Allocator,

    animations: std.StringHashMap(*Animation),
    playing: std.ArrayList(*Animation),

    pub fn init() Self {
        return Self{
            .alloc = fyr.getAllocator(.instance),
            .animations = std.StringHashMap(*Animation).init(fyr.getAllocator(.instance)),
            .playing = std.ArrayList(*Animation).init(fyr.getAllocator(.instance)),
        };
    }

    pub fn deinit(self: *Self) void {
        var iterator = self.animations.iterator();
        while (iterator.next()) |item| {
            item.value_ptr.*.deinit();
        }

        self.playing.deinit();
        self.animations.deinit();
    }

    pub fn chain(self: *Self, anim: Animation) !void {
        const ptr = try self.alloc.create(Animation);
        ptr.* = anim;

        try self.animations.put(anim.name, ptr);
    }

    pub fn isPlaying(self: *Self, name: []const u8) bool {
        const anim = self.animations.get(name) orelse return false;
        return anim.playing;
    }

    pub fn play(self: *Self, name: []const u8) !void {
        const anim = self.animations.get(name) orelse return;
        if (anim.playing) return;

        try self.playing.append(anim);

        anim.playing = true;
        anim.current_percent = 0;
        anim.start_time = fyr.time.gameTime();
    }

    pub fn stop(self: *Self, name: []const u8) void {
        const anim = self.animations.get(name) orelse return;
        if (!anim.playing) return;

        for (self.playing.items, 0..) |item, index| {
            if (item.uuid != anim.uuid) continue;

            _ = self.playing.swapRemove(index);
            break;
        }

        anim.playing = false;
    }
};

pub const AnimatorBehaviour = struct {
    const Cache = struct {
        animations: fyr.WrappedArray(Animation),
        animator: ?*Animator = null,
        transform: ?*fyr.Transform = null,
        display: ?*fyr.Display = null,
    };

    fn awake(store: *fyr.Store, cache_ptr: *anyopaque) !void {
        const cache = fyr.CacheCast(Cache, cache_ptr);

        var animator = Animator.init();
        for (cache.animations.items) |item| {
            try animator.chain(item);
        }

        cache.animations.deinit();

        try store.addComonent(animator);

        cache.animator = store.getComponent(fyr.Animator) orelse return;
        cache.transform = store.getComponent(fyr.Transform) orelse return;
        cache.display = store.getComponent(fyr.Display) orelse return;
    }

    fn update(_: *fyr.Store, cache_ptr: *anyopaque) !void {
        const cache = fyr.CacheCast(Cache, cache_ptr);

        const transform = cache.transform orelse return;
        const display = cache.display orelse return;
        const animator = cache.animator orelse return;

        for (animator.playing.items) |animation| {
            const current = animation.current();
            const next = animation.next();

            const current_keyframe = current orelse continue;

            if (next == null) {
                current_keyframe.apply(transform, display);
                continue;
            }

            const next_keyframe = next orelse continue;

            const interpolation_factor =
                @min(1, @max(0, (fyr.time.gameTime() - fyr.tof32(animation.start_time)) / fyr.tof32(animation.length)));

            const anim_progress_percent = animation.timing_function(0, 1, interpolation_factor);
            const next_index_percent = animation.timing_function(0, 1, fyr.tof32(animation.next_index) / 100);

            const percent = @min(1, @max(0, anim_progress_percent / next_index_percent));

            current_keyframe
                .interpolate(next_keyframe, t.interpolation.lerp, percent)
                .apply(transform, display);

            if (percent != 1) continue;

            animation.incrementCurrentPercent(fyr.toi32(interpolation_factor * 100));
            if (!animation.playing) {
                animator.stop(animation.name);
                break;
            }
        }
    }

    fn deinit(_: *fyr.Store, cache_ptr: *anyopaque) !void {
        const cache = fyr.CacheCast(Cache, cache_ptr);

        if (cache.animator) |animator| {
            animator.deinit();
        }
    }

    pub fn behaviour(anims: fyr.WrappedArray(Animation)) !fyr.Behaviour {
        var b = try fyr.Behaviour.initWithDefaultValue(Cache{
            .animations = anims,
        });

        b.add(.awake, awake);
        b.add(.update, update);
        b.add(.deinit, deinit);

        return b;
    }
}.behaviour;
