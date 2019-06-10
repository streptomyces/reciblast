#!/usr/bin/perl
use 5.14.0;
use utf8;
use Carp;
use open qw< :encoding(UTF-8) >;
use lib qw(/home/sco /home/sco/perllib);
use File::Basename;
use Sco::Common qw(tablist linelist tablistE linelistE tabhash tabhashE tabvals
    tablistV tablistVE linelistV linelistVE tablistH linelistH
    tablistER tablistVER linelistER linelistVER tabhashER tabhashVER csvsplit);
use File::Spec;
use Bio::SeqIO;
use Sco::Blast;
use Bio::DB::Fasta;
use Fcntl qw(:flock);
use Sco::Genbank;
use DBI;
use File::Temp qw(tempfile tempdir);
my $tempdir = qw(/mnt/volatile);
my $template="kelleyXXXXX";
my $scobl = Sco::Blast->new();
my $scogbk = Sco::Genbank->new();


# {{{ Getopt::Long
use Getopt::Long;
my $outdir;
my $skip = 0;
my $conffile = qq(local.conf);
my $errfile = "locking_err"; 
my $progress_file = "locking_progress"; 
my $query = "reci_query.faa";
my $refdb = "blastdb/vnz";
my $outfile = qq(locking_reciblast);
my $organism; # For testing only.
my $sqlfile;
my $expect = 0.1;
my $paraflag;
my $np = 1;
my $keep_temp;
my $testCnt = 0;
our $verbose;
my $help;
GetOptions (
"outfile:s" => \$outfile,
"outdir:s" => \$outdir,
"queryfile:s" => \$query,
"refdb:s" => \$refdb,
"paraflag:i" => \$paraflag,
"jobs|processes:i" => \$np,
"sqlfile:s" => \$sqlfile,
"organism:s" => \$organism,
"conffile:s" => \$conffile,
"expect|evalue:f" => \$expect,
"errfile:s" => \$errfile,
"progressfile:s" => \$progress_file,
"testcnt:i" => \$testCnt,
"keeptemp" => \$keep_temp,
"verbose" => \$verbose,
"help" => \$help
);
# }}}

# {{{ POD Example

=head1 Name

para_reciblast.pl

=head2 Example

Below is how you run it for 12 paraflags.
 
 para-recibl () {
 progfn=whig_progress
 errfn=whig_err
 ofn=rsig-whig.reciblast
 rm $progfn $errfn $ofn
 orglist=confirmed_rsig.list
 njobs=12
 for pf in $(seq 1 $njobs); do
  echo perl code/para_reciblast_locking.pl -paraflag ${pf} -jobs $njobs \
  -progress $progfn -errfile $errfn \
  -queryfile whig.faa -outfile $ofn -test 3 -- $orglist
 done
 }
 para-recibl
 para-recibl | parallel

 rm locking_progress locking_err locking_reciblast
 orglist=all_streps.list
 njobs=12
 para-recibl () {
 for pf in $(seq 1 $njobs); do
  echo perl code/para_reciblast_locking.pl -paraflag ${pf} -jobs $njobs \
  -queryfile reci_query.faa -test 3 -- $orglist
 done
 }
 para-recibl
 para-recibl | parallel




=cut

# }}}

# {{{ POD blurb

=head2 Blurb

gbffgz files are in /mnt/isilon/ncbigenomes/refrepgbk/

Postgresql database is genbank and the table is gbk.

At this time only the reference and representative genomes have
paraflag populated. The script to do this is
mnt/isilon/ncbigenomes/code/para_mark.pl.

If run with the paraflag option $paraflag is appended to all the output
file names (error, out and progress).

=head2 Options

=over 2

=item -queryfile

Defaults to query.faa. Has to be a fasta format proteins file.

=item -refdb

The reference blastp database. All query proteins should belong to this.

=item -outfile

This will have the paraflag appended to its name if the paraflag option
is used.

=item -progressfile

The filehandle for this file is unbuffered to allow monitoring of progress.
Monitoring on STDERR is avoided because error output from BioPerl clutters it
up.

=item -errfile

File of error messages. Deletion of temporary files is also logged
here.

=item -testcnt

Stop after blast searching this many genomes.

=item -expect (or -evalue)

Significance threshold passed on to blastp.

=item -sqlfile

Filename containing the sql query to be run to get the accessions
etc. of the organism to be blast searched.



=back

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
linelistH($errh, "Specified configuration file $conffile not found.");
}
# }}}

open(my $progress, ">>", $progress_file);
$progress->autoflush(1);
open(my $ofh, ">>", $outfile);
select($ofh);

my @infiles = @ARGV;

my $accCnt = 0;
my $doneCnt = 0;
my $noCDScnt = 0;

# {{{ Cycle through all the infiles.
for my $infile (@infiles) {
open(my $ifh, "<$infile") or croak("Could not open $infile");
my $lineCnt = 0;
if($skip) {
for (1..$skip) { my $discard = readline($ifh); }
}
# local $/ = ""; # For reading multiline records separated by blank lines.
while(my $line = readline($ifh)) {
chomp($line);
if($line=~m/^\s*\#/ or $line=~m/^\s*$/) {next;}
$lineCnt += 1;

if ($paraflag and $lineCnt % ($np) != ($paraflag - 1)) { next; }

my ($acc, $org, $lineage) = split(/\t/, $line);
  $accCnt += 1;
# $paraflag  = $hr->{paraflag};
  my $accnover = $acc;
  $accnover =~ s/\.\d+$//;
  my $glob = $conf{gbkdir} . "/" . $accnover . "*";
  my @files = glob($glob);

  unless(@files) { next; }
  my $infile = $files[0];

# linelistE($infile, $glob);

  my($bldbfh, $bldbfn)=tempfile($template, DIR => $tempdir, SUFFIX => '');
  close($bldbfh);
  my($faafh, $faafn)=tempfile($template, DIR => $tempdir, SUFFIX => '.faa');
  close($faafh);

  my %ret = $scogbk->genbank2blastpDB(files => [$infile], name => $bldbfn,
      title => $org, faafn => $faafn);
  unless(%ret) {
    $noCDScnt += 1;
    tempclean($org, $faafn, $bldbfn);
    linelistH($errh, "Blast database not made for $acc");
    next; 
  }
  my $numContigs = $ret{numContigs};

  my $biodb = Bio::DB::Fasta->new($faafn); # may be a dir with several fasta files

my $qio = Bio::SeqIO->new(-file => $query);
while(my $qobj = $qio->next_seq()) {
  my $qname = $qobj->display_id();

    my ($for, $rev) = $scobl->reciblastp(query => $qobj, refdb => $refdb,
        db => $bldbfn, biodb => $biodb, expect => $expect,
        comp_based_stats => "F");

  my $reciprocal = 0;

  my @ll = ($paraflag, $acc, $org, $numContigs);
# paraflag accession organism numcontigs qname qlen hname hlen qcover hcover
# fracid qgaps hgaps numhsps signif revhit reciprocal lineage
  if(ref($for)) {
    push(@ll, $for->{qname}, $for->{qlen}, $for->{hname}, $for->{hlen},
        $for->{qcover}, $for->{hcover},
        $for->{fracid}, $for->{qgaps}, $for->{hgaps},
        $for->{numhsps}, $for->{signif});
    if(ref($rev)) {
      if($for->{qname} eq $rev->{hname}) { $reciprocal = 1; }
      push(@ll, $rev->{hname}, $reciprocal, $lineage);
    }
    else {
      push(@ll, "NRH", $reciprocal, $lineage);
    }
  }
  else {
    push(@ll, $qname);
    for(1..11) {
      push(@ll, "NFH");
    }
    push(@ll, $reciprocal, $lineage);
  }
  flock($ofh, LOCK_EX);
  tablistH($ofh, @ll);
  flock($ofh, LOCK_UN);

}
  tempclean($org, $faafn, $bldbfn);
  $doneCnt += 1;
  flock($progress, LOCK_EX);
  tablistH($progress, $paraflag, $accCnt, $doneCnt, $noCDScnt);
  flock($progress, LOCK_UN);
  if($testCnt and $doneCnt >= $testCnt) { last; }
}

close($ifh);
}
# }}}
exit;

# Multiple END blocks run in reverse order of definition.
END {
close($ofh);
close(STDERR);
close($progress);
close($errh);
}

sub tempclean {
  my $org = shift(@_);
  for my $fn (@_) {
    if($keep_temp) {
      flock($errh, LOCK_EX);
      tablistH($errh, $org, $fn, "kept");
      flock($errh, LOCK_UN);
    }
    else {
      my $unret = unlink(glob("$fn*"));
      flock($errh, LOCK_EX);
      tablistH($errh, $org, $fn, $unret);
      flock($errh, LOCK_UN);
    }
  }
}


__END__

