# GPSeqNP

Commands starting with ```$``` are executed in the command line.

The specifics of the machines necessary to run the pipeline will depend mainly on the available time and space resources. We recommend at least 15Gb of RAM and dual core processors.  

If you use this sofware please cite the original manuscript [1].

## Setting up gpseq container

1. Install Docker.
```
$ sudo apt install docker.io 
$ sudo snap install docker
```

2. Create a Docker group and add users to the group.
[!] You need sudo permission to set up the docker.
```
$ sudo groupadd docker
$ sudo usermod -aG docker $USER
```

3. Close and restart a bash terminal. Check if docker can be run without root. 
```
$ docker run hello-world
```

4. Clone or download the latest version of the GPSeqNP pipeline from its Git repository using the following commands: 
```
$ git clone https://github.com/BiCroLab/GPSeqNP.git
$ cd GPSeqNP
```

5. Pull gpseq container from docker hub.
```
$ docker pull wenjingk/gpseq
```
or, you could also build the container using the following commands:
```
$ cd docker
$ bash build.sh
$ cd ..
```
If the docker container (named “gpseq” with size 2.98GB) is successfully created, you can find it in the docker image list. 
```
$ docker images
```

## GPSeq preprocessing (test demonstration)

6. Configure parameters and paths for the pipeline. 
```
$ run_id="test"
$ path_to_GPSeqNP="/home/wenjing/GPSeqNP"
$ localinput="${path_to_GPSeqNP}/test/input/"
$ localoutput="${path_to_GPSeqNP}/test/output/"
$ mkdir -p ${path_to_GPSeqNP}/ref/
$ localref="${path_to_GPSeqNP}/ref/"
$ threads=6
```
[!] the path must be absolute. The GPSeq FASTQ files should be put in the ```$localinput``` folder.

7. Start the gpseq container and mount local directories and files to the container.
```
$ docker run -it --rm -d --name gpseq_container_${run_id} \
  -v $localinput:$localinput \
  -v $localref:$localref \
  -v  $localoutput:$localoutput gpseq:latest
```

8. Check if the gpseq container is running.
```
$ docker ps
```
If the gpseq container shows up, it means that it is running. You can find the identity, name and start time of the container. 

9. Get into the gpseq container (optional).
```
$ docker exec -it gpseq_container_${run_id} bash
```
When you get into the container, the bash command line changed from ```wenjing@bicro-sirius:~/GPSeqNP$``` to ```root@de5157770dbb:/app#```.

10. Exit from the gpseq container (optional). 
```
$ exit
```

11. Copy scripts from GPSeqNP folder to the gpseq container.
```
$ docker cp ${path_to_GPSeqNP}/scripts gpseq_container_${run_id}:/home 
```

12. Proprocess GPSeq FASTQ file in a running gpseq container.
```
$ docker exec gpseq_container_${run_id} bash /home/scripts/GPSeqNP.sh \ ${run_id} KG151 CATCACGC \
  ${path_to_GPSeqNP}/test/input/KG151_sub.fastq.gz \
  Homo_sapiens.GRCh37 75 MboI GATC ${localref} ${localoutput} ${threads}
```
[!] the parameters should be provided in the correct order: run ID, sample ID, sample barcode (8-nt barcode sequence from GPSeq adaptor), full path to input file, reference genome ID, reference genome version, name of restriction enzyme, cut site sequence of the restriction enzyme, full path of reference folder, full path of output folder, number of threads. The run ID and sample ID should be named in alphanumeric series. Other symbols, such as dot(.) or dash (-) will not be recognized by regulation expression for later summary table generation. The reference genome ID “Homo_sapiens.GRCh37” and version “75” are defined based on the reference fasta file “Homo_sapiens.GRCh37.75.dna.primary_assembly.fa.gz” from ensemble public release repository “http://ftp.ensembl.org/pub/release-75/fasta/homo_sapiens/dna/”. Feel free to search the reference fasta file that is available in the repository and change the reference genome ID and version accordingly. The cut site file, containing cut site coordinates, is generated based on the provided reference genome and cut site sequence of the restriction enzyme. 

13. Confirm that the screen output looks highly similar to this:
```
project ID: test
sample ID: KG151
barcode: CATCACGC
input path: /home/wenjing/GPSeqNP/test/input/KG151_sub.fastq.gz
reference genome: Homo_sapiens.GRCh37
digestion enzyme: MboI
cut site: GATC
cutsite file: /home/wenjing/GPSeqNP/ref//Homo_sapiens.GRCh37.75.dna.primary_assembly.MboI_sites.bed.gz
reference path: /home/wenjing/GPSeqNP/ref/
bowtie2 indexed file path: /home/wenjing/GPSeqNP/ref//Homo_sapiens.GRCh37.75.dna.primary_assembly
output path: /home/wenjing/GPSeqNP/test/
threads: 2

Step 1. check genome and cut site reference files
Reference genome files are present, skip the automatically downloading.
Cutsite reference file is present, skip the automatically downloading.

Step 2. fastQC quality control of KG151
soft link input fastq to the expected output folder in required name format.

Step 2 of KG151 is done!

Step 3. identify  UMIs, barcodes and cut sites of KG151
Step 3 of KG151 is done!

Step 4. filter reads based on barcode and cut site of KG151
Step 4 of KG151 is done!

Step 5. align reads of KG151 to reference genome Homo_sapiens.GRCh37
Step 5 of KG151 is done!

Step 6. remove reads with low mapping quality
Step 6 of KG151 is done!

Step 7. correct aligned position
Step 7 of KG151 is done!

Step 8. group UMIs
Step 8 of KG151 is done!

Step 9. assign UMIs to cutsites
Step 9 of KG151 is done!

Step 10. deduplicate
Step 10 of KG151 is done!

Step 11. generate final bed file
Step 11 of KG151 is done!
```

14. Repeat the GPSeq preprocessing (Step 12) for the other GPSeq FASTQ files.
```
$ docker exec gpseq_container_${run_id} bash /home/scripts/GPSeqNP.sh \ ${run_id} KG156 GTCGTATC \
  ${path_to_GPSeqNP}/test/input/KG156_sub.fastq.gz \
  Homo_sapiens.GRCh37 75 MboI GATC ${localref} ${localoutput} ${threads}
```

15. Generate summary table of GPSeq preprocessing. 
```
$ docker exec gpseq_container_${run_id} \
  /home/scripts/mk_summary_table.py ${localoutput}
```

### Output from the GPSeq preprocessing 
When the GPSeq preprocessing pipeline is finished, the output files from the test run will be located in “${path_to_GPSeqNP}/test/output”. Execution of the pipeline will generate the following folders:

* fastq, containing soft linked input FASTQ files with the name reformatted. 
* fastqc, containing FASTQC reports. 
* fastq_hq, containing FASTQ files that UMI, barcode and cut site sequence are extracted and written in the header of each read based on the regular expression match defined in the GPSeqNP.sh script. Read is sorted into “hq.fastq.gz” if no more than 20% of bases of the UMI sequence have sequencing quality lower than 30. Otherwise the read is sorted into “lq.fastq.gz”. 
* fastq_prefix, containing FASTQ files that maximal one mismatches is allowed for the extracted barcode and cut site sequences. 
* mapping, containing BAM files of read alignment. 
* atcs, containing files that UMIs are assigned to the cut sites. 
* dedup, containing files that reads are deduplicated if the UMIs are identical and aligned to the same cut site. 
* bed, containing BED files showing coordinates of cut sites and the number of reads that are aligned and deduplicated by UMI sequences. 

Execution of the pipeline will also generate a summary table file named “summary_table.tsv”, which shows the statistics of read number before and after, filtering, mapping and deduplication. 

## GPSeq score calculation (test demonstration)

16. Prepare a samplesheet configuration file (tab delimited) with four fields: “run ID”, “time of restriction enzyme treatment” (ascending chronological order), “sample ID” and “full path of the bed file generated by GPSeq preprocessing pipeline”. The header of the configuration file must be named as “exid”, “cond”, “libid” and “fpath”. See the example at ```${path_to_GPSeqNP}/test/input/test_GPSeqScore.config```.

17. Download and reformat the file of chromosome size.
```
$ cd $localref
$ wget https://hgdownload.cse.ucsc.edu/goldenpath/hg19/bigZips/hg19.chrom.sizes
$ cat hg19.chrom.sizes | grep -v "_" | grep -v "chrM" | awk -F"\t" '{print$1"\t""0""\t"$2}' > hg19_chrom_size.bed
$ cd ${path_to_GPSeqNP}
```
Feel free to search and use the chromosome size file for another reference genome in “https://hgdownload.cse.ucsc.edu/goldenpath” and edit the path of downloading and file format accordingly. 

18. Prepare masking file for GPSeq score calculation (optional).
Since the repeated regions often give extreme GPSeq scores, which affect the overall scaling of the GPSeq scores, a masking file containing regions with low mappability (< 80% coverage of k50 UMAP data, https://bismap.hoffmanlab.org/), including highly repeated regions (e.g. chromosome centromeres), is recommended for GPSeq score calculation, in which these masking regions will not be used for GPSeq score calculation. You can find an example of how to generate the masking file in ```${path_to_GPSeqNP}/masking_files/script.sh``` and ```${path_to_GPSeqNP}/masking_files/generate_masking_files.ipynb```. 

19. Calculate GPSeq scores using the BED files generated from step 12. 
```
$ config_GPSeqScore="${path_to_GPSeqNP}/test/input/test_GPSeqScore.config"
$ cutsite_file="/home/wenjing/GPSeqNP/ref/Homo_sapiens.GRCh37.75.dna.primary_assembly.MboI_sites.bed.gz"
$ cp ${path_to_GPSeqNP}/masking_files/hg19_low_mappability.UMAP_S50.bins_1e+06_1e+05.tsv ${localinput}
$ masking_file="${localinput}/hg19_low_mappability.UMAP_S50.bins_1e+06_1e+05.tsv"

$ docker exec gpseq_container_${run_id} \
  rm -r ${localoutput}/radical-out-gpseq/

$ docker exec gpseq_container_${run_id} /app/GPSeq-RadiCal-0.0.9/gpseq-radical.R ${config_GPSeqScore} ${localoutput}/radical-out-gpseq/ \
  --chromosome-wide -b 1e6:1e5,5e5:5e4,1e5:1e4,5e4:5e4,25e3:25e3 \
  --normalize-by lib \
  --ref-genome hg19 --chrom-tag 22:X,Y \
  --threads 6 --export-level 1 \
  --site-domain universe --site-bed ${cutsite_file} \
  --mask-bed ${masking_file} \
  -c ${localref}/hg19_chrom_size.bed
```

[!] The path of “cut site file” can be found in the screen output of Step 13. 
Edit the parameters accordingly depending on the interest of window size, normalization method, reference genome and so on. 
