class_name EarthAttack
extends SpellAttack
## Earth: slams a fissure of stone spikes out along the ground. Heavy: a slow cast that roots the
## hero, a lot of mana and no steering, so it pays to read where the target is going. In return it
## hits hard, stuns, and leaves pillars standing for cover.

const COST := 28.0
const THROW_SPEED := 0.9
const WINDUP := 0.5  # seconds into the animation when the ground breaks


func begin() -> void:
	if caster.mana < COST or not caster.begin_cast(Player.ANIM_THROW, 0.0, THROW_SPEED):
		return
	caster.spend_mana(COST)
	await get_tree().create_timer(WINDUP).timeout
	_slam()


func _slam() -> void:
	var feet := caster.global_position
	var flat := caster.aim_point() - feet
	flat.y = 0.0
	if flat.length() < 0.1:
		flat = -caster.camera.global_basis.z
		flat.y = 0.0
	var fissure := Fissure.new()
	fissure.element = element
	fissure.caster = caster
	fissure.origin = feet
	fissure.direction = flat.normalized()
	caster.get_parent().add_child(fissure)
