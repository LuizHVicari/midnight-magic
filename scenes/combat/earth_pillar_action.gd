class_name EarthPillarAction
extends AbilityAction
## Pillar: a column of stone rises where you aim. Raised under you, it is a platform that lifts you
## up (aim at your own feet). Raised under foes, it throws them into the air to fall back hurt. It has little life and
## crumbles after a few seconds, so the platform has to be used quickly. Foes cannot see through it.

const MAX_REACH := 40.0
const SIZE := Vector3(2.2, 3.6, 2.2)
const HIT_POINTS := 40.0
const LIFE := 10.0
const LAUNCH := 20.0
const REACH := 1.9  # how close to the middle counts as standing on it
const SELF_SNAP := 2.6  # aimed this close to your own feet, the pillar rises right under you
const DELAY := 0.2


func _cast() -> bool:
	if not caster.begin_cast(Player.ANIM_THROW, 0.0, 1.8):
		return false
	var aim := caster.aim_point()
	var away := aim - caster.global_position
	var spot := aim if away.length() <= MAX_REACH else caster.global_position + away.normalized() * MAX_REACH
	var near := Vector2(spot.x - caster.global_position.x, spot.z - caster.global_position.z)
	if near.length() < SELF_SNAP:
		spot = caster.global_position
	caster.get_tree().create_timer(DELAY).timeout.connect(func() -> void: _raise(spot))
	return true


func _raise(spot: Vector3) -> void:
	for health: Health in caster.get_tree().get_nodes_in_group("damageable"):
		var animal := health.get_parent() as Animal
		if animal == null or animal.dead:
			continue
		var flat := Vector2(animal.global_position.x - spot.x, animal.global_position.z - spot.z)
		if flat.length() <= REACH and absf(animal.global_position.y - spot.y) < 1.5:
			animal.launch(LAUNCH)
	var pillar := StoneBlock.new()
	var flat := Vector2(caster.global_position.x - spot.x, caster.global_position.z - spot.z)
	if flat.length() <= SIZE.x * 0.5 + 0.2 and absf(caster.global_position.y - spot.y) < 1.2:
		pillar.riders.append(caster)
	pillar.size = SIZE
	pillar.hit_points = HIT_POINTS
	pillar.life = LIFE
	pillar.seed_value = randi()
	pillar.position = spot
	caster.get_parent().add_child(pillar)
