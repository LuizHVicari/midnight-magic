class_name EarthCocoonAction
extends AbilityAction
## Stone cocoon: a shell of stone closes round the foe you aim at. It cannot move or act while the
## shell stands, and takes extra damage from everything but earth. Every blow it takes wears the
## shell down, so hitting it is how it gets out; otherwise the shell gives way in a few seconds.
## Heavy foes break out in half the time. Does nothing if nobody is in your sights.

const REACH := 35.0
const CONE := 6.0
const HIT_POINTS := 100.0
const LIFE := 7.0
const HEAVY_SHARE := 0.5
const DELAY := 0.15


func _cast() -> bool:
	var target := _target()
	if target == null:
		return false
	if not caster.begin_cast(Player.ANIM_THROW, 0.0, 1.8):
		return false
	var foe := target.get_parent() as Animal
	caster.get_tree().create_timer(DELAY).timeout.connect(func() -> void: _close(foe))
	return true


func _target() -> Health:
	var camera := caster.camera
	var found := Combat.find_target(caster, camera.global_position, -camera.global_basis.z, REACH, CONE)
	if found == null or not found.get_parent() is Animal:
		return null
	for cocoon: Node in caster.get_tree().get_nodes_in_group(StoneBlock.BLOCKS):
		if cocoon is StoneCocoon and (cocoon as StoneCocoon).foe == found.get_parent():
			return null
	return found


func _close(foe: Animal) -> void:
	if not is_instance_valid(foe) or foe.dead:
		return
	var heavy := foe is Foe and (foe as Foe).is_heavy()
	var cocoon := StoneCocoon.new()
	cocoon.element = element
	cocoon.foe = foe
	cocoon.hit_points = HIT_POINTS * (HEAVY_SHARE if heavy else 1.0)
	cocoon.life = LIFE * (HEAVY_SHARE if heavy else 1.0)
	caster.get_parent().add_child(cocoon)
