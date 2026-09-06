class_name AchBackend
extends RefCounted

# ── Зеркало достижений на платформе ──────────────────────────────────────────
# ЭКРАН В ИГРЕ — ОСНОВНОЙ, GAME CENTER — ЗЕРКАЛО. Не наоборот, и это не уступка
# ради Андроида: интерфейс Game Center — отдельное модальное окно поверх игры, в
# которое большинство игроков не заходит никогда. Если достижения живут только
# там, для игрока их нет.
#
# Отсюда и устройство: игра считает и показывает сама, а сюда УХОДИТ КОПИЯ.
# Отвалилась платформа, игрок не залогинился, запретил Game Center — экран
# работает ровно так же. «Работает только у залогиненных» — поломка, которую на
# своём устройстве не увидишь.
#
# ── Почему пачкой, а не по одному ────────────────────────────────────────────
# `submit` только КОПИТ. Каждая отправка в Game Center — сетевой запрос, и семь
# открытий подряд посреди забега это семь запросов в тот момент, когда кадр
# дорог. Отправляет `flush()` — его зовут в конце забега.
#
# ── iOS ──────────────────────────────────────────────────────────────────────
# В Godot 4 встроенной поддержки Game Center нет (была в 3.x, вырезана). Нужен
# плагин `GameCenter` из godotengine/godot-ios-plugins и пересборка
# iOS-экспорта с ним. Здесь мы его только ИЩЕМ: собран экспорт с плагином —
# зеркало работает, собран без — молча не работает, и это допустимое состояние,
# а не ошибка.
#
# ── Андроид ──────────────────────────────────────────────────────────────────
# Google Play Games НЕ БЕРЁМ: своя регистрация, свой вход, свой набор
# ограничений — а взамен та же плашка, которую мы и так рисуем сами. На Андроиде
# `available()` возвращает false, и всё живёт на экране игры и на сервере.
#
# ── Идентификаторы ───────────────────────────────────────────────────────────
# `com.normaldo.mobapp.ach.<id>` — ровно то, что заводит
# dev/tools/push_achievements.py. МЕНЯТЬ ИХ НЕЛЬЗЯ НИКОГДА: сменённый id — это
# новое достижение, а старое остаётся у игроков висеть навсегда. Поэтому
# префикс собран здесь из одной константы, а не написан в двух местах.
#
# См. /Концепция/Достижения.md, scripts/achievement_manager.gd

const BUNDLE : String = "com.normaldo.mobapp"
const PREFIX : String = BUNDLE + ".ach."

# Имя синглтона, который отдаёт плагин iOS-экспорта.
const IOS_SINGLETON : String = "GameCenter"

var _queue : Dictionary = {}   # id достижения → процент 0..100
var _iface : Object = null
var _looked : bool = false

static func vendor_id(aid: String) -> String:
	return PREFIX + aid

# Плагин доступен, только если экспорт собран с ним. Ищем ОДИН РАЗ: искать на
# каждый вызов значило бы дёргать движок в цикле отправки.
func _plugin() -> Object:
	if _looked:
		return _iface
	_looked = true
	if Engine.has_singleton(IOS_SINGLETON):
		_iface = Engine.get_singleton(IOS_SINGLETON)
	return _iface

func available() -> bool:
	if OS.get_name() != "iOS":
		return false
	return _plugin() != null

# Копит. Процент — 0..100, как его и принимает Game Center: он работает
# процентами, а не «да/нет», и без процента игрок видит только момент открытия,
# но не путь к нему.
func submit(aid: String, percent: float) -> void:
	if aid == "":
		return
	var p := clampf(percent, 0.0, 100.0)
	# Если это же достижение уже в очереди — оставляем БОЛЬШИЙ процент. Game
	# Center меньший всё равно проигнорирует, но отправлять заведомо лишнее
	# незачем.
	if _queue.has(aid) and float(_queue[aid]) >= p:
		return
	_queue[aid] = p

func flush() -> void:
	if _queue.is_empty():
		return
	var batch := _queue.duplicate()
	_queue.clear()
	var gc := _plugin()
	if gc == null:
		return
	# Плагин принимает по одному, но ОДНИМ ЗАХОДОМ и вне забега — это и есть
	# та экономия, ради которой очередь заведена.
	for aid in batch:
		if gc.has_method("award_achievement"):
			gc.call("award_achievement", {
				"name": vendor_id(String(aid)),
				"progress": float(batch[aid]),
			})

# Показать окно Game Center. Кнопка на экране достижений её и зовёт — но только
# когда `available()`, иначе кнопки нет вовсе: кнопка, которая ничего не делает,
# хуже отсутствующей.
func show_ui() -> void:
	var gc := _plugin()
	if gc != null and gc.has_method("show_game_center"):
		gc.call("show_game_center", { "view": "achievements" })
