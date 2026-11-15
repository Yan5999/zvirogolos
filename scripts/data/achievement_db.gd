class_name AchievementDB
extends RefCounted
## Перелік внутрішніх досягнень. Стан зберігається в GameState.achievements (id -> дата).
## У Steam кожне дублюється як "ACH_" + ID у верхньому регістрі (див. SteamManager).

const ALL: Array[Dictionary] = [
	{"id": "first_find", "title": "Перший друг", "desc": "Знайди першого звіра"},
	{"id": "five_found", "title": "Слідопит", "desc": "Знайди 5 звірів"},
	{"id": "half_zoo", "title": "Півзоопарку", "desc": "Знайди 15 звірів"},
	{"id": "full_zoo", "title": "Повний зоопарк", "desc": "Знайди всіх звірів"},
	{"id": "night_find", "title": "Нічний мисливець", "desc": "Знайди нічного звіра"},
	{"id": "biome_forest", "title": "Лісовий знавець", "desc": "Знайди всіх звірів лісу"},
	{"id": "biome_desert", "title": "Знавець пустелі", "desc": "Знайди всіх звірів пустелі"},
	{"id": "biome_lake", "title": "Знавець озера", "desc": "Знайди всіх звірів озера"},
	{"id": "biome_snow", "title": "Знавець снігів", "desc": "Знайди всіх звірів снігів"},
	{"id": "first_voice", "title": "Перший голос", "desc": "Запиши голос першому звіру"},
	{"id": "full_chorus", "title": "Великий хор", "desc": "Запиши голос кожному звіру"},
	{"id": "first_photo", "title": "Перший кадр", "desc": "Зроби фото (F)"},
	{"id": "photo_animal", "title": "Вдалий кадр", "desc": "Сфотографуй звіра"},
	{"id": "photo_5", "title": "Натураліст", "desc": "Май фото п'яти різних звірів"},
	{"id": "guess_3", "title": "Гострий слух", "desc": "Вгадай 3 голоси поспіль"},
	{"id": "guess_7", "title": "Абсолютний слух", "desc": "Вгадай 7 голосів поспіль"},
	{"id": "storm", "title": "Грозовий день", "desc": "Побач блискавку в лісі або біля озера"},
]

const BIOME_IDS: Array[String] = ["biome_forest", "biome_desert", "biome_lake", "biome_snow"]


static func find(id: String) -> Dictionary:
	for a: Dictionary in ALL:
		if a["id"] == id:
			return a
	return {}
