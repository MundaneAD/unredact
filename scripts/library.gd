# evidence_ui.gd
extends Control

const DB_PATH := "res://data/doc_db.tres"

@export var search_input: LineEdit
@export var search_button: Button
@export var results_list: ItemList
@export var evidence_title: Label
@export var evidence_body: RichTextLabel
@export var redacted_text: RedactedLabel
@export var status_label: Label

var db: DocDB
var index: Dictionary = {}
var unlocked_words: Dictionary = {}
var opened_docs: Dictionary = {}
var last_query: String = ""

var SPECIAL_PHRASES := [
	"yuri yudin", "cut open", "from the inside", "only in underwear",
	"skull", "the clothes of the previous bodies", "radioactive",
	"tongue", "eyebrows", "paradoxical undressing", "avalanche",
	"cloth and glasses", "united states military", "lsd",
	"3-quinuclidinyl benzilate (bz)", "psychoactive agents",
	"radiological material"
]

func _ready() -> void:
	db = ResourceLoader.load(DB_PATH)
	_rebuild_index()
	search_button.pressed.connect(_on_search)
	search_input.text_submitted.connect(func(_t): _on_search())
	results_list.item_clicked.connect(func(i, _pos, _btn):
		_open_doc(results_list.get_item_metadata(i))
	)
	status_label.text = "Search the archive."
	evidence_body.meta_clicked.connect(_on_meta_clicked)

func _on_meta_clicked(meta):
	print(meta)
	_unlock_word(meta)

func _on_search() -> void:
	var q := search_input.text.strip_edges().to_lower()
	if q.is_empty():
		status_label.text = "Type something to search."
		return

	last_query = q
	results_list.clear()

	if not index.has(q):
		status_label.text = "No results for '%s'." % q
		return

	# One entry per doc — first matching paragraph only
	var seen_docs := {}
	var hits: Array = []
	for entry in index[q]:
		if not seen_docs.has(entry.doc_key):
			seen_docs[entry.doc_key] = true
			hits.append(entry)

	hits.sort_custom(func(a, b): return str(db.docs[a.doc_key].title) < str(db.docs[b.doc_key].title))

	for hit in hits:
		var doc: Doc = db.docs[hit.doc_key]
		results_list.add_item(doc.title)
		results_list.set_item_metadata(results_list.item_count - 1, hit)

	status_label.text = "%d result(s) for '%s'." % [hits.size(), q]

func _open_doc(hit: Dictionary) -> void:
	var key: StringName = hit.doc_key
	var par_idx: int = hit.par_idx

	if not db.docs.has(key):
		status_label.text = "Could not open document."
		return

	var doc: Doc = db.docs[key]
	opened_docs[str(key)] = true
	evidence_title.text = doc.title

	var par := doc.paragraphs[par_idx].strip_edges()
	var newly_revealed: Array[String] = []
	var seen := {}
	for w in doc.reveals_words[par_idx]:
		var wl := str(w).to_lower()
		if not unlocked_words.has(wl) and not seen.has(wl):
			seen[wl] = true
			newly_revealed.append(wl)

	#for w in newly_revealed:
		#_unlock_word(w)

	var highlight_terms: Array = newly_revealed.duplicate()
	#if not last_query.is_empty():
		#highlight_terms.append(last_query)

	evidence_body.clear()
	evidence_body.bbcode_enabled = true
	evidence_body.text = _highlight_terms(par, highlight_terms)

	status_label.text = "New keyword(s) added to stack." if newly_revealed.size() > 0 \
			else "You found something, but no new keywords stand out."

func _unlock_word(word: String) -> void:
	if unlocked_words.has(word):
		return
	unlocked_words[word] = true
	redacted_text.unlock_word(word)

# ── Index ─────────────────────────────────────────────────────────────────────

func _rebuild_index() -> void:
	index.clear()
	for key in db.docs:
		_index_doc(key, db.docs[key])

func _index_doc(doc_key: StringName, doc: Doc) -> void:
	for i in range(doc.paragraphs.size()):
		var par := doc.paragraphs[i].to_lower()
		for w in _tokenize(par):
			_add_to_index(w, doc_key, i)
		for phrase in SPECIAL_PHRASES:
			if par.find(phrase) != -1:
				_add_to_index(phrase, doc_key, i)

func _add_to_index(key: String, doc_key: StringName, par_idx: int) -> void:
	if not index.has(key):
		index[key] = []
	var entry := { "doc_key": doc_key, "par_idx": par_idx }
	for existing in index[key]:
		if existing.doc_key == doc_key and existing.par_idx == par_idx:
			return
	index[key].append(entry)

# ── Helpers ───────────────────────────────────────────────────────────────────

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
		result += "[url="+m.get_string()+"][color=yellow]" + m.get_string() + "[/color][/url]"
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
