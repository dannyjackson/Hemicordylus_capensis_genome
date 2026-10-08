# Download sequence data

Navigate to correct directory
```
PROJDIR=/data/Wilson_Lab/projects/Group_Genome_Assembly/Hemicordylus_capensis/
cd ${PROJDIR}/scripts
git clone https://github.com/dannyjackson/Hemicordylus_capensis_genome
SCRIPTDIR=${PROJDIR}/scripts/Hemicordylus_capensis_genome

```
## Accessions of DNA reads:
```
cat > ${PROJDIR}/reference_lists/HiFi_Accessions.txt <<'EOF'
SRR22311009
SRR22311010
SRR22311011
SRR22311012
EOF

cat > ${PROJDIR}/reference_lists/HiC_Accessions.txt <<'EOF'
SRR22311007
SRR22311008
EOF
```

## Accessions of RNA reads:
```
cat > ${PROJDIR}/reference_lists/RNA_Accessions.txt <<'EOF'
SRR22311005
SRR22311006
SRR22311013
SRR22311014
SRR22311015
SRR22311016
SRR22311017
SRR22311018
SRR22311019
SRR22311020
SRR22311021
SRR22311022
EOF
```
chmod +x ${SCRIPTDIR}/0a_download_sra.sh

mkdir -p ${PROJDIR}/data/assembly/HiFi_reads ${PROJDIR}/data/assembly/HiC_reads ${PROJDIR}/data/annotation/

${SCRIPTDIR}/0a_download_sra.sh ${PROJDIR}/reference_lists/HiFi_Accessions.txt ${PROJDIR}/data/assembly/HiFi_reads
${SCRIPTDIR}/0a_download_sra.sh ${PROJDIR}/reference_lists/HiC_Accessions.txt ${PROJDIR}/data/assembly/HiC_reads