#!/usr/bin/perl
use strict;
use Bio::SeqIO;
use Bio::SearchIO;
use Bio::DB::Fasta;
use Carp;

use File::Temp qw(tempfile tempdir);
my $template="selrblXXXXX";
use DBI;

# {{{ Getopt::Long stuff
use Getopt::Long;
my($test_count, $infas, $refblastdb, $dbfile, $where, $accfile);
$test_count = 0;
my $outfile;
GetOptions (
"infas|infile=s" => \$infas,
"refdb|refblastdb=s" => \$refblastdb,
"accessions=s" => \$accfile,
"genbankdb|dbfile=s" => \$dbfile,
"test_count:i" => \$test_count,
"outfile=s" => \$outfile
);

unless($infas and $refblastdb and $dbfile) {
exec("perldoc $0");
exit;
}
# }}}

# {{{ POD

=head1 Name

reciblast_genbanks_selected.pl

=head1 Description


 perl code/reciblast_genbanks_selected.pl -infas query.faa \
 -refdb blastdb/NC_018750 -acc accs -dbfile genbank.qlt -test 3 \
 -out stuff

 -infas is faa file of query sequences
 -refdb  is blast database of the reference. This should have the
        query sequences in it.
 -accs  Accession against which reciprocal blasting is to be carried
        out. The should exist in genbank.qlt.
 -dbfile genbank.qlt. It is looked for in /home/sco/seq/nt/genbank_ftp/
 -test  Do only this many accessions.
 -out   File to write output to.

=cut

# }}}

open(OUT, ">", $outfile) or croak("Could not open $outfile for writing\n");
my $limitstr;
if($test_count) {
$limitstr= " limit $test_count";
}

my $gbdir='/home/sco/seq/nt/genbank_ftp';

unless(-e $dbfile) { $dbfile = $gbdir . "/" . $dbfile }
unless(-e $dbfile) { croak("Could not find $dbfile\n"); }


my $handle=DBI->connect("DBI:SQLite:dbname=$dbfile", '', '');
my $orgtab = 'orgtab';

$handle->do("create temporary table t_accs (accession text)");
my @tempdone;
open(ACC, "<", $accfile);
while(<ACC>) {
my $line=$_;
chomp($line);
if($line=~m/^\s*\#/ or $line=~m/^\s*$/) {next;}
my @llist=split(/\t/, $line);   ### change the split char here.
unless(grep { $_ eq $llist[0] } @tempdone) {
$handle->do("insert into t_accs (accession) values('$llist[0]')");
push(@tempdone, $llist[0]);
}
}
close(ACC);

my $qstr0 = "select count(*) as count from t_accs";
my ($naccs) = $handle->selectrow_array($qstr0);
print(STDERR "$naccs records in table t_accs\n");

my $wherestr="where accession in (select accession from t_accs)";

my $timestamp=`date`;
print(OUT "\# starting at $timestamp");

my $qstr="select accession, organism, definition from $orgtab $wherestr order by taxonomy $limitstr";
### print(STDERR "$qstr\n"); exit;  ### testing only ###
my $stmt=$handle->prepare($qstr);
unless($stmt) {
print(STDERR "\n\n$qstr\n\n");
exit;
}
$stmt->execute();

my $prog_count=0; # progress counter
# {{{ the main while
while(my $hr=$stmt->fetchrow_hashref()) {
my $accession=$hr->{accession};
$accession=~s/\s+.*$//; # rarely there are two accession numbers. we use the first.
my $organism=$hr->{organism};
my $definition=$hr->{definition};
my $porg;
if($definition=~m/plasmid/i) {$porg = 'P';}
else{$porg= 'G';}
$prog_count+=1;
print(STDERR "$prog_count\t$accession\n");
&process_genbank($accession, $organism, $porg);
}
# }}}

$timestamp=`date`;
print(OUT "\# finished at $timestamp");

$stmt->finish();
$handle->disconnect();

close(OUT);
exit;

# {{{ sub process_genbank
sub process_genbank {
  my $accession = shift(@_);
  my $organism = shift(@_);
  my $porg = shift(@_);
  my $gbfile = $gbdir .'/'. $accession . '.gbk';
# sometimes there is no genbank file for an accession.
  unless(-e $gbfile) {print(STDERR "$gbfile does not exist\n"); return();}
  my($fh, $fn)=tempfile($template, DIR => '/home/sco/volatile', SUFFIX => '.faa');
  my $seqio=Bio::SeqIO->new(-file => $gbfile);
  my $seqout=Bio::SeqIO->new(-file => ">$fn", -format => 'fasta');
  my $seqobj=$seqio->next_seq();
  my $count=0;
  foreach my $feature ($seqobj->all_SeqFeatures()) {
    if($feature->primary_tag() eq 'CDS') {
      my $locus_tag;
      if($feature->has_tag('locus_tag')) {
      $locus_tag = join(" ", $feature->get_tag_values('locus_tag'));
      }
      elsif($feature->has_tag('systematic_id')) {
      my @temp = $feature->get_tag_values('systematic_id');
      $locus_tag = $temp[0]; 
      }
      else {$locus_tag = $accession . '_' . $count;}
      my $product;
      if($feature->has_tag('product')) {
        $product=join(" ", $feature->get_tag_values('product'));
      }
      my $feat_aaobj=&feat_trans($feature);
      $feat_aaobj->display_name($locus_tag);
      $feat_aaobj->description($product);
      $seqout->write_seq($feat_aaobj);
      $count+=1;
    }
  }
`/usr/local/bin/makeblastdb -in $fn -dbtype prot`;
#`/usr/local/blast/bin/formatdb -i $fn -p T`;
close($fh);
&reciblast($fn, $accession, $organism, $porg);
print(OUT "\/\/\n");
unlink($fn);
unlink(glob("$fn*"));
return();
}

# }}}


# {{{ sub feat_trans

=head2 sub feat_trans

Given a Bio::SeqFeature::Generic returns a Bio::Seq for the
translation of the spliced seq


=cut

sub feat_trans {
  my $feature=shift(@_);
  my $codon_start=1;
  if($feature->has_tag('codon_start')) {
      ($codon_start) = $feature->get_tag_values('codon_start');
      }
      my $offset=1;
      if($codon_start > 1) { $offset = $codon_start;}
      my $featobj=$feature->spliced_seq(-nosort => '1');
      my $aaobj=$featobj->translate(-offset => $offset);
  return($aaobj);
}
# for translate() see Bio::PrimarySeqI documentation.
# }}}

# {{{ sub reciblast

sub reciblast {
  my $blastdb=shift(@_);
  my $accession = shift(@_);
  my $organism = shift(@_);
  my $porg = shift(@_);
  my $fastafile=$blastdb;
  my $expect='1e-2';
  my $seqio=Bio::SeqIO->new(-file => $infas);
  while(my $seqobj = $seqio->next_seq()) {
    my($fh, $fn)=tempfile($template, DIR => '/home/sco/volatile', SUFFIX => '.faa');
    my $seqout=Bio::SeqIO->new(-fh => $fh, -format => 'fasta');
    my $query_id = $seqobj->display_name(); # for printing if no hit
    my $query_len = $seqobj->length(); # for printing if no hit
    $seqout->write_seq($seqobj);
    close($fh);
    my($fh1, $fn1)=tempfile($template, DIR => '/home/sco/volatile', SUFFIX => '.blo1');
      `/usr/local/bin/blastp -comp_based_stats F -seg no -query $fn -evalue $expect -db $blastdb -out $fn1`;
    my ($qname, $hname, $signif, $qcover, $hcover, $fracid,$qlen, $hlen)=&tophit($fn1);
    if($hname) {
      my $db = Bio::DB::Fasta->new($fastafile);
      my $hitseq=$db->seq($hname);
      my $temp=$db->header($hname);
      my($name, $desc)=split(/\s+/, $temp, 2);
      my $hitobj=Bio::Seq->new(-seq => $hitseq);
      $hitobj->display_name($name);
      $hitobj->description($desc);
      my($fh2, $fn2)=tempfile($template, DIR => '/home/sco/volatile', SUFFIX => '.faa');
      my $seqout2=Bio::SeqIO->new(-fh => $fh2, -format => 'fasta');
#$seqout->write_seq($hitobj);
      $seqout2->write_seq($hitobj);
      close($fh2);
      my($fh3, $fn3)=tempfile($template, DIR => '/home/sco/volatile', SUFFIX => '.blo2');
      close($fh3);
      `/usr/local/bin/blastp -comp_based_stats F -seg no -query $fn2 -evalue $expect -db $refblastdb -out $fn3`;
      my (undef, $sconame, $scosig, $scoqc, $scohc, $scofracid, $scoqlen, $scohlen)=&tophit($fn3);
      unlink($fn, $fn2);
      unlink($fn1, $fn3);
      my $reciBool = "FALSE";
      if($sconame eq $qname) { $reciBool = "TRUE"; }
      printf(OUT "%s\t%s\t%s\t%s\t%d\t%s\t%d\t%s\t%.3f\t%.3f\t%.3f\t%.3E\t%s\n", $accession,$organism,$porg,$qname,$qlen,$hname,$hlen,$sconame,$qcover,$hcover,$fracid, $signif, $reciBool);
#      print("$accession\t$organism\t$qname\t$hname\t$sconame\t$porg\t$scoqc\t$scohc\t$scosig\n");
    }
    else {
      unlink($fn, $fn1);
      printf(OUT "%s\t%s\t%s\t%s\t%s\t%s\t%d\t%.3f\t%.3f\t%.3f\t%.3f\t%.3E\n", $accession,$organism,$porg,$query_id,$query_len,undef,undef,undef,undef, undef, undef,10000);
    }
  }
#last;
}

# }}}


# {{{ sub tophit
sub tophit {
my $filename=shift(@_);
#print(STDERR "$filename\n");
  my $searchio = new Bio::SearchIO( -format => 'blast',
				    -file   => $filename );

  my $result = $searchio->next_result();
  unless($result) { return(); }
  my $qname=$result->query_name();
  my $qlen=$result->query_length();
  my $hit = $result->next_hit();
  if($hit) {
    my $hname=$hit->name();
    my $hlen=$hit->length();
    my $hdesc=$hit->description();
    my $signif=$hit->significance();
    my $laq=$hit->length_aln('query');
    my $frac_id = sprintf("%.3f", $hit->frac_identical());
    my $qcover = $laq/$qlen;
    my $lah=$hit->length_aln('hit');
    my $hcover = $lah/$hlen;
    return($qname, $hname, $signif, $qcover, $hcover, $frac_id, $qlen, $hlen);
  }
  else {
    return();
  }
}
# }}}

__END__

perl reciblast_genbanks.pl \
-refblastdb /home/sco/customers/tracy/NC_000913 \
-infas narg_tatc.faa \
-genbankdb genbank.qlt \
-where "where organism like '%streptomyces coelicolor%'" \
-test 3 > temp

perl reciblast_genbanks.pl \
-refblastdb /home/sco/customers/tracy/NC_000913 \
-infas narg_tatc.faa \
-genbankdb genbank.qlt > narg_tatc_reciblast.out



