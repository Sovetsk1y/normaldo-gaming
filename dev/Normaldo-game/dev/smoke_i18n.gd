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

# ── ТАБЛИЦА ЧИТАЕТСЯ ТЕКСТОМ, А НЕ `preload`-ом ────────────────────────────
# Повторённый ключ GDScript не прощает: словарь с двумя одинаковыми ключами не
# собирается вовсе, и падает разбор ВСЕГО файла. А `preload` роняет вместе с ним
# и сам тест — вместо «повторён ключ ПАУЗА» приходит «Could not resolve external
# class member STRINGS», по которому настоящей причины не найти.
#
# Поэтому ключи и переводы достаются из ИСХОДНОГО ТЕКСТА файла. Так тест
# переживает сломанную таблицу и может сказать, чем именно она сломана.

# ЗАГРУЖАЕТСЯ ЛЕНИВО, А НЕ `preload`-ом — ровно по той же причине, что и скрипт
# обучения в smoke_tutorial.gd: `loc.gd` ссылается на автолоад SaveData, а тот
# появляется ПОЗЖЕ, чем разбирается сам тест. `preload` компилировал бы его в
# момент, когда SaveData ещё нет, ронял компиляцию и оставлял в кеше сломанный
# ресурс. Таблица переводов (`loc_en.gd`) — просто словарь и ни на что не
# смотрит, её можно и заранее.
const TABLE : String = "res://scripts/loc_en.gd"

var _loc_script : GDScript = null

func _loc() -> GDScript:
	if _loc_script == null:
		_loc_script = load("res://scripts/loc.gd") as GDScript
	return _loc_script

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 18

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
	print("── Надпись доходит до словаря целой ──")
	_test_not_mangled()
	print("── Выбор языка ──")
	await _test_pick()
	print("── Русский остаётся русским ──")
	_test_ru_untouched()
	_restore_language()

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

# Ключ → перевод, вынутые из текста таблицы. Порядок сохраняется, повторы
# видны: словарь тут не годится, он бы их и склеил.
func _pairs() -> Array:
	var out : Array = []
	var tbl := FileAccess.get_file_as_string(TABLE)
	var re := RegEx.new()
	re.compile('\n\t"((?:[^"\\\\]|\\\\.)*)":\\s*\n?\\s*"((?:[^"\\\\]|\\\\.)*)"')
	for m in re.search_all(tbl):
		out.append([_unesc(m.get_string(1)), _unesc(m.get_string(2))])
	return out

# Строка в коде записана с экранированием; нам нужен тот текст, каким он станет
# в словаре.
func _unesc(s: String) -> String:
	return s.replace("\\n", "\n").replace('\\"', '"')

# ── Все ключи таблицы живут в коде ──────────────────────────────────────────
func _test_keys_exist() -> void:
	var src := _all_sources()
	_check(not src.is_empty(), "исходники прочитаны: %d символов" % src.length())
	var pairs := _pairs()
	var keys : Array = []
	for pr in pairs:
		keys.append(String((pr as Array)[0]))
	var orphans : Array = []
	for key in keys:
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
	_check(pairs.size() > 100, "строк в таблице: %d" % pairs.size())

	# ── ПОВТОРЁННЫЙ КЛЮЧ ЛОМАЕТ ТАБЛИЦУ ЦЕЛИКОМ ─────────────────────────────
	# Отваливается не одна строка, а весь перевод разом: словарь не собирается,
	# и игра остаётся русской на любом языке.
	var seen : Dictionary = {}
	var twice : Array = []
	for k in keys:
		if seen.has(k):
			twice.append(k)
		seen[k] = true
	_check(twice.is_empty(), "повторённых ключей нет: %s" % [twice])

	# И ТАБЛИЦА ДЕЙСТВИТЕЛЬНО СОБИРАЕТСЯ. Проверка выше ловит известную причину
	# поломки, эта — саму поломку, какой бы она ни была.
	var tbl_script : GDScript = load(TABLE) as GDScript
	var built : Dictionary = {}
	if tbl_script != null:
		built = tbl_script.get_script_constant_map().get("STRINGS", {})
	_check(built.size() == pairs.size(),
		"и таблица собирается целиком: %d из %d" % [built.size(), pairs.size()])

	# И ни один перевод не пуст: пустая строка на экране выглядит поломкой, а в
	# таблице — как будто работа сделана.
	var empty : Array = []
	for pr in pairs:
		if String((pr as Array)[1]).strip_edges() == "":
			empty.append((pr as Array)[0])
	_check(empty.is_empty(), "пустых переводов нет: %s" % [empty])

	# И В ПЕРЕВОДЕ НЕ ОСТАЛОСЬ РУССКОГО. Строку переводят по кускам и бросают на
	# середине; на экране это выглядит как опечатка, а в таблице — как готовая
	# работа, потому что перевод вроде бы есть.
	var half : Array = []
	var cre := RegEx.new()
	cre.compile("[А-Яа-яЁё]")
	for pr in pairs:
		if cre.search(String((pr as Array)[1])) != null:
			half.append((pr as Array)[1])
	_check(half.is_empty(), "в переводах не осталось русского: %s" % [half])

	# ── ПОДСТАНОВКИ ОБЯЗАНЫ СОВПАДАТЬ ───────────────────────────────────────
	# Строка вроде «УРОВЕНЬ %d · %s» собирается оператором `%`, и он требует
	# РОВНО столько значений, сколько в ней спецификаторов. Перевод, потерявший
	# один, роняет подстановку в рантайме; перевод, поменявший %d на %s, тихо
	# печатает не то.
	#
	# Ловится это только на английской сборке и только на том экране, где строка
	# показывается, — то есть в лучшем случае глазами, в худшем никогда.
	var bad_fmt : Array = []
	var fre := RegEx.new()
	fre.compile("%[0-9.]*[a-zA-Z%]")
	for pr in pairs:
		var ru := String((pr as Array)[0])
		var en := String((pr as Array)[1])
		var a : Array = []
		var b : Array = []
		for m in fre.search_all(ru):
			if m.get_string() != "%%":
				a.append(m.get_string())
		for m in fre.search_all(en):
			if m.get_string() != "%%":
				b.append(m.get_string())
		if a != b:
			bad_fmt.append("%s: %s против %s" % [ru, a, b])
	_check(bad_fmt.is_empty(), "подстановки совпадают с оригиналом: %s" % [bad_fmt])

	# ДОЛГ. Не проверка, а счёт: сколько надписей в игре ещё без перевода.
	var all_ru : Dictionary = {}
	var re := RegEx.new()
	re.compile('"[^"\\n]*[А-Яа-яЁё][^"\\n]*"')
	for m in re.search_all(src):
		var lit := m.get_string()
		all_ru[lit.substr(1, lit.length() - 2)] = true
	var left : int = 0
	for k in all_ru:
		if not seen.has(k):
			left += 1
	print("  ОСТАЛОСЬ ПЕРЕВЕСТИ: %d из %d надписей" % [left, all_ru.size()])

# ── НАДПИСЬ ДОЛЖНА ДОЙТИ ДО СЛОВАРЯ ЦЕЛОЙ ──────────────────────────────────
# Ключ — сама русская надпись. Значит в словаре ищется РОВНО ТА СТРОКА, которая
# доехала до `Label.text`. Всё, что успело случиться с ней по дороге, ключ
# ломает — а тишина при этом полная: перевод просто не находится.
#
# Два способа сломать, оба уже случались:
#
#   l.text = it["title"] + "\n" + it["desc"]   — склейка. В словарь уходит
#       двухстрочная простыня, которой там нет. Половина экрана скинов осталась
#       русской при ПОЛНОЙ таблице, и заметить это удалось только на скриншоте.
#
#   lbl.text = String(a["title"]).to_upper()   — переиначивание. В словаре лежит
#       «Первый укус», а спрашивают «ПЕРВЫЙ УКУС». Тоже не находится.
#
# Лечится одинаково: `tr()` ставится ПЕРЕД склейкой и ПЕРЕД сменой регистра.
# Здесь это и проверяется — по исходникам, потому что на экране такое видно
# только на английской сборке и только на нужном экране.
const MANGLE_OK : Array = [
	# Не надписи, а служебные строки: имя платформы, хеш, кусок идентификатора,
	# промокод из поля ввода. Регистр им меняют не для показа.
	"OS.", "sha256", "_hex", ".substr(", ".strip_edges()",
	# Имя скина — имя собственное, оно и по-английски НОРМАЛЬДО.
	"name_ru",
	# Латинский идентификатор жира — запасной вариант, когда его нет в таблице.
	"tier.to_upper()",
	# Имя предмета переводится ВНУТРИ `SkinProgression.item_name()` — той самой
	# единственной двери, ради которой её и сделали. Снаружи `tr()` не видно, и
	# проверка этого знать не может: сквозь вызов функции она не смотрит.
	"item_name(",
]

func _test_not_mangled() -> void:
	var re_case := RegEx.new()
	re_case.compile("\\.(to_upper|to_lower|capitalize)\\(\\)")
	var bad_case : Array = []
	var bad_glue : Array = []
	for f in _gd_files("res://scripts"):
		# Лаборатория скинов — инструмент разработчика, её надписи не переводятся
		# намеренно (см. раздел «остатки» в loc_en.gd).
		if f.ends_with("/skin_lab.gd") or f.ends_with("/loc_en.gd"):
			continue
		var name : String = f.get_file()
		var n := 0
		for line in FileAccess.get_file_as_string(f).split("\n"):
			n += 1
			var s := String(line).strip_edges()
			if s.begins_with("#"):
				continue
			var skip := false
			for ok in MANGLE_OK:
				if s.contains(String(ok)):
					skip = true
					break
			if not skip:
				for m in re_case.search_all(s):
					if not _receiver(s, m.get_start()).begins_with("tr("):
						bad_case.append("%s:%d %s" % [name, n, s.substr(0, 90)])
			# Склейка: русская надпись, соединённая с чем-то ещё прямо в
			# присваивании текста.
			if _has_ru_literal(s) and (s.contains(" + ") or s.contains("%")) \
					and not s.contains("tr(") and _looks_like_text(s):
				bad_glue.append("%s:%d %s" % [name, n, s.substr(0, 90)])
	_check(bad_case.is_empty(),
		"регистр меняется ПОСЛЕ перевода: %s" % [bad_case])
	_check(bad_glue.is_empty(),
		"надписи не склеиваются до перевода: %s" % [bad_glue])

# Выражение слева от точки: от `at` идём назад, считая скобки, и
# останавливаемся на границе выражения. Для `title.to_upper()` вернётся
# «title», для `tr(chapter["title"]).to_upper()` — «tr(chapter["title"])».
func _receiver(s: String, at: int) -> String:
	var depth := 0
	var i := at - 1
	while i >= 0:
		var c := s[i]
		if c == ")" or c == "]":
			depth += 1
		elif c == "(" or c == "[":
			if depth == 0:
				break
			depth -= 1
		elif depth == 0 and (c == " " or c == "," or c == "=" or c == "%" or c == "+"):
			break
		i -= 1
	return s.substr(i + 1, at - i - 1)

func _has_ru_literal(s: String) -> bool:
	var re := RegEx.new()
	re.compile('"[^"\\n]*[А-Яа-яЁё][^"\\n]*"')
	return re.search(s) != null

func _looks_like_text(s: String) -> bool:
	return s.contains("text") or s.contains("_make_label(")

# ── ЯЗЫК ВОЗВРАЩАЕТСЯ КАКИМ БЫЛ ────────────────────────────────────────────
# Выбор языка лежит В СОХРАНЕНИИ, а сохранение — на диске и переживает прогон.
# Тест, оставивший после себя английский, переключает на него и все следующие
# сюиты батареи, и игру разработчика заодно.
#
# Поймалось это ровно так: smoke_death упал на том, что ищет русские надписи, а
# нашёл наполовину переведённые — потому что этот тест отработал раньше него.
var _lang_before : String = ""
var _lang_saved  : bool   = false

func _remember_language() -> void:
	if _lang_saved:
		return
	var save := get_root().get_node_or_null("SaveData")
	if save != null:
		_lang_before = String(save.get("language"))
		_lang_saved  = true

func _restore_language() -> void:
	if not _lang_saved:
		return
	var save := get_root().get_node_or_null("SaveData")
	var loc  := get_root().get_node_or_null("Loc")
	if save == null:
		return
	save.set("language", _lang_before)
	save.call("_save")
	if loc != null:
		loc.call("apply")

# ── Какой язык выбирается ───────────────────────────────────────────────────
func _test_pick() -> void:
	await process_frame
	_remember_language()
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
	_check(String(TranslationServer.translate(probe)) == "EAT PIZZA",
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
