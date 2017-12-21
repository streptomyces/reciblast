#!/usr/bin/perl
use 5.14.0;
use utf8;
use Carp;
use lib qw(/home/sco /home/sco/perllib);
use File::Basename;
use Sco::Common qw(tablist linelist tablistE linelistE tabhash tabhashE tabvals
                   tablistV tablistVE linelistV linelistVE tablistH linelistH);
use Sco::Genbank;
my $scogbk = Sco::Genbank->new();

# {{{ Usage message

my $usage = <<"USAGE";

 -infile:   Input file to read data from.

 -outfile:  File to which output will be written.
            If this is not specified output is to STDOUT.

 -append:   Boolean. If true, the output file is opened
            for appending.

 -testcnt:  May be used to stop before processing
            all the data in the input file. For testing.

USAGE

# }}}

# {{{ Getopt::Long stuff
use Getopt::Long;
my $infile;
my $errfile;
my $outfile;
my $testCnt = 0;
my $append = 0;
our $verbose;
my $skip = 0;
my $help;
GetOptions (
"infile|filename=s" => \$infile,
"outfile:s" => \$outfile,
"errfile:s" => \$errfile,
"testcnt:i" => \$testCnt,
"skip:i" => \$skip,
"append" => \$append,
"verbose" => \$verbose,
"help" => \$help
);

unless($infile) {
print<<"USAGE";
infile has to be specified.
USAGE
exit;
}
# }}}

my ($noex, $dir, $ext)= fileparse($infile, qr/\.[^.]*/);
my $bn = $noex . $ext;
# tablistE($infile, $bn, $noex, $ext);

if($errfile) {
open(ERRH, ">", $errfile);
print(ERRH "$0", "\n");
close(STDERR);
open(STDERR, ">&ERRH"); 
}

# {{{ Open the out file
my $ofh;
if($outfile) {
  if($append) {
    open($ofh, ">>", $outfile);
  }
  else {
    open($ofh, ">", $outfile);
  }
}
else {
  open($ofh, ">&STDOUT");
}
select($ofh);
# }}}




# sub genbank2blastpDB %([files], name, title) returns %(name, [files]);

# {{{ Open the infile and work
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

my $gbk = $ll[0];
my $organism = $ll[1];
my ($bn) = $gbk =~ m/([^.]*)/;
my $bldbname = "blastdb" . "/". $bn;

tablist($gbk, $organism, $bn, $bldbname);

my %ret = $scogbk->genbank2blastpDB(files => [$gbk], name => $bldbname,
title => $organism);

tablist("======", $ret{name});


$lineCnt += 1;
if($testCnt and $lineCnt >= $testCnt) { last; }
}
close($ifh);
# }}}


exit;

# Multiple END blocks run in reverse order of definition.
END {
close($ofh);
close(STDERR);
close(ERRH);
# $handle->disconnect();
}

