# Assess quality of the fastq files
Stages:
1. Run fastqc on each fastq file and combine fastqc outputs using multiqc.
2. Run seqkit stats on the fastq files.
3. Run jellyfish and generate a kmer distribution using GenomeScope: http://genomescope.org/genomescope2.0/

## 0. Set up environment
```
PROJDIR=/data/Wilson_Lab/projects/Group_Genome_Assembly/Hemicordylus_capensis/
SCRIPTDIR=${PROJDIR}/scripts/Hemicordylus_capensis_genome
cd $SCRIPTDIR
git pull

mkdir -p ${PROJDIR}/data/quality_control
cd ${PROJDIR}/data/quality_control
mkdir -p fastQC jellyfish seqkit

source myconda
mamba activate hifi_env
```

## 1. FastQC
```
cd ${PROJDIR}/data/quality_control/fastQC

# Run on HiFi files
bash ${SCRIPTDIR}/1a_fastqc.sh ${PROJDIR}/reference_lists/HiFi_Accessions.txt ${PROJDIR}/data/assembly/HiFi_reads ${PROJDIR}/data/quality_control/fastQC hifi_env

# Run on HiC files
bash ${SCRIPTDIR}/1a_fastqc.sh ${PROJDIR}/reference_lists/HiC_Accessions.txt ${PROJDIR}/data/assembly/HiC_reads ${PROJDIR}/data/quality_control/fastQC hifi_env
```

## 2. seqkit stats
```
cd ${PROJDIR}/data/quality_control/seqkit

# Run on HiFi files
bash ${SCRIPTDIR}/1b_seqkit_stats.sh ${PROJDIR}/reference_lists/HiFi_Accessions.txt ${PROJDIR}/data/assembly/HiFi_reads ${PROJDIR}/data/quality_control/seqkit hifi_env

# Run on HiC files
bash ${SCRIPTDIR}/1b_seqkit_stats.sh ${PROJDIR}/reference_lists/HiC_Accessions.txt ${PROJDIR}/data/assembly/HiC_reads ${PROJDIR}/data/quality_control/seqkit hifi_env

```

## 3. jellyfish kmer distribution
```
cd ${PROJDIR}/data/quality_control/jellyfish

bash ${SCRIPTDIR}/1c_jellyfish_genomescope.sh ${PROJDIR}/reference_lists/HiFi_Accessions.txt ${PROJDIR}/data/assembly/HiFi_reads ${PROJDIR}/data/quality_control/jellyfish hifi_env

bash ${SCRIPTDIR}/1c_jellyfish_genomescope.sh ${PROJDIR}/reference_lists/HiC_Accessions.txt ${PROJDIR}/data/assembly/HiC_reads ${PROJDIR}/data/quality_control/jellyfish hifi_env

```