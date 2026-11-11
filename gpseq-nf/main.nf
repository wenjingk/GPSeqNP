#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { GPSEQ_PREP_REF } from './modules/gpseq_prep_ref.nf'
include { GPSEQ_MAP      } from './modules/gpseq_map.nf'
include { GPSEQ_SUMMARY  } from './modules/gpseq_summary.nf'
include { GPSEQ_RADICAL  } from './modules/gpseq_radical.nf'
include { GPSEQ_MULTIQC  } from './modules/gpseq_multiqc.nf'

// ============================================================================
// Lookup helpers — load genomes.csv and enzymes.csv into in-memory maps once.
// ============================================================================
def loadCsvMap(path, keyCol) {
    def file = new File(path)
    if (!file.exists()) error "Lookup table not found: $path"
    def lines = file.readLines().findAll { it && !it.startsWith('#') }
    def headers = parseCsvLine(lines[0])
    def keyIdx  = headers.indexOf(keyCol)
    if (keyIdx < 0) error "Column '$keyCol' missing from $path"
    def map = [:]
    lines.drop(1).each { line ->
        def fields = parseCsvLine(line)
        def row = [:]
        headers.eachWithIndex { h, i -> row[h] = fields[i] ?: '' }
        map[row[keyCol]] = row
    }
    return map
}

// Minimal CSV line parser that handles quoted fields containing commas.
def parseCsvLine(line) {
    def out = []
    def buf = new StringBuilder()
    def inQuotes = false
    line.each { ch ->
        if (ch == '"') {
            inQuotes = !inQuotes
        } else if (ch == ',' && !inQuotes) {
            out << buf.toString()
            buf = new StringBuilder()
        } else {
            buf.append(ch)
        }
    }
    out << buf.toString()
    return out
}

// exid defaults to run_id verbatim. The historical BiCroLab convention of
// stripping the alphabetic prefix and adding a 'B' (WK208 → B208) is no longer
// derived automatically — set `exid` explicitly in the samplesheet if you
// want it.

// Build a fully-resolved per-sample meta map from one samplesheet row, applying
// genomes.csv / enzymes.csv defaults for any missing column.
def resolveMeta(row, genomes, enzymes) {
    // Required columns
    def required = ['run_id', 'sample_id', 'barcode', 'fastq', 'timepoint', 'ref_build', 'enzyme']
    required.each { col ->
        if (!row[col]) error "Samplesheet row missing required column '$col': $row"
    }

    def g = genomes[row.ref_build]
    if (!g && (!row.ref_genome || !row.ref_version || !row.chrom_tag)) {
        error "ref_build='${row.ref_build}' not in assets/genomes.csv — either add a row there OR provide ref_genome/ref_version/chrom_tag/mask explicitly in the samplesheet"
    }
    def e = enzymes[row.enzyme]
    if (!e && !row.cut_seq) {
        error "enzyme='${row.enzyme}' not in assets/enzymes.csv — either add a row there OR provide cut_seq explicitly in the samplesheet"
    }

    return [
        // Required (per-sample)
        run_id:      row.run_id,
        sample_id:   row.sample_id,
        barcode:     row.barcode,
        timepoint:   row.timepoint,
        fastq:       row.fastq,

        // Build-derived (samplesheet overrides genomes.csv default)
        ref_build:   row.ref_build,
        ref_genome:  row.ref_genome  ?: g.ref_genome,
        ref_version: row.ref_version ?: g.ref_version,
        chrom_tag:   row.chrom_tag   ?: g.chrom_tag,
        mask:        row.mask        ?: (g ? g.mask : ''),

        // Enzyme-derived (samplesheet overrides enzymes.csv default)
        enzyme:      row.enzyme,
        cut_seq:     row.cut_seq     ?: e.cut_seq,

        // Read structure
        umi_length:  (row.umi_length ?: params.default_umi_length).toString().toInteger(),

        // gpseq-radical knobs
        exid:         row.exid         ?: row.run_id,
        bins:         row.bins         ?: params.default_bins,
        normalize_by: row.normalize_by ?: params.default_normalize_by,
    ]
}

// Validate that every per-run-constant column actually agrees across all rows
// of the same run_id. Bails out early with a clear message if they don't.
def validatePerRunConsistency(metas) {
    def perRun = ['ref_build', 'ref_genome', 'ref_version', 'chrom_tag', 'mask',
                  'enzyme', 'cut_seq', 'exid', 'bins', 'normalize_by', 'umi_length']
    metas.groupBy { it.run_id }.each { rid, rows ->
        perRun.each { col ->
            def distinct = rows.collect { it[col] }.unique()
            if (distinct.size() > 1) {
                error "run_id='$rid' has inconsistent values in column '$col': $distinct — these are per-run-constant"
            }
        }
    }
}

// ============================================================================
// Workflow
// ============================================================================
workflow {
    if (!params.samplesheet) error 'Required: --samplesheet <path/to/samplesheet.csv>'

    def genomes = loadCsvMap(params.genomes_csv, 'ref_build')
    def enzymes = loadCsvMap(params.enzymes_csv, 'enzyme')

    // Eagerly resolve + validate the full sample list (cheap, ~tens of rows).
    def rows = file(params.samplesheet).readLines().findAll { it && !it.startsWith('#') }
    def headers = parseCsvLine(rows[0])
    def all_metas = rows.drop(1).collect { line ->
        def fields = parseCsvLine(line)
        def row = [:]
        headers.eachWithIndex { h, i -> row[h] = fields[i] ?: '' }
        resolveMeta(row, genomes, enzymes)
    }
    validatePerRunConsistency(all_metas)

    log.info "Loaded ${all_metas.size()} samples across ${all_metas.collect{it.run_id}.unique().size()} run(s): ${all_metas.collect{it.run_id}.unique().join(', ')}"

    // PREP_REF: one task per unique (ref_genome, ref_version, enzyme, cut_seq) combo
    ch_refs = Channel.fromList(
        all_metas.collect { [it.ref_genome, it.ref_version, it.enzyme, it.cut_seq] }
                .unique()
                .collect { rg, rv, e, cs -> tuple(rg, rv, e, cs) }
    )
    GPSEQ_PREP_REF(ch_refs,
                   file(params.ref_dir),
                   file(params.gpseqnp_scripts))

    // Gate GPSEQ_MAP on PREP_REF: combine each sample with the matching ref-ready flag
    ch_samples_keyed = Channel.fromList(all_metas).map { meta ->
        tuple([meta.ref_genome, meta.ref_version, meta.enzyme, meta.cut_seq],
              meta,
              file(meta.fastq, checkIfExists: true))
    }
    ch_refs_keyed = GPSEQ_PREP_REF.out.map { rg, rv, e, cs, flag ->
        tuple([rg, rv, e, cs], flag)
    }
    ch_samples_ready = ch_samples_keyed.combine(ch_refs_keyed, by: 0)
        .map { _key, meta, fq, _flag -> tuple(meta, fq) }

    GPSEQ_MAP(ch_samples_ready,
              file(params.ref_dir),
              file(params.gpseqnp_scripts))

    // SUMMARY: gather all per-sample output dirs by run_id
    GPSEQ_MAP.out.dir
        | map { run_id, meta, d -> tuple(run_id, d) }
        | groupTuple(by: 0)
        | set { ch_summary_in }
    GPSEQ_SUMMARY(ch_summary_in, file(params.gpseqnp_scripts))
    GPSEQ_MULTIQC(ch_summary_in)

    // RADICAL: gather metas + bed paths by run_id, preserving samplesheet order
    GPSEQ_MAP.out.bed
        | map { run_id, meta, bed -> tuple(run_id, meta, bed) }
        | groupTuple(by: 0)
        | map { run_id, metas, beds ->
            // Sort by samplesheet order — gpseq-radical treats the row order as
            // the timepoint sequence; the user's samplesheet order is the source
            // of truth. groupTuple may scramble; restore order via samplesheet
            // index lookup.
            def order_lookup = all_metas.findAll { it.run_id == run_id }.collect { it.sample_id }
            def sorted = (0..<metas.size()).collect { i -> [metas[i], beds[i]] }
                .sort { a, b -> order_lookup.indexOf(a[0].sample_id) <=> order_lookup.indexOf(b[0].sample_id) }
            tuple(run_id, sorted.collect{it[0]}, sorted.collect{it[1]})
          }
        | set { ch_radical_in }
    GPSEQ_RADICAL(ch_radical_in, file(params.ref_dir), file(params.mask_dir), file(params.radical_script))
}

workflow.onComplete {
    log.info "Pipeline complete. Status: ${workflow.success ? 'OK' : 'FAILED'}. Duration: ${workflow.duration}"
    log.info "Results: ${params.outdir}"
}
