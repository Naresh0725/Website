# V1 exam scope and PYQ sourcing proposal
Review date: 2026-10-04. Status: sourcing approval pending. This is a design and source inventory, not an imported dataset or an implemented importer.

## Locked scope
Exactly the ten exams in `v1-launch-exams.json` are approved for V1. The manifest is a planning contract, not a deployed database seed or runtime restriction. Other exam families remain extensible but outside V1. IBPS Clerk/CSA is one canonical exam with historical aliases; SBI Clerk maps to Junior Associate. NTPC graduate/undergraduate and Technician Grade I Signal/Grade III are distinct tracks, not additional launch exams.

The storage model must support unlimited historical cycles, including at least a ten-year inventory window (initially 2016–2025), older authentic records, and incremental 2026 records. Ten years of storage support is not a claim that ten annual examinations or ten complete verified datasets exist.

## Source and coverage inventory
“Documented release” below means an official page/notice records a paper/key release. It does NOT mean the underlying paper was acquired, its final key authenticated, every shift found, or commercial rights cleared. Several old official pages could be searched but timed out on direct fetch. Those records need artifact-level rechecking before import. No acquired paper/shift is certified import-ready by this proposal.

| Exam | Proposed primary source | Documented acquisition leads | Official key position / remaining gap |
|---|---|---|---|
| SSC CGL | SSC current answer-key section and legacy archive [S1] | 2018 Tier I/II; 2021 Tier I/II; 2022 Tier I/II; 2023 Tier II have final-key release records. 2022 has specific notices [S2,S3]. | SSC releases final keys. Obtain exact paper and final-key exports per date/shift; these notices do not establish continuous 2016–2025 coverage. Other years/stages remain inventory pending. |
| RRB NTPC | Official RRB Chandigarh cycle archives and official regional mirrors | CEN 03/2015: CBT1 held March–May 2016, CBT2 release in January 2017 [R1,R2]. CEN 01/2019: CBT1 held Dec 2020–July 2021 and CBT2 releases in 2022 [R3,R4]. CEN 06/2024 undergraduate CBT1 held Aug–Sept 2025 [R5]. | RRB records official keys; R1 explicitly describes updated final keys. Objection-stage keys are provisional. Finality must be authenticated per artifact. Graduate/UG, pay levels, and shifts must not be conflated. |
| SSC CHSL | SSC current and legacy archive [S1] | 2016 Tier I [S4]; archive records for 2018, 2021, 2023 Tier I; 2024 Tier I specific final-key notice [S5]. | Official final keys documented; 2016 and 2024 access windows expired. All-shift acquisition and remaining years/stages unresolved. |
| RRB Group D | Official RRB CEN 02/2018 and RRC 01/2019 archives [R6,R7] | 2018 cycle with January 2019 paper/key release; RRC 01/2019 CBT held in 2022 with October 2022 objection tracker. | Official objection keys documented; source each final/revised key separately. No annual continuity or complete shift coverage claimed. Later cycles require separate inventory. |
| IBPS PO | IBPS CRP PO/MT notices, information handouts, FAQ [B1] | No authenticated actual-paper/final-key archive established for any year in 2016–2025. | IBPS policy says it does not provide papers/answer sheets/right answer keys. Official handout examples are not PYQs. Written authorized archival supply would need evaluation. |
| SBI PO | SBI Careers PO page, recruitment archive [B2] | No authenticated actual-paper/final-key archive established for 2016–2025. | SBI policy says it does not provide papers/answer sheets/right answer keys. No verified ten-year banking claim permitted. |
| IBPS Clerk/CSA | IBPS clerical/CSA CRP notices and FAQ [B1] | No authenticated actual-paper/final-key archive established for 2016–2025. | Same IBPS restriction. Keep notification-era title and CRP number; do not fabricate shifts from coaching recollections. |
| SBI Clerk | SBI Careers Junior Associate page and recruitment archive [B3] | No authenticated actual-paper/final-key archive established for 2016–2025. | Same SBI restriction. Training/sample material cannot establish historical appearance. |
| RRB Technician | Official CEN 01/2018 ALP & Technician archive [R8]; CEN 02/2024 official notices [R9,R10] | Legacy 2018 cycle CBT2 release in February 2019; 2024 Grade I and Grade III paper/objection-key notices. | Official objection keys exist; finality unresolved per paper. Keep historical shared ALP/Technician stages separate from modern Grade I Signal and Grade III. Never relabel an ALP-only question as Technician. |
| SSC MTS | SSC current and legacy archive [S1] | 2019, 2020, 2021 Paper I final-key records; MTS/Havaldar 2024 final-key notice [S6]. | Official final keys documented. 2024 candidate access was 26 March–25 April 2025; not a permanent public question archive. Other years and all shifts unresolved. |

For all ten exams: individual date/shift/question-ID coverage remains unconfirmed until exact source files are acquired and reviewed. A notice giving an exam date range cannot establish possession of every shift. Banking gaps are an explicit sourcing blocker, not permission to substitute memory-based papers.

Secondary acquisition route, subject to approval: licensed archival suppliers/publishers able to supply original paper artifacts, authenticated keys, per-question provenance and written digital/commercial reuse rights. No publisher is currently approved. Books, coaching sites, Telegram files, marketplace datasets and “memory-based PYQs” are not self-authenticating. A commercial license alone does not prove historical appearance. Candidate-supplied official exports may be reviewed only with lawful sharing, consent and privacy redaction; do not collect portal passwords or bypass expired access.

## Classification and verification
The five public categories are mutually exclusive for a specific question occurrence. Historical verification is occurrence-specific: a question verified in one paper does not automatically become verified in another.

| Category | Required evidence / handling |
|---|---|
| VERIFIED_PYQ | Authentic exact paper occurrence, stage/date/shift or official paper identity, exact source question/option mapping, and an authenticated final official answer key or demonstrably authorized equivalent final key. Independent paper and answer review approved. |
| PAPER_VERIFIED | Historical appearance authenticated, but final key missing, provisional, disputed or not authenticated. Any editorial solution is explicitly separate and cannot confer official-key status. |
| UNVERIFIED | Claimed historical source cannot yet be authenticated; quarantine, review required, excluded from verified-PYQ selection and coverage totals. |
| ORIGINAL_PRACTICE | Independently authored practice with authorship and rights recorded; never assigned a historical occurrence merely for similarity. |
| GENERATED_PRACTICE | Generated content with model/generation provenance and review; never upgraded to PYQ based on resemblance. |

Known reconstructions, recalled questions and “similar questions” are rejected from the historical import route, not parked in UNVERIFIED as though they could establish exact appearance. They may remain in a non-published source registry for reference; any separately authorized practice use requires honest provenance and rights review, never a fabricated authorship claim.

Missing official sources mean review is required. A preserved copy with a demonstrable authentic chain can be considered; a coaching answer, two agreeing websites, a model response, a scorecard alone, or a filename containing “official” cannot substitute for proof.

Workflow:
1. Register source and rights basis; snapshot source notice, publisher, URL, retrieval time, checksum and provenance chain.
2. Acquire allowed artifacts into private staging. Scan files, redact candidate PII, preserve a restricted original only where justified by consent/retention policy.
3. Identify exam, recruitment cycle, stage, track, held date, shift/session, paper/form and language. Unknown values remain unknown and block final verification when identity is ambiguous.
4. Extract/OCR without inventing text. Preserve raw text, page/bounding-box locator, question ID, option IDs, assets and extraction version.
5. Validate structure and compare against the source visually, including equations, Hindi text, figures and shared passages. Low confidence or missing content goes to quarantine.
6. Match official answer-key question/option IDs; distinguish candidate-selected responses from correct responses. Record final/provisional status, revisions, withdrawn questions and multiple accepted answers.
7. Independent content and provenance/key reviewers record decisions; importer cannot approve its own verification. Rights approval is a separate gate.
8. Publish through a database-controlled transition only after mandatory evidence and approvals. No privileged importer bypass; all promotions, corrections, withdrawals and source changes are audited.
9. Later corrected official keys create new immutable versions and invalidate stale approval/publication eligibility. Preserve the historical evidence and supersession chain.

## Database design changes proposed
Existing schema already has exams, stages, syllabus versions, subjects/topics, versioned questions/options/translations/answer keys, sources, papers, occurrences, reviews, and import batches/items. These extensions are proposed for the Question Bank implementation, not claimed implemented here.

| Entity/change | Responsibility and constraints |
|---|---|
| exam_aliases, exam_tracks, exam_cycles | Preserve historical names, notification number/year and actual exam dates separately; cycles belong to one canonical exam. |
| exam_papers extension | Stable non-null canonical paper identity using cycle, track, stage, held date/session, official paper/form identity; stage and cycle must belong to the same exam. Unknown-identity imports remain staging candidates. Unique identity enforced in DB, not nullable-column conventions. Record cancellation/re-exam relationships. |
| paper_sections | Original subject/section, sequence and marking context independent of editable syllabus/topic mapping. |
| sources + source_artifacts + source_rights | Publisher, original URL, retrieval time, SHA-256, media type, private storage key, chain of custody, rights scope/expiry/evidence and redaction lineage. Sources can have multiple artifacts and revisions. |
| question_evidence | Many-to-many links between occurrence/version and artifacts; evidence role (paper/key/explanation), original IDs, page/locator, extraction version and reviewer. Preserve every additional source after deduplication. |
| paper_key_versions + occurrence_key_entries | Final/provisional/authenticated status, issuing authority, supersession, accepted source option IDs, dropped/bonus/disputed states. Different historical scoring decisions for identical question text must remain occurrence-specific. |
| question_translations + options + assets | Raw and canonical multilingual text, original option IDs and order, mathematical content, diagram hashes, shared passage/group membership. Translation never creates a new historical occurrence. |
| classification/publication guards | Historical occurrence status separate from original/generated origin and from rights/publication eligibility; VERIFIED requires matching final-key entry and evidence. Block generated/original records from historical claims. Exact five labels exposed by a validated view/API. |
| coverage_inventory | Per exam/cycle/stage/paper/shift: discovery pending, notice found, artifact acquired, paper verified, key verified, rights cleared, published, unavailable, or not-held. NOT_HELD needs evidence; unknown is not not-held. Track expected vs acquired vs verified counts, allowing unknown totals. |
| import_batches/items/jobs | Input/schema/parser versions, digest, idempotency key, source links, row offsets, resumable checkpoints, leases, retries, validation report, duplicate/conflict decisions and actor. |
| review/audit events | Append-only reviewer decisions, old/new state, reason, evidence references, actor and timestamp. Publication permissions separate from source upload and rights approval. |

Index occurrence paper/question ID, paper cycle/stage/date, source hashes, content fingerprints, topic/language/difficulty and import job state. Use normal relational indexes first; measure before partitioning. Object storage holds PDFs/images, PostgreSQL holds searchable normalized metadata and evidence links. Retention is not capped at ten years.

## Import contract and scalable process
Preferred package: UTF-8 manifest.json, papers.jsonl, questions.jsonl, sources.jsonl and separately checksummed artifacts. A CSV/XLSX adapter may convert into this contract; PDFs are evidence inputs, not trusted structured records. JSONL permits streaming and resumable chunks. Require schema_version and stable external_record_id.

Question record fields:
- Exam slug, cycle/notification code and label, cycle year, held date, track, stage, official paper/form ID, shift/session/time zone, section, source question ID/number.
- Subject/topic mappings and taxonomy version; language; exact stem; options with source option IDs and display order; group/passage/diagram references.
- Answer object (accepted option IDs or numeric answer, key status, key revision, dropped/bonus flags). Allow null when unavailable; do not infer from the candidate response.
- Explanation text, language, author/source and editorial/generated status. If missing, keep null and route to editorial review; never claim a new explanation came from the authority.
- Origin and requested classification (untrusted input), source/artifact IDs, paper/key/explanation locators, publisher/URL/retrieved_at, SHA-256 and rights record.
- Extraction method/version/confidence and review requirements. Server computes actual classification from evidence.

Process: source/rights gate → file validation → private staging → streaming extraction → structural checks → identity resolution → exact/fuzzy duplicate detection → human evidence/key review → dry-run report → approved transactional publication.

Use bounded transactional chunks, durable jobs and resumable offsets; avoid a single giant transaction or in-memory dataset. Retry the same batch/row safely. Unique batch digest and external record constraints plus transactional insert/conflict handling prevent parallel imports from duplicating records. Reports count inserted, linked, duplicate, conflicting, rejected and pending rows with row-specific reasons.

Deduplication:
- Artifact SHA-256 catches repeated files; paper identity + official question ID catches repeated occurrences.
- Versioned canonical content fingerprint covers language, stem, options, group context and asset hashes. Preserve original strings and option mapping.
- Exact matches can reuse question content while adding distinct paper occurrences and all provenance. Different official keys remain separate occurrence-level decisions.
- Near matches generate review candidates only. Do not auto-merge translations, rearranged options, changed numbers/negation or diagram variants.
- Conflicting payloads for an existing paper/question ID are quarantined, never silently overwritten. Hash equality is a duplicate signal, not evidence of authenticity.

Before production bulk import: approve this sourcing plan, build/import tests with synthetic fixtures, then review a small authorized pilot and its coverage/rights report. No bulk job starts without the user's sourcing approval and batch publication authorization. Test requirements include concurrent duplicate imports, resumable retry, source preservation, invalid verification attempts, wrong-paper keys, provisional keys, missing rights, translated/option-order duplicates and immutable published versions.

## Rights and privacy
Publicly reachable does not mean public domain or licensed for a commercial subscription bank. India's Copyright Act includes copyright in government works [L1]; resolve the applicable permission/license for each artifact before publication. This is an acquisition control, not a conclusion that all papers have the same copyright owner or that all reuse is prohibited.

Obtain evidence of rights to reproduce, digitize, adapt/translate and commercially display where applicable, including third-party passages/images and publisher explanations. Attribution and purchasing a book do not themselves supply these permissions. Website reproduction policies must be checked for their scope and third-party exclusions; none is treated here as a blanket license. Candidate consent to share personal data does not grant underlying question copyright. No scraping behind access restrictions. Provide a rights-dispute/takedown process and retain an audit trail.

## Source register
Links below establish policies or release leads, not possession of an importable dataset.

- S1 SSC legacy answer-key archive: https://ssc.nic.in/Portal/AnswerKey ; current: https://ssc.gov.in/home/answer-key
- S2 CGL 2022 Tier I final-key notice: https://ssc.nic.in/SSCFileServer/PortalManagement/UploadedFiles/FinalAnswerkey_CGLE2022_tier1_27022023.pdf
- S3 CGL 2022 Tier II final-key notice: https://ssc.nic.in/SSCFileServer/PortalManagement/UploadedFiles/Write_up_final_answer_key_29052023.pdf
- S4 CHSL 2016 Tier I: https://ssc.nic.in/SSCFileServer/sscold2websitepdf/english/notice_pdf/FinalAnswerkey_chsl_09062017.pdf
- S5 CHSL 2024 Tier I: https://ssc.gov.in/api/attachment/uploads/masterData/NoticeBoards/Final%20Answer%20Key%20and%20marks%20CHSLE%202024%20Tier-I161024.pdf
- S6 MTS 2024: https://ssc.gov.in/api/attachment/uploads/masterData/NoticeBoards/approved_writeup_26425.pdf
- R1 NTPC 2016 historical access/final-key notice: https://www.rrbcdg.gov.in/uploads/2015/rrb-notice-ntpc-24-03-2017.PDF
- R2 RRB historical archive: https://www.rrbcdg.gov.in/archive.php
- R3 NTPC CEN 01/2019 archive: https://www.rrbcdg.gov.in/2019-01-ntpc.php
- R4 NTPC CBT1 dates and access: https://www.rrbcdg.gov.in/uploads/2019/01-NTPC/result_level2.pdf
- R5 NTPC UG 2025 CBT1 release: https://www.rrbcdg.gov.in/uploads/2024/06-NTPCUG/062024-CBT1-ObjectionTracker.pdf
- R6 Group D 2018: https://www.rrbcdg.gov.in/2018-02-grpd.php
- R7 Group D 2019 cycle/2022 exam: https://www.rrbcdg.gov.in/2019-01-rrc.php
- R8 Legacy Technician: https://www.rrbcdg.gov.in/2018-01-alptech.php
- R9 Technician 2024 notices: https://rrbsecunderabad.gov.in/advertisement_category/cen-no-02-2024/
- R10 Technician 2024 archive: https://www.rrbcdg.gov.in/2024-02-tech.php
- B1 IBPS official FAQ: https://www.ibps.in/index.php/faq/
- B2 SBI official PO FAQ: https://sbi.bank.in/web/careers/probationary-officers
- B3 SBI official Junior Associate FAQ: https://sbi.bank.in/web/careers/junior-associate
- L1 Copyright Act, Chapter V, section 28: https://copyright.gov.in/Copyright_Act_1957/chapter_v.html

## Approval boundary
Scope locked; sourcing plan pending approval. No question files acquired for bulk import, no migrations applied, no importer/CBT/payment/dashboard/analytics implementation in this change. Existing authentication and attempt-access rules remain as previously implemented. Approving this proposal authorizes the described acquisition and implementation direction; it does not certify unavailable papers or confer third-party reuse rights.
