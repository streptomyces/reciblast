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
use IO::Uncompress::Gunzip qw(gunzip $GunzipError) ;
use File::Temp qw(tempfile tempdir);
use DBI;
use Fcntl qw(:flock);

my $tempdir = qq(/mnt/volatile);
my $template = qq(gunzippedXXXXX);

# {{{ Getopt::Long
use Getopt::Long;
my $outdir;
my $indir;
my $fofn;
my $outex; # extension for the output filename when it is derived on infilename.
my $conffile = qq(local.conf);
my $errfile;
my $paraflag;
my $runfile;
my $outfile;
my $np = 1;
my $testCnt = 0;
our $verbose;
my $help;
GetOptions (
"outfile:s" => \$outfile,
"dirout:s" => \$outdir,
"indir:s" => \$indir,
"fofn:s" => \$fofn,
"paraflag:i" => \$paraflag,
"jobs|processes:i" => \$np,
"extension:s" => \$outex,
"conffile:s" => \$conffile,
"errfile:s" => \$errfile,
"runfile:s" => \$runfile,
"testcnt:i" => \$testCnt,
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
my $errh;
if($errfile) {
open($errh, ">>", $errfile);
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
  open($ofh, ">>", $ofn);
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

my $handle = DBI->connect("DBI:Pg:dbname = $conf{dbname};host = $conf{dbhost}",
$conf{dbuser}, $conf{dbpass});

$conf{table} = "gbk";

my @accessions;
open(IN, "<", $infiles[0]);
while(<IN>) {
  chomp;
  push(@accessions, $_);
}


# {{{ Cycle through all the infiles.
my $fileCnt = 0;
for my $inacc (@accessions) {
  $fileCnt += 1;
  if ($paraflag and ($fileCnt % $np) != ($paraflag - 1)) { next; }
  my @globfn = glob("refrepgbk/" . $inacc . "*");
  unless(@globfn) {
   lock_tablist($errh, $inacc); 
  }
  if(scalar(@globfn) > 1) {
    lock_tablist($errh, @globfn);
  }

  for my $infile (@globfn) {
    my($gbfh, $gbfn)=tempfile($template, DIR => $tempdir, SUFFIX => '.gbff');
    unless(gunzip $infile => $gbfh, AutoClose => 1) {
      close($gbfh); unlink($gbfn);
      die "gunzip failed: $GunzipError\n";
    }
    open(my $ifh, "<$gbfn") or croak("Could not open $gbfn");
    my $lineCnt = 0;
    my ($acc, $organism) = organism($infile);
    my $cdsflag = 0;
    while(my $line = readline($ifh)) {
      chomp($line);
      if($line =~ m/\s{2,}CDS\s{2,}/) {
        lock_tablist($ofh, $fileCnt, $acc, $organism, "has at least one CDS");
        $cdsflag = 1;
        last;
      }
      $lineCnt += 1;
    }
    unless($cdsflag) {
      lock_tablist($ofh, $fileCnt, $acc, $organism, "has no CDS");
    }
    close($ifh);
    unlink($gbfn);
  }
  if($testCnt and $fileCnt >= $testCnt) { last; }
  if($runfile and (not -e $runfile)) { last; }
}
# }}}

exit;

# Multiple END blocks run in reverse order of definition.
END {
close($ofh);
if($errfile) {
close($errh);
}
$handle->disconnect();
}

sub organism {
my $ifn = shift(@_);
my ($noex, $dir, $ext)= fileparse($ifn, qr/\.[^.]*/);
my ($acc) = $noex =~ m/(^.*?\.\d)/;
my $qstr = qq/select organism from $conf{table} where accession = '$acc'/;
my ($organism) = $handle->selectrow_array($qstr);
# print(STDERR "$qstr\n");
return($acc, $organism);
}

sub lock_tablist {
  my $ofh = shift(@_);
  flock($ofh, LOCK_EX);
  tablistH($ofh, @_);
  flock($ofh, LOCK_UN);
}


__END__

