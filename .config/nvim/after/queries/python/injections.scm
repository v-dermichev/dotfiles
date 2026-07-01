; extends

; PyCharm-style language injection: a `# language=<lang>` comment on the line
; above a string highlights that string as <lang> (the parser must be
; installed). Comments are `extra` nodes in tree-sitter-python so they can't be
; matched as siblings — the language is resolved from the comment text by the
; #inject-lang-from-comment! directive (see lua/config/ts_inject.lua).
((string (string_content) @injection.content)
  (#inject-lang-from-comment! @injection.content))
