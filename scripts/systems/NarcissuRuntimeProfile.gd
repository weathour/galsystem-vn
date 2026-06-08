extends RefCounted
## Runtime constants for the local Narcissu compatibility subset.

const SOURCE_WIDTH := 800.0
const SOURCE_HEIGHT := 600.0
const MANIFEST_PATH := "res://reference_private/narcissu/generated/asset_manifest.json"
const GAME_DATA_PATH := "res://reference_private/narcissu/game_data"
const GENERATED_DIR := "res://reference_private/narcissu/generated"
const BGM_BUS := "Master"
const SFX_BUS := "Master"
const VOICE_BUS := "Master"
const DEFAULT_FADE_MS := 300

static func source_to_viewport(pos: Vector2, viewport_size: Vector2) -> Vector2:
	return Vector2(pos.x / SOURCE_WIDTH * viewport_size.x, pos.y / SOURCE_HEIGHT * viewport_size.y)
