# Assess quality of the fastq files
Stages:
1. Run fastqc on each fastq file and combine fastqc outputs using multiqc.
2. Run seqkit stats on the fastq files.
3. Run jellyfish and generate a kmer distribution using GenomeScope: http://genomescope.org/genomescope2.0/

## 0. Set up environment
```
PROJDIR=/data/Wilson_Lab/projects/Group_Genome_Assembly/Hemicordylus_capensis/
SCRIPTDIR=${PROJDIR}/scripts/Hemicordylus_capensis_genome
git pull https://github.com/dannyjackson/Hemicordylus_capensis_genome

mkdir -p ${PROJDIR}/data/quality_control
cd ${PROJDIR}/data/quality_control
mkdir -p fastQC jellyfish

source myconda
mamba activate hifi_env
```

## 1. FastQC
```
cd ${PROJDIR}/data/quality_control/fastQC

${PROJDIR}/reference_lists/HiFi_Accessions.txt
${PROJDIR}/reference_lists/HiC_Accessions.txt

${SCRIPTDIR}/1a_fastqc.sh ${PROJDIR}/reference_lists/HiFi_Accessions.txt ${PROJDIR}/data/quality_control/fastQC



${SCRIPTDIR}/1a_fastqc.sh ${PROJDIR}/reference_lists/HiFi_Accessions.txt ${PROJDIR}/data/assembly/HiFi_reads ${PROJDIR}/data/quality_control/fastQC hifi_env

# or, with hifi_env already activated from section 0:
${SCRIPTDIR}/1a_fastqc.sh ${PROJDIR}/reference_lists/HiC_Accessions.txt ${PROJDIR}/data/assembly/HiC_reads ${PROJDIR}/data/quality_control/fastQC