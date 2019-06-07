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
my $errfile = qq(select_with_cds.err);
my $paraflag;
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
"testcnt:i" => \$testCnt,
"verbose" => \$verbose,
"help" => \$help
);
# }}}

# {{{ POD markdown

=head1 Name

select_with_cds.pl

=head2 Examples

 perl code/select_with_cds.pl -outfile all_refrep_withcds.list \
 -- all_refrep.list


 ofn=all_refrep_withcds.list
 errfn=selectwithcds.err
 ifn=all_refrep.list
 rm $ofn $errfn
 njobs=3
 para-select () {
 for pf in $(seq 1 $njobs); do
  echo perl code/select_with_cds.pl -paraflag ${pf} -jobs $njobs \
  -test 0 -errfile $errfn -outfile $ofn -- $ifn
 done
 }
 para-select

 
 ofn=all_streps_withcds.list
 errfn=selectwithcds.err
 ifn=all_streps.list
 rm $ofn $errfn
 njobs=9
 para-select () {
 for pf in $(seq 1 $njobs); do
  echo perl code/select_with_cds.pl -paraflag ${pf} -jobs $njobs \
  -test 0 -errfile $errfn -outfile $ofn -- $ifn
 done
 }
 para-select

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

my $lineCnt = 0;
open(IN, "<", $infiles[0]);
while(<IN>) {
  chomp;
  $lineCnt += 1;
  my @ll = split(/\t/, $_);
  my ($acc, $organism, $lineage) = @ll;
  if ($paraflag and ($lineCnt % $np) != ($paraflag - 1)) { next; }
  my @globfn = glob("refrepgbk/" . $acc . "*");
  unless(@globfn) {
    lock_tablist($errh, $acc); 
  }
  if(scalar(@globfn) > 1) {
    lock_tablist($errh, @globfn);
  }
  my $infile = $globfn[0];
  my($gbfh, $gbfn)=tempfile($template, DIR => $tempdir, SUFFIX => '.gbff');
  unless(gunzip $infile => $gbfh, AutoClose => 1) {
    close($gbfh); unlink($gbfn);
    die "gunzip failed: $GunzipError\n";
  }
  open(my $ifh, "<$gbfn") or croak("Could not open $gbfn");
  my $lineCnt = 0;
  my $cdsflag = 0;
  while(my $line = readline($ifh)) {
    chomp($line);
    if($line =~ m/\s{2,}CDS\s{2,}/) {
      lock_tablist($ofh, @ll);
      $cdsflag = 1;
      last;
    }
    $lineCnt += 1;
  }
  unless($cdsflag) {
    lock_tablist($errh, $lineCnt, $acc, $organism, "has no CDS");
  }
  close($ifh);
  unlink($gbfn);
  if($testCnt and $lineCnt >= $testCnt) { last; }
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


sub lock_tablist {
  my $ofh = shift(@_);
  flock($ofh, LOCK_EX);
  tablistH($ofh, @_);
  flock($ofh, LOCK_UN);
}


__END__

