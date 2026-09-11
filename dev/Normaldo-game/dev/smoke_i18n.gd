extends SceneTree

# Локализация.
#   godot --headless --path . --script res://dev/smoke_i18n.gd
#
# ── ЧТО ЗДЕСЬ МОЖЕТ СЛОМАТЬСЯ ТИХО ─────────────────────────────────────────
# Ключом перевода служит САМА РУССКАЯ НАДПИСЬ ИЗ КОДА (см. scripts/loc.gd).
# Значит любая правка надписи — «ЗАБРАТЬ» → «ЗАБРАТЬ!» — молча отцепляет от неё
# перевод: игра продолжает работать, просто на английском телефоне в этом месте
# остаётся русский. Ни ошибки, ни предупреждения.
#
# Поэтому таблица сверяется с исходниками: каждый её ключ обязан найтись в коде.
# Ключ, которого в коде нет, — это либо опечатка, либо надпись, которую увезли,
# а перевод забыли.
#
# Обратную сторону — «надпись есть, а перевода нет» — тест НЕ требует: перевод
# идёт экранами, и незакрытый остаток это нормальное состояние работы. Но он его
# СЧИТАЕТ и печатает, чтобы долг был виден.

const EN := preload("res://scripts/loc_en.gd")

# ЗАГРУЖАЕТСЯ ЛЕНИВО, А НЕ `preload`-ом — ровно по той же причине, что и скрипт
# обучения в smoke_tutorial.gd: `loc.gd` ссылается на автолоад SaveData, а тот
# появляется ПОЗЖЕ, чем разбирается сам тест. `preload` компилировал бы его в
# момент, когда SaveData ещё нет, ронял компиляцию и оставлял в кеше сломанный
# ресурс. Таблица переводов (`loc_en.gd`) — просто словарь и ни на что не
# смотрит, её можно и заранее.
var _loc_script : GDScript = null

func _loc() -> GDScript:
	if _loc_script == null:
		_loc_script = load("res://scripts/loc.gd") as GDScript
	return _loc_script

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 12

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	print("── Таблица сходится с кодом ──")
	_test_keys_exist()
	print("── Выбор языка ──")
	await _test_pick()
	print("── Русский остаётся русским ──")
	_test_ru_untouched()

	print("")
	if _checks < EXPECTED_CHECKS:
		_fails += 1
		print("ПРОВЕРОК ВСЕГО %d, А ЖДАЛИ %d — какая-то оборвалась"
			% [_checks, EXPECTED_CHECKS])
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ (проверок: %d)" % _checks)
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── Все ключи таблицы живут в коде ──────────────────────────────────────────
func _test_keys_exist() -> void:
	var src := _all_sources()
	_check(not src.is_empty(), "исходники прочитаны: %d символов" % src.length())
	var orphans : Array = []
	for key in EN.STRINGS:
		# Ищем ровно так, как строка записана в коде, — в кавычках. Без них
		# короткое «ЖИР» находилось бы внутри «ЖИРОВЫЕ СОСТОЯНИЯ» и проверка
		# ничего бы не значила.
		# Перенос строки в коде записан ДВУМЯ символами — обратной косой и «n», —
		# а в словаре он настоящий. Без обратного превращения «КНИГА\nУЧИТЕЛЯ»
		# ищется как двухстрочный кусок и не находится никогда.
		var needle := String(key).replace("\n", "\\n")
		if not src.contains('"%s"' % needle):
			orphans.append(key)
	_check(orphans.is_empty(),
		"каждый ключ перевода есть в коде, потерянных: %s" % [orphans])
	_check(EN.STRINGS.size() > 100, "строк в таблице: %d" % EN.STRINGS.size())

	# И ни один перевод не пуст: пустая строка на экране выглядит поломкой, а в
	# таблице — как будто работа сделана.
	var empty : Array = []
	for key in EN.STRINGS:
		if String(EN.STRINGS[key]).strip_edges() == "":
			empty.append(key)
	_check(empty.is_empty(), "пустых переводов нет: %s" % [empty])

	# ДОЛГ. Не проверка, а счёт: сколько надписей в игре ещё без перевода.
	var all_ru : Dictionary = {}
	var re := RegEx.new()
	re.compile('"[^"\\n]*[А-Яа-яЁё][^"\\n]*"')
	for m in re.search_all(src):
		var lit := m.get_string()
		all_ru[lit.substr(1, lit.length() - 2)] = true
	var left : int = 0
	for k in all_ru:
		if not EN.STRINGS.has(k):
			left += 1
	print("  ОСТАЛОСЬ ПЕРЕВЕСТИ: %d из %d надписей" % [left, all_ru.size()])

# ── Какой язык выбирается ───────────────────────────────────────────────────
func _test_pick() -> void:
	await process_frame
	var loc := get_root().get_node_or_null("Loc")
	var save := get_root().get_node_or_null("SaveData")
	if loc == null or save == null:
		_check(false, "автолоады Loc/SaveData не поднялись")
		return
	var sup : Array = _loc().get_script_constant_map().get("SUPPORTED", [])
	_check(sup.has("ru") and sup.has("en"), "языка два: %s" % [sup])

	# ЯВНЫЙ ВЫБОР СИЛЬНЕЕ ТЕЛЕФОНА. Игрок, поставивший русский на английском
	# телефоне, не должен объяснять это игре при каждом запуске.
	save.set("language", "en")
	_check(String(loc.call("current")) == "en", "выбранный язык держится: en")
	save.set("language", "ru")
	_check(String(loc.call("current")) == "ru", "и обратно: ru")

	# А без выбора — язык телефона, и русский только для русского телефона.
	save.set("language", "")
	var dev := String(loc.call("device_default"))
	_check(sup.has(dev), "без выбора берётся язык телефона: %s" % dev)
	_check(String(loc.call("current")) == dev, "и он же показывается")

# ── На русском ничего не переводится ────────────────────────────────────────
# Отдельной русской таблицы нет — ключ и есть русский текст. Это работает
# ровно до тех пор, пока ЗАПАСНАЯ ЛОКАЛЬ русская: при запасной «en» сервер, не
# найдя таблицы на ru, уходил в неё и отдавал английский русским игрокам.
func _test_ru_untouched() -> void:
	_check(String(ProjectSettings.get_setting(
			"internationalization/locale/fallback", "")) == "ru",
		"запасная локаль русская")
	var loc := get_root().get_node_or_null("Loc")
	if loc == null:
		return
	loc.call("set_language", "ru")
	var probe := "ЕШЬ ПИЦЦУ"
	_check(TranslationServer.translate(probe) == probe,
		"на ru надпись остаётся собой: %s" % TranslationServer.translate(probe))
	loc.call("set_language", "en")
	_check(String(TranslationServer.translate(probe)) == String(EN.STRINGS[probe]),
		"а на en переводится: %s" % TranslationServer.translate(probe))

# Весь код игры одной строкой: ключи ищутся по нему целиком, а не по списку
# файлов, — иначе список пришлось бы дополнять при каждом новом экране.
func _all_sources() -> String:
	var out := ""
	for f in _gd_files("res://scripts"):
		out += FileAccess.get_file_as_string(f)
	return out

func _gd_files(dir: String) -> Array:
	var out : Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if d.current_is_dir():
			if not n.begins_with("."):
				out.append_array(_gd_files(dir + "/" + n))
		elif n.ends_with(".gd"):
			out.append(dir + "/" + n)
		n = d.get_next()
	d.list_dir_end()
	return out
