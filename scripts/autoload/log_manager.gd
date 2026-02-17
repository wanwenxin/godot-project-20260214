extends Node
## LogManager：将 Godot 调试器面板的报错与警告输出到日志文件
##
## 功能：
## - 捕获 push_error、push_warning、printerr、GDScript 运行时错误（_log_error）
## - 捕获 print、引擎内部 WARNING 等全部输出（_log_message，含 stdout/stderr）
## - 写入 user://logs/game_errors.log
## - 若仍有遗漏，可查看引擎内置 user://logs/godot.log
##
## 依赖：Godot 4.5+ 的 OS.add_logger / Logger 接口
## 说明：user:// 在编辑器与导出版本均可写；通过「项目 → 打开项目数据文件夹」可找到 logs

## 日志文件路径（user:// 对应项目数据目录下的 logs 文件夹）
const LOG_PATH := "user://logs/game_errors.log"

## 内部 Logger 实现，负责将错误/警告写入文件
class FileErrorLogger extends Logger:
	var _log_path: String
	var _mutex: Mutex

	func _init(log_path: String) -> void:
		_log_path = log_path
		_mutex = Mutex.new()

	## 接收 print/printerr 及引擎内部输出；error=true 表示 stderr，error=false 表示 stdout
	## 引擎内部 WARNING 可能走任一流；全部记录以确保控制台警告均落盘（stdout 含普通 print 会略增体积）
	func _log_message(message: String, error: bool) -> void:
		var prefix := "[GAME][STDERR] " if error else "[GAME][STDOUT] "
		_write_line("%s%s" % [prefix, message])

	## 接收 GDScript 运行时错误、push_error、push_warning 等
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
		var line_text := "[GAME][%s] %s | %s" % [type_str, loc, body]
		_write_line(line_text)
		# 若有脚本回溯，追加到日志
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


func _init() -> void:
	OS.add_logger(FileErrorLogger.new(LOG_PATH))


func _ready() -> void:
	# 启动时打印日志路径，便于在控制台看到后打开文件夹
	var abs_path := ProjectSettings.globalize_path(LOG_PATH)
	print("[LogManager] 日志文件: ", abs_path, " （可通过「项目 → 打开项目数据文件夹」进入 logs 目录）")
