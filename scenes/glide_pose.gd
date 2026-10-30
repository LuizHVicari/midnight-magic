class_name GlidePose
extends RefCounted
## Builds the gliding pose in code, because the animation packs have none: arms spread out like
## wings, fluttering a little, and the head lifted to look ahead of the leaning body. It is an
## upper-body animation, played on the layer that holds guard and casts, so the legs keep their own.

const LENGTH := 1.6
const SPREAD := deg_to_rad(78.0)  # how far each arm swings out from the body
const SWEEP_BACK := deg_to_rad(18.0)  # and back, like swept wings
const FLUTTER := deg_to_rad(7.0)
const HEAD_LIFT := deg_to_rad(38.0)
const KEYS := 5


## An [Animation] of the pose for [param skeleton]'s rig, tracks named from [param skeleton_path].
static func build(skeleton: Skeleton3D, skeleton_path: String) -> Animation:
	var animation := Animation.new()
	animation.length = LENGTH
	animation.loop_mode = Animation.LOOP_LINEAR
	_arm(animation, skeleton, skeleton_path, "upperarm.l", 1.0)
	_arm(animation, skeleton, skeleton_path, "upperarm.r", -1.0)
	_hold(animation, skeleton, skeleton_path, "head", Vector3.RIGHT, -HEAD_LIFT)
	return animation


## A wing: the arm swung out to the side (and a touch back), with a slow flutter between keys.
static func _arm(animation: Animation, skeleton: Skeleton3D, path: String, bone: String, side: float) -> void:
	var track := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(track, NodePath("%s:%s" % [path, bone]))
	for key in KEYS:
		var share := float(key) / float(KEYS - 1)
		var flutter := sin(share * TAU) * FLUTTER
		var swing := Basis(Vector3.BACK, side * (SPREAD + flutter)) * Basis(Vector3.RIGHT, -SWEEP_BACK)
		animation.rotation_track_insert_key(track, share * LENGTH, _local(skeleton, bone, swing))


static func _hold(animation: Animation, skeleton: Skeleton3D, path: String, bone: String, axis: Vector3, angle: float) -> void:
	var track := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(track, NodePath("%s:%s" % [path, bone]))
	animation.rotation_track_insert_key(track, 0.0, _local(skeleton, bone, Basis(axis, angle)))
	animation.rotation_track_insert_key(track, LENGTH, _local(skeleton, bone, Basis(axis, angle)))


## The bone's local rotation that turns it by [param turn] in the rig's own frame (X sideways,
## Y up, Z forward) from where it rests, whatever its parents are doing.
static func _local(skeleton: Skeleton3D, bone: String, turn: Basis) -> Quaternion:
	var index := skeleton.find_bone(bone)
	var parent := skeleton.get_bone_parent(index)
	var parent_global := skeleton.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY
	var wanted := turn * skeleton.get_bone_global_rest(index).basis
	return (parent_global.inverse() * wanted).get_rotation_quaternion()
