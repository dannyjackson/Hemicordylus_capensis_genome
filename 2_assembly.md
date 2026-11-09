# 2. 

## 0. Set up environment
```
PROJDIR=/data/Wilson_Lab/projects/Group_Genome_Assembly/Hemicordylus_capensis/
SCRIPTDIR=${PROJDIR}/scripts/Hemicordylus_capensis_genome
source myconda
mamba activate hifi_env
cd $SCRIPTDIR && git pull
WORK=${PROJDIR}/analyses/hifiasm
mkdir -p ${WORK}
cd ${WORK}
```

## Run HiFiasm
```
sbatch ${SCRIPTDIR}/2a_hifiasm.sh \
    ${PROJDIR}/reference_lists/HiFi_Accessions.txt ${PROJDIR}/data/assembly/HiFi_reads_Q20 \
    ${PROJDIR}/reference_lists/HiC_Accessions.txt ${PROJDIR}/data/assembly/HiC_reads \
    ${PROJDIR}/analyses/hifiasm hifi_env