const std = @import("std");
const zap = @import(".zap");

const Cache = struct {
    transform: ?*zap.Transform = null,
    speed: f32 = 10,
};

fn awake(store: *zap.Store, cache_ptr: *anyopaque) !void {
    const cache = zap.CacheCast(Cache, cache_ptr);

    const transform = store.getComponent(zap.Transform);
    cache.transform = transform;
}

fn update(_: *zap.Store, cache_ptr: *anyopaque) !void {
    const cache = zap.CacheCast(Cache, cache_ptr);
    const transform = cache.transform orelse return;

    var move_vec = zap.Vec3(0, 0, 0);

    if (zap.rl.isKeyDown(.w)) {
        move_vec.y -= 1;
    }
    if (zap.rl.isKeyDown(.s)) {
        move_vec.y += 1;
    }
    if (zap.rl.isKeyDown(.a)) {
        move_vec.x -= 1;
    }
    if (zap.rl.isKeyDown(.d)) {
        move_vec.x += 1;
    }

    move_vec = move_vec.normalize();

    transform.position = transform.position.add(
        move_vec.multiply(
            zap.Vec3(cache.speed, cache.speed, 0),
        ).multiply(
            zap.Vec3(
                zap.libs.time.deltaTime(),
                zap.libs.time.deltaTime(),
                0,
            ),
        ),
    );
}

pub fn MovementBehaviour() !zap.Behaviour {
    var b = try zap.Behaviour.initWithDefaultValue(Cache{
        .speed = 300,
    });
    b.add(.awake, awake);
    b.add(.update, update);

    return b;
}
