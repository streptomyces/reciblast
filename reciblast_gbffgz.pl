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
my $runfile;
my $outfile;
my $testCnt = 0;
our $verbose;
my $skip = 0;
my $help;
GetOptions (
"outfile:s" => \$outfile,
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

my $qstr = qq/select accession, organism, lineage from $conf{table}/;
$qstr .= qq/ where lineage ~* 'streptomyces'/;
$qstr .= qq/ limit $ARGV[0]/;

my $stmt=$handle->prepare($qstr);
$stmt->execute();
my $serial = 0;
while(my $hr=$stmt->fetchrow_hashref()) {
my $acc = $hr->{accession};
my $org = $hr->{organism};
my $lineage = $hr->{lineage};
my $accnover = $acc; $accnover =~ s/\.\d+$//;
my $glob = $conf{gbkdir} . "/" . $accnover . "*";
my @files = glob($glob);
$serial += 1;
tablistE($serial, @files);


# sub genbank2blastpDB %([files], name, title, faafn)
# returns %(name, [files], faafn);
# If you supply a faafn then it is your responsibility to unlink it.

my($tmpfh, $tmpfn)=tempfile($template, DIR => $tempdir, SUFFIX => '');
close($tmpfh);
my($tmpfh1, $tmpfn1)=tempfile($template, DIR => $tempdir, SUFFIX => '.faa');
close($tmpfh1);
$scogbk->genbank2blastpDB(files => [@files], name => $tmpfn, title => $org . " " . $acc,
faafn => $tmpfn1);
my $biodb = Bio::DB::Fasta->new($tmpfn1); # may be a dir with several fasta files

my ($blpf, $blpr) = $scobl->reciblastp(query => "bldc.faa",
refdb => "/mnt/isilon/blast_databases/sco/sco",
db => $tmpfn, biodb => $biodb, expect => 1e-2);

if($blpf) {
my $qname = $blpf->{qname};
my $qlen = $blpf->{qlen};
my $hname = $blpf->{hname};
my $hlen = $blpf->{hlen};
my $fracid = $blpf->{fracid};
my $reciprocal = 0;
if($blpr) {
  my $revhit = $blpr->{hname};
  if($revhit eq $qname) { $reciprocal = 1; }
}
tablist($qname, $hname, $reciprocal, $fracid, $org);
}

unlink(glob("$tmpfn*"));
unlink(glob("$tmpfn1*"));

}

__END__

# {{{ Cycle through all the infiles as text files.
for my $infile (@infiles) {
my ($noex, $dir, $ext)= fileparse($infile, qr/\.[^.]*/);
my $bn = $noex . $ext;
# tablistE($infile, $bn, $noex, $ext);

if($idofn) {
my $ofn = File::Spec->catfile($outdir, $noex . "_out" . $outex);
open(OFH, ">", $ofn) or croak("Failed to open $ofn");
select(OFH);
}

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

$lineCnt += 1;
if($testCnt and $lineCnt >= $testCnt) { last; }
if($runfile and (not -e $runfile)) { last; }
}
close($ifh);
close(OFH);
}
# }}}


exit;

# Multiple END blocks run in reverse order of definition.
END {
close($ofh);
close(STDERR);
close(ERRH);
# $handle->disconnect();
}




# my $handle=DBI->connect("DBI:Pg:dbname=$dbname;host=$dbhost", 'sco', 'tsinH4x');
# if connecting to a SQLite database
#my $handle=DBI->connect("DBI:SQLite:dbname=$dbfile", '', '');
#my $handle=DBI->connect"DBI:Pg:dbname=sco;host=jicbio.bbsrc.ac.uk", 'sco', 'tsinH4x');
# If you want to begin a transaction.
# $handle->begin_work();
# AutoCommit remains off till
# $handle->commit()
# or
# $handle->rollback();

my $qstr=" ";
my $stmt=$handle->prepare($qstr);
$stmt->execute();

while(my $hr=$stmt->fetchrow_hashref()) {
my $var=$hr->{field};

my @values=();
foreach my $key (sort keys(%{$hr})) {
push(@values, $hr->{$key});
}
print(++$serial,"\t",join("\t", @values), "\n");

}
$stmt->finish();

### selectrow_array ###
my @row=$handle->selectrow_array($qstr);

# Temporary tables. Start a transaction.
$handle->begin_work();

 my($tmpfh, $table)=tempfile($template, DIR => undef, SUFFIX => undef);
 close($tmpfh); unlink($table);
 linelistE($table);

# Create the temporary table as usual but with the additional clause
# "on commit drop".

 $handle->do(qq/create temporary table $table (file text, locus_tag text,
  bB1 text, bB2 text, bC1 text, bC2 text)
  on commit drop/);

# Now use the table however you wish and when you are done.
 $handle->commit();

$handle->disconnect();






