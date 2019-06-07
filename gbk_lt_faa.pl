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
use Sco::Genbank;

my $scogbk = Sco::Genbank->new();
my $tempdir = qq(/mnt/volatile);
my $template = qq(gunzippedXXXXX);

# {{{ Getopt::Long
use Getopt::Long;
my $outdir;
my $indir;
my $fofn;
my $outex; # extension for the output filename when it is derived on infilename.
my $conffile = qq(local.conf);
my $errfile = qq(gbkltfaa.err);
my $paraflag;
my $reciprocal;
my $evalue = 0.001;
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
"reciprocal" => \$reciprocal,
"jobs|processes:i" => \$np,
"evalue|signif:f" => \$evalue,
"extension:s" => \$outex,
"conffile:s" => \$conffile,
"errfile:s" => \$errfile,
"testcnt:i" => \$testCnt,
"verbose" => \$verbose,
"help" => \$help
);
# }}}

# {{{ POD

=head1 Name

select_with_cds.pl

=head2 Examples

 perl code/gbk_lt_faa.pl -outfile rsig_all_refrep.faa \
 -test 3 -- rsig_all_refrep.txt


 para-gbkfaa () {
 ofn=rsig_all_refrep_reciprocal.faa
 errfn=gbkltfaa.err
 ifn=rsig_all_refrep.reciblast
 rm $ofn $errfn
 njobs=12
 for pf in $(seq 1 $njobs); do
  echo perl code/gbk_lt_faa.pl -paraflag ${pf} -jobs $njobs \
  -test 0 -errfile $errfn -outfile $ofn -reciprocal -- $ifn
 done
 }
 para-gbkfaa | parallel

 para-gbkfaa1 () {
 ofn=rsig_all_refrep.faa
 errfn=gbkltfaa.err
 ifn=rsig_all_refrep.reciblast
 rm $ofn $errfn
 njobs=12
 for pf in $(seq 1 $njobs); do
  echo perl code/gbk_lt_faa.pl -paraflag ${pf} -jobs $njobs \
  -test 0 -errfile $errfn -outfile $ofn -- $ifn
 done
 }
 para-gbkfaa1 | parallel

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
my $seqout = Bio::SeqIO->new(-fh => $ofh, -format => 'fasta');

my $lineCnt = 0;
my $doneCnt = 0;
open(IN, "<", $infiles[0]);
while(<IN>) {
  $lineCnt += 1;
  chomp;
  if($_ =~ m/NFH\tNFH/) { next; }
  my @ll = split(/\t/, $_);
  if($ll[14] > $evalue) { next; }
  if($reciprocal and $ll[16] != 1) { next; }
  my ($acc, $organism, $lt, $lineage) = @ll[1,2,6,17];
  # tablist($acc, $organism, $lt);
  if ($paraflag and ($lineCnt % $np) != ($paraflag - 1)) { next; }
  my @globfn = glob("refrepgbk/" . $acc . "*");
  unless(@globfn) {
    lock_tablist($errh, $acc); 
  }
  if(scalar(@globfn) > 1) {
    lock_tablist($errh, @globfn);
  }
  my $infile = $globfn[0];
  my $aaobj = $scogbk->genbank_lt_prot(file => $infile, locus_tag => $lt);
  if(ref($aaobj)) {
    my $shortlin = lineage($lineage);
    my $id = $aaobj->display_id();
    my $orgid = $id . "_" . $organism; $orgid =~ s/\s+/_/g;
    $aaobj->display_id($orgid);
    my $desc = $shortlin;
    $aaobj->description($desc);
    lock_writeseq($aaobj);
    $doneCnt += 1;
  }
  else {
    lock_tablist($errh, $acc, $lt, $organism);
  }
#  sub genbank_lt_prot %(file, locus_tag, orgname)
  if($testCnt and $doneCnt >= $testCnt) { last; }
}
close(IN);
# }}}

exit;

# Multiple END blocks run in reverse order of definition.
END {
close($ofh);
if($errfile) {
close($errh);
}
}


sub lock_tablist {
  my $ofh = shift(@_);
  flock($ofh, LOCK_EX);
  tablistH($ofh, @_);
  flock($ofh, LOCK_UN);
}

sub lock_writeseq {
  my $aaobj = shift(@_);
  flock($ofh, LOCK_EX);
  $seqout->write_seq($aaobj);
  flock($ofh, LOCK_UN);
}


sub lineage {
my $long = shift(@_);
my @ll = split(/;\s+/, $long);
my @short;
for my $tax (@ll[3,4,5]) {
unless(grep {$_ eq $tax} @short) {
  push(@short, $tax);
}
}
my $retval = join("; ", @short);
return($retval);
}


__END__

