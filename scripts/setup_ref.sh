#!/bin/bash
# setup_ref.sh — extract Step 1 (reference setup) from GPSeqNP.sh as a
# standalone, idempotent script. Builds the bowtie2 index + cut-site BED for a
# given (ref_genome, ref_version, enzyme, cut_seq) combo. Used by the
# GPSEQ_PREP_REF Nextflow process and for manual cache warm-ups.
#
# Usage:
#   setup_ref.sh <ref_genome> <ref_version> <cut_enzyme> <cut_seq> <ref_dir> <threads>
#
# Skips work that's already done. Safe to call concurrently for DIFFERENT refs;
# DO NOT call concurrently for the SAME ref (race on index files).

set -euo pipefail

ref_genome=$1
species=$(echo $ref_genome | cut -d"." -f 1 | sed 's/./\L&/')
version=$2
cut_enzyme=$3
cut_seq=$4
ref_dir=$5
threads=${6:-4}

bowtie2_ref="${ref_dir}/${ref_genome}.${version}.dna.primary_assembly"
cutsite_path="${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.${cut_enzyme}_sites.bed.gz"

mkdir -p "${ref_dir}"

# --- 1. Bowtie2 index (download FASTA + build, if missing) -------------------
if [[ ! -s "${bowtie2_ref}.rev.2.bt2" ]]; then
    echo "[$(date -u +%FT%TZ)] Building bowtie2 index for ${ref_genome}.${version}"
    base="http://ftp.ensembl.org/pub/release-${version}/fasta/${species}/dna"
    # Large genomes (human/mouse) ship *.dna.primary_assembly.fa.gz; small Ensembl
    # genomes (yeast, fly) ship only *.dna.toplevel.fa.gz. Try primary_assembly
    # first (so mammalian behaviour is unchanged), then fall back to toplevel —
    # both in versioned and unversioned filename forms.
    dl_target="${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.noChr.fa.gz"
    src_url=""
    for cand in \
        "${base}/${ref_genome}.${version}.dna.primary_assembly.fa.gz" \
        "${base}/${ref_genome}.dna.primary_assembly.fa.gz" \
        "${base}/${ref_genome}.${version}.dna.toplevel.fa.gz" \
        "${base}/${ref_genome}.dna.toplevel.fa.gz"; do
        if wget -q --method=HEAD "${cand}"; then src_url="${cand}"; break; fi
    done
    if [[ -z "${src_url}" ]]; then
        echo "ERROR: no Ensembl FASTA for ${ref_genome} release ${version} (tried primary_assembly + toplevel, versioned + unversioned)." >&2
        exit 1
    fi
    echo "Download from ${src_url}."
    wget -O "${dl_target}" "${src_url}" \
        &> "${ref_dir}/${ref_genome}.${version}.download.log"
    zcat "${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.noChr.fa.gz" \
        | sed 's/>/>chr/' | cut -d" " -f 1 \
        | gzip > "${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.fa.gz"
    rm "${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.noChr.fa.gz"

    /app/bin/bowtie2-build \
        "${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.fa.gz" \
        "${bowtie2_ref}" \
        --threads "${threads}" --verbose \
        &> "${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.log"
    echo "[$(date -u +%FT%TZ)] bowtie2 index built."
else
    echo "[$(date -u +%FT%TZ)] bowtie2 index present, skipping build."
fi

# --- 2. Cut-site BED (build via fbarber if missing) ---------------------------
if [[ ! -s "${cutsite_path}" ]]; then
    echo "[$(date -u +%FT%TZ)] Building cut-site BED for ${cut_enzyme} (${cut_seq})"
    fbarber find_seq \
        "${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.fa.gz" \
        "${cut_seq}" \
        --case-insensitive --global-name \
        --output "${cutsite_path}" \
        --log-file "${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.${cut_enzyme}_sites.log" \
        &> "${ref_dir}/${ref_genome}.${version}.dna.primary_assembly.${cut_enzyme}_sites.log2"
    echo "[$(date -u +%FT%TZ)] cut-site BED built."
else
    echo "[$(date -u +%FT%TZ)] cut-site BED present, skipping build."
fi

echo "[$(date -u +%FT%TZ)] setup_ref.sh done for ${ref_genome}.${version} + ${cut_enzyme}."
