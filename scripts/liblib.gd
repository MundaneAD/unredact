# search_engine.gd — attach to nothing, instantiate as a resource/node or preload
class_name LibLib
extends RefCounted

var db = preload("res://scripts/evidence_db.gd").new()
var docs: Array = []
var docs_by_id: Dictionary = {}

var index: Dictionary = {}
var full_index: Dictionary = {}
var current_chapter: int = 0

var unlocked_words: Dictionary = {}
var opened_docs: Dictionary = {}

var SPECIAL_PHRASES := [
	"yuri yudin", "cut open", "from the inside", "only in underwear",
	"skull", "the clothes of the previous bodies", "radioactive",
	"tongue", "eyebrows", "paradoxical undressing", "avalanche",
	"cloth and glasses", "united states military", "lsd",
	"3-quinuclidinyl benzilate (bz)", "psychoactive agents",
	"radiological material"
]

func _init() -> void:
	docs = db.DOCS
	for d in docs:
		docs_by_id[str(d["id"])] = d
	_rebuild_index()

# ---- Public API ----

## Returns { "status": String, "results": Array[Dictionary] }
## Each result: { "doc_id": String, "title": String }
func search(query: String) -> Dictionary:
	var q := query.strip_edges().to_lower()
	if q.is_empty():
		return { "status": "Type something to search.", "results": [] }

	if not index.has(q):
		if full_index.has(q):
			return { "status": "Records found, but access is restricted (advance the story).", "results": [] }
		return { "status": "No results for '%s'." % q, "results": [] }

	var doc_ids: Array = index[q].duplicate()
	doc_ids.sort_custom(func(a, b):
		return str(docs_by_id[str(a)].get("title", "")) < str(docs_by_id[str(b)].get("title", ""))
	)

	var results: Array = []
	for doc_id in doc_ids:
		var d: Dictionary = docs_by_id[str(doc_id)]
		results.append({ "doc_id": str(doc_id), "title": str(d.get("title", "Evidence")) })

	return { "status": "%d result(s) for '%s'." % [results.size(), q], "results": results }

## Returns { "title": String, "body_bbcode": String, "new_words": Array[String], "status": String }
func open_doc(doc_id: String, query: String) -> Dictionary:
	if not docs_by_id.has(doc_id):
		return { "title": "", "body_bbcode": "", "new_words": [], "status": "Could not open document." }

	var d: Dictionary = docs_by_id[doc_id]
	var q := query.strip_edges().to_lower()
	opened_docs[doc_id] = true

	var title := str(d.get("title", "Evidence"))
	var content := _get_doc_text(d)
	var snippet := _extract_matching_paragraphs(content, q, 0)

	var newly_revealed := _get_revealed_words(d, q)

	for w in newly_revealed:
		unlocked_words[w] = true

	var status: String
	if newly_revealed.size() == 0:
		status = "You found something, but no new keywords stand out."
	else:
		status = "New keyword(s) added to stack."

	var highlight_terms: Array = [q] + newly_revealed
	var body_bbcode := _highlight_terms(snippet, highlight_terms)

	return {
		"title": title,
		"body_bbcode": body_bbcode,
		"new_words": newly_revealed,
		"status": status
	}

func advance_chapter() -> void:
	current_chapter += 1
	_rebuild_index()

func is_word_unlocked(word: String) -> bool:
	return unlocked_words.has(word.to_lower())

# ---- Internal ----

func _get_revealed_words(d: Dictionary, query: String) -> Array[String]:
	var newly: Array[String] = []

	var reveal_map: Dictionary = d.get("reveal_map", {})
	if reveal_map.has(query):
		for w in reveal_map[query]:
			var wl := str(w).to_lower()
			if not unlocked_words.has(wl):
				newly.append(wl)

	if newly.size() == 0:
		for w in d.get("reveals_words", []):
			var wl := str(w).to_lower()
			if not unlocked_words.has(wl):
				newly.append(wl)

	# Deduplicate
	var uniq := {}
	for w in newly:
		uniq[w] = true
	var out: Array[String] = []
	for k in uniq.keys():
		out.append(str(k))
	return out

func _get_doc_text(d: Dictionary) -> String:
	if d.has("text_file"):
		var path: String = str(d["text_file"])
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			return file.get_as_text()
		return "[Error loading file: %s]" % path
	return str(d.get("text", ""))

func _rebuild_index() -> void:
	index.clear()
	full_index.clear()
	for d in docs:
		_index_doc_into(full_index, d)
		if int(d.get("chapter", 0)) <= current_chapter:
			_index_doc_into(index, d)

func _index_doc_into(target: Dictionary, d: Dictionary) -> void:
	var doc_id := str(d["id"])
	var text := _get_doc_text(d).to_lower()
	for w in _tokenize(text):
		_add_to_index(target, w, doc_id)
	for phrase in SPECIAL_PHRASES:
		if text.find(phrase) != -1:
			_add_to_index(target, phrase, doc_id)

func _add_to_index(target: Dictionary, key: String, doc_id: String) -> void:
	if not target.has(key):
		target[key] = []
	if doc_id not in target[key]:
		target[key].append(doc_id)

func _tokenize(text: String) -> Array[String]:
	var t := text.to_lower()
	for ch in [".", ",", "!", "?", ":", ";", "\"", "'", "(", ")", "[", "]", "\n", "\t", "-", "—"]:
		t = t.replace(ch, " ")
	var out: Array[String] = []
	for p in t.split(" ", false):
		var w := p.strip_edges()
		if w.length() >= 2:
			out.append(w)
	return out

func _extract_matching_paragraphs(text: String, query: String, context: int) -> String:
	if query.is_empty():
		return text
	var paras := text.split("\n\n", false)
	var q := query.to_lower()
	var hits: Array[String] = []
	for i in range(paras.size()):
		if paras[i].to_lower().find(q) != -1:
			var start: int = max(0, i - context)
			var end_i: int = min(paras.size() - 1, i + context)
			for j in range(start, end_i + 1):
				var candidate := paras[j].strip_edges()
				if candidate.length() > 0 and candidate not in hits:
					hits.append(candidate)
	if hits.size() == 0:
		return paras[0] if paras.size() > 0 else text
	return "\n\n---\n\n".join(hits)

func _highlight_terms(text: String, terms: Array) -> String:
	var t := text
	var filtered: Array = terms.filter(func(x): return str(x).strip_edges() != "")
	filtered.sort_custom(func(a, b): return str(a).length() > str(b).length())
	for term_any in filtered:
		var term := str(term_any)
		t = _replace_ci(t, term, "[color=yellow]" + term + "[/color]")
	return t

func _replace_ci(haystack: String, needle: String, replacement: String) -> String:
	var lower_h := haystack.to_lower()
	var lower_n := needle.to_lower()
	var result := ""
	var i := 0
	while true:
		var idx := lower_h.find(lower_n, i)
		if idx == -1:
			result += haystack.substr(i)
			break
		result += haystack.substr(i, idx - i)
		result += replacement
		i = idx + needle.length()
	return result
