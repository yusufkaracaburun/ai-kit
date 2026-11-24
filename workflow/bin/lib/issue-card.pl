#!/usr/bin/env perl
# Parser behind hooks/issue-card.sh: finds each `gh issue create|new` of a call
# and matches its body with the templates.
#
#   issue-card.pl <prefix regex> <dir> <owner/name of origin> <template>...
#     masked call (lib/shell-mask.sh) on stdin. One line per create in this
#     repo, \x1f between kind, template, detail and --parent:
#       ok <template>  (empty when two templates match equally well)
#       other          (the body has a `card: other` line)
#       missing <closest template> <headings>
#       unreadable - <reason>
#     Nothing when no template has an H2.
#
# Known holes, all fail open: a create behind eval, `bash -c`, a script, a
# function, an array, backticks, <( ), xargs or `gh api`, or not at the start
# of its segment; GH_REPO set outside the call; an apostrophe in a comment or
# `<<` in bare (( )) hides what follows. Only the leading `cd` counts: after a
# later one the call's own repo is checked. A body file changed earlier in the
# same call is read as it was before. In a fork, gh creates in the upstream;
# the fork's own templates are checked and after the create nothing is set.
use strict;
use warnings;

# Default action: SIGALRM ends perl even inside a regex; the hook then fails open.
alarm 2;

use constant MAX_BODY => 65536;    # GitHub's limit, in characters
my ($prefix, $dir, $origin, @files) = @ARGV;
my %valued = map { $_ => 1 } qw(-a --assignee --attach --blocked-by --blocking -b --body -F --body-file -l --label
    -m --milestone --parent -p --project --recover -R --repo -T --template -t --title --type);
my %long = ('-b' => '--body', '-F' => '--body-file', '-R' => '--repo', '-w' => '--web', '-h' => '--help');

sub slug { lc($_[0]) =~ m{([^/:]+/[^/]+?)(?:\.git)?/?$} ? $1 : '' }

# Splits a segment into [text, has an expansion].
sub words {
    my ($text) = @_;
    my ($v, $exp, @out);
    while ($text =~ /\G(?:(\s+)|'([^']*)'|"((?:[^"\\]++|\\.)*+)"|\\(.)|([^\s'"\\]+)|(.))/gcs) {
        if (defined $1) { push @out, [ $v, $exp ] if defined $v; ($v, $exp) = (); next }
        my $piece = $2 // $3 // $4 // $5 // $6;
        $exp = 1 if defined $6 || (defined $5 && $piece =~ /[\$`]/) || (defined $3 && $piece =~ /(?<!\\)(?:\\\\)*[\$`]/);
        $piece =~ s/\\(["\\`\$])/$1/g if defined $3;
        $v .= $piece;
    }
    push @out, [ $v, $exp ] if defined $v;
    return @out;
}

# Returns (reason) when unreadable, else ('', text).
sub body_of {
    my ($f) = @_;
    my ($file, $body) = @$f{qw(--body-file --body)};
    return ('there is no --body-file') if !$file && !$body;
    return ('its ' . ($file ? '--body-file path' : '--body') . ' is not literal text') if ($file || $body)->[1];
    my $text = $file ? '' : $body->[0];
    if ($file) {
        return ('it comes from stdin') if $file->[0] eq '-';
        (my $path = $file->[0]) =~ s{^~(?=/)}{$ENV{HOME}};
        $path = "$dir/$path" if $path !~ m{^/};
        return ("$path is missing or not a regular file") if !-f $path;
        return ("$path is larger than GitHub takes") if -s _ > 4 * MAX_BODY;
        open my $fh, '<', $path or return ("$path cannot be read");
        local $/;
        $text = <$fh> // '';
    }
    utf8::decode($text);
    $text =~ tr/\0//d;
    return length $text > MAX_BODY ? ('it is over 65536 characters, more than GitHub takes') : ('', $text);
}

# Returns the H2 texts; sets $$other when a line of its own says `card: other`.
sub headings {
    my ($text, $other) = @_;
    my ($fence, $in_comment, @found) = ('', 0);
    for my $line (split /\r?\n/, $text) {
        if ($fence) {
            $fence = '' if $line =~ /^ {0,3}(`{3,}|~{3,})\s*$/ && index($1, $fence) == 0;
            next;
        }
        if ($in_comment) {
            next if $line !~ s/^.*?-->//;
            $in_comment = 0;
        }
        $$other = 1 if $other && $line =~ /^\s*<!--\s*card:\s*other\s*-->\s*$/;
        if ($line =~ /^ {0,3}(`{3,}(?!.*`)|~{3,})/) { $fence = $1; next }
        $line =~ s/(`[^`]+`)/(my $code = $1) =~ s{<!--}{}g; $code/ge;
        $line =~ s/<!--.*?-->//g;
        $in_comment = 1 if $line =~ s/<!--.*//;
        next if $line !~ /^ {0,3}##[ \t]+(.*?)(?:[ \t]+#+)?[ \t]*$/;
        (my $h = $1) =~ s/(?<=\S)\s*\([^()]*\)$//;
        $h =~ s/\s+/ /g;
        push @found, $h if $h ne '';
    }
    return @found;
}

my @templates;
for my $file (@files) {
    open my $fh, '<:encoding(UTF-8)', $file or next;
    my $text = do { local $/; <$fh> } // '';
    $text =~ s/\A---\r?\n.*?\n---\r?\n//s;
    my @want = headings($text) or next;
    push @templates, [ $file, @want ];
}
exit if !@templates;

sub verdict {
    my ($text) = @_;
    my $other = 0;
    my %has = map { lc($_) => 1 } headings($text, \$other);
    return 'other' if $other;
    my ($best, @ok);
    for (@templates) {
        my ($file, @want) = @$_;
        my @missing = grep { !$has{ lc $_ } } @want;
        my $t = { file => $file, n => scalar @want, missing => \@missing, part => 1 - @missing / @want };
        push @ok, $t if !@missing;
        $best = $t if !$best || $t->{part} > $best->{part} || $t->{part} == $best->{part} && @missing < @{ $best->{missing} };
    }
    return ('missing', $best->{file}, join ', ', map { "## $_" } @{ $best->{missing} }) if !@ok;
    @ok = sort { $b->{n} <=> $a->{n} } @ok;
    return ('ok', @ok > 1 && $ok[0]{n} == $ok[1]{n} ? '' : $ok[0]{file});
}

my $masked = do { local $/; <STDIN> } // '';
$masked =~ s/\\\x06/\x0b/g;             # line continuation: blank outside quotes, newline inside
$masked =~ s/(^|[\s;&|()])#[^\n]*/$1/g;
binmode STDOUT, ':encoding(UTF-8)';
for my $seg (split /[;&|()\n]+/, $masked) {
    $seg =~ s/^\s+//;
    1 while $seg =~ s/^(?:rtk|env(?:\s+-u\s+\S+)+)\s+// || $seg =~ s/$prefix/$3/;
    next if $seg !~ s/^gh\s+issue\s+(?:create|new)(?=\s|$)//;
    $seg =~ tr/\x01-\x08\x0b/;&|()\n \t\n/;
    my (%f, @w);
    @w = words($seg);
    while (my $w = shift @w) {
        my ($name, $value) = $w->[0] =~ /^(--?[A-Za-z][\w-]*)(?:=(.*))?$/s or next;
        $f{ $long{$name} // $name } = !$valued{$name} ? [ $value // 'true' ] : defined $value ? [ $value, $w->[1] ] : shift @w;
    }
    next if $f{'--help'} || $f{'--web'} && $f{'--web'}[0] =~ /^(?:1|t|true)$/i;
    my ($repo, $parent) = @f{qw(--repo --parent)};
    next if $repo && !$repo->[1] && slug($repo->[0]) ne $origin;
    my ($reason, $text) = $repo && $repo->[1] ? ('its --repo is not literal text') : body_of(\%f);
    my ($kind, $file, $detail) = $reason ? ('unreadable', '', $reason) : verdict($text);
    print join("\x1f", $kind, $file // '', $detail // '', $parent && !$parent->[1] ? $parent->[0] : ''), "\n";
}
