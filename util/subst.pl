#!/usr/bin/env perl
#
# Author: graehl

use strict;
use warnings;
use Getopt::Long;

### script info ##################################################
use File::Basename;
my $scriptdir; # location of script
my $scriptname; # filename of script
my $BLOBS;

sub dumpValue {
    print STDERR join(' ',@_),'\n';
}
BEGIN {
   $scriptdir = &File::Basename::dirname($0);
   ($scriptname) = &File::Basename::fileparse($0);
   push @INC, $scriptdir; # now you can say: require "blah.pl" from the current directory
    $ENV{BLOBS}='/home/hpc-22/dmarcu/nlg/blobs' unless exists $ENV{BLOBS};
   $ENV{BLOBS}="$ENV{HOME}/blobs" unless -d $ENV{BLOBS};
    $BLOBS=$ENV{BLOBS};
    my $libgraehl="$BLOBS/libgraehl/unstable";
    push @INC,$libgraehl if -d $libgraehl;
}

require "libgraehl.pl";

### arguments ####################################################

my $ttable;
my $isregexp;
my $sep="\t";
my $substflags="";
my $parallel;
my $inplace;
my $reverse;
my $wholeword;
my $startsword;
my $endsword;
my $dryrun;
my $firstonly;
my $verbose;
my $substre;
my @substs;
my $abspath=1;
my $sizeMax;
my $rmlines;

my @options=(
"Global or regexp search and replace from a translation file (list of tab-separated source/replacement pairs)",
["abspath!"=>\$abspath,"for inplace, modify pointed to file by absolute path (don't remove symlink)"],
["translations-file=s"=>\$ttable,"list of tab-separated source/replacement pairs"],
["rmlines-file=s"=>\$rmlines,q{list of source res - lines matching them with ^re$ are deleted}],
["reverse!"=>\$reverse,"reverse: replace second column in translations-file with first column"],
["inplace!"=>\$inplace,"in-place edit (note: cannot handle compressed inputs)"],
["eregexp!"=>\$isregexp,"treat source as regexp"],
["substregexp!"=>\$substre,"treat ttable lines as arbitrary s/whatever/to/g lines to be eval"],
["wholeword!"=>\$wholeword,"match only starting ANd ending at word boundary (\\b)"],
["startsword!"=>\$startsword,"match only starting ANd ending at word boundary (\\b)"],
["endsword!"=>\$endsword,"match only ending at word boundary (\\b)"],
["dryrun!"=>\$dryrun,"show substituted lines on STDOUT (no inplace)"],
["firstonly!"=>\$firstonly,"don't process subsequent translations after the first matching per line"],
["verbose!"=>\$verbose,"show each applied substitution"],
["size-max=s"=>\$sizeMax,"skip files smaller than this #bytes"],
#["substflags=s"=>\$substflags,"flags for s///flags, e.g. e for expression"],
#["parallel!"=>\$parallel,"perform at most one replacement per matched section"],
);


my $cmdline=&escaped_cmdline;
my ($usagep,@opts)=getoptions_usage(@options);
#info("COMMAND LINE:");
#info($cmdline);
$startsword = $startsword || $wholeword;
$endsword = $endsword || $wholeword;
show_opts(@opts);

sub refor {
    my $find = $_[0];
    my $q = quotemeta($find);
    debug("quotemeta: $q") if !$isregexp;
    $q = $find if $isregexp;
    $startsword ? ($endsword ? qr/\b$q\b/ : qr/\b$q/) : ($endsword ? qr/$q\b/ : qr/$q/);
}

my @rms;
my $fh=openz($ttable);
while(<$fh>) {
    chomp;
    y/\013//d;
    if (/[\t]/) {
        my $re = &refor($_);
        push @rms, qr/^$re$/;
    }
}

my @rewrites;
my $fh2=openz($ttable);
while(<$fh2>) {
    chomp;
    y/\013//d;
    if ($substre) {
        &debug("substre:",$_);
        push @substs,[eval "sub { $_ }",$_];
    } else {
        my ($find,$replace)=split /$sep/;
        next unless $find;
        unless ($replace) {
            next if $reverse;
            $replace="";
        }
        ($find,$replace)=($replace,$find) if $reverse;
        &debug($find,$replace);
        push @rewrites, [&refor($find), $replace, "s{$find}{$replace}"];
    }
}

my $hadargs=scalar @ARGV;
if (defined($sizeMax)) {
    use File::stat;
    @ARGV=grep{stat($_)->size <= $sizeMax} @ARGV;
}
if ($inplace) {
    my %modify_files;
    file: for my $file (@ARGV) {
        open LOOKFOR,'<',$file or die "$file: ".`ls -l $file`;
        print STDERR " $file" if $verbose;
        while(my $line=<LOOKFOR>) {
            for my $sd (@rewrites) {
                my $source=$sd->[0];
                if ($line =~ /$source/) {
                    $modify_files{$file}=1;
                    &debug("rewrite matched $file: $source");
                    next file;
                }
            }
            for my $source (@rms) {
                if ($line =~ $source) {
                    $modify_files{$file}=1;
                    &debug("remove matched $file: $source");
                    next file;
                }
            }
            for my $sdesc (@substs) {
                my ($s,$desc)=@{$sdesc};
                $_=$line;
                &debug("$_?");
                if ($s->()) {
                    $modify_files{$file}=1;
                    &debug("substition matched $file: $desc");
                    next file;
                }
            }
        }
        close LOOKFOR;
    }
print STDERR "\n" if $verbose;
@ARGV=keys %modify_files;
@ARGV=uniq(map { abspath($_) } @ARGV) if $abspath;
count_info("modifying $_") for (@ARGV);
    &debug(@ARGV);
    $^I = "~" unless $dryrun;
} else {
    &argvz;
}

if ($hadargs && scalar @ARGV == 0) {
    fatal("None of the input files match any patterns in $ttable for in-place edit - no change");
}


sub count_subst {
    my ($desc,$pre,$n)=@_;
    if ($n) {
        my $rec="$ARGV: $desc";
        count_info($rec,$n);
        count_info("BEFORE: $pre",$n);
        info("$rec\n\tBEFORE: $pre") if $verbose;
        print if $dryrun;
    }
}

while(<>) {
    my $pre=$_;
    chomp($pre);
    for my $source (@rms) {
        if ($_ =~ $source) {
            &debug("remove matched line from $ARGV: $source");
            last if $firstonly;
            count_subst("remove $source",$pre,1);
        }
    }
    for my $sdd (@rewrites) {
        my ($source,$dest,$desc)=@{$sdd};
        my $n=s/$source/$dest/g;
#        &debug($desc,$n,$_);
        count_subst($desc,$pre,$n);
        last if $firstonly && $n;
    }
    for my $sd (@substs) {
        my ($s,$desc)=@{$sd};
        my $n=$s->();
        count_subst($desc,$pre,$n);
        last if $firstonly && $n;
    }
    print unless $dryrun;
}
info_summary();
