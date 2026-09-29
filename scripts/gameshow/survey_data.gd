class_name SurveyData
extends RefCounted
## Loads the Nosy Neighbors survey questions and fuzzy-matches free-text
## answers against the board. Answers are stored highest-points-first, so
## index 0 is always the #1 answer.


static func load_questions() -> Array:
	var f := FileAccess.open("res://data/survey_questions.json", FileAccess.READ)
	if f == null:
		push_error("SurveyData: could not open survey_questions.json")
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		push_error("SurveyData: survey_questions.json is not a dictionary")
		return []
	var survey = parsed.get("survey", [])
	return survey if survey is Array else []


static func load_fast_money() -> Array:
	var f := FileAccess.open("res://data/survey_questions.json", FileAccess.READ)
	if f == null:
		push_error("SurveyData: could not open survey_questions.json")
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return []
	var fm = parsed.get("fast_money", [])
	return fm if fm is Array else []


## Returns the answer index matching `text`, or -1. Exact normalized match
## wins; otherwise a Levenshtein distance <= 2 on answers of length >= 4
## counts (handles typos like "deviled egss"). Revealed answers never match.
static func match_answer(text: String, answers: Array, revealed: Array) -> int:
	var norm := normalize(text)
	if norm.is_empty():
		return -1
	for i in answers.size():
		if revealed[i]:
			continue
		if normalize(answers[i]["text"]) == norm:
			return i
	for i in answers.size():
		if revealed[i]:
			continue
		var target := normalize(answers[i]["text"])
		if target.length() >= 4 and _lev(norm, target) <= 2:
			return i
	return -1


static func normalize(s: String) -> String:
	var r := s.to_lower().strip_edges()
	var out := ""
	for i in r.length():
		var c := r[i]
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == " ":
			out += c
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.strip_edges()


static func _lev(a: String, b: String) -> int:
	var m := a.length()
	var n := b.length()
	if m == 0:
		return n
	if n == 0:
		return m
	var prev := []
	var cur := []
	prev.resize(n + 1)
	cur.resize(n + 1)
	for j in range(n + 1):
		prev[j] = j
	for i in range(1, m + 1):
		cur[0] = i
		for j in range(1, n + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			cur[j] = mini(mini(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost)
		var tmp := prev
		prev = cur
		cur = tmp
	return prev[n]
