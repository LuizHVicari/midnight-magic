class_name FoeSpecies
extends Species
## A kind of enemy for the camps: a KayKit character with a weapon, a way of fighting and its own
## senses. Everything numeric is for a level 1 foe; the [Foe] scales it with its level.

## How the foe fights: MELEE rushes in, ARCHER keeps its distance and shoots (with a weak stab up
## close), HEAVY is slow and tough and guards against hits from the front.
enum Style { MELEE, ARCHER, HEAVY }

@export var style := Style.MELEE
## Colors the model's cloth and skin, so one character becomes several factions.
@export var tint := Color.WHITE
@export var weapon_right: PackedScene
@export var weapon_left: PackedScene

@export_group("Combat")
## Damage of the main attack; [member Species.attack_damage] is not used.
@export var damage := 10.0
@export var reach := 2.0
@export var windup := 0.5  # seconds into the attack animation when the blow lands
@export var attack_animation := "Melee_1H_Attack_Chop"
@export var attack_speed := 1.0
## Archers: the weak close-range attack, and the range they like to shoot from.
@export var stab_damage := 4.0
@export var arrow_speed := 26.0
@export var preferred_range := Vector2(11.0, 17.0)
## Heavies: share of the damage that gets through when hit from the front.
@export_range(0.0, 1.0) var guard_taken := 1.0
## Whether a hit interrupts the attack in progress.
@export var poise := false

@export_group("Awareness")
## How fast it notices the hero: 1 is average. Higher spots you sooner.
@export var alertness := 1.0
## Farther than this from its camp it gives up the chase.
@export var leash := 65.0
@export var patrol_radius := 9.0

@export_group("Rewards")
@export var xp := 14
@export var coins := Vector2i(2, 6)
