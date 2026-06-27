extends Node2D

const REPEAY_DELAY: float = 0.2
var echo_pressed_delay: float = 0.0

var steps_taken: int = 0
var last_move_was_successful: bool = true

enum ObjectType {NOTHING, KEY, LOCKED_DOOR}

# CW orientation - absolute direction
const DIRECTIONS = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.DOWN,
]
const CCW_90 := -1
const CW_90 := 1
const CCW_180 := -2
const CW_180 := 2

# struct
class Player:
	var coords: Vector2i
	var dir: Vector2i

var key_coords: Array[Vector2i] = []
var locked_door_coords: Array[Vector2i] = []
var player: Player

# NOTE (sam): minimal to get working... it's not a minimal delta as it could be.
# maybe we dont care?
class UndoState:
	var player: Player
	var key_coords: Array[Vector2i]
	var locked_door_coords: Array[Vector2i]

var undo_stack: Array[UndoState] = []
var last_move_was_reset: bool = false

const PLAYER_ATLAS = Vector2i(0, 0)
const KEY_ATLAS = Vector2i(1, 0)

const WALL_ATLASES := [
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
	Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
	Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
	Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5),
	Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6),
	Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7),
]
func wall(atlas: Vector2i) -> bool:
	return atlas in WALL_ATLASES

const PLAYER_HOLDING_KEY_ATLASES := {
	Vector2i.UP: [Vector2i(5, 1), Vector2i(5, 0)],
	Vector2i.RIGHT: [Vector2i(2, 0), Vector2i(3, 0)],
	Vector2i.DOWN: [Vector2i(4, 0), Vector2i(4, 1)],
	Vector2i.LEFT: [Vector2i(3, 1), Vector2i(2, 1)],
}

const STAIRS_UP_ATLAS := Vector2i(0, 2)
const STAIRS_DOWN_ATLAS := Vector2i(1, 2)
const LOCKED_DOOR_ATLAS := Vector2i(5, 2)
const EMPTY_ATLASES := [Vector2(0, 3), Vector2(1, 3)]

@onready var world_tiles: TileMapLayer = $Static
@onready var entity_tiles: TileMapLayer = $Entities

var initial_world_state: PackedByteArray
var initial_entity_world_state: PackedByteArray

var completed: bool = false
signal complete

func _ready() -> void:
	initial_world_state = world_tiles.tile_map_data
	initial_entity_world_state = entity_tiles.tile_map_data
	for coords: Vector2i in entity_tiles.get_used_cells():
		if entity_tiles.get_cell_atlas_coords(coords) == PLAYER_ATLAS:
			var new_player: Player = Player.new()
			new_player.coords = coords
			new_player.dir = Vector2i.ZERO
			player = new_player
		elif entity_tiles.get_cell_atlas_coords(coords) == KEY_ATLAS:
			key_coords.push_back(coords)
		elif entity_tiles.get_cell_atlas_coords(coords) == LOCKED_DOOR_ATLAS:
			locked_door_coords.push_back(coords)

func push_undo_state():
	var state = UndoState.new()

	var copy := Player.new()
	copy.coords = player.coords
	copy.dir = player.dir
	state.player = copy
	
	state.key_coords = key_coords.duplicate()
	state.locked_door_coords = locked_door_coords.duplicate()
	
	# NOTE (sam): any state-changing world tiles can get saved here.
	for coord in world_tiles.get_used_cells():
		var atlas := world_tiles.get_cell_atlas_coords(coord)

	undo_stack.push_back(state)

# basically similar to the init.
func reset() -> void:
	world_tiles.tile_map_data = initial_world_state
	entity_tiles.tile_map_data = initial_entity_world_state
	
	key_coords.clear()
	locked_door_coords.clear()
	
	for coords: Vector2i in entity_tiles.get_used_cells():
		if entity_tiles.get_cell_atlas_coords(coords) == PLAYER_ATLAS:
			var new_player: Player = Player.new()
			new_player.coords = coords
			new_player.dir = Vector2.ZERO
			player = new_player
		elif entity_tiles.get_cell_atlas_coords(coords) == KEY_ATLAS:
			key_coords.push_back(coords)
		elif entity_tiles.get_cell_atlas_coords(coords) == LOCKED_DOOR_ATLAS:
			locked_door_coords.push_back(coords)
	
	last_move_was_reset = true

func undo() -> void:
	if len(undo_stack) < 1:
		return
	
	var state: UndoState = undo_stack.pop_back()
	
	var copy := Player.new()
	copy.coords = state.player.coords
	copy.dir = state.player.dir
	player = copy
	
	key_coords = state.key_coords.duplicate()
	locked_door_coords = state.locked_door_coords.duplicate()
	
	# NOTE (sam): any state-changing world tiles can get restored here.
	world_tiles.tile_map_data = initial_world_state

func _input(event: InputEvent) -> void:
	if completed:
		return
		
	if event.is_action_pressed("undo"):
		print("UNDOING")
		if event.is_echo() and echo_pressed_delay <= 0:
			echo_pressed_delay = REPEAY_DELAY
		elif event.is_echo() and echo_pressed_delay > 0:
			return
		
		undo()
		update_entity_visuals()
		return
	
	var movement_dir: Vector2i = Vector2i.ZERO
	if event.is_action_pressed("reset"):
		# NOTE (sam): nice if we spam reset, we only save a single operation in the undo stack.
		# right now undo state is done before a move (eg. saves the previous right before we do the next)
		# so that we have the state we want to jump back to at the top.
		# if we saved after every move, we'd have to peek back 2, maybe there's a reason to do this (eg. saving and resuming a session from disk).
		if not last_move_was_reset:
			push_undo_state()
		
		reset()
		update_entity_visuals()
	elif event.is_action_pressed("left"):
		movement_dir += Vector2i.LEFT
	elif event.is_action_pressed("right"):
		movement_dir += Vector2i.RIGHT
	elif event.is_action_pressed("up"):
		movement_dir += Vector2i.UP
	elif event.is_action_pressed("down"):
		movement_dir += Vector2i.DOWN
	
	if movement_dir != Vector2i.ZERO:
		last_move_was_reset = false
		
		if last_move_was_successful:
			push_undo_state()
			steps_taken += 1
		
		last_move_was_successful = move_player(movement_dir)
		update_entity_visuals()



func move_player(dir: Vector2i) -> bool:
	# phase 1: initial intent
	var target_coords = player.coords
	var target_dir := player.dir
	var will_drop_key := false
	
	# phase 2: collision
	if player.dir == Vector2i.ZERO:
		var target_tile := world_tiles.get_cell_atlas_coords(player.coords + dir)
		if wall(target_tile) or player.coords + dir in locked_door_coords:
			return false
		elif player.coords + dir in key_coords:
			var target_tile_after := world_tiles.get_cell_atlas_coords(player.coords + dir + dir)
			if wall(target_tile_after):
				return false
		
		target_coords = player.coords + dir
	else:
		# 1. if moving in same dir as key, check wall 2 in front.
		if player.dir == dir:
			var target_tile := world_tiles.get_cell_atlas_coords(player.coords + dir + dir)
			if wall(target_tile):
				return false
			target_coords = player.coords + dir
		# 2. if moving backwards, check wall 1 behind.
		elif player.dir == -dir:
			var target_tile := world_tiles.get_cell_atlas_coords(player.coords + dir)
			if wall(target_tile) or player.coords + dir in locked_door_coords:
				return false
			target_coords = player.coords + dir
		# 3. if moving perpendicular:
		#    a. if wall in way of player, dont move.
		#    b. if wall in way of key, rotate.
		else:
			var adjacent_tile := world_tiles.get_cell_atlas_coords(player.coords + dir)
			if wall(adjacent_tile) or player.coords + dir in locked_door_coords:
				return false
			var adjacent_key_tile := world_tiles.get_cell_atlas_coords(player.coords + player.dir + dir)
			if wall(adjacent_key_tile) or player.coords + player.dir + dir in locked_door_coords:
				target_coords = player.coords + dir
				target_dir = -dir
			else:
				target_coords = player.coords + dir

	# phase 3: commit
	if will_drop_key:
		key_coords.push_back(player.coords + player.dir)
	player.coords = target_coords
	player.dir = target_dir
	
	# phase 4: resolve
	var world_tile := world_tiles.get_cell_atlas_coords(player.coords)
	if player.coords in key_coords:
		player.dir = dir
		key_coords.erase(player.coords)
	elif world_tile == STAIRS_DOWN_ATLAS:
		print("can move down stairs")
	elif world_tile == STAIRS_UP_ATLAS:
		print("can move up stairs")
	elif player.dir != Vector2i.ZERO and (player.coords + player.dir) in locked_door_coords:
		print("unlocked door")
		locked_door_coords.erase(player.coords + player.dir)
		player.dir = Vector2i.ZERO

	return true

func update_entity_visuals() -> void:
	entity_tiles.clear()
	for coords in key_coords:
		entity_tiles.set_cell(coords, 0, KEY_ATLAS)
	for coords in locked_door_coords:
		entity_tiles.set_cell(coords, 0, LOCKED_DOOR_ATLAS)
	if player.dir == Vector2i.ZERO:
		entity_tiles.set_cell(player.coords, 0, PLAYER_ATLAS)
	else:
		entity_tiles.set_cell(player.coords, 0, PLAYER_HOLDING_KEY_ATLASES[player.dir][0])
		entity_tiles.set_cell(player.coords + player.dir, 0, PLAYER_HOLDING_KEY_ATLASES[player.dir][1])

func _process(delta: float) -> void:
	echo_pressed_delay -= delta
