# Internship GitHub Scoring Rubric

Design notes for a prompt that drives an agent to evaluate internship candidates' GitHub profiles.

> **New here?** See `README.md` for setup, usage, and how to read the results. This
> document is the scoring spec the agent follows.

## Invocation Behavior (agent instructions)

When this rubric is invoked, the agent MUST first ask the user two questions before doing any work:

### Question 1 — Scope

> "Do you want to evaluate a **single resume** (one PDF file) or a **folder of resumes** (batch)?"

- **Single file:** run the per-candidate flow (steps 1–6) on that PDF and produce one scorecard.
- **Folder:** run `score_all.sh` on the folder to stage everyone, then evaluate each staged candidate and produce one scorecard per candidate.

### Question 2 — Output format

> "How do you want the results saved — **CSV file** or a **per-candidate flat file**?"

- **CSV** — open and **append** to `results/candidate_score.csv` (create the file
  with the header row if it doesn't exist; never overwrite existing rows).
  Headers, in this order:

  ```
  Candidate Name, PDF File Name, Clean Code & Conventions, Genuine/Original Work,
  Technical Depth, Engineering Process & Habits, Communication & Documentation,
  Engagement & Consistency, Final Score, Summary
  ```

  - One row per candidate.
  - The six middle columns carry the individual parameter scores (1–5 each).
  - `FINAL SCORE` is the weighted 1–10 score (one decimal).
  - `SUMMARY` is a single free-text column with the verdict about the candidate. Commas inside Summary must be escaped (wrap the field in double quotes, doubling any internal quotes) so the CSV stays parseable. Scores are plain numbers, never quoted.

- **Per-candidate flat file** — one plain-text file per candidate containing the
  score results (the full scorecard: per-parameter scores with justifications
  and evidence). File name: `results/<Candidate Name>.txt` (spaces kept, e.g.
  `results/Abhinav M.txt`). For folder runs, one file per candidate is written
  alongside each other.

Default when the user is unsure: **CSV**.

**Output location (always):** the results file(s) are created inside a `results/`
directory in the same folder where the scripts live — `~/AI/GitReview/results/`
(e.g. `candidate_score.csv` or `<Candidate Name>.txt`). Create the directory
if it does not exist. Both `results/` and `candidates/` are git-ignored, so
downloaded clones and score files are never committed.

In every mode the full human-readable scorecard is still shown in the conversation;
the chosen output file is the persisted record.

## The Flow (option B)

The prompt instructs an agent to do everything:

1. Read the submission PDF (resume + GitHub link) — extract text and hyperlinks with `extract_pdf_links.py`
2. Extract the GitHub profile URL (flagged `GITHUB` in the links output)
3. Pull profile metadata, original-repo list, and commit histories with `gh_profile_summary.sh`
4. Download the top original repos for source reading with `clone_candidate.sh` (or stage the whole folder at once with `score_all.sh`)
5. Read actual source files locally in the cloned repos
6. Produce a scorecard with scores and evidence

**Excluded:** forked repositories are never considered.

### Tools (all in `~/AI/GitReview/`)

| Tool | Purpose |
|------|---------|
| `extract_pdf_links.py <resume.pdf>` | Extracts all hyperlink URIs (GitHub URLs flagged) + text from a resume PDF. Stdlib only, no dependencies. |
| `gh_profile_summary.sh <profile-url> [top_repos]` | Profile header, table of original (non-fork) repos, and commit histories (date/author/message) for the top N originals. Uses authenticated `gh` CLI. |
| `clone_candidate.sh <profile-url> [max_repos]` | Shallow-clones the N most recently pushed original repos into `candidates/<username>/`. Re-runnable; already-cloned repos are skipped. |
| `score_all.sh <resumes-folder> [clone_limit]` | Batch runner: loops over every PDF in a folder, extracts the GitHub profile link, and clones top originals for each. Skips candidates already staged; prints a summary (staged / skipped / no-link). |

### Batch flow (folder of resumes)

```bash
cd ~/AI/GitReview
./score_all.sh "<path-to-resumes-folder>" 3   # stage everyone, 3 repos each
```

This stages all candidates under `candidates/<username>/`. Then, for each
candidate, run the per-candidate evaluation below (profile summary → read
cloned source → scorecard). Candidates whose resumes contain no GitHub link
are reported and skipped.

Workflow notes for the agent:

- Run `gh_profile_summary.sh` first — it decides which repos are "most substantial/recent originals" for the deep code read. Resume-listed repos that turn out to be forks (or other people's repos) are excluded and noted in the scorecard.
- After cloning, read source files with the Read/Grep tools directly under `candidates/<username>/<repo>/` — no web fetching needed.
- Commit evidence comes from the histories printed by `gh_profile_summary.sh` (or `git log` in the clone).

## Purpose

Score candidates for a **software engineering internship**. Looking for signals of:

- Genuine, self-driven coding work (not inflated numbers)
- Real engagement vs. tutorial-following projects
- *How* they work: commit habits, READMEs, code organization
- **Clean code conventions** (explicitly important)

Note: most submitted code is AI-generated; this is NOT penalized. No red-flag dimension.

## The Six Parameters and Weights

| # | Parameter | Weight | What it measures |
|---|-----------|--------|------------------|
| 1 | **Clean Code & Conventions** | 25% | Readable naming, consistent formatting, sensible structure, idiomatic patterns. Assessed by reading actual source files. |
| 2 | **Genuine/Original Work** | 20% | Self-driven projects vs. tutorial-following; unique ideas, custom solutions. |
| 3 | **Technical Depth** | 20% | Project complexity actually handled + edge cases/correctness. Complexity tiers below. |
| 4 | **Engineering Process & Habits** | 15% | Commit history quality, incremental development vs. one dump, version control sanity. |
| 5 | **Communication & Documentation** | 10% | README quality, docs, whether a stranger could understand and run the project. |
| 6 | **Engagement & Consistency** | 10% | Activity over time, recency. Weighted low: students have exam-season gaps. |

Weighting logic: top three (60%) = who they are as a coder today; bottom three (40%) = coachable habits.

## Complexity Lens (inside Technical Depth)

These are intern submissions — judge complexity pragmatically, not like a staff-engineer
architecture review. Technical Depth = how complex the project actually is **plus**
edge cases/correctness.

### What counts as a "hard thing"

A hard thing is a problem whose wrong solutions are *invisible until they bite* — the
project had to think about something that tutorial code never touches. Count a hard
thing only if the code shows it handled, not just present. Common intern-level examples:

- **State & correctness under change** — races/idempotency handled (locks, atomic transactions, retry-safe writes, conflict detection when data changes mid-flow), cache/state invalidation when sources of truth disagree
- **Failure & fallback paths** — what happens when an external call fails/times out: retries, fallbacks to a second provider, partial-failure recovery, degraded-but-working behavior
- **Data integrity & domain invariants** — money/math done right (integer minor units, Decimal, no float drift), uniqueness/constraint enforcement, validation at trust boundaries (user input, file uploads, API params), malformed input survived rather than crashing
- **Coordination between moving parts** — multiple services/windows/processes that must agree (webhooks ↔ database state, background jobs ↔ foreground UI, multi-step pipelines with ordering constraints)
- **Non-trivial algorithms or data modeling** — matching/allocation/parsing logic with real rules (reconciliation across periods, schema inference, text extraction), data structures chosen because the naive one doesn't scale

### What does NOT count as a hard thing

- Adding a technology (Kafka, K8s, Redis, microservices) without a problem that needs it
- File/folder count, LOC, number of endpoints, "clean architecture" folder naming
- Anything visible only in README/claims — code or it didn't happen
- Config, scaffolding, boilerplate, CRUD over one table, auth via a single library call
- Prompt engineering alone (talking to an LLM is one API call; the pipeline *around* it may be a hard thing)

### Tier table

| Tier | Score | What you see in the code |
|------|-------|--------------------------|
| Multi-part | 4–5 | 2+ distinct hard things (from the list above, different categories) genuinely working together — all pointable in code |
| Single-part | 2–3 | One hard thing done properly — or several claimed but only one real |
| Basic | 1 | CRUD/tutorial-level only; nothing hard attempted, or everything is stubs |

Scoring within Multi-part: 5 means the hard things *interact correctly* (the fallback
considers the race; the transaction covers the invariant), 4 means each works but
seams between them show gaps. Scoring within Single-part: 3 means the hard thing
survives realistic misuse; 2 means it works only on the happy path.

The evidence rule that keeps it honest: **you must name the hard thing you saw in the
code** (file/function). If you can't point to it, the complexity doesn't count. Stubs
and README-only claims score at the tier below the claim. Then adjust within the tier
using edge-case handling and correctness (e.g., real fallbacks and boundary handling
push a Single-part 3 up toward 4; bugs that break the core path pull it down).

## Scoring Scale

- Each parameter: **1–5** (1 = absent/bad, 3 = adequate, 5 = excellent)
- Final score: weighted, expressed **1–10**:

  `Final = (0.25·CC + 0.20·Orig + 0.20·Depth + 0.15·Proc + 0.10·Comm + 0.10·Cons) × 2`

  Max = 10, floor = 2. Real candidates cluster ~4–8.

## Evidence-Gathering Depth (option B)

- Profile-level review of everything (repos, names, descriptions, languages, READMEs, commit stats) — via `gh_profile_summary.sh`
- Then **read actual source code locally, in the top 2–3 most substantial/recent original repos cloned by `clone_candidate.sh`**, for the Clean Code judgment

## Output Format (option C)

Full scorecard per candidate:

- Each parameter's 1–5 score with 1–2 sentence justification citing specific evidence (repo names, commit patterns, code examples)
- Final weighted score (1–10)

In addition, per the Invocation Behavior section, results are saved either by appending
to `results/candidate_score.csv` (one row per candidate) or by writing one
`results/<Candidate Name>.txt` flat file per candidate — the user's choice at invocation.

## Open Questions (remaining)

- Use resume context or score GitHub cold?
- Anything else before drafting the final prompt?
