#!/usr/bin/env perl
# Parser behind hooks/lead-guard.sh: takes out of a Bash call what a lead may do.
#
#   lead-allow.pl <cwd>
#     masked call (lib/shell-mask.sh) on stdin. On stdout, split by \x1f, the call
#     and the same with quotes blanked and newlines as `;`, both without
#     - segments it has proven: writes inside the memo and temp dirs, `git add`
#       with literal files, `git worktree remove`, `git branch -d`,
#       `gh issue create|edit|comment`;
#     - redirects into those dirs, `-X GET` of `gh api`, and heredoc bodies that
#       are data.
#     The hook judges what is left, so a segment this cannot prove stays denied.
#     Exit 1: the mask cannot be trusted for this call, nothing was taken out.
#
# Paths are judged as text and through symlinks that exist now; a link made
# earlier in the same call (`cp -R`) is not seen. Only $HOME, $TMPDIR and ~
# resolve. `git add` takes existing files only, so a deleted one is denied.
use strict;
use warnings;
use Cwd ();

# Default action: SIGALRM ends perl even inside a regex; the hook then denies.
alarm 1;

my ($cwd) = @ARGV;
my $HOME = $ENV{HOME}   // '';
my $TMP  = $ENV{TMPDIR} // '';
my $q    = qr/"(?:[^"\\]++|\\.)*+"|'[^']*+'|\\./s;
my $cat = qr/\$\x04cat\x07+(?:<<-?\x07?'(\w+)'\x06(?:(?!\x06\g{-1}\x06).)*+\x06\g{-1}\x06|[\w.\/~-]+)\x05/s;

sub unmask { (my $s = shift) =~ tr/\x01-\x08/;&|()\n \t/; $s }
sub give_up { exit 1 }

my $m = do { local $/; <STDIN> } // '';

# --- heredocs, and what makes the mask untrustworthy -------------------------
my $reader = qr/^\s*(?:cat|tee|grep|jq|head|tail|wc|uniq|tr|cut|diff|gh\s+(?:issue|api|pr))(?!\S)/;
my ($depth, $all, $delim, $keep, @lines, @bodies, @data) = (0, '');
for my $line (split /\n/, $m, -1) {
    if (defined $delim) {
        my $body = $line =~ s/^(.*\x06)?(?=\t*\Q$delim\E$)//s ? $1 // '' : $line;
        if ($body eq $line) { $line = '' }
        (my $live = $body) =~ s/\\.//gs;
        push @bodies, $body;
        push @data, !$keep || $keep == 2 && $live !~ /\$\x04|`/;
        $line = "\x0e$#bodies\x0e$line";
        undef $delim;
    }
    my $open;
    (my $bare = $line) =~ s{($q)|(?<!<)<<(?!<)(?:-?[ \t]*(?:'([A-Za-z_]\w*)'|"([A-Za-z_]\w*)"|([A-Za-z_]\w*))(?=[\s;&|<>)]|$))?}{
        if (defined $1) { "\x0f" }
        else {
            my $d = $2 // $3 // $4;
            give_up() if defined $open || !defined $d;
            $open = defined $4 ? 2 : 0;
            $delim = $d;
            "\x10";
        }
    }ge;
    give_up() if $bare =~ /["']|\$\x0f/ || $bare =~ /(?:^|[\s;&|()])#.*[\x0f\x10`]/;
    for ($line =~ /($q)/g) {
        next if !/^"/ || /^"$cat"$/;
        s/\\.//gs;
        my $subst = () = /\$\x04/g;
        give_up() if ($subst || /`/) && /'/ || tr/\x04// != tr/\x05// && $subst
            || tr/`// % 2 || (() = /\$\{/g) > tr/}//;
    }
    if (defined $open) {
        my ($pre, $rest) = split /\x10/, $bare, 2;
        give_up() if $line =~ /\\\x06/ || $pre =~ /\(\(|\$\[|\$\{[^}]*$|\[[^\]]*$|\blet\b/;
        (my $flat = $bare) =~ s/\$\{\w+\}//g;
        my ($head) = $pre =~ /([^;&|]*)$/;
        my ($pipe) = $rest =~ /^((?:[<>]&|&>|[^;&|]|(?<!\|)\|(?!\|))*)/;
        my @cmds = split /\|/, "$head\x10$pipe", -1;
        $keep = $depth || $flat =~ /[(){}`]/ || $rest =~ /\|\s*$/ || grep({ $_ !~ $reader } @cmds) ? 1 : $open;
    }
    $all .= "$bare\n";
    $depth += ($bare =~ tr/(//) - ($bare =~ tr/)//);
    $line =~ s/(?<=[ \t])\\\x06/ /g;
    push @lines, $line;
}
$m = join "\n", @lines;
$all =~ s/\$\{\w+\}//g;
my $piped_group = $all =~ /(?:[)}]|\b(?:done|fi|esac)\b)[^\n]*?(?<!\|)\|(?!\|)|[<>]\(|\beval\b|\(\)|\bfunction\b/;
$m =~ s/\x0e(\d+)\x0e/$data[$1] && !$piped_group ? '' : $&/ge;

# --- paths -------------------------------------------------------------------
# A form that may move the directory or the variables in a way not followed here.
my $complex = $all =~ /`|\(\)|(?:^|[\n;&|(])\s*(?:if|then|else|elif|for|while|until|do|case|select|function|trap|\.|\{|\[\[)(?=\s)/
    || $all =~ /(?:^|[\s;&|()])(?:chdir|pushd|popd|alias|eval|source|command|builtin)(?=[\s;&|()])/
    || $m =~ /(?<![\$\{\w])(?:HOME|TMPDIR|CDPATH)\b/;
my $base  = $complex ? undef : $cwd;
my %value = $complex ? () : (HOME => $HOME, TMPDIR => $TMP);

# The text of a word when that is certain, else nothing.
sub expand {
    my ($w) = @_;
    my $t = '';
    while ($w =~ /\G(?:'([^']*)'|"([^"\\`]*)"|([^'"\\`]+)|.)/gcs) {
        my $p = $1 // $2 // $3 // return;
        if (!defined $1) {
            my $unquoted = defined $3;
            return if $unquoted && $p =~ /[\[\]<>!#^]|(?<!\$)\{|\{(?!\w+\})/;
            $p =~ s{^~(?=/|$)}{$value{HOME} // "\0"}e if $unquoted && $t eq '';
            my $sure = 1;
            $p =~ s{\$(?:\{(\w+)\}|(\w+))}{
                my $v = $value{ $1 // $2 } // '';
                $sure = 0 if $v eq '' || $unquoted && $v =~ /\s/;
                $v;
            }ge;
            return if !$sure || $p =~ /\$/;
        }
        $t .= $p;
    }
    $t = unmask($t);
    return $t =~ m{^[\w .,/+\@:=%*?\x80-\xff-]+$} && $t !~ /\n/ ? $t : ();
}

sub absolute {
    my ($t) = @_;
    my $p = $t =~ m{^/} ? $t : "$base/$t";
    $p =~ s{/(?:\.?/)+}{/}g;
    $p =~ s{(?<=.)/\.?$}{};
    return $p;
}

# The path behind its symlinks; the part that does not exist yet stays as text.
sub real {
    my ($up, $rest) = (shift, '');
    $rest = $1 . $rest while !-l $up && !-e _ && $up =~ s{(/[^/]+)$}{};
    my $real = Cwd::realpath($up eq '' ? '/' : $up);
    return defined $real ? ($real eq '/' ? '' : $real) . $rest : undef;
}

my @roots = map { my ($r, $level) = @$_; $r =~ s{/+$}{}; ([ $r, $level ], [ real($r) // $r, $level ]) }
    grep { $_->[0] =~ m{^/[^/]} } [ '/tmp', 3 ], [ '/private/tmp', 3 ], [ $TMP, 3 ], [ "$HOME/.claude", 2 ];

# Below a temp dir 3, below a memo dir 2, such a dir itself (or one between them) 1, outside 0.
sub level {
    my ($p) = @_;
    my $level = $p =~ m{/(?:\.agents/memory|\.planning)(/.+)?$} ? defined $1 ? 2 : 1 : 0;
    for (@roots) {
        my ($root, $here) = @$_;
        return 1 if $p eq $root || index($root, "$p/") == 0 && grep { index($p, "$_->[0]/") == 0 } @roots;
        $level = $here if index($p, "$root/") == 0 && (!$level || $here < $level);
    }
    return $level;
}

sub inside {
    my ($t) = @_;
    return 0 if !defined $t || $t =~ m{(?:^|/)\.\.(?:/|$)} || length $t > 4096 || $t !~ m{^/} && !defined $base;
    my $p     = absolute($t);
    my $level = level($p) or return 0;
    my $there = level(real($p) // return 0);
    return $there < $level ? $there : $level;
}

# --- segments ----------------------------------------------------------------
my %options = (
    mkdir => qr/^-[pv]+$/, touch => qr/^-[acm]+$/, cp => qr/^-[aRrpfnvPLHi]+$/,
    rm    => qr/^(?:-[rRfvdi]+|--recursive|--force)$/,
);
my $delim_re = qr{([/|\#,\@:])};
my $addr     = qr{(?:\d+|\$|/(?:[^/\\\n]|\\.)*+/)};
my $sed_one  = qr{(?:$addr(?:,$addr)?)?(?:s$delim_re(?:(?!\g{-1})[^\\\n]|\\.)*+\g{-1}(?:(?!\g{-1})[^\\\n]|\\.)*+\g{-1}[gpIi0-9]*|[dp])};
my $sed_script = qr{^\s*$sed_one(?:\s*;\s*$sed_one)*\s*;?\s*$|^$addr[aic]\\\n[^\n]*(?<!\\)\n?$}s;

sub writes_inside {
    my ($cmd, @w) = @_;
    if ($cmd eq 'sed') {
        my ($edits, $script, @files);
        while (defined(my $w = shift @w)) {
            if ($w =~ /^-i(?:\.\w+)?$/) { $edits = 1; shift @w if @w && $w[0] =~ /^(?:''|"")$/; next }
            next if $w =~ /^-[nEr]+$/;
            if ($w eq '-e' || !defined $script && $w !~ /^-/) {
                $w = shift @w // return if $w eq '-e';
                return if $w !~ /^(?:'([^']*)'|"([^"\\\$`]*)"|([^'"\\\$`]+))$/;
                $script = unmask($1 // $2 // $3);
                return if $script !~ $sed_script;
                next;
            }
            return if $w =~ /^-/;
            push @files, $w;
        }
        return $edits && defined $script && @files && !grep { (inside(expand($_)) // 0) < 2 || /[*?]/ } @files;
    }
    my $flags = $options{$cmd} or return;
    my ($needed, @args) = ($cmd eq 'rm' ? 2 : 1);
    while (@w && $w[0] =~ /^-/) {
        my $w = shift @w;
        last if $w eq '--';
        return if $w !~ $flags;
        $needed = 3 if $cmd eq 'rm' && $w =~ /^-[^-]*[rR]|^--r/;
    }
    for (@w) {
        my ($t) = expand($_);
        return if !defined $t || $t =~ /^-/;
        return if $t =~ /[*?]/ && ($cmd !~ /^(?:rm|cp)$/ || $t !~ m{^(?:[^*?]*/)?(?!\.)[^/]+$});
        push @args, $t;
    }
    return if @args < ($cmd eq 'cp' ? 2 : 1);
    if ($cmd eq 'cp') {
        my $target = pop @args;
        return if $target =~ /[*?]/ || !inside($target);
        return !grep { my ($name) = m{([^/]+)/*$}; ($name // '*') !~ /[*?]|^\.\.?$/ && !inside("$target/$name") } @args;
    }
    return !grep { inside($_) < $needed || /[*?]/ && inside(m{^(.*)/} ? $1 : '.') < $needed } @args;
}

sub literal {
    my ($w) = @_;
    return if $w =~ /[\$~`*?\[\]{}\\]/;
    my ($t) = expand($w);
    return defined $t && $t !~ /^[-:]/ ? $t : ();
}

sub git_allowed {
    my @w = @_;
    my $dir = $base;
    if (@w && $w[0] eq '-C') {
        ($dir) = literal($w[1] // '');
        return if !defined $dir || $dir !~ m{^/};
        splice @w, 0, 2;
    }
    my $verb = shift @w // '';
    if ($verb eq 'add') {
        shift @w if @w && $w[0] eq '--';
        return if !@w;
        for (@w) {
            my ($f) = literal($_);
            return if !defined $f || $f =~ m{(?:^|/)\.{0,2}$};
            $f = defined $dir ? "$dir/$f" : return if $f !~ m{^/};
            return if !-f $f;
        }
        return 1;
    }
    my $sub = shift @w // '';
    return if !@w || grep { !defined literal($_) } @w;
    return $verb eq 'worktree' && $sub eq 'remove' && @w == 1 || $verb eq 'branch' && $sub eq '-d';
}

my @t = split /(&&|\|\|?|;|(?<![<>])&(?!>)|[()\n])/, $m =~ s/>\|/>/gr;
my ($cond, $chained, @stack) = (0, 0);
my ($out, $carry) = ('', '');
for (my $i = 0; $i < @t; $i += 2) {
    my ($prev, $seg, $next) = ($i ? $t[ $i - 1 ] : '', $t[$i], $t[ $i + 1 ] // '');
    # a newline after an operator continues it
    $prev = $carry if $prev eq "\n" && $t[ $i - 2 ] =~ /^\s*(?:#.*)?$/;
    $carry = $prev;
    if    ($prev eq '&&') { $cond ||= 1 }
    elsif ($prev eq '(') { push @stack, [ $base, $cond, $chained ]; ($cond, $chained) = (0, 0) }
    elsif ($prev eq ')') { ($base, $cond, $chained) = @{ pop @stack // [ undef, 0, 0 ] } }
    else { undef $base if $chained; $chained = 0; $cond = $prev =~ /^[|&]/ ? 2 : 0 }

    my $subst = $next eq '(';
    for ($seg =~ /($q)/g) {
        next if !/^"/ || /^"$cat"$/ && $seg =~ /^\s*gh\s+issue\s/;
        (my $s = $_) =~ s/\\.//gs;
        $subst = 1 if $s =~ /\$\x04|`|\$\{(?!\w+\})/;
    }
    my ($kept, $bad) = ($seg, $subst || $seg =~ /\x0e/);
    if (!$subst) {
        $kept =~ s{($q)|(?:(?<!\S)\d+|&)?(?<!<)>>?[ \t]*((?:$q|[^\s"'\\<>&])+)}{
            my $whole = $&;
            my ($f) = defined $1 ? () : expand($2);
            defined $f && $f !~ /[*?]/ && inside($f) > 1 ? ' ' : $whole;
        }ge;
    }
    (my $plain = $kept) =~ s{($q)|(?:(?<!\S)\d+|&)?>>?[ \t]*(?:/dev/null|&[\d-]+)(?!\S)|(?<!<)<<-?[ \t]*(?:$q|\w+)|<{1,3}[ \t]*(?:$q|[^\s"'\\<>&])+}{defined $1 ? $1 : ' '}ge;
    (my $bare = $plain) =~ s/$q/\x0f/g;
    $bad ||= $bare =~ /[<>`]|(?:^|\s)#/;
    my ($cmd, @w) = split ' ', $plain;
    ($cmd //= '') =~ s{^(?:/usr)?/bin/}{};

    if ($bare =~ /(?:^|\s)cd(?!\S)|^\s*(?![A-Za-z_]\w*=)\S*[\x0f\$]/) {
        my ($to) = $cmd eq 'cd' && @w == 1 && !$bad ? expand($w[0]) : ();
        if (!defined $to || $to =~ m{[*?]|^-|(?:^|/)\.\.(?:/|$)} || !defined $base && $to !~ m{^/} || $cond == 2 || $next =~ /^(?:\|\|?|&|\()$/ || $complex) {
            undef $base;
        }
        else {
            $base = absolute($to);
            $chained = 1 if $cond || !-d $base;
        }
    }
    elsif (!$subst && !$bad) {
        my $proven =
              $cmd eq 'git' ? git_allowed(@w)
            : $cmd eq 'gh'  ? @w > 1 && $w[0] eq 'issue' && $w[1] =~ /^(?:create|edit|comment)$/ && !grep { tr/"'\\//dr =~ /^--delete/ } @w
            :                 writes_inside($cmd, @w);
        $kept = '' if $proven;
    }
    if ($kept =~ /^\s*gh\s+api\s/) {
        1 while $kept =~ s/(\s)(?:-X[ \t]*=?|--method(?:=|[ \t]+))(["']?)GET\g{-1}(?=\s|$)/$1/;
    }
    $out .= $kept . $next;
}
(my $flat = $out) =~ s/($q)/substr($1, 0, 1) eq '\\' ? '_' : '""'/ge;
$flat =~ tr/\n/;/;
$flat =~ s/\x0e(\d+)\x0e/$bodies[$1] =~ s{'[^'\x06]*'}{''}gr =~ s{"[^"\x06]*"}{""}gr =~ tr{\x06}{;}r/ge;
$flat =~ s/;[;\s]*;/;/g;
$out =~ s/\x0e(\d+)\x0e/$bodies[$1]/g;
$out =~ s/([;\n])[;\s]*(?=\1)//g;
print unmask($out), "\x1f", unmask($flat);
