@tool
extends EditorPlugin
## EditorLogger：将编辑器进程的报错与警告输出到日志文件
##
## 捕获 push_error、push_warning、部分引擎输出；写入 user://logs/game_errors.log
## 补充：GDScript::reload 的解析错误（UNUSED_PARAMETER、STATIC_CALLED_ON_INSTANCE 等）
## 走 _err_print_error → 引擎 file_logging 的 godot.log，不经过 OS.add_logger。
## 通过定时从 godot.log 中继相关错误行到 game_errors.log，实现统一落盘。

const LOG_PATH := "user://logs/game_errors.log"
## 引擎内置日志路径（与 project.godot 中 file_logging/log_path 一致）
const GODOT_LOG_PATH := "user://logs/godot.log"
## 中继定时器间隔（秒）
const RELAY_INTERVAL := 2.0

var _relay_timer: Timer
var _last_relay_pos: int = 0
var _relay_initialized: bool = false
var _file_logger: EditorFileLogger
## Output 面板的 RichTextLabel 缓存（用于中继 GDScript 警告）
var _output_log: RichTextLabel = null
var _last_output_text_hash: int = 0


class EditorFileLogger extends Logger:
	var _log_path: String
	var _mutex: Mutex

	func _init(log_path: String) -> void:
		_log_path = log_path
		_mutex = Mutex.new()

	func _log_message(message: String, error: bool) -> void:
		var prefix := "[EDITOR][STDERR] " if error else "[EDITOR][STDOUT] "
		_write_line("%s%s" % [prefix, message])

	func _log_error(
		_function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		script_backtraces: Array
	) -> void:
		var type_str := _error_type_to_string(error_type)
		var loc := "%s:%d in %s()" % [file, line, _function]
		var body: String = rationale if rationale.length() > 0 else code
		_write_line("[EDITOR][%s] %s | %s" % [type_str, loc, body])
		for bt in script_backtraces:
			if bt is ScriptBacktrace and not bt.is_empty():
				_write_line("  Backtrace:\n%s" % bt.format(2, 4))

	func _error_type_to_string(t: int) -> String:
		match t:
			0: return "ERROR"
			1: return "WARNING"
			2: return "SCRIPT"
			3: return "SHADER"
			_: return "UNKNOWN"

	## 供中继逻辑调用，将文本写入日志文件
	func write_line(text: String) -> void:
		_write_line(text)

	func _write_line(text: String) -> void:
		_mutex.lock()
		var dir := _log_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)
		# READ_WRITE 在文件不存在时返回 null，需先用 WRITE 创建
		var f := FileAccess.open(_log_path, FileAccess.READ_WRITE)
		if f == null:
			f = FileAccess.open(_log_path, FileAccess.WRITE)
		if f:
			f.seek_end()
			var timestamp := Time.get_datetime_string_from_system()
			f.store_line("[%s] %s" % [timestamp, text])
			f.close()
		_mutex.unlock()


func _enter_tree() -> void:
	_file_logger = EditorFileLogger.new(LOG_PATH)
	OS.add_logger(_file_logger)
	# 启动时写入一行，用于验证插件已加载且能写入
	_file_logger.write_line("[EditorLogger] 插件已加载，日志路径: %s" % ProjectSettings.globalize_path(LOG_PATH))
	_relay_timer = Timer.new()
	_relay_timer.wait_time = RELAY_INTERVAL
	_relay_timer.one_shot = false
	_relay_timer.timeout.connect(_relay_godot_log_errors)
	add_child(_relay_timer)
	_relay_timer.start()
	print("[EditorLogger] 编辑器日志已启用，与游戏日志同文件: ", ProjectSettings.globalize_path(LOG_PATH))


func _exit_tree() -> void:
	if _relay_timer:
		_relay_timer.stop()
		_relay_timer.queue_free()
		_relay_timer = null
	# Logger 无法通过 API 移除，编辑器退出时自动清理


## 从 godot.log 与 Output 面板中继 GDScript::reload 等解析错误到 game_errors.log
## GDScript 警告可能仅出现在 Output 面板（调试器），不写入 godot.log，故需双路中继
func _relay_godot_log_errors() -> void:
	if _file_logger == null:
		return
	_relay_from_godot_log()
	_relay_from_output_panel()


func _relay_from_godot_log() -> void:
	var godot_log := ProjectSettings.globalize_path(GODOT_LOG_PATH)
	if not FileAccess.file_exists(godot_log):
		return
	var f := FileAccess.open(godot_log, FileAccess.READ)
	if f == null:
		return
	# 首次运行时从文件末尾开始，避免中继历史内容
	if not _relay_initialized:
		f.seek_end()
		_last_relay_pos = f.get_position()
		_relay_initialized = true
		f.close()
		return
	f.seek(_last_relay_pos)
	var remaining := f.get_length() - _last_relay_pos
	if remaining <= 0:
		f.close()
		return
	var new_content := f.get_buffer(remaining)
	_last_relay_pos = f.get_position()
	f.close()
	if new_content.size() == 0:
		return
	var text := new_content.get_string_from_utf8()
	for line in text.split("\n"):
		line = line.strip_edges()
		if line.is_empty():
			continue
		if _is_gdscript_reload_error_line(line):
			_file_logger.write_line("[EDITOR][RELAY] %s" % line)


## 从 Output 面板读取并中继 GDScript 警告（调试器输出不经过 godot.log）
func _relay_from_output_panel() -> void:
	if _output_log == null:
		_output_log = _find_output_richtextlabel()
	if _output_log == null:
		return
	var full_text := _output_log.get_parsed_text()
	var current_hash := full_text.hash()
	if current_hash == _last_output_text_hash:
		return
	# 首次获取时只记录 hash，不中继历史
	if _last_output_text_hash == 0:
		_last_output_text_hash = current_hash
		return
	_last_output_text_hash = current_hash
	var lines := full_text.split("\n")
	for line in lines:
		line = line.strip_edges()
		if line.is_empty():
			continue
		if _is_gdscript_reload_error_line(line):
			_file_logger.write_line("[EDITOR][OUTPUT] %s" % line)


## 递归查找 Output 面板中的 RichTextLabel
func _find_output_richtextlabel() -> RichTextLabel:
	var base := get_editor_interface().get_base_control()
	if base == null:
		return null
	return _find_richtextlabel_recursive(base)


func _find_richtextlabel_recursive(node: Node) -> RichTextLabel:
	if node is RichTextLabel:
		var rtl := node as RichTextLabel
		var path_str := str(node.get_path())
		# 检查是否在 Output 面板下（Godot 4 编辑器结构可能为 .../Output/... 或含 output）
		if "output" in path_str.to_lower():
			return rtl
		var p := node.get_parent()
		while p != null:
			if p.name == "Output" or "output" in p.name.to_lower():
				return rtl
			p = p.get_parent()
	for child in node.get_children():
		var found := _find_richtextlabel_recursive(child)
		if found != null:
			return found
	return null


## 判断是否为 GDScript 解析/重载相关错误行（避免中继无关内容）
func _is_gdscript_reload_error_line(line: String) -> bool:
	var lower := line.to_lower()
	# 包含 res://、built-in、.gd: 或 GDScript 错误标记
	var has_location := "res://" in line or "built-in" in line or ".gd:" in line or "<gdscript" in lower
	var has_gdscript_marker := "gdscript::reload" in lower or "gdscript 错误" in line or "gdscript 源文件" in line
	# 匹配 "W 0:00:00:492   GDScript::reload:" 格式（Output/调试器）
	var is_warning_line := line.begins_with("W ") and "gdscript" in lower
	if not has_location and not has_gdscript_marker and not is_warning_line:
		return false
	return (
		"parse error" in lower
		or "compile error" in lower
		or "gdscript::reload" in lower
		or "unused_parameter" in lower
		or "static_called_on_instance" in lower
		or "integer_division" in lower
		or "confusable_local_declaration" in lower
		or "narrowing_conversion" in lower
		or "script error" in lower
		or "the parameter" in lower
		or "is a static function" in lower
		or "declared below in the parent block" in lower
		or "decimal part will be discarded" in lower
		or "loses precision" in lower
		or (("error" in lower or "warning" in lower) and ("at:" in lower or "gdscript" in lower))
	)
