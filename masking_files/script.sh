wget https://hgdownload.cse.ucsc.edu/goldenpath/hg38/bigZips/hg38.chrom.sizes
cat hg38.chrom.sizes | grep -v "chrUn_" | grep -v "_" > hg38.genome
rm hg38.chrom.sizes

wget https://hgdownload.cse.ucsc.edu/goldenpath/hg19/bigZips/hg19.chrom.sizes
cat hg19.chrom.sizes | grep -v "chrUn_" | grep -v "_" > hg19.genome
rm hg19.chrom.sizes

wget https://hgdownload.cse.ucsc.edu/goldenpath/mm10/bigZips/mm10.chrom.sizes
cat mm10.chrom.sizes | grep -v "chrUn_" | grep -v "_" > mm10.genome
rm mm10.chrom.sizes

wget https://hgdownload.cse.ucsc.edu/goldenpath/mm9/bigZips/mm9.chrom.sizes
cat mm9.chrom.sizes | grep -v "chrUn_" | grep -v "_" > mm9.genome
rm mm9.chrom.sizes

bedtools makewindows -i srcwinnum -g hg38.genome -w 1000000 -s 100000 > hg38_bins_1e+06_1e+05.bed
bedtools makewindows -i srcwinnum -g mm10.genome -w 1000000 -s 100000 > mm10_bins_1e+06_1e+05.bed
bedtools makewindows -i srcwinnum -g hg19.genome -w 1000000 -s 100000 > hg19_bins_1e+06_1e+05.bed
bedtools makewindows -i srcwinnum -g mm9.genome -w 1000000 -s 100000 > mm9_bins_1e+06_1e+05.bed
