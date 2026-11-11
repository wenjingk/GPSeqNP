// GPSEQ_RADICAL — per-run centrality score via gpseq-radical.R.
// Builds the centrality TSV (exid/cond/libid/fpath) from the samplesheet metas,
// resolves mask + cut-site BED from the genome lookup, and derives the
// chrom-size BED from the masking_files .genome file if needed.

process GPSEQ_RADICAL {
    tag        "$run_id"
    publishDir "${params.outdir}/${run_id}", mode: 'copy', overwrite: true

    input:
    tuple val(run_id), val(metas), path(beds)
    path  ref_dir
    path  mask_dir
    path  radical_script

    output:
    tuple val(run_id), path('radical-out-gpseq', type: 'dir')

    script:
    def first       = metas[0]
    def exid        = first.exid
    def ref_build   = first.ref_build
    def ref_genome  = first.ref_genome
    def ref_version = first.ref_version
    def enzyme      = first.enzyme
    def chrom_tag   = first.chrom_tag
    def bins        = first.bins
    def normalize   = first.normalize_by
    def mask_name   = first.mask ?: ''
    def cutsite     = "${ref_dir}/${ref_genome}.${ref_version}.dna.primary_assembly.${enzyme}_sites.bed.gz"
    def chrom_bed   = "${ref_dir}/${ref_build}_chrom_size.bed"
    def genome_file = "${mask_dir}/${ref_build}.genome"
    def mask_arg    = mask_name ? "--mask-bed ${mask_dir}/${mask_name}" : ''

    // Build a (timepoint, sample_id, bed_filename) row list — pwd-prepended in
    // bash so the staged work-dir path resolves at runtime.
    def tsv_rows = metas.withIndex().collect { m, i ->
        "${m.timepoint}\\t${m.sample_id}\\t${beds[i].name}"
    }.join('\\n')

    """
    set -euo pipefail

    # 1. Centrality metadata TSV (derived from samplesheet; bed paths absolute)
    {
        printf 'exid\\tcond\\tlibid\\tfpath\\n'
        printf '${tsv_rows}\\n' | awk -v exid='${exid}' -v wd="\$PWD" \\
            'BEGIN{OFS="\\t"} {print exid, \$1, \$2, wd"/"\$3}'
    } > centrality.tsv

    # 2. Chrom-size BED — derive from masking_files/<build>.genome if missing
    if [[ ! -s "${chrom_bed}" ]]; then
        if [[ ! -s "${genome_file}" ]]; then
            echo "ERROR: no chrom-size source for ref_build=${ref_build} (looked for ${genome_file})" >&2
            exit 1
        fi
        awk -F'\\t' 'BEGIN{OFS="\\t"} \$1!~/_/ && \$1!="chrM" {print \$1, 0, \$2}' \\
            "${genome_file}" > "${chrom_bed}"
    fi

    # 3. Sanity: cut-site BED must exist (Part 1 will have built it)
    [[ -s "${cutsite}" ]] || { echo "ERROR: missing cut-site BED ${cutsite}" >&2; exit 1; }

    # 4. Run gpseq-radical.R (patched: supports flat chrom lists for non-mammalian)
    rm -rf radical-out-gpseq
    Rscript ${radical_script} centrality.tsv radical-out-gpseq \\
        --chromosome-wide -b '${bins}' \\
        --normalize-by '${normalize}' \\
        --ref-genome '${ref_build}' --chrom-tag '${chrom_tag}' \\
        --threads ${task.cpus} --export-level 1 \\
        --site-domain universe --site-bed '${cutsite}' \\
        ${mask_arg} \\
        -c '${chrom_bed}'
    """
}
