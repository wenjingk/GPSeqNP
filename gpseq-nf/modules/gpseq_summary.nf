// GPSEQ_SUMMARY — assemble summary_table.tsv for a run by merging per-sample
// outputs and running upstream mk_summary_table.py.

process GPSEQ_SUMMARY {
    tag        "$run_id"
    publishDir "${params.outdir}/${run_id}", mode: 'copy', overwrite: true

    input:
    tuple val(run_id), path(sample_dirs, stageAs: 'sample_dirs/*')
    path  scripts_dir

    output:
    tuple val(run_id), path('summary_table.tsv')

    script:
    """
    set -euo pipefail
    mkdir -p merged
    # Hardlink each per-sample output tree into a single canonical layout so
    # mk_summary_table.py can crawl it as if it were one shared run dir.
    for d in sample_dirs/*; do
        cp -rl "\$d"/* merged/ 2>/dev/null || cp -r "\$d"/* merged/
    done
    ${scripts_dir}/mk_summary_table.py merged
    mv merged/summary_table.tsv ./
    """
}
