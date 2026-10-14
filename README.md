# GitReview — GitHub Candidate Scorer

Score internship candidates by looking at their actual GitHub work — the code they
wrote, how they commit, how they document. Give the tool a folder of resumes (or one
resume), and it downloads each candidate's original repositories, reads the source,
and produces a score per candidate.

**What it checks** (six dimensions, weighted): clean code (25%), original work (20%),
technical depth (20%), engineering habits (15%), documentation (10%), consistency (10%).
Each is scored 1–5 and combined into a final score out of 10.

---

## Quick Start (3 steps)

### Step 1 — One-time setup (5 minutes, needs a technical person once)

You need two things installed on the Mac running this:

1. **Claude Code** — the AI assistant that does the evaluation. Install with:
   ```
   npm install -g @anthropic-ai/claude-code
   ```
2. **GitHub CLI (`gh`)** — how the tool downloads candidates' repos. Install with:
   ```
   brew install gh
   ```
   then log in (a browser window opens, click "Authorize"):
   ```
   gh auth login
   ```

That's it. Clone this project anywhere you like:
```
git clone <this-repo-url> ~/GitReview
cd ~/GitReview
```

### Step 2 — Ask Claude to score the resumes

Open Claude Code in the project folder:
```
cd ~/GitReview
claude
```
Then type (adjusting the path to where your resume PDFs are):

```
Run the GitReview rubric on the folder ~/Downloads/resumes
```

Claude asks two simple questions:
1. **Single resume or folder?** (it usually already knows from your path)
2. **Results as CSV, or one text file per candidate?**

Then it runs by itself — extracting GitHub links, downloading repos, reading code —
and shows each scorecard as it goes. No other input needed.

*(Comfortable with the terminal instead? Skip Claude and run the scripts directly — see [Running without Claude](#running-without-claude).)*

### Step 3 — See the results

Results land in the `results/` folder inside this project:

- **`results/candidate_score.csv`** — open with Excel/Numbers/Google Sheets. One row
  per candidate: name, which PDF, the six dimension scores, final score out of 10,
  and a short verdict. New candidates are **appended**, so the file grows as you go.
- **`results/<Candidate Name>.txt`** — if you chose flat files: the full scorecard for
  one candidate, with the reasoning and evidence behind every score.

See [Reading the scores](#reading-the-scores) below for what the numbers mean.

---

## Reading the scores

| Score | Meaning |
|-------|---------|
| **8–10** | Exceptional — real open-source engineer; interview with priority |
| **6–8** | Solid genuine candidate — worth an interview |
| **4–6** | Average — some real work, notable gaps |
| **2–4** | Weak — inflated resume, thin actual work |

The six columns before the final score (each 1–5):

- **Clean Code & Conventions** — is the code readable and sensibly organized? (weight: highest)
- **Genuine/Original Work** — their own ideas vs. copied tutorials
- **Technical Depth** — do they tackle hard problems and edge cases?
- **Engineering Process & Habits** — commit messages, version control discipline
- **Communication & Documentation** — could a stranger understand and run their project?
- **Engagement & Consistency** — steady activity over time vs. one-off bursts

The **Summary** column is a one-paragraph human verdict — interview probes and
caveats (e.g., "resume links to someone else's repo") are noted there.

**Important:** scores reflect the GitHub work only. Candidates with no GitHub link in
their resume are skipped and reported — that is information too.

---

## Running without Claude

All the intelligence is in the evaluation, but the mechanical parts are three scripts:

```bash
cd ~/GitReview

# What GitHub links are in a resume?
python3 extract_pdf_links.py /path/to/resume.pdf

# Profile overview + commit history for a candidate
./gh_profile_summary.sh github.com/<username> 3

# Download a candidate's original repos (forks excluded)
./clone_candidate.sh github.com/<username> 3

# Batch: stage every resume in a folder (3 repos each)
./score_all.sh /path/to/resume-folder 3
```

Re-running `score_all.sh` is safe — already-downloaded candidates are skipped, so it
only fetches what's new.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| "API rate limit exceeded" | Run `gh auth login` again — the login expired or was never done |
| "SKIP (no GitHub link)" | The resume has no GitHub URL. Ask the candidate for one, or skip them |
| "Error: no repositories found" | Username parsed wrong, or the profile is private/empty — check the link in the resume |
| Clone hangs or fails mid-batch | Re-run the same command; finished candidates are skipped, it resumes where it stopped |
| CSV row looks garbled in Excel | Open via Data → Import → CSV in Excel, or use Numbers/Google Sheets directly |

---

## Privacy & data

- Only **public** GitHub data is read (anything visible to anyone on github.com).
- Resume PDFs and results never leave your machine — nothing is uploaded anywhere.
- Downloaded candidate code lives in `candidates/` (git-ignored, ~350MB for a batch
  of 35 — delete it when done: `rm -rf candidates/`).
- Scores in `results/` are also git-ignored, so they won't be pushed to GitHub.

## Project layout

```
GitReview/
├── internship-scoring-rubric.md   # the full scoring rules + agent instructions
├── extract_pdf_links.py           # pull GitHub links out of a resume PDF
├── gh_profile_summary.sh          # profile + commit histories (read-only)
├── clone_candidate.sh             # download one candidate's original repos
├── score_all.sh                   # batch: every PDF in a folder
├── candidates/                    # downloaded code (git-ignored, safe to delete)
└── results/                       # scores (git-ignored): candidate_score.csv or per-candidate .txt
```
