# gpseq-nf

A Nextflow wrapper for **GPSeqNP**, the GPSeq preprocessing workflow. Takes a samplesheet
of FASTQ files to deduplicated BAMs, cut-site BED files, and RADICAL centrality scores.

GPSeq measures the radial organization of chromatin in the nucleus. The method and these
processing scripts were published in:

> Girelli G, Custodio J, Kallas T, Agostini F, Wernersson E, Spanjaard B, Mota A,
> Kolbeinsdottir S, Gelali E, Crosetto N, Bienko M.
> **GPSeq reveals the radial organization of chromatin in the cell nucleus.**
> *Nature Biotechnology* **38**, 1184-1193 (2020).

> **Authorship in one line:** the processing scripts in `scripts/` are Gabriele Girelli's;
> `gpseq-nf/` is a Nextflow wrapper around them written by Wenjing Kang. It invokes the
> original scripts rather than reimplementing them. See `AUTHORS.md`.

## Why a wrapper

The original scripts process one sample per invocation. The wrapper adds what a multi-sample
run needs:

- **Reference preparation** cached per (genome, enzyme) combination, so a Bowtie2 index and
  cut-site BED are built once rather than per run.
- **Per-sample parallelism and failure isolation** — one bad library no longer stops a run.
- **Resumability** via `-resume`, which matters because UMI deduplication is the expensive
  step and a late failure used to mean repeating everything.
- **Aggregation** — summary table, RADICAL centrality, and a MultiQC report per run.

## Quick start

```bash
nextflow run gpseq-nf/main.nf \
  --samplesheet samplesheets/BICRO293.example.csv \
  --outdir results \
  -profile docker
```

Samplesheet columns: `run_id,sample_id,barcode,fastq,timepoint,ref_build,enzyme`. See
`samplesheets/*.example.csv`. Read structure is UMI + barcode + enzyme cut site + genomic
sequence; UMI length defaults to 8 and is settable per row.

## Validation status

Validated by re-processing libraries with known-good published output and comparing
byte-for-byte:

| reference | library | result |
|---|---|---|
| **hg38** | WK208 | **content-identical** — all 6 `rescaled.bins_*.tsv.gz` including chromosome-wide centrality, all 5 cut-site BEDs (5.4–6.3 M lines each), every numeric column of `summary_table.tsv`. Only the run-name label in column 1 differed. |
| **mm10** | BICRO293 | **content-identical** — 5/5 BED files match on md5 and line count; summary identical bar the run label. |

So orchestration does not alter results on the two references used in production.

**Not yet validated:** other enzymes (HindIII, MspI, DpnII are implemented and selectable
but untested), other genomes (hg19, dm6, sacCer3 are configured but untested), multi-run
samplesheets, and per-row RADICAL parameter overrides. These are tracked as T4–T7 in
`TESTING.md`. Treat them as implemented-but-unverified.

## Requirements

Nextflow ≥ 23.04 and Docker or Singularity/Apptainer. The mapping step is allocated 48 GB:
UMI deduplication forks several R workers and was OOM-killed at 16 GB.

## Repository layout

```
scripts/        original GPSeqNP processing scripts (G. Girelli), with three patches
gpseq-nf/       the Nextflow wrapper: main.nf, nextflow.config, modules/, assets/
samplesheets/   *.example.csv with relative paths
TESTING.md      test matrix and status
AUTHORS.md      authorship, attribution, licensing
```

## Citing

Two things:

1. **the GPSeq method and its processing scripts** — Girelli et al., *Nature
   Biotechnology* 38, 1184-1193 (2020), as above;
2. **gpseq-nf**, the Nextflow wrapper — this repository's release tag, if the
   orchestration is relevant to what you are reporting.

## Licence

MIT, copyright held jointly — see `LICENSE` and `AUTHORS.md`.
