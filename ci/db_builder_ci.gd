# scripts/db_builder_ci.gd
extends SceneTree

const INPUT_DIR  := "res://docs/"
const OUTPUT_RES := "res://data/doc_db.tres"

func _init() -> void:
	var db := DocDB.new()
	var dir := DirAccess.open(INPUT_DIR)
	if dir == null:
		push_error("Cannot open input dir: %s" % INPUT_DIR)
		quit(1)
		return

	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".txt"):
			var doc := _parse_file(INPUT_DIR + filename)
			if doc:
				var key := StringName(filename.get_basename())
				db.docs[key] = doc
				print("Parsed: ", filename)
		filename = dir.get_next()
	dir.list_dir_end()

	var err := ResourceSaver.save(db, OUTPUT_RES)
	if err != OK:
		push_error("Failed to save DocDB: %d" % err)
		quit(1)
		return

	print("Saved DocDB to: ", OUTPUT_RES)
	quit(0)

func _parse_file(path: String) -> Doc:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_warning("Empty or missing file: %s" % path)
		return null
	var doc := Doc.new()
	var pars = text.split("\n\n", false)
	doc.title = _strip_markers(pars[0].strip_edges())
	pars.remove_at(0)
	for par in pars:
		if par == "":
			continue
		var result := _extract_words(par)
		doc.paragraphs.append(result.clean)
		doc.reveals_words.append(result.words)
	return doc

func _strip_markers(line: String) -> String:
	return _extract_words(line).clean

func _extract_words(raw: String) -> Dictionary:
	var clean  := ""
	var words  : Array[String] = []
	var regex  := RegEx.new()
	regex.compile("\\[\\[(.+?)\\]\\]")
	var pos := 0
	for m in regex.search_all(raw):
		clean += raw.substr(pos, m.get_start() - pos)
		var inner = m.get_string(1)
		words.append(inner.strip_edges())
		clean += inner
		pos = m.get_end()
	clean += raw.substr(pos)
	return { "clean": clean.strip_edges(), "words": words }
