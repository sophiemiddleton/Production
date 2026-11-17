# Notes: making `mds.sh` agentic, POMS and prodtools

Written 2026-11-06. This is background for planning, not documentation of
`mds.sh`. prodtools changes often, so check the claims below against the
current repo before relying on them.

## Is an MCP server needed?

Not to start with. `mds.sh` already gives an agent (for example Claude Code
calling it through Bash) most of what it needs:

- **State it can read:** `manifest.env`, the `step_<name>_done` markers and
  `mds.sh status`.
- **Safe retries:** steps can be rerun, `--dry-run`, step ordering checks
  and a lock.
- **Next-step hints:** each step prints the next command.
- **Logs per run** in `run_logs/`.

An agent helps most where the shell scripts stop:

1. **The POMS hand-offs:** launching the ensemble campaign after `publish`,
   and running `json2jobdef` plus a relaunch after `digireco`. This includes
   watching grid jobs and deciding when `validate` can run.
2. **Diagnosis:** reading `validate.txt`/`validate.csv`, spotting a sampled
   fraction that's off from its FCL weight or an input that ran out, and
   tracing it back to a version pin or a file count in `build`.
3. **Choosing input versions** in SAM.

An MCP server is worth building when one of these applies:

- It reaches a system with no good command-line tool (POMS is the candidate).
- It enforces guardrails, such as read-only tools apart from gated write
  tools.
- Other people will use it from Claude clients without a shell on the gpvm.

Cheaper first steps:

- `mds.sh status --json`, and clear exit codes from `validate`.
- A Claude Code skill describing the workflow. It should say which steps act
  outside the workroot (`publish`, `digireco --install`) and that `publish`
  always gets a `--dry-run` first.
- Permission allowlists and a hook that blocks `publish` without a
  successful dry run.

## What prodtools offers

Repo: <https://github.com/Mu2e/prodtools> (read at commit from 2026-10-29).

### 1. MCP servers that bypass POMS

`.mcp.json` registers two servers (code in `mcp/src/`, setup in
`mcp/README.md` and `mcp/SUBMIT.md`):

- **`prodtools` (read-only):** `campaign_status`, `list_campaigns`,
  `find_datasets`, `dataset_details`, `dataset_files`, `locate_file`,
  `trace_provenance`, `run_status`.
- **`prodtools-write`:** `push_cnf` builds the cnf, registers it in SAM and
  creates a campaign. `run_submissions` submits jobs, checks outputs against
  SAM and resubmits what's missing. Also `submit_once` and `run_local`.

These submit directly to `jobsub` and keep their own SQLite record of
submissions. No prodtools code calls `poms_client`. For the reasoning, see:

- `wiki/pages/2026-04-29-remove-poms-from-submit-loop.md`
- `wiki/pages/2026-07-18-direct-recovery-loop.md`

### 2. POMS reference, for driving POMS directly

`wiki/pages/poms-reference.md` is the best write-up of POMS internals found
so far:

- **Client calls:** `poms_client` has
  `launch_campaign_stage_jobs(campaign_name, stage_name)`,
  `submission_details(submission_id)` and
  `update_campaign_stage(..., dataset=...)`.
- **Mu2e wiring:** one fixed `runjobdef` stage (in
  `Production/CampaignConfig/mdc2025_main.cfg`) serves every map file in
  `/exp/mu2e/app/users/mu2epro/production_manager/poms_map/` through a
  `%(map)s` parameter. The `i<stem>` index definitions only set how many jobs
  run.
- **Stage settings for MDC2025 live only in the POMS database.** They're
  edited in the web UI and nothing on disk records them.
- **Untested:** the page says driving POMS through this API is
  "end-to-end on the Mu2e instance: still untested."
- **Recovery caveat:** POMS's `process_status` and `consumed_status`
  recoveries rerun input files whose outputs already exist. Only
  `pending_files` checks for outputs first. This caused data loss in
  Run1Ban.

### 3. Safety patterns worth copying

- Separate read-only and write servers, so read-only tools can be called
  without asking.
- Every write takes `run_as="self"|"mu2epro"`. A `mu2epro` call needs
  `confirm=true` and also triggers a PreToolUse hook that asks the user. If
  the hook can't tell which account a call uses, it asks anyway. See
  `.claude/hooks/mcp-write-guard.sh` and `.claude/hooks/mu2epro-guard.sh`.
- `state: "unknown"` means the query failed. It never means zero, so never
  start a recovery on it.
- Nothing advances by itself. Each slice or recovery is an explicit
  `run_submissions` call, and that call is never wrapped in `timeout`: a kill
  after submission leaves jobs nobody is tracking.

## What this means for MDS

| MDS step | Today | With prodtools |
|---|---|---|
| Input discovery (`build`, Stage0) | `samweb` + version sorting | read-only `find_datasets` / `dataset_details`, usable now |
| Ensemble campaign (after `publish`) | POMS launch as mu2epro | `push_cnf` seems to expect a JSON config, not a prebuilt tarball (from a skim of `mcp/src/prodtools_mcp_write/tools.py`), so it doesn't fit yet |
| digi/reco/ntuple (after `digireco`) | `json2jobdef` + POMS relaunch | likely fits as is: `data/mdc2030/mds3a.json` already defines MDS3a digi/reco with `input_data: dts.mu2e.ensembleMDS3a…` |
| Watching jobs before `validate` | manual | `campaign_status` until the queue is empty, then `validate` |

## Recommended order

1. **Install the read-only prodtools server** (`bash mcp/scripts/install.sh`,
   then `bash mcp/scripts/start_mcp.sh --check`). It's safe and useful now
   for checking inputs and campaign status.
2. **Move the digi/reco/ntuple stages to prodtools** instead of POMS,
   following `data/mdc2030/mds3a.json`.
3. **For the ensemble stage, ask the prodtools maintainers** before building
   anything. The question is whether `push_cnf` could accept the cnf tarball
   that `mds.sh build` already makes, or whether `mds.sh` should write a
   prodtools-style JSON entry instead.
4. **Build a POMS client only if MDS has to stay on POMS.** Use
   `poms-reference.md` as the spec, and expect to be the first to test it on
   Mu2e's POMS.

## Open question

Is MDS production expected to stay on POMS, or can it move to the prodtools
direct-submission path? Steps 2 to 4 depend on the answer.
