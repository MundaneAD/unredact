# lib_lib.gd
class_name LibLib
extends RefCounted

const DB_PATH := "res://data/doc_db.tres"

var db: DocDB
var index: Dictionary = {}
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
	db = ResourceLoader.load(DB_PATH)
	_rebuild_index()

# ── Public API ────────────────────────────────────────────────────────────────

func search(query: String) -> Dictionary:
	var q := query.strip_edges().to_lower()
	if q.is_empty():
		return { "status": "Type something to search.", "results": [] }

	if not index.has(q):
		return { "status": "No results for '%s'." % q, "results": [] }

	var keys: Array = index[q].duplicate()
	keys.sort_custom(func(a, b):
		return str(db.docs[a].title) < str(db.docs[b].title)
	)

	var results: Array = []
	for key in keys:
		results.append({ "doc_id": str(key), "title": db.docs[key].title })

	return { "status": "%d result(s) for '%s'." % [results.size(), q], "results": results }

func open_doc(doc_id: String, query: String) -> Dictionary:
	var key := StringName(doc_id)
	if not db.docs.has(key):
		return { "title": "", "body_bbcode": "", "new_words": [], "status": "Could not open document." }

	var doc: Doc = db.docs[key]
	var q := query.strip_edges().to_lower()
	opened_docs[doc_id] = true

	var hits: Array[String] = []
	var newly_revealed: Array[String] = []
	var seen := {}

	for i in range(doc.paragraphs.size()):
		var par := doc.paragraphs[i]
		if q.is_empty() or par.to_lower().find(q) != -1:
			var candidate := par.strip_edges()
			if candidate.length() > 0 and candidate not in hits:
				hits.append(candidate)
			for w in doc.reveals_words[i]:
				var wl := str(w).to_lower()
				if not unlocked_words.has(wl) and not seen.has(wl):
					seen[wl] = true
					newly_revealed.append(wl)

	var snippet := "\n\n---\n\n".join(hits) if hits.size() > 0 \
			else (doc.paragraphs[0] if doc.paragraphs.size() > 0 else "")

	for w in newly_revealed:
		unlocked_words[w] = true

	var highlight_terms: Array = newly_revealed.duplicate()
	if not q.is_empty():
		highlight_terms.append(q)

	return {
		"title": doc.title,
		"body_bbcode": _highlight_terms(snippet, highlight_terms),
		"new_words": newly_revealed,
		"status": "New keyword(s) added to stack." if newly_revealed.size() > 0 \
				  else "You found something, but no new keywords stand out."
	}

func is_word_unlocked(word: String) -> bool:
	return unlocked_words.has(word.to_lower())

# ── Internal ──────────────────────────────────────────────────────────────────

func _get_revealed_words(doc: Doc) -> Array[String]:
	var seen := {}
	var out: Array[String] = []
	for w in doc.reveals_words:
		var wl := str(w).to_lower()
		if not unlocked_words.has(wl) and not seen.has(wl):
			seen[wl] = true
			out.append(wl)
	return out

func _rebuild_index() -> void:
	index.clear()
	for key in db.docs:
		_index_doc(key, db.docs[key])

func _index_doc(doc_key: StringName, doc: Doc) -> void:
	for par in doc.paragraphs:
		for w in _tokenize(par.to_lower()):
			_add_to_index(w, doc_key)
		for phrase in SPECIAL_PHRASES:
			if par.to_lower().find(phrase) != -1:
				_add_to_index(phrase, doc_key)

func _add_to_index(key: String, doc_key: StringName) -> void:
	if not index.has(key):
		index[key] = []
	if doc_key not in index[key]:
		index[key].append(doc_key)

func _tokenize(text: String) -> Array[String]:
	var t := text
	for ch in [".", ",", "!", "?", ":", ";", "\"", "'", "(", ")", "[", "]", "\n", "\t", "-", "—"]:
		t = t.replace(ch, " ")
	var out: Array[String] = []
	for p in t.split(" ", false):
		var w := p.strip_edges()
		if w.length() >= 2:
			out.append(w)
	return out

func _matching_paragraphs(paragraphs: Array[String], query: String) -> String:
	if query.is_empty():
		return "\n\n".join(paragraphs)
	var q := query.to_lower()
	var hits: Array[String] = []
	for par in paragraphs:
		if par.to_lower().find(q) != -1:
			var candidate := par.strip_edges()
			if candidate.length() > 0 and candidate not in hits:
				hits.append(candidate)
	if hits.is_empty():
		return paragraphs[0] if paragraphs.size() > 0 else ""
	return "\n\n---\n\n".join(hits)

func _highlight_terms(text: String, terms: Array) -> String:
	var t := text
	var filtered: Array = terms.filter(func(x): return str(x).strip_edges() != "")
	filtered.sort_custom(func(a, b): return str(a).length() > str(b).length())
	for term_any in filtered:
		t = _replace_ci(t, str(term_any))
	return t

func _replace_ci(haystack: String, needle: String) -> String:
	var escaped := needle
	for ch in [".", "+", "*", "?", "^", "$", "(", ")", "[", "]", "{", "}", "|", "\\"]:
		escaped = escaped.replace(ch, "\\" + ch)
	var regex := RegEx.new()
	regex.compile("(?i)\\b" + escaped + "\\b")
	var result := ""
	var i := 0
	for m in regex.search_all(haystack):
		result += haystack.substr(i, m.get_start() - i)
		result += "[color=yellow]" + m.get_string() + "[/color]"
		i = m.get_end()
	result += haystack.substr(i)
	return result
	#var lower_h := haystack.to_lower()
	#var lower_n := needle.to_lower()
	#var result := ""
	#var i := 0
	#while true:
		#var idx := lower_h.find(lower_n, i)
		#if idx == -1:
			#result += haystack.substr(i)
			#break
		#result += haystack.substr(i, idx - i)
		#result += replacement
		#i = idx + needle.length()
	#return result
