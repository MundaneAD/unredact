extends Control

# ---- UI NodePaths (match your scene tree) ----
var last_query: String = ""
var CONTEXT_PARAGRAPHS := 0 # 0 = only matching paragraph, 1 = include prev/next too
@export var search_input: LineEdit 
@export var search_button: Button 
@export var results_list: ItemList 
@export var evidence_title: Label 
@export var evidence_body: RichTextLabel 
#@export var word_stack_container: FlowContainer 
@export var redacted_text: RedactedLabel
@export var status_label: Label
@export var next_chapter_button: Button 


# ---- Data ----
# ---- Data ----
var db = preload("res://scripts/evidence_db.gd").new()
var docs: Array = []
var docs_by_id: Dictionary = {}     # doc_id -> doc dictionary

# Search indices
var index: Dictionary = {}          # visible (<= current_chapter): key -> Array[doc_id]
var full_index: Dictionary = {}     # all chapters: key -> Array[doc_id]

var current_chapter: int = 0

# State
var unlocked_words: Dictionary = {}  # word -> true
var opened_docs: Dictionary = {}     # doc_id -> true

# Multi-word redactions / phrases you want searchable as-is
var SPECIAL_PHRASES := [
	"yuri yudin",
	"cut open",
	"from the inside",
	"only in underwear",
	"skull",
	"the clothes of the previous bodies",
	"radioactive",
	"tongue",
	"eyebrows",
	"paradoxical undressing",
	"avalanche",
	"cloth and glasses",
	"united states military",
	"lsd",
	"3-quinuclidinyl benzilate (bz)",
	"psychoactive agents",
	"radiological material"
]

func _ready() -> void:
	# Load docs from DB
	docs = db.DOCS
	for d in docs:
		docs_by_id[str(d["id"])] = d

	# Wire UI signals
	search_button.pressed.connect(_on_search)
	search_input.text_submitted.connect(_on_search_submitted)
	next_chapter_button.pressed.connect(advance_chapter)

	# Single click open
	results_list.item_clicked.connect(func(i, _pos, _btn):
		_on_result_activated(i)
	)

	_rebuild_index()
	status_label.text = "Search the archive (Chapter %d). Try: tent" % (current_chapter + 1)
	advance_chapter()
	advance_chapter()
	advance_chapter()

func _on_search_submitted(_text: String) -> void:
	_on_search()

func _on_search() -> void:
	var q := search_input.text.strip_edges().to_lower()
	if q.is_empty():
		status_label.text = "Type something to search."
		return

	last_query = q
	results_list.clear()

	# No visible results
	if not index.has(q):
		if full_index.has(q):
			status_label.text = "Records found, but access is restricted (advance the story)."
		else:
			status_label.text = "No results for '%s'." % q
		return

	var doc_ids: Array = index[q]

	# Sort by title
	doc_ids.sort_custom(func(a, b):
		return str(docs_by_id[str(a)].get("title", "")) < str(docs_by_id[str(b)].get("title", ""))
	)

	for doc_id in doc_ids:
		var d: Dictionary = docs_by_id[str(doc_id)]
		results_list.add_item(str(d.get("title", "Evidence")))
		results_list.set_item_metadata(results_list.item_count - 1, str(doc_id))

	status_label.text = "%d result(s) for '%s'." % [doc_ids.size(), q]

func _on_result_activated(item_index: int) -> void:
	var doc_id = results_list.get_item_metadata(item_index)
	if doc_id == null:
		return

	_open_doc(str(doc_id))

func _open_doc(doc_id: String) -> void:
	if not docs_by_id.has(doc_id):
		status_label.text = "Could not open document."
		return

	var d: Dictionary = docs_by_id[doc_id]
	opened_docs[doc_id] = true

	evidence_title.text = str(d.get("title", "Evidence"))

	var content := _get_doc_text(d)
	var snippet := _extract_matching_paragraphs(content, last_query, CONTEXT_PARAGRAPHS)

	evidence_body.clear()
	evidence_body.bbcode_enabled = true
	evidence_body.text = _highlight_terms(snippet, [last_query])

	# ---------------- REVEAL LOGIC ----------------
	var newly_revealed: Array[String] = []

	# 1) Query-triggered reveal_map
	var reveal_map: Dictionary = d.get("reveal_map", {})
	if reveal_map.has(last_query):
		for w in reveal_map[last_query]:
			newly_revealed.append(str(w).to_lower())

	# 2) Fallback: always-on-open reveals_words
	if newly_revealed.size() == 0:
		var reveals_words: Array = d.get("reveals_words", [])
		for w in reveals_words:
			newly_revealed.append(str(w).to_lower())

	# Deduplicate
	var uniq := {}
	for w in newly_revealed:
		uniq[w] = true
	newly_revealed = []
	for k in uniq.keys():
		newly_revealed.append(str(k))

	if newly_revealed.size() == 0:
		status_label.text = "You found something, but no new keywords stand out."
	else:
		for w in newly_revealed:
			_unlock_word(w)
		status_label.text = "New keyword(s) added to stack."
		evidence_body.text = _highlight_terms(snippet, [last_query] + newly_revealed)
func _get_doc_text(d: Dictionary) -> String:
	if d.has("text_file"):
		var path: String = str(d["text_file"])
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			return file.get_as_text()
		return "[Error loading file: %s]" % path

	return str(d.get("text", ""))

func _unlock_word(word: String) -> void:
	if unlocked_words.has(word):
		return
	unlocked_words[word] = true

	var b := Button.new()
	b.text = word.to_upper()
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		status_label.text = "Selected: %s" % word
	)
	#word_stack_container.add_child(b)
	redacted_text.unlock_word(word)

# ---- Index building (visible + full) ----
func _rebuild_index() -> void:
	index.clear()
	full_index.clear()

	for d in docs:
		_index_doc_into(full_index, d)

		if int(d.get("chapter", 0)) <= current_chapter:
			_index_doc_into(index, d)

func _index_doc_into(target_index: Dictionary, d: Dictionary) -> void:
	var doc_id: String = str(d["id"])
	var text: String = _get_doc_text(d).to_lower()

	for w in _tokenize(text):
		_add_to_index(target_index, w, doc_id)

	for phrase in SPECIAL_PHRASES:
		if text.find(phrase) != -1:
			_add_to_index(target_index, phrase, doc_id)

func _add_to_index(target_index: Dictionary, key: String, doc_id: String) -> void:
	if not target_index.has(key):
		target_index[key] = []
	if doc_id not in target_index[key]:
		target_index[key].append(doc_id)

func _tokenize(text: String) -> Array[String]:
	var t := text.to_lower()
	for ch in [".", ",", "!", "?", ":", ";", "\"", "'", "(", ")", "[", "]", "\n", "\t", "-", "—"]:
		t = t.replace(ch, " ")
	var parts := t.split(" ", false)

	var out: Array[String] = []
	for p in parts:
		var w := p.strip_edges()
		if w.length() >= 2:
			out.append(w)
	return out

# ---- Story progression ----
func advance_chapter() -> void:
	current_chapter += 1
	_rebuild_index()
	results_list.clear()
	#status_label.text = "Chapter %d unlocked." % (current_chapter + 1)

# ---- Snippet + highlight helpers (TOP-LEVEL, not nested!) ----
func _extract_matching_paragraphs(text: String, query: String, context: int) -> String:
	if query.is_empty():
		return text

	var paras := text.split("\n\n", false)
	var q := query.to_lower()

	var hits: Array[String] = []
	for i in range(paras.size()):
		var p := paras[i]
		if p.to_lower().find(q) != -1:
			var start: int = max(0, i - context)
			var end: int = min(paras.size() - 1, i + context)
			for j in range(start, end + 1):
				var candidate := paras[j].strip_edges()
				if candidate.length() > 0 and candidate not in hits:
					hits.append(candidate)

	if hits.size() == 0:
		return paras[0] if paras.size() > 0 else text		
	return "\n\n---\n\n".join(hits)

func _highlight_terms(text: String, terms: Array) -> String:
	var t := text

	terms = terms.duplicate()
	terms = terms.filter(func(x): return str(x).strip_edges() != "")
	terms.sort_custom(func(a, b):
		return str(a).length() > str(b).length()
	)

	for term_any in terms:
		var term := str(term_any)
		if term.is_empty():
			continue
		t = _replace_case_insensitive(t, term, "[color=yellow]" + term + "[/color]")

	return t

func _replace_case_insensitive(haystack: String, needle: String, replacement: String) -> String:
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
