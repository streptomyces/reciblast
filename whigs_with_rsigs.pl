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
use Sco::Global;
use Bio::SeqIO;
use Bio::DB::Fasta;
my $slob = Sco::Global->new();

# {{{ Getopt::Long
use Getopt::Long;
my $outdir;
my $indir;
my $outex; # extension for the output filename when it is derived on infilename.
my $conffile = qq(local.conf);
my $fofn;
my $errfile;
my $runfile;
my $fastafile;
my $outfile;
my $testCnt = 0;
our $verbose;
my $skip = 0;
my $help;
GetOptions (
"outfile:s" => \$outfile,
"dirout:s" => \$outdir,
"indir:s" => \$indir,
"fastafile:s" => \$fastafile,
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

perl code/whigs_with_rsigs.pl \
-fasta work_whig/top_whig.faa \
-outfile whigs_with_rsigs.faa \
-- work_whig/list_rsiG_homologs.csv work_whig/whig_tophits.csv
#;

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


my @organisms;
# {{{
my $infile = shift(@infiles);
my ($noex, $dir, $ext)= fileparse($infile, qr/\.[^.]*/);
my $bn = $noex . $ext;
$skip = 1;
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
  push(@organisms, $ll[0]);
  $lineCnt += 1;
  if($testCnt and $lineCnt >= $testCnt) { last; }
  if($runfile and (not -e $runfile)) { last; }
}
close($ifh);
# }}}

# linelist(@organisms);

my $db = Bio::DB::Fasta->new($fastafile); # may be a dir with several fasta files
my $seqout=Bio::SeqIO->new(-fh => $ofh, -format => 'fasta');


# {{{
my @found;
my %acc;
$infile = shift(@infiles);
($noex, $dir, $ext)= fileparse($infile, qr/\.[^.]*/);
$bn = $noex . $ext;
open($ifh, "<$infile") or croak("Could not open $infile");
$lineCnt = 0;
if($skip) {
  for (1..$skip) { my $discard = readline($ifh); }
}
# local $/ = ""; # For reading multiline records separated by blank lines.
while(my $line = readline($ifh)) {
  chomp($line);
  if($line=~m/^\s*\#/ or $line=~m/^\s*$/) {next;}
  my @ll=split(/\t/, $line);
  my $name = $ll[1];
  my $hname = $ll[4];
  for my $org (@organisms) {
    if($name eq $org) {
      if(exists($acc{$hname})) {
        $acc{$hname} += 1;
      }
      else {
      my $seqobj = $db->get_Seq_by_id($hname);
      $seqout->write_seq($seqobj);
      $acc{$hname} += 1;
      # linelistE($line, $seqid);
      push(@found, $org);
      }
    }
  }
  $lineCnt += 1;
  if($testCnt and $lineCnt >= $testCnt) { last; }
  if($runfile and (not -e $runfile)) { last; }
}
close($ifh);
# }}}

my($comref, $u1, $u2) = $slob->listCompare(\@organisms, \@found);
linelistE(@{$u1});
linelistE(@{$u2});

for my $seqid (keys(%acc)) {
if($acc{$seqid} > 1) {
tablistE($seqid, $acc{$seqid});
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

