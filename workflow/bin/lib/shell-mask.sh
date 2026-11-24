# shellcheck shell=bash
# Shared by the hooks that look for a command inside a Bash call.

# Words that may stand before the command; group 3 is the rest.
# shellcheck disable=SC2034
SHELL_PREFIX_RE='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|timeout([[:space:]]+[0-9]+[smh]?)?|time|env|command|nice|exec|sudo|npx|bunx|pnpx|\{|!|then|do)[[:space:]]+(.*)$'

# mask_shell: stdin to stdout. Quoted text and heredoc bodies keep their
# separators and spaces masked as \x01-\x08 for ;&|() newline space tab, so
# a commit message naming `pnpm test` is never a segment of its own. One
# leftmost pass, as in bash: a quote opened first hides a `<<`, a heredoc
# opened first hides the quotes in its body. A backslash escapes the next
# char outside single quotes. Arithmetic `$(( ))` is masked too, so its `<<`
# is a shift, never a heredoc opener. Perl dies (exit 142) after 2s.
# shortcut: bare `(( y = 1<<x ))` and `for ((..<<x..))` still fail open; mask them if one hides a run.
mask_shell() {
  perl -0777 -p \
    -e 'BEGIN { alarm 2 } sub hide { (my $s = shift) =~ tr{;&|()\n \t}{\x01-\x08}; $s }' \
    -e 'my $quoted = qr/"(?:[^"\\]|\\.)*"|\x27[^\x27]*\x27|\\.|\$\((\((?:[^()\$]++|\$(?!\()|(?-1))*+\))\)/s;' \
    -e 's{(?<!<)(<<(-)?[ \t]*(["\x27]?)([A-Za-z_]\w*)\3)([^\n]*\n)(.*?)(?=^(?(2)\t*)\4$|\z)|($quoted)}' \
    -e '{ defined $7 ? hide($7) : do { my ($h, $r, $b) = ($1, $5, $6); $h . ($r =~ s/$quoted/hide($&)/ger) . hide($b) } }gsme'
}
