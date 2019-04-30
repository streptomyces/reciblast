#!/usr/bin/perl
use 5.14.0;
use utf8;
use Carp;
use lib qw(/home/sco /home/sco/mnt/smoke/perllib);
use File::Basename;
use Sco::Common qw(tablist linelist tablistE linelistE tabhash tabhashE tabvals
    tablistV tablistVE linelistV linelistVE tablistH linelistH
    tablistER tablistVER linelistER linelistVER tabhashER tabhashVER csvsplit);
use File::Spec;

# {{{ Getopt::Long
use Getopt::Long;
my $outdir;
my $indir;
my $fofn;
my $outex; # extension for the output filename when it is derived on infilename.
my $conffile = qq(local.conf);
my $family;
my $errfile;
my $runfile;
my $outfile;
my $testCnt = 0;
our $verbose;
my $skip = 0;
my $help;
GetOptions (
"outfile:s" => \$outfile,
"dirout:s" => \$outdir,
"indir:s" => \$indir,
"family:s" => \$family,
"extension:s" => \$outex,
"conffile:s" => \$conffile,
"errfile:s" => \$errfile,
"runfile:s" => \$runfile,
"testcnt:i" => \$testCnt,
"skip:i" => \$skip,
"verbose" => \$verbose,
"help" => \$help
);
# }}}

# {{{ POD markdown

=pod

=begin markdown

# script.pl

## Usage

~~~ {.sh}

perl script.pl -outfile outfn -- infile1 infile2 infile3 ...

~~~

## Description

A description of what this script does.

## Options

* -outfile
* -errfile
* -testcnt: Defaults to 0 which means process all input.
* -conffile: Defaults to local.conf
* -help: Display this documentation and exit.

These are the commonly used one. There are a few more.

=end markdown

=cut

# }}}

if($help) {
exec("perldoc $0");
exit;
}

# {{{ open the errfile
if($errfile) {
open(ERRH, ">", $errfile);
print(ERRH "$0", "\n");
close(STDERR);
open(STDERR, ">&ERRH"); 
}
# }}}

# {{{ Populate %conf if a configuration file 
my %conf;
if(-s $conffile ) {
  open(my $cnfh, "<", $conffile);
  my $keyCnt = 0;
  while(my $line = readline($cnfh)) {
    chomp($line);
    if($line=~m/^\s*\#/ or $line=~m/^\s*$/) {next;}
    my @ll=split(/\s+/, $line, 2);
    $conf{$ll[0]} = $ll[1];
    $keyCnt += 1;
  }
  close($cnfh);
}
elsif($conffile ne "local.conf") {
linelistE("Specified configuration file $conffile not found.");
}
# }}}

# {{{ outdir and outfile business.
my $ofh;
my $idofn = 0;    # Flag for input filename derived output filenames. 
if($outfile) {
  my $ofn;
  if($outdir) {
    unless(-d $outdir) {
      unless(mkdir($outdir)) {
        croak("Failed to make $outdir. Exiting.");
      }
    }
    $ofn = File::Spec->catfile($outdir, $outfile);
  }
  else {
    $ofn = $outfile;
  }
  open($ofh, ">", $ofn);
}
elsif($outdir) {
linelistE("Output filenames will be derived from input");
linelistE("filenames and placed in $outdir");
    unless(-d $outdir) {
      unless(mkdir($outdir)) {
        croak("Failed to make $outdir. Exiting.");
      }
    }
$idofn = 1;
}
else {
  open($ofh, ">&STDOUT");
}
select($ofh);
# }}}

# {{{ populate @infiles
my @infiles;
if(-e $fofn and -s $fofn) {
open(FH, "<", $fofn);
while(my $line = readline(FH)) {
chomp($line);
if($line=~m/^\s*\#/ or $line=~m/^\s*$/) {next;}
my $fn;
if($indir) {
$fn = File::Spec->catfile($indir, $line);
}
else {
$fn = $line;
}

push(@infiles, $fn);
}
close(FH);
}
else {
@infiles = @ARGV;
}

# }}}

my @lol;
my @loh;
my %acc;

# {{{ Cycle through all the infiles.
my $cycle = 0;
for my $infile (@infiles) {
  my ($noex, $dir, $ext)= fileparse($infile, qr/\.[^.]*/);
  my $bn = $noex . $ext;
# tablistE($infile, $bn, $noex, $ext);

  open(my $ifh, "<$infile") or croak("Could not open $infile");
  my $lineCnt = 0;
  if($skip) {
    for (1..$skip) { my $discard = readline($ifh); }
  }
# local $/ = ""; # For reading multiline records separated by blank lines.
  while(my $line = readline($ifh)) {
    chomp($line);
    if($line=~m/^\s*\#/ or $line=~m/^\s*$/) {next;}
    my @ll=split(/\t/, $line);
    if($ll[3] =~ m/$family/) {
    push(@{$lol[$cycle]}, $ll[0]);
    $loh[$cycle]->{$ll[0]} += 1;
    push(@{$acc{$ll[0]}}, $ll[2]);
    }
    elsif($ll[11] =~ m/$family/) {
    push(@{$lol[$cycle]}, $ll[1]);
    $loh[$cycle]->{$ll[1]} += 1;
    }

    $lineCnt += 1;
    if($testCnt and $lineCnt >= $testCnt) { last; }
    if($runfile and (not -e $runfile)) { last; }
  }
  close($ifh);
  $cycle += 1;
}
# }}}

# perl code/file_compare.pl -- searchset.csv work_amfc/amfc_tophits.csv

# $sss search set species
# $ths top hits species
my @done;
for my $sss (@{$lol[0]}) {
  unless(grep {$_ eq $sss} @{$lol[1]}) {
#tablist($sss, @{$acc{$sss}}, $loh[0]->{$sss}, $loh[1]->{$sss});
    for my $accession (@{$acc{$sss}}) {
      unless(grep {$_ eq $accession} @done) {
        linelist($accession);
        push(@done, $accession);
      }
    }
  }
}


exit;

# Multiple END blocks run in reverse order of definition.
END {
close($ofh);
close(STDERR);
close(ERRH);
# $handle->disconnect();
}

__END__

perl code/file_compare.pl -- searchset.csv work_amfc/amfc_tophits.csv



