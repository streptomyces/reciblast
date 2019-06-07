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
use DBI;

# {{{ Getopt::Long
use Getopt::Long;
my $outdir;
my $indir;
my $outex; # extension for the output filename when it is derived on infilename.
my $conffile = qq(local.conf);
my $errfile;
my $runfile;
my $dbname;
my $dbhost = qq(n108377.nbi.ac.uk);
my $dbuser = qw(sco);
my $dbpass = qw(tsinH4x);
my $outfile;
my $queryfile;
my $query;
my $testCnt = 0;
our $verbose;
my $skip = 0;
my $help;
GetOptions (
"outfile:s" => \$outfile,
"dirout:s" => \$outdir,
"indir:s" => \$indir,
"sqlfile|queryfile:s" => \$queryfile,
"query:s" => \$query,
"dbhost:s" => \$dbhost,
"dbname:s" => \$dbname,
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

unless($dbname) {
$dbname = $conf{dbname};
}
unless($dbhost) {
$dbhost = $conf{dbhost};
}
unless($dbuser) {
$dbuser = $conf{dbuser};
}
unless($dbpass) {
$dbpass = $conf{dbpass};
}


my $handle = DBI->connect("DBI:Pg:dbname = $dbname;host = $dbhost",
$dbuser, $dbpass);

my $qstr;

if($queryfile and -s $queryfile) {
open(my $qfh, "<", $queryfile);
while(<$qfh>) {
# chomp($_);
$qstr .= $_;
}
close($qfh);
}
else {
$qstr = $ARGV[0];
}


my $stmt = $handle->prepare($qstr);
$stmt->execute();

while(my $ar = $stmt->fetchrow_arrayref()) {
tablist(@{$ar});
}
$stmt->finish();
# Multiple END blocks run in reverse order of definition.
END {
close($ofh);
close(STDERR);
close(ERRH);
$handle->disconnect();
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

