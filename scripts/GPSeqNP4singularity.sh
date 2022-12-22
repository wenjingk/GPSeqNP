#!/bin/bash

# parameters
run_id=$1
libid=$2
barcode=$3
len_barcode=$(echo $barcode | awk '{print length}')
input=$4
ref_genome=$5
species=$(echo $ref_genome | cut -d"." -f 1 | sed 's/./\L&/')
version=$6
cut_enzyme=$7
cut_seq=$8
len_cut_seq=$(echo $cut_seq | awk '{print length}')
ref_dir=$9
bowtie2_ref="${ref_dir}/${ref_genome}.${version}.dna.primary_assembly"
cutsite_path="${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.${cut_enzyme}_sites.bed.gz"
output=${10}
threads=${11}

echo "project ID: "$run_id
echo "sample ID: "$libid
echo "barcode: "$barcode
echo "input path: "$input
echo "reference genome: "$ref_genome
echo "digestion enzyme: "$cut_enzyme
echo "cut site: "$cut_seq
echo "cutsite file: "$cutsite_path
echo "reference path: "$ref_dir
echo "bowtie2 indexed file path: "$bowtie2_ref
echo "output path: "$output
echo "threads: "$threads
echo ""

# Set up references, if the reference files are not available, it will download from http://ftp.ensembl.org/pub/

echo "Step 1. check genome and cut site reference files"

mkdir -p ${ref_dir}

i=0

while [[ $i -lt 1 ]]
do


    if [[ ! -s "${bowtie2_ref}.rev.2.bt2" ]]
    then
	echo "Reference genome fasta or bowtie indexed files are not present, trying to download ..."

	url="http://ftp.ensembl.org/pub/release-${version}/fasta/${species}/dna/${ref_genome}.${version}.dna.primary_assembly.fa.gz"
	if wget -q --method=HEAD ${url};
	then
	    echo "Download from ${url}."
	    wget -O ${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.noChr.fa.gz ${url} &> ${ref_dir}/download.log
	else
	    url2="http://ftp.ensembl.org/pub/release-${version}/fasta/${species}/dna/${ref_genome}.dna.primary_assembly.fa.gz"
	    if wget -q --method=HEAD ${url2};
	    then
		echo "Download from ${url2}."
		wget -O ${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.noChr.fa.gz ${url2} &> ${ref_dir}/download.log
	    else
		echo "The file ${url} or ${url2} does not exist."
		break
	    fi
	fi
	zcat ${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.noChr.fa.gz | sed 's/>/>chr/' | cut -d" " -f 1 | gzip > ${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.fa.gz
	rm ${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.noChr.fa.gz
	/app/bin/bowtie2-build ${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.fa.gz ${ref_dir}/${ref_genome}.${version}.dna.primary_assembly --threads 4 --verbose &> ${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.log
	echo "Downloading and bowtie indexing are done."
    else
	echo "Reference genome files are present, skip the automatically downloading."
    fi

if [[ ! -s "${cutsite_path}" ]]
then
    echo "Cut site reference file is not present, trying to generate ..."
    fbarber find_seq ${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.fa.gz ${cut_seq} --case-insensitive --global-name --output ${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.${cut_enzyme}_sites.bed.gz --log-file ${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.${cut_enzyme}_sites.log &> ${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.${cut_enzyme}_sites.log2
    echo "Cut site reference file is generated."
else
    echo "Cutsite reference file is present, skip the automatically downloading."
fi

echo ""

# check if input file is present. 
if [[ ! -s "$input" ]]
then
    echo "The $input file does not exist."
    break
fi
    

# FASTQ quality control
echo "Step 2. fastQC quality control of ${libid}"

#soft link input fastq to output folder
echo "soft link input fastq to the expected output folder in required name format."
mkdir -p $output/fastq
tailfilename=$(basename $input | sed 's#.*fastq#fastq#g')
ln -s $input $output/fastq/${libid}.${tailfilename}

mkdir -p $output/fastqc
fastqc $input -o $output/fastqc &> $output/fastqc/$libid.log
basefilename=$(basename $input | sed 's#.fastq.*##g')
if [[ ! -s "$output/fastqc/${basefilename}_fastqc.html" ]]
then
    echo "Step 2 doesn't work, please check if the fastq file is truncated or path is provided correctly"
    break
else
    echo "Step 2 of ${libid} is done!"
fi
echo ""

# Extract flags and filter by UMI quality
echo "Step 3. identify  UMIs, barcodes and cut sites of ${libid}"
mkdir -p $output/fastq_hq
fbarber flag extract \
   "$input" $output/fastq_hq/$libid.hq.fastq.gz \
   --filter-qual-output $output/fastq_hq/$libid.lq.fastq.gz \
   --unmatched-output $output/fastq_hq/$libid.unmatched.fastq.gz \
   --log-file $output/fastq_hq/$libid.log \
   --pattern "umi8bc"${len_barcode}"cs"${len_cut_seq} --simple-pattern \
   --flagstats bc cs --filter-qual-flags umi,30,.2 \
   --threads $threads --chunk-size 200000 &> $output/fastq_hq/$libid.err

if [[ ! -s "$output/fastq_hq/$libid.lq.fastq.gz" ]]
then
    echo "Step 3 doesn't work, please check the $output/fastq_hq/$libid.log and $libid.err file."
    break
else
    echo "Step 3 of ${libid} is done!"
    fi
echo ""

# Filter by prefix
echo "Step 4. filter reads based on barcode and cut site of ${libid}"
mkdir -p $output/fastq_prefix
fbarber flag regex \
    $output/fastq_hq/$libid.hq.fastq.gz $output/fastq_prefix/$libid.fastq.gz \
    --unmatched-output $output/fastq_prefix/$libid.unmatched.fastq.gz \
    --log-file $output/fastq_prefix/$libid.log \
    --pattern "bc,^(?<bc>"${barcode}"){s<2}$" "cs,^(?<cs>"${cut_seq}"){s<2}$" \
    --threads $threads --chunk-size 200000 &> $output/fastq_prefix/$libid.err

if [[ ! -s "$output/fastq_prefix/$libid.fastq.gz" ]]
then
    echo "Step 4 doesn't work, please check $output/fastq_prefix/$libid.log and $libid.err file."
    break
else
    echo "Step 4 of ${libid} is done!"
fi
echo ""

# Align
echo "Step 5. align reads of ${libid} to reference genome ${ref_genome}"
mkdir -p $output/mapping
bowtie2 \
    -x "$bowtie2_ref" $output/fastq_prefix/$libid.fastq.gz \
    --very-sensitive -L 20 --score-min L,-0.6,-0.2 --end-to-end --reorder -p $threads \
    -S $output/mapping/$libid.sam &> $output/mapping/$libid.mapping.log

if [[ ! -s "$output/mapping/$libid.sam" ]]
then
    echo "Step 5 doesn't work, please check $output/mapping/$libid.mapping.log file."
    break
else
    echo "Step 5 of ${libid} is done!"
fi
echo ""

# Filter alignment
echo "Step 6. remove reads with low mapping quality"
sambamba view -q -S $output/mapping/$libid.sam -f bam -t $threads > $output/mapping/$libid.bam


sambamba view -q $output/mapping/$libid.bam -f bam \
    -F "mapping_quality<30" -c -t $threads \
    > $output/mapping/$libid.lq_count.txt
sambamba view -q $output/mapping/$libid.bam -f bam \
    -F "ref_name=='chrM'" -c -t $threads \
    > $output/mapping/$libid.chrM.txt
sambamba view -q $output/mapping/$libid.bam -f bam -t $threads \
    -F "mapping_quality>=30 and not secondary_alignment and not unmapped and not chimeric and ref_name!='chrM'" \
    > $output/mapping/$libid.clean.bam
sambamba view -q $output/mapping/$libid.clean.bam -f bam -c -t $threads > $output/mapping/$libid.clean_count.txt

if [[ ! -s "$output/mapping/$libid.clean.bam" ]]
then
    echo "Step 6 doesn't work, please check ? file."
    break
else
    echo "Step 6 of ${libid} is done!"
    rm $output/mapping/$libid.sam
fi
echo ""



# Correct aligned position
echo "Step 7. correct aligned position"
mkdir -p $output/atcs
sambamba view -q -t $threads -h -f bam -F "reverse_strand" \
    $output/mapping/$libid.clean.bam -o $output/atcs/$libid.clean.revs.bam
sambamba view -q -t $threads $output/atcs/$libid.clean.revs.bam | \
    convert2bed --input=sam --keep-header - > $output/atcs/$libid.clean.revs.bed
cut -f 1-4 $output/atcs/$libid.clean.revs.bed | tr "~" $'\t' | cut -f 1,3,7,16 | gzip \
    > $output/atcs/$libid.clean.revs.umi.txt.gz
rm $output/atcs/$libid.clean.revs.bam $output/atcs/$libid.clean.revs.bed

sambamba view -q -t $threads -h -f bam -F "not reverse_strand" \
    $output/mapping/$libid.clean.bam -o $output/atcs/$libid.clean.plus.bam
sambamba view -q -t $threads $output/atcs/$libid.clean.plus.bam | \
    convert2bed --input=sam --keep-header - > $output/atcs/$libid.clean.plus.bed
cut -f 1-4 $output/atcs/$libid.clean.plus.bed | tr "~" $'\t' | cut -f 1,2,7,16 | gzip \
    > $output/atcs/$libid.clean.plus.umi.txt.gz
rm $output/atcs/$libid.clean.plus.bam $output/atcs/$libid.clean.plus.bed

if [[ ! -s "$output/atcs/$libid.clean.revs.umi.txt.gz" ]]
then
    echo "Step 7 doesn't work, please check ? file."
    break

else
    if [[ ! -s "$output/atcs/$libid.clean.plus.umi.txt.gz" ]]
    then
	echo "Step 7 doesn't work, please check ? file."
	break
    else
	echo "Step 7 of ${libid} is done!"
    fi
fi
echo ""


# Group UMIs
echo "Step 8. group UMIs"
./scripts/group_umis.py \
    $output/atcs/$libid.clean.plus.umi.txt.gz \
    $output/atcs/$libid.clean.revs.umi.txt.gz \
    $output/atcs/$libid.clean.umis.txt.gz \
    --compress-level 6 --len ${len_cut_seq} &> $output/atcs/$libid.group_umis.log
rm $output/atcs/$libid.clean.plus.umi.txt.gz $output/atcs/$libid.clean.revs.umi.txt.gz

if [[ ! -s "$output/atcs/$libid.clean.umis.txt.gz" ]]
then
    echo "Step 8 doesn't work, please check $output/atcs/$libid.group_umis.log file."
    break
else
    echo "Step 8 of ${libid} is done!"
fi
echo ""


# Assign UMIs to cutsites
echo "Step 9. assign UMIs to cutsites"
./scripts/umis2cutsite.py \
    $output/atcs/$libid.clean.umis.txt.gz $cutsite_path \
    $output/atcs/$libid.clean.umis_at_cs.txt.gz --compress --threads $threads &> $output/atcs/$libid.umis2cutsite.log
#rm $output/atcs/$libid.clean.umis.txt.gz

if [[ ! -s "$output/atcs/$libid.clean.umis_at_cs.txt.gz" ]]
then
    echo "Step 9 doesn't work, please check $output/atcs/$libid.umis2cutsite.log file and cut site reference file at $cutsite_path."
    break
else
    echo "Step 9 of ${libid} is done!"
fi
echo ""


# Deduplicate
echo "Step 10. deduplicate"
mkdir -p $output/dedup
Rscript ./scripts/umi_dedupl.R \
    $output/atcs/$libid.clean.umis_at_cs.txt.gz \
    $output/dedup/$libid.clean.umis_dedupd.txt.gz \
    -c $threads -r 10000 &> $output/dedup/$libid.umi_dedupl.log

if [[ ! -s "$output/dedup/$libid.clean.umis_dedupd.txt.gz" ]]
then
    echo "Step 10 doesn't work, please check $output/dedup/$libid.umi_dedupl.log file."
    break
else
    echo "Step 10 of ${libid} is done!"
fi
echo ""


# Generate final bed
echo "Step 11. generate final bed file"
mkdir -p $output/bed
zcat $output/dedup/$libid.clean.umis_dedupd.txt.gz | \
    awk 'BEGIN{FS=OFS="\t"}{print $1 FS $2 FS $2 FS "pos_"NR FS $4}' | \
    gzip > $output/bed/$libid.bed.gz

if [[ ! -s "$output/bed/$libid.bed.gz" ]]
then
    echo "Step 11 doesn't work, please check $output/bed folder."
    break
else
    echo "Step 11 of ${libid} is done!"
fi
echo ""

((i=i+1))

done

