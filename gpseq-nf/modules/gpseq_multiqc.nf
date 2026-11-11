// GPSEQ_MULTIQC — aggregate FastQC + bowtie2 mapping logs into a per-run
// MultiQC report. Uses a separate container since multiqc isn't bundled in the
// gpseq image.

process GPSEQ_MULTIQC {
    tag        "$run_id"
    container  'quay.io/biocontainers/multiqc:1.25--pyhdfd78af_0'
    publishDir "${params.outdir}/${run_id}", mode: 'copy', overwrite: true

    input:
    tuple val(run_id), path(sample_dirs, stageAs: 'sample_dirs/*')

    output:
    // MultiQC names its data dir after the report filename: with
    // `--filename multiqc_report.html` the data dir is `multiqc_report_data`
    // (not the default `multiqc_data`). Declare the name MultiQC actually writes.
    tuple val(run_id), path("multiqc_report.html"), path("multiqc_report_data", type: 'dir')

    script:
    """
    set -euo pipefail
    # Hardlink per-sample outputs into a flat dir so MultiQC can crawl them.
    mkdir -p merged
    for d in sample_dirs/*; do
        cp -rl "\$d"/* merged/ 2>/dev/null || cp -r "\$d"/* merged/
    done
    multiqc merged/ -o . --force --filename multiqc_report.html
    """
}
