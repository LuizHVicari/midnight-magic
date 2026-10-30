class_name EarthWallAction
extends AbilityAction
## Stone wall: a wide, low wall rises across the way you are aiming, where you aim. It blocks
## arrows, sight and the way, takes a good deal of damage before it breaks and crumbles after a
## while. Foes stuck behind it start hitting it.

const MAX_REACH := 40.0
const SIZE := Vector3(7.0, 2.8, 1.0)
const HIT_POINTS := 150.0
const LIFE := 15.0
const DELAY := 0.2


func _cast() -> bool:
	if not caster.begin_cast(Player.ANIM_THROW, 0.0, 1.8):
		return false
	var aim := caster.aim_point()
	var away := aim - caster.global_position
	var spot := aim if away.length() <= MAX_REACH else caster.global_position + away.normalized() * MAX_REACH
	var flat := away * Vector3(1.0, 0.0, 1.0)
	var heading := flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD
	var across := heading.cross(Vector3.UP)
	caster.get_tree().create_timer(DELAY).timeout.connect(func() -> void: _raise(spot, across))
	return true


func _raise(spot: Vector3, across: Vector3) -> void:
	var wall := StoneBlock.new()
	wall.size = SIZE
	wall.hit_points = HIT_POINTS
	wall.life = LIFE
	wall.seed_value = randi()
	wall.rise_time = 0.3
	wall.rotation.y = atan2(-across.z, across.x)
	wall.position = spot
	caster.get_parent().add_child(wall)
