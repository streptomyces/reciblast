# Kelley

### Thu 21 Dec 2017

     parawhig () {
       for pf in $(seq 1 6); do
     echo perl ../code/blastp_gbffgz.pl -test 0 -outfile whig_refrep.csv \
     -outfaa whig_refrep.faa -queryfile ../whig.faa -paraflag $pf \
     -conffile ../local.conf
     done
     }


     paraamfc () {
       for pf in $(seq 1 6); do
     echo perl ../code/blastp_gbffgz.pl -test 0 -outfile amfc_refrep.csv \
     -outfaa amfc_refrep.faa -queryfile ../amfc.faa -paraflag $pf \
     -conffile ../local.conf
     done
     }

### Fri 22 Dec 2017

     cd work_whig
     cat Failed_? > failed_accessions
     rm Failed_?
     cat whig_refrep.csv_? > whig.csv
     rm whig_refrep.csv_?
     cat whig_refrep.faa_? > whig.faa
     rm whig_refrep.faa_?
     cd ..

     cd work_amfc
     cat Failed_? > failed_accessions
     rm Failed_?
     cat amfc_refrep.csv_? > amfc.csv
     rm amfc_refrep.csv_?
     cat amfc_refrep.faa_? > amfc.faa
     rm amfc_refrep.faa_?
     cd ..

Now

     ls -lhtr /mnt/isilon/customers/kelley/2017_12_20/work_whig

gives

     -rw-rw-r-- 1 chandra molmic  75K Dec 22 12:52 failed_accessions
     -rw-rw-r-- 1 chandra molmic 5.0M Dec 22 13:52 whig.csv
     -rw-rw-r-- 1 chandra molmic 6.5M Dec 22 13:52 whig.faa

and

     ls -lhtr /mnt/isilon/customers/kelley/2017_12_20/work_amfc

gives

     -rw-rw-r-- 1 chandra molmic 75K Dec 22 13:59 failed_accessions
     -rw-rw-r-- 1 chandra molmic 44K Dec 22 13:59 amfc.csv
     -rw-rw-r-- 1 chandra molmic 38K Dec 22 13:59 amfc.faa

     perl code/tophit.pl -outfile work_whig/whig_tophits.csv -- work_whig/whig.csv

     perl code/tophit.pl -outfile work_amfc/amfc_tophits.csv -- work_amfc/amfc.csv

### Tue 02 Jan 2018

     pushd work_whig
     perl ../code/selectFastaEntries.pl -outfile top_whig.faa \
     -fastafile whig.faa -- whig_tophits.csv
     pushd

     pushd work_amfc
     perl ../code/selectFastaEntries.pl -outfile top_amfc.faa \
     -fastafile amfc.faa -- amfc_tophits.csv
     pushd

     zipfile=2018_01_02
     rm ${zipfile}.zip
     for dir in work_whig work_amfc; do
     find $dir -name '*csv' \
     -exec zip -l $zipfile {} \; \
     -o -name '*faa' \
     -exec zip -l $zipfile {} \;
     done
     unzip -l $zipfile
     cp ${zipfile}.zip ~/mnt/wstemp/kelley/

> Hi Kelley,
> 
> The attached zip file has the following files in it.
> 
> work\_whig/whig.faa work\_whig/whig.csv work\_whig/top\_whig.faa
> work\_whig/whig\_tophits.csv work\_amfc/amfc.faa
> work\_amfc/amfc\_tophits.csv work\_amfc/top\_amfc.faa
> work\_amfc/amfc.csv
> 
> \* work\_whig/whig.csv: Results of blastp in tabular format
> 
> \* work\_whig/whig.faa: Protein sequences of hits in blastp
> 
> \* work\_whig/whig\_tophits.csv: Only the best hit from any given
> organism. This is a subset of whig.csv.
> 
> \* work\_whig/top\_whig.faa: Only the best hit from any given organism.
> This is a subset of whig.faa.
> 
> The same description applies to the corresponding amfc files.
> 
> Let me know if you need anything else or you need these files further
> processed in any manner.
> 
> Best wishes for 2018!
> 
> Govind

### Tue 12 Jun 2018

> Hi Govind,
> 
> I have a couple of follow-up questions about these blast searches. Is it
> possible to get a list of the Streptomyces strains that were included in
> the 'all sequenced bacterial genomes' database that you searched for
> amfC and whiG?
> 
> My goal with this is to be able to say something like, 'out of 100
> Streptomyces genomes analysed, all 100 contain an amfC (and/or) whiG
> homolog.'
> 
> I was also wondering, how difficult would it be for the set of
> Streptomyces genomes to determine how far away amfC and whiG are from
> each other? If it's an easy thing to check, it would be nice to be able
> to say in the paper if amfC and whiG are always distant on the genome,
> like they are in S. venezuelae. I have sort of looked for this using the
> JGI server, I just looked and noticed that for all Streptomyces genomes
> on that database (one caveat is that this includes many draft genomes),
> the assigned gene numbers for amfC and whiG were never close to each
> other. But it would be nice to be able to say this more formally, if
> possible.
> 
> No rush on either of these questions, let me know if anything is
> unclear!
> 
> Cheers,
> 
> Kelley

### Tue 12 Jun 2018

Made directories para\_whig and para\_amfc to work separately on whig
and amfc. Then

     pushd para_whig
     threads=12
     parawhig () {
       for pf in $(seq 0 11); do
     echo perl ../code/blastp_gbffgz.pl -test 0 -outfile whig_refrep.csv \
     -outfaa whig_refrep.faa -queryfile ../whig.faa -table gbk \
     -conffile ../local.conf -threads $threads -jobserial $pf 2\> /dev/null
     done
     }
     parawhig | parallel --jobs 12
     pushd

     pushd para_amfc
     threads=12
     paraamfc () {
       for pf in $(seq 0 11); do
     echo perl ../code/blastp_gbffgz.pl -test 0 -outfile amfc_refrep.csv \
     -outfaa amfc_refrep.faa -queryfile ../amfc.faa -table gbk \
     -conffile ../local.conf -threads $threads -jobserial $pf 2\> /dev/null
     done
     }
     paraamfc | parallel --jobs 12
     pushd


     cd para_whig
     cat Failed_* > failed_accessions
     rm Failed_*
     cat whig_refrep.csv_* > whig.csv
     rm whig_refrep.csv_*
     cat whig_refrep.faa_* > whig.faa
     rm whig_refrep.faa_*
     cd ..

     cd para_amfc
     cat Failed_* > failed_accessions
     rm Failed_*
     cat amfc_refrep.csv_* > amfc.csv
     rm amfc_refrep.csv_*
     cat amfc_refrep.faa_* > amfc.faa
     rm amfc_refrep.faa_*
     cd ..

     perl code/tophit.pl -outfile para_whig/whig_tophits.csv -- para_whig/whig.csv

     perl code/tophit.pl -outfile para_amfc/amfc_tophits.csv -- para_amfc/amfc.csv
     
     perl code/whig_amfc_distance.pl -outfile whig_amfc_distance.csv -- \
     para_whig/whig_tophits.csv para_amfc/amfc_tophits.csv
     
     cp whig_amfc_distance.csv ~/mnt/wstemp/kelley/

The above was emailed to Kelley.

### Tue 02 Apr 2019

Kelly's query: From email of 2 Jan 2018, is it possible to determine
the original search set?

local.conf looks like below.

    dbname        genbank
    dbhost        n108377.nbi.ac.uk
    dbuser        sco
    dbpass        tsinH4x
    # table         gbk
    table         rrt
    # gbkdir        /mnt/isilon/ncbigenomes/actinogbk
    gbkdir        /mnt/isilon/ncbigenomes/refrepgbk


Table rrt has 5591 records in it. This is the one from which genomes
to search in must have been decided. So the following was done.

~~~ 
/mnt/isilon/customers/kelley/2017_12_20
perl code/postgres2csv.pl -outfile searchset.csv
cp searchset.csv ~/mnt/wstemp/kelley/
~~~

File *searchset.csv* was converted to an excel file and emailed to
Kelley.

### Thu 25 Apr 2019

Need to compare the Streptomyces species in work_amfc/amfc_tophits.csv
and searchset.csv

~~~ 
perl code/has_cds.pl -- \
$(perl code/file_compare.pl -- searchset.csv work_amfc/amfc_tophits.csv)
~~~



