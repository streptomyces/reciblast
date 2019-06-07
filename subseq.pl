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
use Bio::SeqIO;
use Sco::Genbank;
my $scogbk = Sco::Genbank->new();

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
my $from;
my $to;
my $name;
my $revcom;
our $verbose;
my $skip = 0;
my $help;
GetOptions (
"outfile:s" => \$outfile,
"dirout:s" => \$outdir,
"indir:s" => \$indir,
"fofn:s" => \$fofn,
"extension:s" => \$outex,
"conffile:s" => \$conffile,
"errfile:s" => \$errfile,
"runfile:s" => \$runfile,
"testcnt:i" => \$testCnt,
"revcom" => \$revcom,
"from:i" => \$from,
"to:i" => \$to,
"name:s" => \$name,
"skip:i" => \$skip,
"verbose" => \$verbose,
"help" => \$help
);
# }}}

# {{{ POD

=head1 Name

=head2 Example

perl code/subseq.pl -from 3340109 -to 3346109 -outfile around_vnz_15005.fna \
-name around_vnz_15005 \
-- /home/nouser/souk/data/vnz/vnz_chr.fas

perl code/subseq.pl -from 3332321 -to 3338321 -outfile around_SVEN15_2987.fna \
-name around_SVEN15_2987 \
-- /home/nouser/souk/data/sven15/sven15_chr.fas

blastn -query around_vnz_15005.fna -subject around_SVEN15_2987.fna \
-task blastn -evalue 1e-6 -dust no | less

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
  linelistE("$keyCnt keys placed in conf.");
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


my $infile = shift(@infiles);

my $seqio=Bio::SeqIO->new(-file => $infile);
my $seqout=Bio::SeqIO->new(-fh => $ofh, -format => 'fasta');

while(my $seqobj=$seqio->next_seq()) {
  my $subseq = $scogbk->subseq(seqobj => $seqobj, start => $from, end => $to,
  revcom => $revcom);
  if($name) { $subseq->display_id($name); }
  $seqout->write_seq($subseq);
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

# {{{ For gzipped files.
use IO::Uncompress::Gunzip qw(gunzip $GunzipError) ;
use File::Temp qw(tempfile tempdir);
my $tempdir = qq(/mnt/volatile);
my $template = qq(gunzippedXXXXX);
# Now you can use the gunzip function. AutoClose closes the file being
# written to after all the writing has been done.

my($gbfh, $gbfn)=tempfile($template, DIR => $tempdir, SUFFIX => '.gbff');
unless(gunzip $infile => $gbfh, AutoClose => 1) {
  close($gbfh); unlink($gbfn);
  die "gunzip failed: $GunzipError\n";
}
# }}}

