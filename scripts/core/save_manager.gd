class_name SaveManager
extends RefCounted
## Atomic local saves, schema checks and one previous known-good backup.
const VERSION: int = 1
var directory: String = "user://"
var last_error: String = ""

func write_file(filename: String, payload: Dictionary) -> bool:
	last_error = ""
	var path: String = directory.path_join(filename)
	var envelope: Dictionary = {"version": VERSION, "data": payload}
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Не удалось открыть файл сохранения"
		return false
	file.store_string(JSON.stringify(envelope, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		last_error = "Ошибка записи: %s" % error_string(write_error)
		return false
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	var result: Error = DirAccess.rename_absolute(path + ".tmp", path)
	if result != OK:
		last_error = "Ошибка замены сохранения: %s" % error_string(result)
	return result == OK

func read_file(filename: String) -> Dictionary:
	last_error = ""
	for suffix: String in ["", ".bak"]:
		var path: String = directory.path_join(filename + suffix)
		if not FileAccess.file_exists(path):
			continue
		var parser: JSON = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK:
			continue
		var envelope: Variant = parser.data
		if envelope is Dictionary and envelope.get("version", 0) == VERSION and envelope.get("data") is Dictionary:
			if suffix == ".bak":
				last_error = "Повреждённое сохранение восстановлено из резервной копии"
			return envelope["data"]
	last_error = "Сохранение отсутствует, повреждено или имеет другую версию"
	return {}
