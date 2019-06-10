# Kelley

Remember, RsiG and AmfC are the same.


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
perl code/has_cds.pl -outfile kelley_2019_04_29.csv -- \
$(perl code/file_compare.pl -- searchset.csv work_amfc/amfc_tophits.csv)

cp kelley_2019_04_29.csv ~/mnt/wstemp/kelley/
~~~

### Tue 30 Apr 2019

~~~ 

famcmp () {
for family in $(cat families); do
echo $family;
perl code/has_cds.pl -- \
$(perl code/file_compare.pl -fam $family \
-- searchset.csv work_amfc/amfc_tophits.csv)
done
}

famcmp > list_compare_cds.csv
cp list_compare_cds.csv ~/mnt/wstemp/kelley/

~~~

Kelley's email of 30 April 2019.

> Heya Govind!
> 
> 
> So, another thing I am interested in looking at is if all RsiG homologs
> are likely to interact with WhiG. Since the list of WhiG hits in bacteria
> is a bit overwhelming, I thought it might be easier to just pull out these
> sequences from strains with RsiG homologs and take a look at the
> conservation of some key residues.
> 
> 
> So, I have attached a list of strains that have RsiG homologs, and I was
> wondering if it would be easy to pull out WhiG from this set of strains
> from the list of top WhiG hits that you sent me previously (also
> attached)? If it’s not super straightforward no worries, I can have a go
> at it!
> 
> 
> Hopefully this makes sense, let me know if you have any questions!
> 
> Kelley

The script below has column numbers hardcoded in it.

~~~ 
perl code/whigs_with_rsigs.pl \
-fasta work_whig/top_whig.faa \
-outfile whigs_with_rsigs.faa \
-- work_whig/list_rsiG_homologs.csv work_whig/whig_tophits.csv
~~~

### Wed 22 May 2019

Need to find out which of the WhiG top hits are actually reciprocal.

~~~ 
cd /mnt/isilon/customers/kelley/2017_12_20/work_whig
perl ../code/confirm_whig_reciprocal.pl -outfile \
whig_tophits_reciprocal.csv -test 0 -- whig_tophits.csv
cp whig_tophits_reciprocal.csv ~/mnt/wstemp/kelley/
~~~

Need to find out which of the AmfC top hits are actually reciprocal.

~~~ 
perl ../code/confirm_amfc_reciprocal.pl -outfile \
amfc_tophits_reciprocal.csv -test 0 -- amfc_tophits.csv 
cp amfc_tophits_reciprocal.csv ~/mnt/wstemp/kelley/
~~~

### Mon 03 Jun 2019

Below, Mark's email to Kelley.

> Hi Kelley
> 
> 
> 
> Can you come up with 2 numbers please:
> 
> 
> 
>  1. “In a search of ??? reference bacterial genomes available at GenBank
>     (60 of which are Streptomyces genomes), we found a total of 132 rsiG
>     homologs, all exclusively in members of the phylum Actinobacteria
>     (Table S4).” How many reference bacterial genomes in total?
>  2. “While whiH and whiI are present in all 326 complete and annotated
>     Streptomyces genomes available at GenBank
>     (https://www.ncbi.nlm.nih.gov/genbank/), homologs of vnz15005 are
>     present in only ??%.”
> 
> 
> 
> Cheers!
> 
> Mark

~~~ 
grep -i 'streptomyces' searchset.csv > temp
selectColumns.pl -col 2 temp > temp1

ofn=streptomyces_hascds
rm $ofn
jobs=12
para-hascds () {
for job in $(seq 1 $jobs); do
echo perl code/has_cds.pl -outfile $ofn -jobs $jobs -paraflag $job \
-test 0 -- $(cat temp1)
done
}
para-hascds
para-hascds | parallel


table=gbk;
psql -U sco -d genbank -h n108377.nbi.ac.uk <<EOT
\t
select count(*) from $table where organism ~* '^streptomyces';
EOT

sql2csv.pl -outfile temp -dbname genbank -- "select accession from gbk where \
organism ~* '^streptomyces';"
-- organism ~* '^streptomyces' and level ~* 'genome|chromosome|scaffold';"

ofn=strep_all_hascds
errfn=err
rm $ofn $errfn
jobs=12
para-hascds () {
for job in $(seq 1 $jobs); do
echo perl code/has_cds.pl -outfile $ofn -errfile $errfn -jobs $jobs -paraflag $job \
-test 0 -- temp
done
}
para-hascds
para-hascds | parallel

grep 'at least' $ofn | wc -l
grep 'no CDS'   $ofn | wc -l


~~~

### Tue 04 Jun 2019

~~~ 

blastn \
-query /home/nouser/souk/data/sven15/sven15_chr.fas \
-db blastdb/vnz \
-evalue 1e-3 -outfmt 6 -out sven15_vnz.blast -task blastn \
-num_threads 12 -dust no

~~~

While whiH and whiI are present in all 326 complete and annotated
Streptomyces genomes available at GenBank
(https://www.ncbi.nlm.nih.gov/genbank/), homologs of vnz15005 are
present in only ??%.

~~~ 
perl code/sql2csv.pl -outfile all_streps.list -dbname genbank -- \
"select accession, organism, lineage from gbk where organism ~ '^Streptomyces'";

ofn=all_streptomyces.reciblast
rm locking_progress locking_err $ofn
orglist=all_streps.list
njobs=12
para-recibl () {
for pf in $(seq 1 $njobs); do
 echo perl code/para_reciblast_locking.pl -paraflag ${pf} -jobs $njobs \
 -queryfile reci_query.faa -outfile $ofn -test 0 -- $orglist
done
}
para-recibl

vir $ofn


perl code/sql2csv.pl -outfile all_refrep.list -dbname genbank -- \
"select accession, organism, lineage from gbk \
where rscat ~* 'reference|representative'";
~~~

### Wed 05 Jun 2019

vnz_27205 WhiH
vnz_28820 WhiI
vnz_15005
vnz_19430 AmfC, RsiG

~~~ 
blt=all_streptomyces.reciblast
selectRows.pl -expr '$ll[4] eq "vnz_27205"' -- $blt | wc -l
selectRows.pl -expr '$ll[4] eq "vnz_28820"' -- $blt | wc -l
selectRows.pl -expr '$ll[4] eq "vnz_15005"' -- $blt | wc -l
selectRows.pl -expr '$ll[4] eq "vnz_19430"' -- $blt | wc -l
~~~

All of the above give 802.
Below, produce .txt files for Kelley.

~~~ 

echo "paraflag accession organism numcontigs qname qlen hname hlen qcover hcover" > ph
echo "fracid qgaps hgaps numhsps signif revhit reciprocal lineage" >> ph

blt=all_streptomyces.reciblast

ofn=whih_all_strep.txt
perl code/print_header.pl -- ph > $ofn
selectrows.pl -expr '$ll[4] eq "vnz_27205" and $ll[16] == 1' -- $blt >> $ofn
echo >> $ofn
selectrows.pl -expr '$ll[4] eq "vnz_27205" and $ll[16] == 0' -- $blt >> $ofn
cp $ofn ~/mnt/wstemp/kelley/

ofn=whii_all_strep.txt
perl code/print_header.pl -- ph > $ofn
selectRows.pl -expr '$ll[4] eq "vnz_28820" and $ll[16] == 1' -- $blt >> $ofn
echo >> $ofn
selectRows.pl -expr '$ll[4] eq "vnz_28820" and $ll[16] == 0' -- $blt >> $ofn
cp $ofn ~/mnt/wstemp/kelley/

ofn=vnz_15005_all_strep.txt
perl code/print_header.pl -- ph > $ofn
selectRows.pl -expr '$ll[4] eq "vnz_15005" and $ll[16] == 1' -- $blt >> $ofn
echo >> $ofn
selectRows.pl -expr '$ll[4] eq "vnz_15005" and $ll[16] == 0' -- $blt >> $ofn
cp $ofn ~/mnt/wstemp/kelley/

ofn=rsig_all_strep.txt
perl code/print_header.pl -- ph > $ofn
selectRows.pl -expr '$ll[4] eq "vnz_19430" and $ll[16] == 1' -- $blt >> $ofn
echo >> $ofn
selectRows.pl -expr '$ll[4] eq "vnz_19430" and $ll[16] == 0' -- $blt >> $ofn
cp $ofn ~/mnt/wstemp/kelley/

~~~

The 4 .txt files produced above were emailed to Kelley.
Now search for RsiG in all refrep.

Below, WhiG search in all Streptomyces.

~~~ 
ofn=whig_all_streptomyces.reciblast
rm locking_progress locking_err $ofn
orglist=all_streps.list
njobs=12
para-recibl () {
for pf in $(seq 1 $njobs); do
 echo perl code/para_reciblast_locking.pl -paraflag ${pf} -jobs $njobs \
 -queryfile whig.faa -outfile $ofn -test 0 -- $orglist
done
}
para-recibl

blt=whig_all_streptomyces.reciblast
ofn=whig_all_strep.txt
perl code/print_header.pl -- ph > $ofn
selectRows.pl -expr '$ll[4] eq "vnz_26215" and $ll[16] == 1' -- $blt >> $ofn
echo >> $ofn
selectRows.pl -expr '$ll[4] eq "vnz_26215" and $ll[16] == 0' -- $blt >> $ofn
cp $ofn ~/mnt/wstemp/kelley/

~~~

whig_all_strep.txt produced above was emailed to Kelley.


Below, RsiG search in all refrep.

~~~ 

ofn=rsig_all_refrep.reciblast
rm locking_progress locking_err $ofn
orglist=all_refrep_withcds.list
njobs=12
para-recibl () {
for pf in $(seq 1 $njobs); do
 echo perl code/para_reciblast_locking.pl -paraflag ${pf} -jobs $njobs \
 -queryfile rsig.faa -outfile $ofn -test 0 -- $orglist
done
}
para-recibl


ofn=rsig_all_refrep.txt
perl code/print_header.pl -- ph > $ofn
perl code/binning.pl -- rsig_all_refrep.reciblast >> $ofn
cp $ofn ~/mnt/wstemp/kelley/
~~~

Hi Kelley,

I have partitioned the results of RsiG search in all refrep into 4.

1. Reciprocal hits in which the query and the hit are both covered
70 percent or more and fraction identity is 30 percent or more.

2. Reciprocal hits but not fulfilling the other criteria of 1.

3. Hit which are not reciprocal.

4. No hits below evalue of 0.1.

These partitions are separated by blank lines in the attached file
names rsig_all_refrep.txt. Once again, open in excel for viewing.

The number of refrep genomes is 5589 of which 3963 have annotation.

Cheers

Govind


### Fri 07 Jun 2019

~~~ 
selectRows.pl -expr '$ll[6] ne "NFH"' -outfile stuff -- \
rsig_all_refrep.reciblast

selectColumns.pl -outfile stuff1 -col 14,15,16 -- stuff

~~~

Kelley emailed.

> Hi Govind –
> 
> Two more things for the rsiG/whiG conservation stuff (whenever you have
> time!). If I can help in any way with either of these, please let me know!
> 
> 
> 
>  1. Given the new list of RsiG homologs (from rep-ref genomes only), I am
>     interested in looking at an updated list of ‘WhiGs with RsiGs’. I have
>     attached a list of genomes that have (alignment-confirmed) rsiG
>     homologs. Would it be possible for me to get an FAA file of reciprocal
>     best WhiG hits in each of these 134 genomes?
> 
> 
> 
>  2. Since the list of rsiG homologs has changed slightly, I would just
>     like to confirm the number of total annotated genomes from the search
>     set in the following families:
> 
>           Family
>      Acidimicrobiaceae
>       Acidothermaceae
>     Actinopolysporaceae
>      Catenulisporaceae
>      Cellulomonadaceae
>      Conexibacteraceae
>     Cryptosporangiaceae
>     Geodermatophilaceae
>     Ilumatobacteraceae
>       Kineosporiaceae
>       Nocardioidaceae
>      Patulibacteraceae
>     Pseudonocardiaceae
>      Rubrobacteraceae
>      Streptomycetaceae
>     Thermoleophilaceae

The file she attached was saved as alignment_confirmed_rsiG_homologs_list.xlsx
then made in to alignment_confirmed_rsiG_homologs_list.csv.

~~~ 
perl code/add_accession.pl -outfile confirmed_rsig.list \
-- alignment_confirmed_rsiG_homologs_list.csv

para-recibl () {
progfn=whig_progress
errfn=whig_err
ofn=rsig-whig.reciblast
rm $progfn $errfn $ofn
orglist=confirmed_rsig.list
njobs=6
for pf in $(seq 1 $njobs); do
 echo perl code/para_reciblast_locking.pl -paraflag ${pf} -jobs $njobs \
 -progress $progfn -errfile $errfn \
 -queryfile whig.faa -outfile $ofn -test 0 -- $orglist
done
}
para-recibl

para-gbkfaa () {
ofn=confirmed_rsig_whig.faa
errfn=gbkltfaa.err
ifn=rsig-whig.reciblast
rm $ofn $errfn
njobs=3
for pf in $(seq 1 $njobs); do
 echo perl code/gbk_lt_faa.pl -paraflag ${pf} -jobs $njobs \
 -test 0 -errfile $errfn -outfile $ofn -reciprocal -- $ifn
done
}
para-gbkfaa | parallel

famcnt () {
for family in Acidimicrobiaceae Acidothermaceae Actinopolysporaceae \
Catenulisporaceae Cellulomonadaceae Conexibacteraceae Cryptosporangiaceae \
Geodermatophilaceae Ilumatobacteraceae Kineosporiaceae Nocardioidaceae \
Patulibacteraceae Pseudonocardiaceae Rubrobacteraceae Streptomycetaceae \
Thermoleophilaceae; do
echo $family
grep $family all_refrep_withcds.list | wc -l
done
}

famcnt > counts_for_families.txt

~~~

Files counts_for_families.txt and confirmed_rsig_whig.faa were emailed
to Kelley.

