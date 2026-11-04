# pressR successor qualification — 3 November 2026

## Purpose, baseline and preservation

pressR serves researchers analysing pressure-sensor recordings. Its principal
journeys are importing measurements with correct channel identities and units,
calculating explicitly defined summaries and temporal profiles, inspecting data
in Shiny, and exporting reproducible bundles, tables and reports.

The manuscript baseline remains commit `5f5b370` (0.1.0). The existing, unpublished
0.2 successor was preserved in its original checkout and copied into an isolated
worktree. Current upstream `d8fbd2c` contributes branding/packaging repairs; those
were integrated without discarding the successor. No study data were added.
Authorship, ORCID and legal notices remain the maintainer's existing metadata.

The integrated baseline passed 1,695 assertions with two explicitly unavailable
private-design checks. That is software evidence, not a fresh reanalysis of the
historical study corpus. Earlier study reconciliation and performance receipts
remain historical evidence; they do not establish current-release acceptance.

## Strategy and acceptance

1. Essential integrity repairs: validate actual object fields and complete layout
   contracts, preserve units and source paths, and repair representable numerical
   failures. Use independent small analytic examples, malformed inputs and source
   byte preservation. Refuse unsupported cases clearly rather than invent data.
2. Dependable persistence and use: retain exact measurements through bundles,
   recover output files after reported failures, reject archive collisions, and
   exercise browser upload, recovery, comparison, temporal analysis and downloads.
   Validate real HTML/PDF reports, unavailable calibration and selected masks.
3. Reproducible source milestone: document intentional 0.1-to-0.2 changes, preserve
   the frozen API baseline, build an exact archive, run full and required-only
   checks, enforce the existing successor coverage/API gates, and independently
   review documentation and installed first use. Observe hosted checks on the
   eventual published commit before claiming platform readiness.
4. Later work: fresh complete private-corpus reconciliation, prospective method
   validation, clinical use, and a formal release/DOI require separate evidence.
   No published manuscript environment or source recordings are replaced.

## Confirmed findings and current repair record

| Priority | Evidence and user impact | Action and validation |
| --- | --- | --- |
| Essential | Mutated layouts bypass shallow validation and can produce invalid physical quantities; absent exact fields can partially match unrelated names | Validate full layouts and exact required fields; malformed-state and analytical regressions |
| Essential | Direct CSV/ASCII/force readers omit the source path used by export protection | Retain exact source provenance and reject source overwrites before writing; byte-preservation probes |
| Essential | Finite arithmetic can overflow in force, centre-of-pressure and integration intermediates | Preserve ordinary calculations and qualify bounded numerical repairs against independent oracles |
| Essential | CSV-only bundles change floating-point values and therefore measurement-bound reference hashes | Version 2 retains exact typed measurements, with version 1 compatibility; exact-object and locked-reference comparisons |
| Essential | Decimal readers corrupt some extreme or zero-padded numeric tokens; inferred CSV layouts can replace or reorder sensor identities | Bound nonzero decimal magnitudes to `1e-290`–`1e290`, check conversion, align wide sensor labels and refuse incompatible long IDs; independent decimal and asymmetric COP probes |
| Dependable use | Atomic rename alone cannot replace an existing Windows output; replacement failures need recovery | Stage completed output, preserve the old file, restore after failure and retain/report any unrecoverable backup |
| Dependable use | Archive selections `one.asc` and `./one.asc` silently become one output file | Reject aliases before publication and protect staged targets; real archive fixtures and source byte checks |
| Dependable use | Navbar text is almost indistinguishable from its background; plots have generic alternatives | Scoped contrast fixes and meaningful plot descriptions; actual browser checks |
| Dependable use | Report metadata is interpreted as Markdown/HTML, and foot panels/tables clip content | Escape literal table cells for HTML/LaTeX, include the required LaTeX table dependency and split wide panels; actual rendered payload probes and visual PDF review |
| Provenance | An unresolved draft Zenodo identifier was advertised as published; metadata-only names can be partially matched as recorded identities | Keep draft status explicit and use exact provenance fields; primary metadata lookup and report checks |

The typed bundle format uses R serialization. Checksums establish integrity, not
sender authenticity; trusted input is required. Report/export recovery covers
reported failures, not process termination or competing writers. Optional study
assets remain linked by explicit acquisition keys; matching bytes do not prove
that recordings share an acquisition identity.

The reference observations were checked against primary sources. The
[Nyikos paper](https://pferdeheilkunde.de/files/20050301.pdf), abstract p.187,
supports the six saddle values and their 26-horse/trot context. The
[Armstrong abstract](https://pubmed.ncbi.nlm.nih.gov/9710782/) supports the
case-control EMED observation and its limited discrimination. Neither is treated
as a universal diagnostic threshold. Unsupported older values remain withdrawn.

## Verification and handover

The 4 November checkpoint preserves all 315 originally present files, including
bytes, modification times, modes and inodes; the originally deleted snapshot
remains absent. Original HEAD, branch and working-tree status are unchanged.

Independent exact-rational checks cover 42 force/COP/PTI/impulse results within
two ULP of the correctly rounded binary-input result. The final affected core
lane passes 393 assertions; the persistence lane passes 233, with a later reserved
device-name correction covered by 75 focused assertions. App/report tests pass
66 assertions. All six template/format combinations render, and actual browser
downloads, failure recovery, comparison refusal and session isolation were
exercised. Eighteen control states have contrast at least 6.08:1; all seven tabs
fit a 390-pixel viewport, with wide tables scrolling inside their containers.
These are bounded checks, not full accessibility or cross-platform certification.

Strict text conversion has a measured cost. The same synthetic 10,000-frame by
256-sensor CSV takes 6.594 seconds versus 0.723 seconds in the preserved baseline;
both yield identical pressure/time hashes. Maximum R vector heap is 134.1 versus
77.8 MiB. Process RSS also rose, but development tooling in the candidate process
prevents attributing that entire difference to parsing. Further performance work
must preserve the corruption checks and belongs after this integrity milestone.

The first exact source archive built successfully and passed its full check with
zero errors, zero warnings and two NOTEs. One NOTE identifies unqualified utility
calls being repaired; the other records a new submission/development version.
Fifteen installed first-use checks pass. Final archive qualification and source
publication remain in progress; hosted checks must be observed on the published
commit before claiming platform readiness.

The blocking vocabulary check and workflow syntax check pass. Broader style
diagnostics are retained separately; the existing workflow deliberately checks
vocabulary without requiring cosmetic renaming of supported arguments. The
successor API and 95% coverage gates remain required and are not relaxed.

Use the prerequisites and exact commands in `README.md` to install, inspect the
synthetic example and launch Shiny. Private study reconciliation and prospective
clinical validation remain outside this software milestone; no release, DOI,
submission or deployment has been performed.

### Final source checkpoint, 4 November

The final archive is `pressR_0.2.0.9000.tar.gz`, SHA-256
`49289e02024f2a20cf4d5c2082e2033f9ab96ddd2be4e39113564604d143acd9`.
Its 270 regular files contain no private study scripts or recordings. The
namespace correction passes code analysis. The final installed suite passes
1,877 assertions with zero test warnings and two explicit private-design skips.

The full archive check nevertheless finishes with **two errors, one warning and
one NOTE**: the machine exhausted disk space during vignette rebuilding and PDF
manual generation, reporting `No space left on device` and inability to create
`R_TempDir`. The required-only follow-up was stopped and is incomplete. Coverage
has not run against this final archive; the 95% gate remains required. No overall
final check pass, main publication or hosted result is claimed.

Separately rendered documentation is preserved: all 121 Rd files match the
reviewed 107-page manual, with no clipped words or TOC/link mismatches. The three
vignette sources match the reviewed site inputs. Scientific images retain their
colours; 353 checked code-text elements in each site theme have minimum contrast
5.18:1 (light) and 5.33:1 (dark). All cross-reference targets survive the link
wrapping repair. The actual synthetic production-browser script passes after
correcting its hidden-tab navigation and no-op input waits. Final site generation
from the archive remains pending.

Next action: restore sustained disk headroom, rerun the unchanged final archive's
full and required-only checks, measure coverage without weakening the gate,
complete final installed first use and site verification, then pull/review/publish
the completed source milestone and observe its hosted checks. The original dirty
production checkout and five unfinished study-specific scripts remain preserved.
Current working evidence is maintained outside the package archive; no unrun
check is counted as a pass. The README gives the installation and first-use path.

### Completed local qualification after disk recovery

The same final archive subsequently passed a fresh full check with zero errors,
zero warnings and one incoming development NOTE, and a required-only check with
zero errors, zero warnings and two NOTEs (development version and optional V8
unavailable for HTML math rendering). Installed assertions pass 1,877/full and
1,819/minimal, with two and eight named skips respectively. Coverage is 95.78984%,
meeting the unchanged 95% gate. Fifteen installed first-use checks pass.

The final site has 132 HTML pages and no broken references among 5,901 local HTML
links and 54 CSS references. Forty-eight browser page/theme/viewport states pass;
720 sampled scientific image pixels match their source images. The successful
stock manual has 107 pages, 121 contents entries and 660 numeric links with no
mismatches or out-of-page words; 19 selected pages were visually reviewed.

The earlier ENOSPC results remain preserved. Local source qualification is now
complete; publication and hosted results are recorded separately. Private-corpus
and clinical acceptance, formal release/DOI and deployment remain separate.
