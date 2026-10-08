# Download sequence data

Navigate to correct directory
```
PROJDIR=/data/Wilson_Lab/projects/Group_Genome_Assembly/Hemicordylus_capensis/
SCRIPTDIR=${PROJDIR}/
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
chmod +x ${SCRIPTDIR}/download_sra.sh
${SCRIPTDIR}/download_sra.sh /path/to/run_accessions.txt /path/to/output