extends Node

# Lightweight logger. Always prints to stdout (Godot Output panel) and also
# appends every line to user://debug.log so we can review past sessions.
# The file is rotated when it crosses MAX_BYTES.

const LOG_PATH  : String = "user://debug.log"
const MAX_BYTES : int    = 256 * 1024  # 256 KB

var _file : FileAccess = null

func _ready() -> void:
	_rotate_if_needed()
	_open()
	info("Logger", "session start")

func _open() -> void:
	if _file != null:
		return
	_file = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if _file == null:
		_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if _file != null:
		_file.seek_end()

func _rotate_if_needed() -> void:
	if not FileAccess.file_exists(LOG_PATH):
		return
	var f := FileAccess.open(LOG_PATH, FileAccess.READ)
	if f == null:
		return
	var size := f.get_length()
	f.close()
	if size <= MAX_BYTES:
		return
	# Keep the last 64 KB
	var keep := 64 * 1024
	var src := FileAccess.open(LOG_PATH, FileAccess.READ)
	if src == null:
		return
	src.seek(maxi(0, size - keep))
	var tail := src.get_buffer(keep)
	src.close()
	var dst := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if dst == null:
		return
	dst.store_buffer(tail)
	dst.close()

func info(tag: String, msg: String) -> void:
	_write("INFO", tag, msg)

func warn(tag: String, msg: String) -> void:
	_write("WARN", tag, msg)
	push_warning("[%s] %s" % [tag, msg])

func err(tag: String, msg: String) -> void:
	_write("ERR", tag, msg)
	push_error("[%s] %s" % [tag, msg])

func info_dict(tag: String, msg: String, data: Variant) -> void:
	info(tag, "%s :: %s" % [msg, str(data)])

func _write(level: String, tag: String, msg: String) -> void:
	var line := "[%s][%s][%s] %s" % [_timestamp(), level, tag, msg]
	print(line)
	if _file == null:
		_open()
	if _file != null:
		_file.store_line(line)
		_file.flush()

func file_path() -> String:
	return ProjectSettings.globalize_path(LOG_PATH)

func _timestamp() -> String:
	var t := Time.get_time_dict_from_system()
	var ms := Time.get_ticks_msec() % 1000
	return "%02d:%02d:%02d.%03d" % [t.hour, t.minute, t.second, ms]
