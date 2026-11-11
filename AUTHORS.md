# Authorship and attribution

This repository contains two layers with different authorship. Please cite and credit
accordingly.

## Original GPSeq processing scripts — Gabriele Girelli

`scripts/GPSeqNP.sh`, `scripts/GPSeqNP4singularity.sh` and the supporting scripts
implement the GPSeq preprocessing workflow and were **written by Gabriele Girelli**. They
are the substance of the analysis: barcode and cut-site filtering, alignment, UMI grouping
and UMI-level deduplication, and cut-site assignment.

The GPSeq method itself should be cited from its primary publication (Girelli et al.,
*Nature Biotechnology*, 2020).

## Nextflow wrapper and patches — Wenjing Kang

**Wenjing Kang** contributed, for this project:

- `gpseq-nf/` — a Nextflow wrapper providing reference preparation, per-sample
  parallelism and failure isolation, resumability, and the summary / RADICAL centrality /
  MultiQC aggregation steps. It **invokes the original scripts**; it does not reimplement
  them.
- Three minor, backward-compatible patches to the originals:
  - `GPSeqNP.sh` / `GPSeqNP4singularity.sh` — UMI length exposed as a twelfth positional
    argument (default 8), where it had been hard-coded.
  - `mk_summary_table.py` — library list derived from `fastq_hq/*.log` rather than the
    `fastq/` directory, which is empty under the wrapper's one-FASTQ-per-sample input.
  - `gpseq-radical.R` — chromosome-tag handling generalised for non-mammalian genomes,
    gated on `nchrom == 0` so mammalian behaviour is unchanged.

## Third-party, vendored

`tools/GPSeq-RadiCal/gpseq-radical.R` originates from `BiCroLab/GPSeq-RadiCal` and is
**not** authored by either of the above. It is vendored as a pinned snapshot with the
non-mammalian patch applied. An upstream pull request with that patch is optional and
independent of this repository.

## Licensing

Released under the MIT licence (see `LICENSE`), with copyright held jointly: Gabriele
Girelli for the original processing scripts in `scripts/`, Wenjing Kang for the `gpseq-nf/`
wrapper and the patches listed above.

`tools/GPSeq-RadiCal/gpseq-radical.R` is vendored from `BiCroLab/GPSeq-RadiCal` and retains
whatever terms that project carries; it is not covered by this repository's licence.
