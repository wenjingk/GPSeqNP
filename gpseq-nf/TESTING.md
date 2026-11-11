# gpseq-nf — test plan and progress

> **This is the development test record**, kept for transparency: it documents what was
> validated, how, and which bugs were found on the way. Paths are relative to the
> repository. Status summary is in the README.


Resume-from-here doc. If you (or a future session) come back to this work,
this is the source of truth for what's been tested, what's pending, and how
to run each test reproducibly.

**Last updated:** 2026-05-26 (added a 10M-read **subsample plumbing test (T1-sub)** to validate the SUMMARY→RADICAL→MULTIQC tail cheaply before committing to a full-depth run. Subsample run 1 confirmed the SUMMARY collision fix and surfaced 2 more tail bugs — MULTIQC output-dir name + header-only summary_table — both now fixed. **Subsample run 2 exercised the full chain (MAP×5 → SUMMARY → MULTIQC → RADICAL) but its nohup'd driver was interrupted before publishing; run 3 (`-resume`, 14:43) then closed clean — `Succeeded: 1, Cached: 8`, publishing a fully-populated `summary_table.tsv`, `radical-out-gpseq/`, and `multiqc_report.html`. ✅ T1-sub PASSED — the pipeline now runs end-to-end with all tail bugs fixed.** **✅ T1 (full depth) PASSED 2026-05-26 21:34 — run 5 closed `Status: OK` (6h 44m) and its bed / summary / all-6 rescaled.bins outputs are byte-content-identical to the WK208 known-good (only the summary's col-1 run label differs). gpseq-nf is validated end-to-end at full depth; the WK208 accuracy gate is the last T1 milestone.**)

## Status

| Test | Status | Last result | Notes |
|---|---|---|---|
| Scaffolding (5 processes parse) | ✅ done 2026-05-22 | OK (`nextflow inspect` clean) | — |
| hg38 PREP_REF (manual pre-build) | ✅ done 2026-05-22 11:06:56 UTC | bowtie2 index + MboI cut-site BED in `tools/GPSeqNP/ref/` (74 min wall) | One-off cache warm-up. Subsequent in-pipeline PREP_REF tasks for hg38 will short-circuit on existence check. |
| gpseq-radical.R patch (non-mammalian chrom_tag) | ✅ done 2026-05-22 | Applied in `tools/GPSeq-RadiCal/gpseq-radical.R` | Backward compatible for mammalian; gated on `nchrom == 0` |
| GPSeqNP.sh patch (configurable UMI length) | ✅ done 2026-05-22 | Applied in `tools/GPSeqNP/scripts/GPSeqNP.sh` and `GPSeqNP4singularity.sh` | 12th positional arg, default 8 |
| **T1** — WK208 baseline (full depth) | ✅ **PASSED 2026-05-26 21:34** — run 5 closed `Status: OK`, 6h 44m 21s, Succeeded 8 / Cached 1, all processes ✔ (PREP_REF cached → MAP×5 → SUMMARY → MULTIQC → RADICAL). **Accuracy gate met: byte-match vs WK208 known-good** (`WK208/output/radical-out-gpseq/B208/`). Verified content-identical: all 6 `rescaled.bins_*.tsv.gz` incl. `chrom_wide` centrality (29390 / 25 / 294553 / 117502 / 58876 / 58877 lines), all 5 `bed/MS{13..17}.bed.gz` (5.4M–6.3M lines each), and every numeric column of `summary_table.tsv` across all 5 samples. **Only diff = the summary's column-1 label (`merged` vs gold `output`) — cosmetic run-name, not data.** Plumbing was pre-validated via T1-sub. Log `T1_WK208_run5.nohup.log`. **gpseq-nf is now validated end-to-end at full depth.** | Run 1 (2026-05-22) failed at step 8 (`/home/scripts/group_umis.py: No such file or directory`). **Scripts-dir fix applied** (`nextflow.config:43` binds `-v $projectDir/tools/GPSeqNP/scripts:/home/scripts:ro`) — confirmed working: steps 1–9 now pass. Run 2 aborted (obsolete coexist cap). **Run 3 (2026-05-23, 2h 30m) FAILED at step 10 (UMI dedup) — OOM.** Kernel log: `Memory cgroup out of memory: Killed process (R)`, `constraint=CONSTRAINT_MEMCG` — the per-container 16 GB cap (`docker run … --memory 16384m`, from `GPSEQ_MAP memory='16 GB'`) is too tight for `umi_dedupl.R -c 8 -r 10000` (8 forked R workers exceed 16 GB). All 5 samples ran dedup concurrently; only MS14 fit under 16 GB; MS13/15/16/17 OOM-killed; no `results/WK208/bed/` published. **OOM fix:** `GPSEQ_MAP memory 16 GB → 48 GB` in `nextflow.config:73`. **Run 4 (2026-05-25, 8h 3m): OOM fully resolved** — step 10 cleared on all 5 samples, all `results/WK208/{bed/MS*.bed.gz, mapping/MS*.clean.bam}` produced. **But pipeline ended Status: FAILED at `GPSEQ_SUMMARY`:** `input file name collision -- multiple input files for: sample_dirs/sample_out` — `GPSEQ_MAP` emitted its packed dir as `sample_out` for every sample, so the groupTuple feeding SUMMARY staged all 5 under the same `sample_dirs/sample_out` (`gpseq_summary.nf:9`). GPSEQ_MULTIQC then errored, GPSEQ_RADICAL was killed → no `summary_table.tsv`, no `radical-out`. **Fix applied (2026-05-26):** `modules/gpseq_map.nf` now emits `sample_out_${meta.sample_id}` (unique per sample; also fixes a latent publishDir overwrite). `nextflow inspect` clean. Logs preserved: `T1_WK208_run1_failed.nohup.log`, `T1_WK208_run2_aborted.nohup.log`, `T1_WK208.nohup.log` (run 3). The SUMMARY/RADICAL/MULTIQC tail is now being shaken out on the **T1-sub** subsample (next row) rather than burning ~8h per full run. | Full-depth run 5 = final accuracy check (bed/summary/rescaled-bins byte-match vs `WK208/output/`); launch only after T1-sub exits 0 |
| **T1-sub** — WK208 10M-read subsample (plumbing) | ✅ **PASSED 2026-05-26 14:43** — run 3 (`-resume`) closed clean: `Succeeded: 1, Cached: 8`, 18m 17s. Published `results_subtest/WK208sub/`: **`summary_table.tsv` fully populated** (5 rows MS13–MS17, uniq% 88.6/93.8/96.5/97.9/98.7), `radical-out-gpseq/` (bed.metadata + rescaled bins, chrom-wide scores ~1.38–1.40), `multiqc_report.html`. First fully-clean end-to-end run — plumbing conclusively validated. | Fast end-to-end plumbing test: all 5 WK208 fastqs head-subsampled to 10M reads (`WK208sub/input/`, `samplesheets/WK208sub.csv`, run_id `WK208sub`, `--outdir results_subtest -w work_subtest`). Goal: exercise SUMMARY→RADICAL→MULTIQC in minutes, not 8h. **Run 1 (1h 4m):** confirmed the `gpseq_map.nf` collision fix (unique `sample_out_MS{13..17}`, all 5 bed/bam, `summary_table.tsv` written) but exposed 2 more bugs — (a) **MULTIQC** declared output `multiqc_data` while MultiQC writes `multiqc_report_data` for `--filename multiqc_report.html` → false "missing output" aborted the pipeline and collaterally killed RADICAL (MultiQC itself exit 0); (b) **`summary_table.tsv` header-only** — `mk_summary_table.py` derived its library list from the `fastq/` dir, which is empty under the pipeline's one-fastq-per-sample input (GPSeqNP only fills `fastq_prefix/`+`fastq_hq/`). **Fixes (2026-05-26):** `modules/gpseq_multiqc.nf` → declare `multiqc_report_data`; `tools/GPSeqNP/scripts/mk_summary_table.py` → derive library list from `fastq_hq/*.log`. **Run 2 (relaunched with `-resume`)** — editing `mk_summary_table.py` (inside the staged `scripts_dir`) busted GPSEQ_MAP's cache, so MAP re-ran (~45 min) before the tail. The chain then completed: MAP×5 ✅ (exit 0) → SUMMARY ✅ (exit 0) → MULTIQC ✅ (exit 0) → **GPSEQ_RADICAL ran ~17.5 min and wrote a complete, sane output set**, but the nohup'd driver was interrupted in the finalize window so there was no `.exitcode`/publish. **Run 3 (`-resume`, 2026-05-26 14:43, 18m 17s) closed it out clean: `Succeeded: 1, Cached: 8`** — RADICAL re-ran from the only un-cached stage and published `results_subtest/WK208sub/{summary_table.tsv (5 populated rows), radical-out-gpseq/, multiqc_report.html}`. ✅ **T1-sub PASSED — pipeline runs end-to-end with all tail bugs fixed.** Logs: `T1_WK208sub.nohup.log` (run 1), `T1_WK208sub_run2.nohup.log` (run 2), `T1_WK208sub_run3_finalize.nohup.log` (run 3). | First clean `exit 0` with populated summary + MultiQC report + `radical-out-gpseq/` is the gate to launch full-depth run 5. **Architecture nit:** GPSEQ_MAP stages the whole `scripts_dir` as input → any script edit invalidates all MAP cache on `-resume`; consider staging only needed scripts. |
| **T2** — mm10 (BICRO293) | ✅ **PASSED 2026-05-27** (recorded 2026-11-11 — the row was never flipped at the time) | Satisfied by the production Task-16 runs, not a separate test: **BICRO293** (KG54-58) `Status: OK` 03:43, 5h 35m, 71.5 CPU-h, 9/9 succeeded; **BICRO299** (KG77-82) `Status: OK` 07:54, 4h 11m, 63.6 CPU-h, 10/10. **Accuracy gate met:** byte-check vs the ad-hoc `tools/GPSeqNP/output/BICRO293/` run PASSED — 5/5 bed files decompressed-content-identical (md5 + line counts match), `summary_table.tsv` identical bar the column-1 run label. uniq% KG54 47.46 / KG55 73.80 / KG56 85.67 / KG57 80.47 / KG58 87.32. | mm10 ref already cached. Logs `logs/{BICRO293,BICRO299}_mm10_run1.nohup.log`. **With T1 (hg38) this means both accuracy gates have passed byte-identically on two references.** |
| **T3** — UMI length variation | ✅ **core PASSED 2026-05-26** (ran in parallel with run 5; `samplesheets/T3_umi10.csv`, 2× 100K-read subset, `umi_length=10`) — `GPSEQ_MAP` ✅ 2/2 and the fbarber pattern was **`umi10bc8cs4`** (vs baseline `umi8bc8cs4`), confirming the `umi_length` patch plumbs through. Pipeline then errored at `GPSEQ_RADICAL` (`Can't assign 8 names to a 9 column data.table`) — the **expected degenerate-data outcome** (umi=10 mismatches the real read structure → near-empty beds), just a messier error than the predicted "Provide at least two bed files". | Minor: gpseq-radical could fail more gracefully on near-empty beds. Still TODO: umi=6, and a umi=8 control. Log `T3_umi10.nohup.log`. |
| **T4** — Enzyme variations (HindIII / MspI / DpnII) | ⏳ pending | — | Subsetted fastq (100K subset now exists at `test_inputs/MS1{3,4}_100K_R1_001.fastq.gz`) |
| **T5a** — hg19 reference | ⏳ pending | — | Triggers PREP_REF for new ref (mammalian → primary_assembly path, unaffected by the toplevel fix) |
| **T5b** — Drosophila (dm6) | 🟡 **PREP_REF half PASSED 2026-05-26** (ran parallel w/ run 5, `samplesheets/T5bc_nonmammal.csv` via full samplesheet-override, no genomes.csv edit) — index built fine after the `setup_ref.sh` toplevel fix. **But MAP/RADICAL can't be validated with this data:** the reads are *human*, so ~none map to dm6 → no `bed/*.bed.gz` → MAP fails on missing output. Needs real fly GPSeq reads (or a spiked input) to exercise the non-mammalian `chrom_tag`/gpseq-radical patch. | Non-mammalian `0:2L,2R,...` chrom_tag plumbed through resolveMeta OK; radical patch itself still unexercised on real fly data. |
| **T5c** — Yeast (sacCer3) | 🟡 **PREP_REF half PASSED 2026-05-26** — **surfaced + fixed a real bug:** `setup_ref.sh` only fetched `*.dna.primary_assembly.fa.gz`, which doesn't exist for small Ensembl genomes (yeast/fly ship only `*.dna.toplevel.fa.gz`) → 404. **Fixed** (added versioned+unversioned `toplevel` fallback after primary_assembly; mammalian behaviour unchanged). Re-run: both yeast + fly FASTAs downloaded and indexed. **MAP still blocked** same as T5b — human reads don't map to the 12 Mb yeast genome → empty bed → MAP missing-output fail. Roman-numeral chrom check needs real yeast data. | Logs: `T5bc_nonmammal.nohup.log` (run 1, caught the bug), `T5bc_nonmammal_run2.nohup.log` (run 2, post-fix). |
| **T6** — Multi-run samplesheet | ⏳ pending | — | Validates `groupTuple by run_id` and PREP_REF de-dup |
| **T7** — Per-row gpseq-radical knob override | ⏳ pending | — | `chrom_tag`, `normalize_by` overrides |

## Test matrix

Baseline is **hg38 / MboI (GATC) / UMI=8**, with all gpseq-radical defaults. Each
test mutates exactly one parameter (or one related group of parameters).

### T1 — WK208 baseline

- **Varies:** nothing (defaults). End-to-end validation.
- **Input:** `samplesheets/WK208.csv` — full WK208 fastqs (5 samples, ~80M reads each).
- **Pass criteria:**
  - Pipeline exits 0.
  - `results/WK208/bed/MS{13..17}.bed.gz` byte-diffs match `gpseq-nf/WK208/output/bed/MS{13..17}.bed.gz` content-wise (gunzip + sort, ignore timestamps/metadata).
  - `results/WK208/summary_table.tsv` numerical columns match the existing `WK208/output/summary_table.tsv` row-for-row.
  - `results/WK208/radical-out-gpseq/WK208/rescaled.bins_*.tsv.gz` content matches existing `WK208/output/radical-out-gpseq/B208/rescaled.bins_*.tsv.gz` (note: existing run used `exid=B208`, new run uses `exid=WK208` per the simpler default; subdir name differs but content should be identical).
  - MultiQC report rendered to `results/WK208/multiqc_report.html`.
- **Cost:** ~5–6h wall (5 samples × ~1h mapping in parallel + radical step).
- **Launch:**
  ```bash
  cd gpseq-nf
  NXF_VER=24.04.4 <project>/bin/nextflow run main.nf \
    -profile docker \
    --samplesheet samplesheets/WK208.csv \
    --outdir results
  ```

### T2 — mouse reference (BICRO293)

- **Varies:** `ref_build` → mm10.
- **Input:** `samplesheets/BICRO293.csv` — full BICRO293 fastqs (5 samples).
- **Pass criteria:**
  - Pipeline exits 0.
  - `results/BICRO293/bed/KG{54..58}.bed.gz` byte-diffs match `<project>/tools/GPSeqNP/output/BICRO293/bed/KG{54..58}.bed.gz` (from yesterday's outside-pipeline run).
  - `summary_table.tsv` matches yesterday's row-for-row.
- **Cost:** ~6h (mm10 ref cached so PREP_REF short-circuits).
- **Launch:**
  ```bash
  nextflow run main.nf -profile docker \
    --samplesheet samplesheets/BICRO293.csv \
    --outdir results
  ```

### T3 — UMI length variation

- **Varies:** `umi_length` ∈ {6, 10} (also smoke-test 8 to confirm default).
- **Input:** First 100K reads of MS13 from WK208 (subset for speed).
- **Pass criteria:**
  - Pipeline exits 0 for each umi_length value.
  - `fastq_hq/.../*.log` contains `--pattern "umi${N}bc8cs4"` (verify the value plumbed correctly).
  - BAMs are non-empty for umi=8 (matches read structure); near-empty for umi=6/10 (read structure mismatch — expected).
  - gpseq-radical may fail with "Provide at least two bed files" for umi mismatches if BAMs are too empty — that's an acceptable failure mode (not a plumbing bug). Confirm by running with two samples.
- **Cost:** ~5–10 min per umi_length value.
- **Launch:**
  ```bash
  # Make subsetted fastq + samplesheet first; see "Subsetting fastqs" below.
  nextflow run main.nf -profile docker \
    --samplesheet samplesheets/T3_umi10.csv \
    --outdir results_T3
  ```

### T4 — Enzyme variations

- **Varies:** `enzyme` ∈ {HindIII (AAGCTT), MspI (CCGG), DpnII (GATC)}. MboI is the baseline.
- **Input:** First 100K reads of MS13 from WK208.
- **Pass criteria:**
  - PREP_REF builds per-enzyme cut-site BED for HindIII and MspI (cached under `ref/`).
  - DpnII's cut-site BED is byte-identical to MboI's (both `GATC`). The pipeline builds both files but they should be functionally the same — verify with `cmp` after gunzip.
  - Pipeline exits 0 for each enzyme.
  - Mapping yield drops for HindIII/MspI vs MboI (real biology — WK208 reads were generated with MboI).
- **Cost:** ~15 min each (one fbarber `find_seq` per enzyme + tiny mapping).

### T5 — Reference genome variations (three sub-tests)

#### T5a — hg19

- **Varies:** `ref_build` → hg19.
- **Input:** First 100K reads of MS13 from WK208.
- **Pass criteria:**
  - PREP_REF builds hg19 index from Ensembl release 75.
  - Pipeline exits 0.
  - gpseq-radical output produced in `results_T5a/T5a_hg19/radical-out-gpseq/T5a_hg19/`.
  - **Regression check on the gpseq-radical patch:** since hg19 is mammalian, the patched script should produce output identical to what an unpatched script would produce. Optionally byte-diff against an unpatched-container run.
- **Cost:** ~30–60 min (hg19 PREP_REF) + 5 min.

#### T5b — Drosophila (dm6)

- **Varies:** `ref_build` → dm6.
- **Setup:** Add a row to `assets/genomes.csv`:
  ```csv
  dm6,Drosophila_melanogaster.BDGP6.46,110,"0:2L,2R,3L,3R,4,X,Y",,https://hgdownload.cse.ucsc.edu/goldenpath/dm6/bigZips/dm6.chrom.sizes
  ```
  (empty `mask` column → pipeline skips `--mask-bed`.)
- **Input:** First 100K reads of MS13 from WK208 (data is human; this test is purely "does the pipeline run end-to-end on a fly reference").
- **Pass criteria:**
  - PREP_REF builds dm6 (~5–10 min, 140 MB genome).
  - Pipeline exits 0.
  - `radical-out-gpseq/T5b_dm6/rescaled.bins_*.tsv.gz` exists and contains rows with `chrom ∈ {chr2L, chr2R, chr3L, chr3R, chr4, chrX, chrY}` (NOT `chr1..chr4`).
- **Cost:** ~15 min total.

#### T5c — Yeast (sacCer3)

- **Varies:** `ref_build` → sacCer3.
- **Setup:** Add to `genomes.csv`:
  ```csv
  sacCer3,Saccharomyces_cerevisiae.R64-1-1,110,"0:I,II,III,IV,V,VI,VII,VIII,IX,X,XI,XII,XIII,XIV,XV,XVI",,https://hgdownload.cse.ucsc.edu/goldenpath/sacCer3/bigZips/sacCer3.chrom.sizes
  ```
- **Input:** First 100K reads of MS13 from WK208.
- **Pass criteria:**
  - PREP_REF builds sacCer3 (~1–2 min, 12 MB genome).
  - Pipeline exits 0.
  - Output `chrom` column uses roman numerals: `chrI, chrII, ..., chrXVI`.
- **Cost:** ~5 min total.

### T6 — Multi-run samplesheet

- **Varies:** Two `run_id`s in one samplesheet (one row each from subsetted WK208 + BICRO293).
- **Pass criteria:**
  - PREP_REF runs once for `(Homo_sapiens.GRCh38, 105, MboI, GATC)` and once for `(Mus_musculus.GRCm38, 102, MboI, GATC)` — verify in `.nextflow.log` that exactly 2 PREP_REF tasks executed.
  - Two output dirs: `results/WK208/` and `results/BICRO293/`.
  - `groupTuple by run_id` produces correct partitioning.
- **Cost:** ~10 min.

### T7 — Per-row gpseq-radical knob overrides

- **Varies:** Set `chrom_tag=22:X` (drop Y) and `normalize_by=chrom` in a WK208-subset row.
- **Pass criteria:**
  - Pipeline exits 0.
  - gpseq-radical was invoked with `--chrom-tag 22:X --normalize-by chrom` (verify in `.command.sh`).
  - Validation also catches mismatched overrides — try a samplesheet where two rows of the same run_id have different `chrom_tag` values; pipeline should error before scheduling work.
- **Cost:** ~5 min.

## Subsetting fastqs for parameter-variation tests

For T3–T7, 100K-read subsets reduce per-test cost from hours to minutes:

```bash
mkdir -p gpseq-nf/test_inputs
zcat gpseq-nf/WK208/input/MS13_S1_LALL_R1_001.fastq.gz \
  | head -400000 | gzip \
  > gpseq-nf/test_inputs/MS13_100K.fastq.gz
```

Then create test-specific samplesheets in `samplesheets/T*_*.csv` pointing at the subsetted fastq. Each test gets its own samplesheet so launches stay reproducible.

## Resuming after logout

If you come back to this work in a new session:

1. **Read this file first** — gives current test status.
2. **Read `README.md`** — pipeline layout and launch instructions.
3. **Check CNATrace tasks** — `<project>/notes/CNATrace_tasks.md` references this pipeline under Task 16.
4. **Check pre-build state** — `ls -la <project>/tools/GPSeqNP/ref/Homo_sapiens*` (look for `*.rev.2.bt2` and `*MboI_sites.bed.gz` as the "ready" indicators).
5. **Check what's running** — `docker ps`, `ps -ef | grep nextflow`.

## Patches we maintain on the upstream

| File | Upstream | Patch | Reason |
|---|---|---|---|
| `tools/GPSeqNP/scripts/GPSeqNP.sh` | github.com/BiCroLab/GPSeqNP | accept `umi_length` as 12th positional arg (default 8); use it in fbarber `--pattern` | Expose UMI length so non-default protocols work |
| `tools/GPSeqNP/scripts/GPSeqNP4singularity.sh` | (same as above, singularity variant) | (same patch) | Same reason; mirrors the docker variant |
| `tools/GPSeq-RadiCal/gpseq-radical.R` | github.com/BiCroLab/GPSeq-RadiCal | gate `1:nchrom` synthesis on `nchrom > 0`; assign hetero IDs by position when `nchrom == 0` | Support non-mammalian genomes (fly/yeast/worm) with chrom names that don't fit the `chr1..chrN` pattern |
| `tools/GPSeqNP/scripts/setup_ref.sh` | github.com/BiCroLab/GPSeqNP | after the two `*.dna.primary_assembly.fa.gz` attempts, fall back to `*.dna.toplevel.fa.gz` (versioned + unversioned) | Small Ensembl genomes (yeast, fly) ship only `toplevel`, not `primary_assembly` — without this, PREP_REF 404s for any non-mammalian ref. Mammalian downloads still hit primary_assembly first (unchanged). Found by T5c, 2026-05-26. |

Mammalian behaviour is preserved bit-for-bit for both patches.

## Known issues / improvements — reference handling (pre-publish backlog)

Raised 2026-05-26 while reviewing the genome-ref approach. Prioritised for the
gated GitHub publish. None of these block current mammalian runs.

### I1 — Optional user-provided local FASTA (`ref_fasta`) — *approved, to implement*

**Problem:** the genome is *only ever* obtained by downloading from Ensembl FTP,
with the URL constructed from `ref_genome` + `ref_version` (`setup_ref.sh`). There
is no way to point the pipeline at a local FASTA. So a custom/non-Ensembl assembly,
an air-gapped run, or a genome not in the Ensembl layout simply can't be used.

**Proposed design (additive, Ensembl path unchanged when `ref_fasta` is empty):**
- New **optional samplesheet column `ref_fasta`** = absolute path to a local `.fa`/`.fa.gz`.
  `ref_genome`/`ref_version` are still required (used as the cache-file *label*),
  plus `chrom_tag`.
- `main.nf` `resolveMeta`: carry `ref_fasta: row.ref_fasta ?: ''` into the meta;
  thread it into the `ch_refs` grouping key (currently `[ref_genome, ref_version,
  enzyme, cut_seq]` at `main.nf:140`) so PREP_REF receives it.
- `gpseq_prep_ref.nf`: add an **optional** `path(ref_fasta)` input via a `NO_FILE`
  placeholder (`file("${projectDir}/assets/NO_FILE")` when empty); pass as a new
  positional arg to `setup_ref.sh`.
- `setup_ref.sh`: if the local FASTA arg is non-empty/exists, **skip `wget`** and use
  it as the source; otherwise download as today. **chr-prefix handling:** detect the
  first header — only `sed 's/>/>chr/'` if it does **not** already start with `>chr`
  (avoid `chrchr1`). Everything downstream of the source step is unchanged.
- **Bonus (closes I2 for this path):** when a local FASTA is given, derive the
  chrom-size BED straight from it (`samtools faidx` → `.fai` → `chrom 0 len`),
  removing the manual `.genome` requirement for custom genomes.

### I2 — Chrom-size BED is a hidden manual prerequisite for new genomes

`gpseq_radical.nf` needs `<ref_dir>/<ref_build>_chrom_size.bed` (3 cols: `chrom 0 length`,
main chromosomes only). It's derived from `masking_files/<ref_build>.genome`, which only
exists for hg38/hg19/mm10/mm9 (hand-made by `masking_files/script.sh`). For any new
genome the user must hand-create `masking_files/<ref_build>.genome` or RADICAL errors
("no chrom-size source"). **Fix:** auto-generate the chrom-size BED in PREP_REF — from
the FASTA `.fai` (works for both Ensembl and local-FASTA paths), or from `chrom_sizes_url`
(see I3).

### I3 — Dead `chrom_sizes_url` column in `genomes.csv`

`assets/genomes.csv` carries a `chrom_sizes_url` per genome (the UCSC `.chrom.sizes` URL),
but `resolveMeta` never reads it — it's wired to nothing. It *looks* like it should
automate I2. **Fix:** either wire it up (PREP_REF fetches it → emits `<ref_build>_chrom_size.bed`)
or drop the column to avoid the false impression that it does something.

### I4 — Reference cache lives inside the repo / not reproducible — *hardening*

- Cache dir is `${projectDir}/tools/GPSeqNP/ref` (`nextflow.config:20`): multi-GB bowtie2
  indexes sit in the project tree (one stray `git add` → in history; needs careful
  `.gitignore`), runtime writes into `projectDir` (breaks read-only/shared installs),
  and the `Mus_musculus…bt2` files are owned by **root** from an early docker-as-root run
  (permission landmine for the next PREP_REF). **Fix:** configurable `--ref_cache` default
  *outside* the repo; ideally convert PREP_REF to Nextflow **`storeDir`** (native
  persistent skip-if-present caching) — retires the hand-rolled `ref_ready.flag` token and
  the script's own "don't call concurrently for the same ref" caveat.
- Download isn't hermetic: `http://` (not https), no verification against Ensembl
  `CHECKSUMS`, and a truncated `wget` exiting 0 would silently yield a bad index.
  **Fix:** https + checksum-verify, fail loudly on mismatch.
- Hardcoded `/app/bin/bowtie2-build` (`setup_ref.sh:57`) ties the script to one container
  image's layout (same class as the earlier `/home/scripts/` bug). **Fix:** call
  `bowtie2-build` on PATH.
- Minor: `species` derivation (`setup_ref.sh:16`, `cut -f1 | sed 's/./\L&/'`) only lowercases
  the first char and relies on Ensembl `Genus_species` casing — use `tr '[:upper:]' '[:lower:]'`
  on the whole token for obvious correctness.
