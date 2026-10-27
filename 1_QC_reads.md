# Assess quality of the fastq files
Stages:
1. Run fastqc on each fastq file and combine fastqc outputs using multiqc.
2. Run seqkit stats on the fastq files.
3. Run jellyfish and generate a kmer distribution using GenomeScope: http://genomescope.org/genomescope2.0/

## 0. Set up environment
```
PROJDIR=/data/Wilson_Lab/projects/Group_Genome_Assembly/Hemicordylus_capensis/
SCRIPTDIR=${PROJDIR}/scripts/Hemicordylus_capensis_genome
source myconda
mamba activate hifi_env
cd $SCRIPTDIR
git pull

mkdir -p ${PROJDIR}/data/quality_control
cd ${PROJDIR}/data/quality_control
mkdir -p fastQC jellyfish seqkit


```

## 1. FastQC
```
cd ${PROJDIR}/data/quality_control/fastQC

# Run on HiFi files
bash ${SCRIPTDIR}/1a_fastqc.sh ${PROJDIR}/reference_lists/HiFi_Accessions.txt ${PROJDIR}/data/assembly/HiFi_reads ${PROJDIR}/data/quality_control/fastQC hifi_env

# Run on HiC files
bash ${SCRIPTDIR}/1a_fastqc.sh ${PROJDIR}/reference_lists/HiC_Accessions.txt ${PROJDIR}/data/assembly/HiC_reads ${PROJDIR}/data/quality_control/fastQC hifi_env

mkdir HiFi HiC
mv *_1* HiC
mv *_2* HiC
mv *zip HiFi
mv *html HiFi

mkdir -p /data/Wilson_Lab/projects/Group_Genome_Assembly/Hemicordylus_capensis/data/quality_control/multiQC/HiFi /data/Wilson_Lab/projects/Group_Genome_Assembly/Hemicordylus_capensis/data/quality_control/multiQC/HiC

# summarize HiFi
output_dir="/data/Wilson_Lab/projects/Group_Genome_Assembly/Hemicordylus_capensis/data/quality_control/multiQC/HiFi"
fastqc_dir="/data/Wilson_Lab/projects/Group_Genome_Assembly/Hemicordylus_capensis/data/quality_control/fastQC/HiFi"
multiqc \
    --module fastqc \
    --title "Hemicordylus capensis FastQC" \
    --filename fastqc_multiqc_report \
    --outdir "$output_dir" \
    --force \
    "$fastqc_dir"

# summarize HiC
output_dir="/data/Wilson_Lab/projects/Group_Genome_Assembly/Hemicordylus_capensis/data/quality_control/multiQC/HiC"
fastqc_dir="/data/Wilson_Lab/projects/Group_Genome_Assembly/Hemicordylus_capensis/data/quality_control/fastQC/HiC"
multiqc \
    --module fastqc \
    --title "Hemicordylus capensis FastQC" \
    --filename fastqc_multiqc_report \
    --outdir "$output_dir" \
    --force \
    "$fastqc_dir"
```

## 2. seqkit stats
```
cd ${PROJDIR}/data/quality_control/seqkit

# Run on HiFi files
bash ${SCRIPTDIR}/1b_seqkit_stats.sh ${PROJDIR}/reference_lists/HiFi_Accessions.txt ${PROJDIR}/data/assembly/HiFi_reads ${PROJDIR}/data/quality_control/seqkit hifi_env

# Run on HiC files
bash ${SCRIPTDIR}/1b_seqkit_stats.sh ${PROJDIR}/reference_lists/HiC_Accessions.txt ${PROJDIR}/data/assembly/HiC_reads ${PROJDIR}/data/quality_control/seqkit hifi_env

printf 'data_type\t%s\n' "$(head -n 1 SRR22311007_seqkit_stats.tsv)" > seqkit_stats.all.tsv

while read -r file;
do
    tail -n +2 ${file}_seqkit_stats.tsv | sed 's/^/HiFi\t/' >> seqkit_stats.all.tsv
done < ${PROJDIR}/reference_lists/HiFi_Accessions.txt

while read -r file;
do
    tail -n +2 ${file}_seqkit_stats.tsv | sed 's/^/HiC\t/' >> seqkit_stats.all.tsv
done < ${PROJDIR}/reference_lists/HiC_Accessions.txt

```

## 3. jellyfish kmer distribution
```
cd ${PROJDIR}/data/quality_control/jellyfish

bash ${SCRIPTDIR}/1c_jellyfish_genomescope.sh ${PROJDIR}/reference_lists/HiFi_Accessions.txt ${PROJDIR}/data/assembly/HiFi_reads ${PROJDIR}/data/quality_control/jellyfish hifi_env

bash ${SCRIPTDIR}/1c_jellyfish_genomescope.sh ${PROJDIR}/reference_lists/HiFi_Accessions.txt ${PROJDIR}/data/assembly/HiFi_reads_Q20 ${PROJDIR}/data/quality_control/jellyfish hifi_env

bash ${SCRIPTDIR}/1c_jellyfish_genomescope.sh ${PROJDIR}/reference_lists/HiC_Accessions.txt ${PROJDIR}/data/assembly/HiC_reads ${PROJDIR}/data/quality_control/jellyfish hifi_env

```
## 4. Filter long reads
```
mkdir -p ${PROJDIR}/data/assembly/HiFi_reads_Q20
cd ${PROJDIR}/data/assembly/HiFi_reads_Q20
bash ${SCRIPTDIR}/1d_filter_hifi.sh ${PROJDIR}/reference_lists/HiFi_Accessions.txt ${PROJDIR}/data/assembly/HiFi_reads ${PROJDIR}/data/assembly/HiFi_reads_Q20 hifi_env
```
## 5. Redo fastqc
```
mkdir ${PROJDIR}/data/quality_control/fastQC/HiFi_Q20

cd ${PROJDIR}/data/quality_control/fastQC/HiFi_Q20

# Run on HiFi files
bash ${SCRIPTDIR}/1a_fastqc.sh ${PROJDIR}/reference_lists/HiFi_Accessions.txt ${PROJDIR}/data/assembly/HiFi_reads_Q20 ${PROJDIR}/data/quality_control/fastQC/HiFi_Q20 hifi_env


# summarize HiFi_Q20
output_dir="/data/Wilson_Lab/projects/Group_Genome_Assembly/Hemicordylus_capensis/data/quality_control/multiQC/HiFi_Q20"
fastqc_dir="/data/Wilson_Lab/projects/Group_Genome_Assembly/Hemicordylus_capensis/data/quality_control/fastQC/HiFi_Q20"
mkdir -p ${output_dir}
multiqc \
    --module fastqc \
    --title "Hemicordylus capensis FastQC" \
    --filename fastqc_multiqc_report \
    --outdir "$output_dir" \
    --force \
    "$fastqc_dir"
```