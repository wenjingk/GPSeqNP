// GPSEQ_PREP_REF — build the bowtie2 index + cut-site BED for one
// (ref_genome, ref_version, enzyme, cut_seq) combo. Runs once per unique combo
// in the samplesheet, before GPSEQ_MAP fans out, so parallel MAP tasks don't
// race on writing the same index files.

process GPSEQ_PREP_REF {
    tag "${ref_genome}.${ref_version}/${enzyme}"

    input:
    tuple val(ref_genome), val(ref_version), val(enzyme), val(cut_seq)
    path  ref_dir
    path  scripts_dir

    output:
    tuple val(ref_genome), val(ref_version), val(enzyme), val(cut_seq), path('ref_ready.flag')

    script:
    """
    set -euo pipefail
    bash ${scripts_dir}/setup_ref.sh \\
        ${ref_genome} ${ref_version} ${enzyme} ${cut_seq} \\
        ${ref_dir} ${task.cpus}
    touch ref_ready.flag
    """
}
