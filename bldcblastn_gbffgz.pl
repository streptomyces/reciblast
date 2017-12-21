#!/usr/bin/perl
use 5.14.0;
use utf8;
use Carp;
use lib qw(/home/sco /home/sco/perllib);
use File::Basename;
use Sco::Common qw(tablist linelist tablistE linelistE tabhash tabhashE tabvals
    tablistV tablistVE linelistV linelistVE tablistH linelistH
    tablistER tablistVER linelistER linelistVER tabhashER tabhashVER csvsplit);
use File::Spec;
use File::Copy;
use Bio::SeqIO;
use Sco::Genbank;
use Sco::Blast;
use DBI;
use File::Temp qw(tempfile tempdir);
use Bio::DB::Fasta;


# {{{ Getopt::Long
use Getopt::Long;
my $outdir;
my $indir;
my $fofn;
my $outex; # extension for the output filename when it is derived on infilename.
my $conffile = qq(local.conf);
my $errfile;
my $paraflag;
my $outfaa;
my $runfile;
my $outfile;
my $queryfile = qq(bldc.faa);
my $testCnt = 0;
our $verbose;
my $skip = 0;
my $help;
GetOptions (
"outfile:s" => \$outfile,
"queryfile:s" => \$queryfile,
"paraflag:i" => \$paraflag,
"outfaa:s" => \$outfaa,
"outdir:s" => \$outdir,
"indir:s" => \$indir,
"fofn:s" => \$fofn,
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

# {{{ POD Example

=head1 Name

Change me.

=head2 Example

 perl changeme.pl -outfile out.txt -- inputfile1 inputfile2

Note that input files are always specified as non-option arguments.

=cut

# }}}

# {{{ POD blurb

=head2 Blurb

Some kind of description here.

=cut

# }}}

# {{{ POD Options

=head2 Options

=over 2

=item -help

Displays help and exits. All other arguments are ignored.

=item -outfile

If specified, output is written to this file. Otherwise it
is written to STDOUT. This is affected by the -outdir option
described below.

=item -outdir

The directory in which output files will be placed. If this is
specified without -outfile then the output filenames are derived
from input filenames and placed in this directory.

If this directory does not exist then an attempt is made to make
it. Failure to make this directory is a fatal error (croak is called).

If -outdir is specified with -outfile then the outfile is placed
in this directory.

=item -extension

By default this ($outex) is undefined. This is the extension to use
when output filenames are derived from input filenames. 

=back

=cut

# }}}

if($help) {
exec("perldoc $0");
exit;
}

my $tempdir = qw(/home/sco/volatile);
my $template="reciblXXXXX";

my $scogbk = Sco::Genbank->new();
my $scobl = Sco::Blast->new();

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
  linelistE("$keyCnt keys placed in conf.");
}
elsif($conffile ne "local.conf") {
linelistE("Specified configuration file $conffile not found.");
}
# }}}

my $handle=DBI->connect("DBI:Pg:dbname=$conf{dbname};host=$conf{dbhost}",
$conf{dbuser}, $conf{dbpass});

# {{{ open the errfile
if($errfile) {
open(ERRH, ">", $errfile);
print(ERRH "$0", "\n");
close(STDERR);
open(STDERR, ">&ERRH"); 
}
# }}}

# {{{ Outdir and outfile business.
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
    $ofn = File::Spec->catfile($outdir, $outfile . "_" . $paraflag);
  }
  else {
    $ofn = $outfile . "_" . $paraflag;
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

my $qstr = qq/select accession, organism, lineage from $conf{table}/;
$qstr .= qq/ where paraflag = $paraflag/;
# $qstr .= qq/ where lineage !~* 'streptomyces'/;
# $qstr .= qq/ limit $ARGV[0]/;

open(my $ofaa, ">", $outfaa . "_" . $paraflag);
open(my $failh, ">", "Failed_" . $paraflag);

my $seqout=Bio::SeqIO->new(-fh => $ofaa, -format => 'fasta');

my $stmt=$handle->prepare($qstr);
$stmt->execute();
my $serial = 0;
my $accCnt = 0;
while(my $hr=$stmt->fetchrow_hashref()) {
my $acc = $hr->{accession};
my $org = $hr->{organism};
my $lineage = $hr->{lineage};
my $accnover = $acc; $accnover =~ s/\.\d+$//;
my $glob = $conf{gbkdir} . "/" . $accnover . "*";
my @files = glob($glob);

unless(@files) { next; }
$serial += 1;
# tablistE($serial, @files);

my($tmpfh, $tmpfn)=tempfile($template, DIR => $tempdir, SUFFIX => '');
close($tmpfh);
my($tmpfh1, $tmpfn1)=tempfile($template, DIR => $tempdir, SUFFIX => '.faa');
close($tmpfh1);
my(@blpmade) =$scogbk->genbank2blastnDB(files => [@files],
name => $tmpfn, title => $org . " " . $acc, faafn => $tmpfn1);
unless(@blpmade) {
unlink($tmpfn);
unlink($tmpfn1);
tablistH($failh, $acc, $org);
next;
}


my $biodb = Bio::DB::Fasta->new($tmpfn1); # may be a dir with several fasta files

# blastp (hash(query, db, expect, outfh, threads, naln, ndesc, outfmt)).

my $tblnfn = $scobl->tblastn(query => $queryfile, db => $tmpfn, expect => 1e-2);

my @hh = $scobl->hspHashes($tblnfn, "tblastn");

# hspHashes (blastOutputFileName, format) returns(list of hashes(qname, hname, qlen, hlen, signif, bit hdesc, qcover, hcover, hstrand) );

for my $hr (@hh) {
  if(ref($hr)) {
    if($hr->{hlen} <= 100) {
      my $hname = $hr->{hname};
      my $desc = $biodb->header($hr->{hname});
      tablist(
          $acc, $org, $hr->{hname}, $hr->{hlen}, $hr->{fracid}, $hr->{signif},
          $desc, $lineage
          );
      my $hitstr = $biodb->seq($hr->{hname});
      my $outobj = Bio::Seq->new(-seq => $hitstr);
      $outobj->display_id($hr->{hname});
      $desc =~ s/^$hname//;
      $outobj->description($desc . " " . $org);
      $seqout->write_seq($outobj);
    }
  }
}


# copy($blfn, "lastblast");
unlink($blfn);
unlink(glob("$tmpfn*"));
unlink(glob("$tmpfn1*"));

$accCnt += 1;
if($testCnt and $accCnt >= $testCnt) { last; }

unless($accCnt % 100) {
linelistE($accCnt);
}


}

$stmt->finish();

exit;

# Multiple END blocks run in reverse order of definition.
END {
close($ofh);
close($ofaa);
close($failh);
close(STDERR);
close(ERRH);
$handle->disconnect();
}

__END__

