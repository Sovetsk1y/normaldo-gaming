extends Node

# ── Каталог: ПРЕДМЕТЫ · ВРАГИ · БОССЫ ────────────────────────────────────────
# Что это. Игра выкидывает на игрока полсотни разных штук, и почти все они
# объясняются ровно один раз — в тот момент, когда впервые бьют. Дальше игрок
# помнит «вот эта красная штука почему-то замедляет», но не помнит, что она
# делает и сколько с неё урона. Каталог в книге учителя закрывает этот разрыв:
# посмотреть, что ты уже встречал и чем оно опасно.
#
# Показывается ТОЛЬКО ВСТРЕЧЕННОЕ. Незнакомое — тёмный силуэт со знаками
# вопроса вместо названия: каталог заодно и список того, что ещё впереди, и
# спойлерить весь бестиарий с первого забега незачем.
#
# ── Как вещь помечается встреченной ──────────────────────────────────────────
# Одним хуком на всю игру: `get_tree().node_added`. Помечать по месту рождения
# значило бы вписать вызов в три десятка мест — спавнер, сет-писы, мини-игры,
# боссы, — и первое же новое место забыли бы.
#
# Опознаётся вещь по СКРИПТУ узла, а у скриптов с полем `kind` (опасности,
# эффекты, ниндзя) — по паре «скрипт + вид». Ранний выход по `get_script() ==
# null` делает хук почти бесплатным: у интерфейса скриптов на узлах нет, а
# именно интерфейс и создаёт узлы пачками.

const S_ITEM  : String = "items"
const S_ENEMY : String = "enemies"
const S_BOSS  : String = "bosses"

const SECTION_TITLES : Dictionary = {
	S_ITEM:  "ПРЕДМЕТЫ",
	S_ENEMY: "ВРАГИ",
	S_BOSS:  "БОССЫ",
}

# id — он же ключ в сейве. Менять его нельзя: у игроков с прежним ключом запись
# «встречено» потеряется, и каталог схлопнется обратно в вопросы.
#
# `script` + `kind` — как узнать вещь на лету. `kind` пуст, если скрипт
# обслуживает ровно один вид.
const ENTRIES : Array = [
	# ── ПРЕДМЕТЫ ─────────────────────────────────────────────────────────────
	{ "id": "pizza", "section": S_ITEM, "title": "ПИЦЦА",
	  "icon": "res://assets/items/pizza.png",
	  "text": "Еда и счёт разом. Каждый кусок — очко и шаг к следующему жиру." },
	{ "id": "dollar", "section": S_ITEM, "title": "ДОЛЛАР",
	  "icon": "res://assets/items/dollar.png",
	  "text": "Деньги забега. На них покупаются скины — жир от них не растёт." },
	{ "id": "money_bag", "section": S_ITEM, "title": "МЕШОК ДЕНЕГ",
	  "icon": "res://assets/items/money_bag.png", "script": "money_bag",
	  "text": "Лопается веером долларов. У пирата — вдвое щедрее." },
	{ "id": "pizza_pack", "section": S_ITEM, "title": "ПАЧКА ПИЦЦЫ",
	  "icon": "res://assets/items/pizza_pack_closed.png", "script": "pizza_pack",
	  "text": "Взрывается пачкой кусков. Большая её родня — мини-игра ПИЦЦА-ПАТИ." },
	{ "id": "mutagen", "section": S_ITEM, "title": "МУТАГЕН",
	  "icon": "res://assets/items/mutagen.png", "script": "mutagen",
	  "text": "Редчайшая склянка. Съел — стал ЖИРОБОССОМ и держишь жир тапами." },
	{ "id": "magnet", "section": S_ITEM, "title": "МАГНИТ",
	  "icon": "res://assets/items/magnet.png", "script": "magnet",
	  "text": "Три секунды притягивает к голове всю добычу с экрана." },
	{ "id": "magic_box", "section": S_ITEM, "title": "МЭДЖИК БОКС",
	  "icon": "res://assets/items/magic_box.png", "script": "magic_box",
	  "text": "Ставка, а не награда: выплюнет что угодно — от пиццы до змеи." },
	{ "id": "hourglass", "section": S_ITEM, "title": "ПЕСОЧНЫЕ ЧАСЫ",
	  "icon": "res://assets/items/hourglass.png", "script": "effect_item", "kind": "hourglass",
	  "text": "Замедляют МИР, а не тебя: время на то, чтобы разобрать завал." },
	{ "id": "casey_mask", "section": S_ITEM, "title": "МАСКА КЕЙСИ",
	  "icon": "res://assets/items/casey_mask.png", "script": "effect_item", "kind": "casey_mask",
	  "text": "Щит на один удар. Ломается вместе с тем, что в тебя прилетело." },
	{ "id": "magic_hat", "section": S_ITEM, "title": "ШЛЯПА МАГА",
	  "icon": "res://assets/items/magic_hat.png", "script": "effect_item", "kind": "magic_hat",
	  "text": "Превращает всё на экране в добычу. Секунда — и стало пусто." },
	{ "id": "cola", "section": S_ITEM, "title": "ЭНЕРГЕТИК",
	  "icon": "res://assets/items/cola.png", "script": "effect_item", "kind": "cola",
	  "text": "Разгоняет голову. Быстрее — значит и в стену быстрее." },
	{ "id": "casino_chip", "section": S_ITEM, "title": "ЖЕТОН",
	  "icon": "res://assets/items/token.png", "script": "effect_item", "kind": "casino_chip",
	  "text": "Валюта автоматов. Тратится на спины, а не на скины." },
	{ "id": "boombox", "section": S_ITEM, "title": "БУМБОКС",
	  "icon": "res://assets/items/boombox1.png", "script": "boombox",
	  "text": "Врубает волну звука и сносит ею всё, что летит навстречу." },

	# ── ВРАГИ ────────────────────────────────────────────────────────────────
	{ "id": "banana", "section": S_ENEMY, "title": "БАНАН",
	  "icon": "res://assets/items/banana_peel.png", "script": "slowing_item",
	  "text": "Урона нет — есть занос. Самая частая причина влететь в следующее." },
	{ "id": "stone", "section": S_ENEMY, "title": "КАМЕНЬ",
	  "icon": "res://assets/items/stone.png",
	  "text": "Просто и честно: летит по прямой, бьёт на единицу." },
	{ "id": "trash", "section": S_ENEMY, "title": "БАК",
	  "icon": "res://assets/items/trash_bin.png",
	  "text": "Крупный и медленный. Видно издалека, объехать мешает размер." },
	{ "id": "cone", "section": S_ENEMY, "title": "КОНУС",
	  "icon": "res://assets/items/cone.png", "script": "cone",
	  "text": "Дорожный конус. Стройка и клуб забиты ими под завязку." },
	{ "id": "roadsign", "section": S_ENEMY, "title": "ЗНАК",
	  "icon": "res://assets/items/road_sign.png", "script": "roadsign_bum",
	  "text": "Дорожный знак поперёк лейна. Читается плоско — тем и коварен." },
	{ "id": "snake", "section": S_ENEMY, "title": "ЗМЕЯ",
	  "icon": "res://assets/items/snake.png", "script": "snake",
	  "text": "Ползёт зигзагом. По прямой её не объехать — надо читать фазу." },
	{ "id": "dog", "section": S_ENEMY, "title": "ЗЛАЯ СОБАКА",
	  "icon": "res://assets/items/angry_dog.png", "script": "dog",
	  "text": "Разгоняется и идёт наперехват. Уходить надо заранее." },
	{ "id": "homeless", "section": S_ENEMY, "title": "БОМЖ",
	  "icon": "res://assets/items/homeless1.png", "script": "homeless",
	  "text": "Тормозит и бьёт. Дракула его ест — остальным лучше объехать." },
	{ "id": "thief", "section": S_ENEMY, "title": "ВОР",
	  "icon": "res://assets/items/thief1.png", "script": "thief",
	  "text": "Крадёт доллары. Единственный, кто отнимает не жизнь, а деньги." },
	{ "id": "police_car", "section": S_ENEMY, "title": "МАШИНА КОПОВ",
	  "icon": "res://assets/items/police_car.png", "script": "police_car",
	  "text": "Идёт по двум лейнам и быстрее потока. Сносит всё на пути и\nразбивается у тебя перед носом — а из неё вылезают двое." },
	{ "id": "glove", "section": S_ENEMY, "title": "ПЕРЧАТКА",
	  "icon": "res://assets/items/boxing_glove.png", "script": "boxing_glove",
	  "text": "Выстреливает вперёд на пружине. Бьёт дальше, чем кажется." },
	{ "id": "cop", "section": S_ENEMY, "title": "КОП",
	  "icon": "res://assets/items/cop.png", "script": "hazard_item", "kind": "cop",
	  "text": "Бьёт и ВЫЗЫВАЕТ ПОДМОГУ: роняет наручники, пока летит." },
	{ "id": "safe", "section": S_ENEMY, "title": "СЕЙФ",
	  "icon": "res://assets/items/safe.png", "script": "hazard_item", "kind": "safe",
	  "text": "Самый тяжёлый предмет игры: два урона и туша во весь лейн." },
	{ "id": "poison", "section": S_ENEMY, "title": "ЯД",
	  "icon": "res://assets/items/poison.png", "script": "hazard_item", "kind": "poison",
	  "text": "Бьёт и травит: урон плюс замедление на три секунды." },
	{ "id": "bird", "section": S_ENEMY, "title": "ПТИЦА",
	  "icon": "res://assets/items/bird.png", "script": "hazard_item", "kind": "bird",
	  "text": "Единственная угроза по синусоиде. По прямой не объехать." },
	{ "id": "cocktail", "section": S_ENEMY, "title": "КОКТЕЙЛЬ",
	  "icon": "res://assets/items/cocktail.png", "script": "hazard_item", "kind": "cocktail",
	  "text": "Урона нет — есть четыре секунды заплетающихся ног." },
	{ "id": "shaman", "section": S_ENEMY, "title": "ШАМАН",
	  "icon": "res://assets/items/shaman.png", "script": "hazard_item", "kind": "shaman",
	  "text": "Колдует на ходу. Что именно — узнаешь, когда прилетит." },
	{ "id": "handcuffs", "section": S_ENEMY, "title": "НАРУЧНИКИ",
	  "icon": "res://assets/items/handcuffs.png", "script": "effect_item", "kind": "handcuffs",
	  "text": "Сковывают: пока не спадут, голова еле ползёт." },
	{ "id": "black_ace", "section": S_ENEMY, "title": "ЧЁРНЫЙ ТУЗ",
	  "icon": "res://assets/items/black_ace.png", "script": "effect_item", "kind": "black_ace",
	  "text": "Забирает спелл. Скин остаётся, а бить ему нечем." },
	{ "id": "loser_ticket", "section": S_ENEMY, "title": "БИЛЕТ ЛУЗЕРА",
	  "icon": "res://assets/items/loser_ticket.png", "script": "effect_item", "kind": "loser_ticket",
	  "text": "Проигрышный билет: обнуляет удачу на автоматах." },
	{ "id": "compass", "section": S_ENEMY, "title": "КОМПАС",
	  "icon": "res://assets/items/compass.png", "script": "compass_item",
	  "text": "Переворачивает управление на пять секунд. Хуже любого урона." },
	{ "id": "bomb", "section": S_ENEMY, "title": "БОМБА",
	  "icon": "res://assets/items/bomb.png", "script": "bomb",
	  "text": "Взрывается по кругу. Опасна не сама, а радиусом." },
	{ "id": "molotov", "section": S_ENEMY, "title": "МОЛОТОВ",
	  "icon": "res://assets/items/molotov1.png", "script": "molotov",
	  "text": "Разливает огонь по лейну. Огонь остаётся и после броска." },
	{ "id": "ninja", "section": S_ENEMY, "title": "НИНДЗЯ",
	  "icon": "res://assets/bosses/ninja_foot/ninja_foot.png", "script": "ninja_item",
	  "text": "Младшая родня босса. Три вида: сюрикены, рывок и дым." },
	{ "id": "girl", "section": S_ENEMY, "title": "ДЕВОЧКА-ЗАЗЫВАЛА",
	  "icon": "res://assets/bosses/club_boss/girl1.png", "script": "club_boss_minion",
	  "text": "Урона нет — есть вязкость. Влип — не успел уйти от следующего." },
	{ "id": "bum_barrel", "section": S_ENEMY, "title": "БОМЖ С БОЧКОЙ",
	  "icon": "res://assets/items/barrel_open1.png", "script": "bum_barrel",
	  "text": "Ставит бочку поперёк дороги и выпускает из неё собаку." },

	# Предметы локаций (раскладка по уровням). Скрипт у всех один —
	# `hazard_item`, — поэтому опознаются они по `kind`, как и первая семёрка.
	{ "id": "umbrella", "section": S_ENEMY, "title": "ЗОНТ",
	  "icon": "res://assets/items/umbrella.png", "script": "hazard_item", "kind": "umbrella",
	  "text": "Парусит и оттого летит медленнее потока. Крупный: объезжают, а не проскакивают." },
	{ "id": "bottle", "section": S_ENEMY, "title": "БУТЫЛКА С ПИСЬМОМ",
	  "icon": "res://assets/items/letter_bottle.png", "script": "hazard_item", "kind": "bottle",
	  "text": "Не бьёт — разливается под ноги и вяжет на четыре секунды." },
	{ "id": "tire", "section": S_ENEMY, "title": "КОЛЕСО",
	  "icon": "res://assets/items/tire.png", "script": "hazard_item", "kind": "tire",
	  "text": "Катится быстрее потока. Успеть отреагировать — весь вопрос." },
	{ "id": "lounger", "section": S_ENEMY, "title": "ШЕЗЛОНГ",
	  "icon": "res://assets/items/lounger.png", "script": "hazard_item", "kind": "lounger",
	  "text": "Самый длинный предмет: обойти можно только сверху или снизу." },
	{ "id": "campfire", "section": S_ENEMY, "title": "КОСТЁР",
	  "icon": "res://assets/items/firewood.png", "script": "hazard_item", "kind": "campfire",
	  "text": "Дрова горят тем же огнём, что остаётся после молотова." },

	# ── БОССЫ ────────────────────────────────────────────────────────────────
	# Восемь на всю игру, и порядок здесь — порядок ВСТРЕЧИ, а не алфавит: раздел
	# читается как дорожная карта. Трое уже стоят в кампании, пятеро ещё нет —
	# и это ЗАТРАВКА: запертые записи показывают, что впереди, не рассказывая
	# что именно.
	#
	# Портреты общие, из авторского листа `dev/art/boss_book/`: в книге у боссов
	# один вид, а не «трое настоящих спрайтов и пятеро силуэтов».
	{ "id": "boss_ninja", "section": S_BOSS, "title": "НОГА НИНДЗЯ",
	  "icon": "res://assets/ui/book/bosses/ninja.png", "script": "ninja_foot",
	  "text": "Конец КАНАЛИЗАЦИИ. Сюрикены, рывки и дым, закрывающий экран." },
	{ "id": "boss_croc", "section": S_BOSS, "title": "КРОКЕР",
	  "icon": "res://assets/ui/book/bosses/croc.png", "script": "leatherhead",
	  "text": "Конец УЛИЦЫ. Снайпер, картечь и пасть, которую отбивают тапами." },
	{ "id": "boss_club", "section": S_BOSS, "title": "ФЭТ ФЕЙС",
	  "icon": "res://assets/ui/book/bosses/club.png", "script": "club_boss",
	  "text": "Хозяин КЛУБА. Охрана, полиция, девочки — и рывок его самого." },
	{ "id": "boss_beatbop", "section": S_BOSS, "title": "БИТ БОП",
	  "icon": "res://assets/ui/book/bosses/beatbop.png",
	  "text": "Кабан в розовой бандане. Пока не встречался — но встретится." },
	{ "id": "boss_rocksteady", "section": S_BOSS, "title": "РОК СТЕДИ",
	  "icon": "res://assets/ui/book/bosses/rocksteady.png",
	  "text": "Носорог в каске. Пока не встречался — но встретится." },
	{ "id": "boss_robotcan", "section": S_BOSS, "title": "РОБОТ КЭН",
	  "icon": "res://assets/ui/book/bosses/robotcan.png",
	  "text": "Жестянка с антенной. Пока не встречалась — но встретится." },
	{ "id": "boss_sickbrain", "section": S_BOSS, "title": "СИК БРЕЙН",
	  "icon": "res://assets/ui/book/bosses/sickbrain.png",
	  "text": "Розовый мозг на щупальцах. Пока не встречался — но встретится." },
	{ "id": "boss_shredo", "section": S_BOSS, "title": "ШРЕДО",
	  "icon": "res://assets/ui/book/bosses/shredo.png",
	  "text": "Тот, кто в шлеме. Последний в списке — и не случайно." },
]

# script → [запись, …]; вид разбирается уже внутри.
var _by_script : Dictionary = {}

func _ready() -> void:
	for e in ENTRIES:
		var sc := String((e as Dictionary).get("script", ""))
		if sc == "":
			continue
		if not _by_script.has(sc):
			_by_script[sc] = []
		(_by_script[sc] as Array).append(e)
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	# Ранний выход: у интерфейса скриптов на узлах нет, а именно он создаёт узлы
	# пачками — без этой строки хук стоил бы дороже, чем приносит.
	var sc : Script = node.get_script() as Script
	if sc == null:
		return
	var name := sc.resource_path.get_file().get_basename()
	var rows : Array = _by_script.get(name, [])
	if rows.is_empty():
		return
	for e in rows:
		var kind := String((e as Dictionary).get("kind", ""))
		if kind != "" and String(node.get("kind")) != kind:
			continue
		SaveData.mark_seen(String((e as Dictionary)["id"]))
		return

# Пицца и доллар летят обычным `item.gd` и отличаются только текстурой, поэтому
# их помечает тот, кто их создаёт (спавнер), а не хук по скрипту.
func mark(id: String) -> void:
	SaveData.mark_seen(id)

func seen(id: String) -> bool:
	return SaveData.seen_entries.has(id)

func entries_of(section: String) -> Array:
	var out : Array = []
	for e in ENTRIES:
		if String((e as Dictionary)["section"]) == section:
			out.append(e)
	return out

# Сколько из раздела уже встречено — для подписи на вкладке.
func progress_of(section: String) -> Vector2i:
	var all := entries_of(section)
	var got := 0
	for e in all:
		if seen(String((e as Dictionary)["id"])):
			got += 1
	return Vector2i(got, all.size())
