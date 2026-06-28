extends Node2D

const REPEAY_DELAY: float = 0.2
var echo_pressed_delay: float = 0.0

var steps_taken: int = 0
var last_move_was_successful: bool = true

# struct
class Player:
	var coords: Vector2i
	var dir: Vector2i
	var dir2: Vector2i

func new_player(start: Vector2i) -> Player:
	var p := Player.new()
	p.coords = start
	p.dir = Vector2.ZERO
	p.dir2 = Vector2.ZERO
	return p

class LevelState:
	var key_coords: Array[Vector2i] = []
	var locked_door_coords: Array[Vector2i] = []
	var locked_crate_coords: Array[Vector2i] = []
	var spike_trap_activated_tiles: Array[Vector2i] = []
	var player: Player

var state: LevelState

var player: Player:
	get:
		return state.player
	set(value):
		state.player = value

func new_state(entities: TileMapLayer) -> LevelState:
	var s := LevelState.new()
	for coords: Vector2i in entities.get_used_cells():
		if entity_tiles.get_cell_atlas_coords(coords) == PLAYER_ATLAS:
			s.player = new_player(coords)
		elif entity_tiles.get_cell_atlas_coords(coords) == KEY_ATLAS:
			s.key_coords.push_back(coords)
		elif entity_tiles.get_cell_atlas_coords(coords) == LOCKED_DOOR_ATLAS:
			s.locked_door_coords.push_back(coords)
		elif entity_tiles.get_cell_atlas_coords(coords) == LOCK_CRATE_ATLAS:
			s.locked_crate_coords.push_back(coords)
	return s

func duplicate_state(s: LevelState) -> LevelState:
	var dup := LevelState.new()
	dup.key_coords = s.key_coords.duplicate()
	dup.locked_door_coords = s.locked_door_coords.duplicate()
	dup.locked_crate_coords = s.locked_crate_coords.duplicate()
	dup.spike_trap_activated_tiles = s.spike_trap_activated_tiles.duplicate()
	
	dup.player = Player.new()
	dup.player.coords = s.player.coords
	dup.player.dir = s.player.dir
	dup.player.dir2 = s.player.dir2
	
	return dup

var undo_stack: Array[LevelState] = []
var last_move_was_reset: bool = false

const PLAYER_ATLAS = Vector2i(0, 0)
const KEY_ATLAS = Vector2i(1, 0)
const GOLD_KEY_ATLAS = Vector2i(1, 1)
const SPIKES_ATLAS = Vector2i(0, 4)
const SPIKE_TRAP_ATLAS = Vector2i(0, 5)
const LOCK_CRATE_ATLAS = Vector2i(1, 4)

const WALL_ATLASES := [
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
	Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
	Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
	Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5),
	Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6),
	Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7),
]

const UP_KEY := Vector2i(5, 0)
const RIGHT_KEY := Vector2i(3, 0)
const DOWN_KEY := Vector2i(4, 1)
const LEFT_KEY := Vector2i(2, 1)
const PLAYER_HOLDING_KEY_ATLASES := {
	Vector2i.UP: [Vector2i(5, 1), UP_KEY],
	Vector2i.RIGHT: [Vector2i(2, 0), RIGHT_KEY],
	Vector2i.DOWN: [Vector2i(4, 0), DOWN_KEY],
	Vector2i.LEFT: [Vector2i(3, 1), LEFT_KEY],
}

const PLAYER_HOLDING_MULTIPLE_KEY_ATLASES := {
	[Vector2i.UP, Vector2i.UP]: [PLAYER_ATLAS, UP_KEY, UP_KEY],
	[Vector2i.UP, Vector2i.RIGHT]: [PLAYER_ATLAS, UP_KEY, RIGHT_KEY],
	[Vector2i.UP, Vector2i.DOWN]: [PLAYER_ATLAS, UP_KEY, DOWN_KEY],
	[Vector2i.UP, Vector2i.LEFT]: [PLAYER_ATLAS, UP_KEY, LEFT_KEY],
	
	[Vector2i.RIGHT, Vector2i.UP]: [PLAYER_ATLAS, RIGHT_KEY, UP_KEY],
	[Vector2i.RIGHT, Vector2i.RIGHT]: [PLAYER_ATLAS, RIGHT_KEY, RIGHT_KEY],
	[Vector2i.RIGHT, Vector2i.DOWN]: [PLAYER_ATLAS, RIGHT_KEY, DOWN_KEY],
	[Vector2i.RIGHT, Vector2i.LEFT]: [PLAYER_ATLAS, RIGHT_KEY, LEFT_KEY],
	
	[Vector2i.DOWN, Vector2i.UP]: [PLAYER_ATLAS, DOWN_KEY, UP_KEY],
	[Vector2i.DOWN, Vector2i.RIGHT]: [PLAYER_ATLAS, DOWN_KEY, RIGHT_KEY],
	[Vector2i.DOWN, Vector2i.DOWN]: [PLAYER_ATLAS, DOWN_KEY, DOWN_KEY],
	[Vector2i.DOWN, Vector2i.LEFT]: [PLAYER_ATLAS, DOWN_KEY, LEFT_KEY],
	
	[Vector2i.LEFT, Vector2i.UP]: [PLAYER_ATLAS, LEFT_KEY, UP_KEY],
	[Vector2i.LEFT, Vector2i.RIGHT]: [PLAYER_ATLAS, LEFT_KEY, RIGHT_KEY],
	[Vector2i.LEFT, Vector2i.DOWN]: [PLAYER_ATLAS, LEFT_KEY, DOWN_KEY],
	[Vector2i.LEFT, Vector2i.LEFT]: [PLAYER_ATLAS, LEFT_KEY, LEFT_KEY],
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
	state = new_state(entity_tiles)

func reset() -> void:
	world_tiles.tile_map_data = initial_world_state
	entity_tiles.tile_map_data = initial_entity_world_state
	state = new_state(entity_tiles)
	
	last_move_was_reset = true

# FIXME: sometimes we drop an undo state somehow.
func push_undo_state():
	var undo_state := duplicate_state(state)
	
	# NOTE (sam): any state-changing world tiles can get saved here.
	for coord in world_tiles.get_used_cells():
		var atlas := world_tiles.get_cell_atlas_coords(coord)

	undo_stack.push_back(undo_state)

func undo() -> void:
	if len(undo_stack) < 1:
		return
	
	var prev: LevelState = undo_stack.pop_back()
	state = duplicate_state(prev)
	
	# NOTE (sam): any state-changing world tiles can get restored here.
	world_tiles.tile_map_data = initial_world_state
	for coords in state.spike_trap_activated_tiles:
		print(coords)
		var tile := world_tiles.get_cell_atlas_coords(coords)
		assert(tile == SPIKES_ATLAS or tile == SPIKE_TRAP_ATLAS, "saved activated spike trap for non-spike trap tile")
		world_tiles.set_cell(coords, 0, SPIKES_ATLAS)

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

func hands_full() -> bool:
	return player.dir != Vector2i.ZERO and player.dir2 != Vector2i.ZERO

func wall(coords: Vector2i) -> bool:
	var tile := world_tiles.get_cell_atlas_coords(coords) 
	return tile in WALL_ATLASES

func spikes(coords: Vector2i) -> bool:
	var tile := world_tiles.get_cell_atlas_coords(coords) 
	return tile == SPIKES_ATLAS

func spike_trap(coords: Vector2i) -> bool:
	var tile := world_tiles.get_cell_atlas_coords(coords)
	return tile == SPIKE_TRAP_ATLAS

func key(coords: Vector2i) -> bool:
	return coords in state.key_coords

func lockeddoor(coords: Vector2i) -> bool:
	return coords in state.locked_door_coords

func locked_crate(coords: Vector2i) -> bool:
	return coords in state.locked_crate_coords

func solid(coords: Vector2i) -> bool:
	return wall(coords) or lockeddoor(coords)

# TODO (sam): idk..
func empty(coords: Vector2i) -> bool:
	return not wall(coords) and not key(coords) and not lockeddoor(coords) and not coords == player.coords
	
func key_pushable(coords: Vector2i, pushdir: Vector2i, pushes: Array) -> bool:
	if wall(coords + pushdir):
		return false
	elif empty(coords + pushdir) or lockeddoor(coords + pushdir) or locked_crate(coords + pushdir):
		pushes.append([coords, coords + pushdir])
		return true
	elif key(coords + pushdir):
		pushes.append([coords, coords + pushdir])
		return key_pushable(coords + pushdir, pushdir, pushes)
	else:
		assert(false, "key_pushable shouldnt get here.")
		return false
		
func locked_crate_pushable(coords: Vector2i, pushdir: Vector2i, pushes: Array) -> bool:
	if wall(coords + pushdir) or lockeddoor(coords + pushdir) or locked_crate(coords + pushdir):
		return false
	elif empty(coords + pushdir) or key(coords + pushdir):
		pushes.append([coords, coords + pushdir])
		return true
	else:
		assert(false, "key_pushable shouldnt get here.")
		return false

func try_pickup_key(coords: Vector2i, movedir: Vector2i, key_pushes: Array) -> bool:
	if wall(coords + movedir):
		return false
		
	if key(coords + movedir):
		var temp_key_pushes = []
		if key_pushable(coords + movedir, movedir, temp_key_pushes):
			key_pushes.append_array(temp_key_pushes)
			return true
		else:
			return false
	
	return true

func try_push_key(coords: Vector2i, movedir: Vector2i, key_pushes: Array) -> bool:
	var temp_key_pushes = []
	if key_pushable(coords, movedir, temp_key_pushes):
		key_pushes.append_array(temp_key_pushes)
		return true
	else:
		return false

func try_push_locked_crate(coords: Vector2i, movedir: Vector2i, crate_pushes: Array) -> bool:
	var temp_crate_pushes = []
	if locked_crate_pushable(coords, movedir, temp_crate_pushes):
		crate_pushes.append_array(temp_crate_pushes)
		return true
	else:
		return false

func move_player(dir: Vector2i) -> bool:
	# phase 1: initial intent
	var target_coords = player.coords
	var target_dir := player.dir
	var target_dir2 := player.dir2
	
	var key_pushes = []
	var locked_crate_pushes = []
	
	# phase 2: collision
	if player.dir == Vector2i.ZERO and player.dir2 == Vector2i.ZERO:
		if solid(player.coords + dir) or spikes(player.coords + dir):
			return false
		elif key(player.coords + dir):
			if not try_pickup_key(player.coords + dir, dir, key_pushes):
				return false
		elif locked_crate(player.coords + dir):
			if not try_push_locked_crate(player.coords + dir, dir, locked_crate_pushes):
				return false
		
		target_coords = player.coords + dir
	else:
		# 1. if moving in same dir as either key, check wall 2 in front.
		if player.dir == dir or player.dir2 == dir:
			if wall(player.coords + dir + dir) or spikes(player.coords + dir):
				return false
			elif key(player.coords + dir + dir):
				if not try_push_key(player.coords + dir + dir, dir, key_pushes):
					return false
			
			target_coords = player.coords + dir
		# 2. if moving in non-key-direction, check wall 1 behind.
		if dir != player.dir and dir != player.dir2:
			if solid(player.coords + dir) or spikes(player.coords + dir):
				return false
			elif key(player.coords + dir):
				if hands_full() and not try_push_key(player.coords + dir, dir, key_pushes):
					return false
				elif not hands_full() and not try_pickup_key(player.coords + dir, dir, key_pushes):
					return false
			elif locked_crate(player.coords + dir):
				if not try_push_locked_crate(player.coords + dir, dir, locked_crate_pushes):
					return false
			target_coords = player.coords + dir
		
		# 3. for each key, check if it should slide against wall (rotate):
		if player.dir != Vector2i.ZERO and player.dir != dir and player.dir != -dir:
			var adjacent := player.coords + player.dir + dir
			if solid(adjacent) or locked_crate(adjacent):
				target_dir = -dir
			if key(adjacent):
				if not try_push_key(adjacent, dir, key_pushes):
					target_dir = -dir
		if player.dir2 != Vector2i.ZERO and player.dir2 != dir and player.dir2 != -dir:
			var adjacent := player.coords + player.dir2 + dir
			if solid(adjacent) or locked_crate(adjacent):
				target_dir2 = -dir
			if key(adjacent):
				if not try_push_key(adjacent, dir, key_pushes):
					target_dir2 = -dir
					
	# phase 3: commit
	var player_old_coords := player.coords
	player.coords = target_coords
	player.dir = target_dir
	player.dir2 = target_dir2
	
	# phase 4: resolve (assuming all collisions are okay)
	
	# activate spike traps
	if spike_trap(player_old_coords) and player.coords != player_old_coords:
		world_tiles.set_cell(player_old_coords, 0, SPIKES_ATLAS)
		state.spike_trap_activated_tiles.push_back(player_old_coords)
		print(state.spike_trap_activated_tiles)
	
	# push keys first (crates wont be pushed yet -> if crate and key are both pushed, key will resolve first.
	var old_key_coords := []
	var new_key_coords := []
	for key_push in key_pushes:
		old_key_coords.append(key_push[0])
		new_key_coords.append(key_push[1])
	for old in old_key_coords:
		state.key_coords.erase(old)
	for new in new_key_coords:
		if lockeddoor(new):
			state.locked_door_coords.erase(new)
		elif locked_crate(new):
			state.locked_crate_coords.erase(new)
		else:
			state.key_coords.append(new)
	
	# push crates
	var old_crate_coords := []
	var new_crate_coords := []
	for crate_push in locked_crate_pushes:
		old_crate_coords.append(crate_push[0])
		new_crate_coords.append(crate_push[1])
	for old in old_crate_coords:
		state.locked_crate_coords.erase(old)
	for new in new_crate_coords:
		if key(new):
			state.key_coords.erase(new)
		else:
			state.locked_crate_coords.append(new)
			
	var world_tile := world_tiles.get_cell_atlas_coords(player.coords)
	if key(player.coords):
		print("on key")
		if player.dir == Vector2i.ZERO:
			player.dir = dir
			state.key_coords.erase(player.coords)
		elif player.dir2 == Vector2i.ZERO:
			player.dir2 = dir
			state.key_coords.erase(player.coords)
	elif world_tile == STAIRS_DOWN_ATLAS:
		print("can move down stairs")
	elif world_tile == STAIRS_UP_ATLAS:
		print("can move up stairs")
	elif player.dir == dir:
		if lockeddoor(player.coords + player.dir):
			print("unlocked door dir1")
			state.locked_door_coords.erase(player.coords + player.dir)
			player.dir = Vector2i.ZERO
		elif locked_crate(player.coords + player.dir):
			print("unlocked crate dir1")
			state.locked_crate_coords.erase(player.coords + player.dir)
			player.dir = Vector2i.ZERO
	elif player.dir2 == dir:
		if lockeddoor(player.coords + player.dir2):
			print("unlocked door dir2")
			state.locked_door_coords.erase(player.coords + player.dir2)
			player.dir2 = Vector2i.ZERO
		elif locked_crate(player.coords + player.dir2):
			print("unlocked crate dir2")
			state.locked_crate_coords.erase(player.coords + player.dir2)
			player.dir2 = Vector2i.ZERO

	return true

func update_entity_visuals() -> void:
	entity_tiles.clear()
	for coords in state.key_coords:
		entity_tiles.set_cell(coords, 0, KEY_ATLAS)
	for coords in state.locked_door_coords:
		entity_tiles.set_cell(coords, 0, LOCKED_DOOR_ATLAS)
	for coords in state.locked_crate_coords:
		entity_tiles.set_cell(coords, 0, LOCK_CRATE_ATLAS)
	if player.dir == Vector2i.ZERO and player.dir2 == Vector2i.ZERO:
		entity_tiles.set_cell(player.coords, 0, PLAYER_ATLAS)
	elif player.dir2 == Vector2i.ZERO:
		var sprites: Array = PLAYER_HOLDING_KEY_ATLASES[player.dir]
		entity_tiles.set_cell(player.coords, 0, sprites[0])
		entity_tiles.set_cell(player.coords + player.dir, 0, sprites[1])
	elif player.dir == Vector2i.ZERO:
		var sprites: Array = PLAYER_HOLDING_KEY_ATLASES[player.dir2]
		entity_tiles.set_cell(player.coords, 0, sprites[0])
		entity_tiles.set_cell(player.coords + player.dir2, 0, sprites[1])
	else:
		var sprites: Array = PLAYER_HOLDING_MULTIPLE_KEY_ATLASES[[player.dir, player.dir2]]
		entity_tiles.set_cell(player.coords, 0, sprites[0])
		entity_tiles.set_cell(player.coords + player.dir, 0, sprites[1])
		entity_tiles.set_cell(player.coords + player.dir2, 0, sprites[2])


func _process(delta: float) -> void:
	echo_pressed_delay -= delta
