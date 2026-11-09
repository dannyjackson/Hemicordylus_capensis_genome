# Environment management

Make working directory, clone github, and define scriptdir
```
PROJDIR=/data/Wilson_Lab/projects/Group_Genome_Assembly/Hemicordylus_capensis/
mkdir -p ${PROJDIR}/scripts
cd ${PROJDIR}/scripts
git clone https://github.com/dannyjackson/Hemicordylus_capensis_genome
SCRIPTDIR=${PROJDIR}/scripts/Hemicordylus_capensis_genome
```
Create hifi environment
```
cd ${PROJDIR}
source myconda
mamba create -n hifi_env hifiasm fastqc multiqc gfatools assembly-stats seqkit seqtk tidk samtools bamtools compleasm ncbi-datasets-cli snakemake
mamba install -n hifi_env -c conda-forge -c bioconda kmer-jellyfish genomescope2
```