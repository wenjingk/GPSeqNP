// GPSEQ_MAP — per-sample preprocessing (UMI extract → align → dedup → BED).
// Wraps the upstream GPSeqNP.sh / GPSeqNP4singularity.sh script (12th arg
// patched in locally to expose UMI length).

process GPSEQ_MAP {
    tag        "${meta.run_id}/${meta.sample_id}"
    publishDir "${params.outdir}/${meta.run_id}", mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(fastq)
    path  ref_dir
    path  scripts_dir

    output:
    tuple val(meta.run_id), val(meta), path("bed/${meta.sample_id}.bed.gz"),         emit: bed
    tuple val(meta.run_id), val(meta), path("mapping/${meta.sample_id}.clean.bam"),  emit: bam
    tuple val(meta.run_id), val(meta), path("sample_out_${meta.sample_id}", type: 'dir'), emit: dir

    script:
    def script_name = workflow.containerEngine == 'singularity' ? 'GPSeqNP4singularity.sh' : 'GPSeqNP.sh'
    // Per-sample packed dir name must be unique across the run, otherwise the
    // groupTuple feeding GPSEQ_SUMMARY stages every sample as 'sample_dirs/sample_out'
    // and Nextflow aborts on an input file name collision (and the publishDir copies
    // would overwrite each other under results/<run_id>/).
    def packed = "sample_out_${meta.sample_id}"
    """
    set -euo pipefail
    bash ${scripts_dir}/${script_name} \\
        ${meta.run_id} \\
        ${meta.sample_id} \\
        ${meta.barcode} \\
        ${fastq} \\
        ${meta.ref_genome} \\
        ${meta.ref_version} \\
        ${meta.enzyme} \\
        ${meta.cut_seq} \\
        ${ref_dir} \\
        . \\
        ${task.cpus} \\
        ${meta.umi_length}
    # Stage all per-sample outputs into a single packed dir for groupTuple/SUMMARY.
    mkdir -p ${packed}
    for d in fastq fastqc fastq_hq fastq_prefix mapping atcs dedup bed; do
        [[ -d "\$d" ]] && cp -rl "\$d" ${packed}/ 2>/dev/null || true
    done
    """
}
