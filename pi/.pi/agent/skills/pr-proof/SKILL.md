---
name: pr-proof
description: Manually validate dd-source PRs in a user-specified Atlas cluster, collect reproducible operational proof, generate clean VHS screenshots from real CLI output, and update the PR Testing section without removing or rewriting existing evidence. Use when deploying a PR to an explicitly approved Atlas target, validating compatibility, or preparing PR evidence.
---

# PR Proof

Validate PRs in a user-specified Atlas cluster and produce review-ready evidence from real command output.

## Core Rules

1. Read all applicable `AGENTS.md`, domain rules, deployment rules, and Kubernetes rules before acting.
2. Before running any deployment or validation command, share a concrete test scenario, tool set, and exact ordered command list. Run only the commands the user explicitly approves; any added or changed command requires renewed approval.
3. Respect the user's requested tool boundary:
   - Always prioritize Bazel for deployments.
   - Do not use Conductor or Rapid when a Bazel deployment is available.
   - Use Conductor or Rapid only when Bazel is not a viable option. Explain why Bazel cannot be used, propose the exact alternative command and scope, and obtain explicit user approval before running it.
   - If the user requests a Bazel deployment, do not substitute Conductor or Rapid.
   - If they request kubectl-only evidence, visible proof commands must use only `kubectl`.
   - Before using Rapid, traverse the Rapid help tree relevant to the requested operation.
4. Before any deployment or operational testing, require the user to specify the exact Atlas cluster and confirm that they have already verified it is the intended validation target. The cluster may be staging or production.
5. Treat the user-provided Atlas cluster as the approved validation boundary; scope every deployment and test to the explicitly approved service, installation, datacenter, and namespace within it.
6. Every `kubectl` command must explicitly include both:
   - `--context <context>`
   - `--namespace <namespace>`
7. Do not deliberately modify runtime-sensitive settings unless they are part of the approved test scenario.
8. Minimize side effects and prefer read-only validation when it can prove the behavior under test.
9. Always clean up temporary resources and restore state changed by the approved test scenario.
10. Store recordings, screenshots, transcripts, and helper files under `/tmp`, never in the repository.
11. Never claim that evidence proves more than the visible commands and outputs demonstrate.

## Phase 1: Understand the PR

Collect:

- PR number, commit, branch, and stack position.
- Exact code paths and behaviors under test.
- Existing PR description and its current `## Testing` section.
- Exact Atlas cluster and the user's confirmation that they have verified it is the intended validation target.
- Deployment target and approved installation within that Atlas cluster.
- Control installation, if backward compatibility must be demonstrated.
- Expected image digest or other artifact identity.
- The user's preferred test scenario, if they already have one.
- The behavior to prove, expected result, constraints, and acceptable side effects.
- Any tools the user requires or forbids.

If the user has not supplied a complete test scenario, propose one based on the changed behavior. Do not begin deployment or operational testing until the user approves the scenario, tool set, and exact commands.

## Phase 2: Propose the Validation Plan

Start by asking the user for their intended test scenario, expected result, and tool constraints. Then propose a concrete scenario when the user has not provided one, or refine their scenario when needed.

The plan should state:

1. Behavior being validated and why the scenario proves it.
2. Exact build or deployment command.
3. Exact user-validated Atlas cluster, Kubernetes context, namespace, service, and installation.
4. Installations and resources that must not be changed.
5. Proposed tool set and why each tool is needed.
6. Exact ordered commands for deployment, baseline capture, test execution, evidence capture, cleanup, and final health checks.
7. Expected output or state for each validation step and clear pass/fail criteria.
8. Side effects, risks, temporary resources, and state changes.
9. Cleanup commands and how cleanup will be verified.

Present the scenario, tool set, and commands before execution and ask the user to confirm or revise them. Approval applies only to the commands shown. Do not substitute tools, improvise additional operational commands, or expand scope without presenting the revised plan and obtaining explicit approval.

Call out risk explicitly. If testing requires a mutation, offer a read-only or lower-impact alternative first.

## Phase 3: Deploy Safely

Use only the approved deployment mechanism. Prefer Bazel whenever it is available. Conductor or Rapid may be used only after Bazel has been ruled out and the user has explicitly approved the exact alternative command and scope.

For Bazel deployments:

```console
bzl run //<exact-target>
```

Never replace a requested Bazel deployment with a Conductor or Rapid run.

Record:

- Exact target.
- Commit under test.
- Deployment revision.
- Previous artifact or image.
- New artifact or image.
- Scope of the deployment.

Confirm that unapproved installations were not targeted.

## Phase 4: Run the Approved Test Scenario

Execute only the approved commands, in the approved order, with the approved tools and scope.

For each step:

1. Confirm that the command matches the approved plan before running it.
2. Record the real command and relevant output.
3. Compare the result with the approved pass/fail criteria.
4. Stop if the result is unexpected, the scope is ambiguous, or a different command or tool is needed.
5. Present any revised or additional command to the user and obtain approval before continuing.

Do not introduce scenario-specific resources, mutations, control installations, or compatibility checks unless they were included in the approved plan.

## Phase 5: Capture Evidence with Approved Commands

Choose evidence commands based on the approved test scenario rather than assuming a particular workload type or Kubernetes resource.

- Include every evidence command and its tool in the plan before execution.
- Use only the commands and tools confirmed by the user.
- Prefer short, focused, self-contained commands whose output directly proves one expected behavior.
- Do not rely on previously exported environment variables or hidden setup for visible proof commands.
- Do not use reconstructed output as evidence.
- Capture baseline, result, artifact identity, logs, metrics, or health state only when they are relevant to the approved scenario.
- If `kubectl` is approved, every command must include the explicit context and namespace required by the Core Rules.
- If a pipeline such as `jq`, `grep`, `awk`, or Python is proposed, show the complete pipeline in the plan and obtain approval for the entire command.
- If the available output does not prove the expected behavior, stop and propose a revised evidence command instead of making a broader claim.

## Phase 6: Generate Screenshots with VHS

Use VHS for terminal evidence. Do not render a custom HTML report.

### Screenshot requirements

The image must contain only:

- The terminal prompt.
- The command entered.
- The command's real output.

Do not add:

- Titles.
- Headers.
- Explanatory text.
- PASS or FAIL labels.
- Summaries.
- Reconstructed output.
- Decorative captions.

VHS settings such as terminal dimensions, font, padding, and color theme are allowed because they do not alter the evidence.

Create one recording per focused proof where practical.

Generic tape template:

```tape
Output "/tmp/pr-validation/proof.gif"

Set Shell "bash"
Set FontFamily "Menlo"
Set FontSize 22
Set Width 2200
Set Height 620
Set Padding 28
Set TypingSpeed 1ms

Type "<exact approved evidence command>"
Enter
Sleep 3s
```

Replace the placeholder with one exact evidence command from the user-approved plan. Do not add commands to the recording merely to improve presentation.

Important:

- Quote absolute paths in `Output`.
- Execute setup and cleanup outside the recording.
- Do not use `Hide` to conceal meaningful proof operations.
- Ensure the recorded resource remains available until VHS completes.
- Use a wide terminal to avoid wrapping image digests unnecessarily.
- Inspect every generated artifact before presenting it.

To create a static screenshot from the final VHS frame:

```console
ffmpeg -sseof -0.1 -i /tmp/pr-validation/proof.gif \
  -frames:v 1 /tmp/pr-validation/proof.png
```

The PNG must be a direct frame from VHS, not an annotated derivative.

## Phase 7: Final Cleanup Verification

Verify:

- Every temporary resource created by the approved scenario was deleted.
- Every state change made by the approved scenario was restored when restoration was part of the plan.
- The approved cleanup commands completed successfully.
- The intended target is in the final state defined by the approved plan.
- Resources outside the approved scope were not intentionally changed.
- No helper files were written into the repository.
- The worktree remains clean unless source changes were explicitly requested.

Do not report success until cleanup is confirmed.

## Phase 8: Update the PR Testing Section

Only update the PR when the user asks.

Rules:

1. Use the existing `## Testing` section.
2. Never create an `## AI Tested`, `## AI Testing`, or similarly named section.
3. Preserve all existing Testing content byte-for-byte.
4. Append new manual-validation evidence within the existing `## Testing` section.
5. If no `## Testing` section exists, create exactly one.
6. Describe only what was actually observed; do not infer unsupported behavior.
7. Include, when applicable:
   - Exact deployment command or Bazel target.
   - Atlas cluster, installation, Kubernetes context, and namespace.
   - Commit and artifact or image identity.
   - Approved test scenario and tool set.
   - Commands that were run and their observed validation result.
   - Cleanup result.
   - Screenshots or relevant Datadog links.
8. Put a short explanation before each screenshot.
9. Do not identify testing as AI testing or mention that an AI performed it.
10. Avoid browser-based GitHub attachment automation when it requires separate authentication.
11. Prefer:
    - User-managed screenshot attachment.
    - Relevant Datadog links.
    - `gh pr edit --body-file` for text changes.
12. Never create a GitHub Release merely to host screenshots unless explicitly approved.

Before updating the PR:

```console
gh pr view <pr> --repo <repo> --json body --jq .body > /tmp/pr-before.md
```

After updating, verify:

- There is exactly one `## Testing` heading.
- The original Testing content remains unchanged.
- The new evidence was appended rather than replacing existing evidence.
- No AI Tested or AI Testing heading was introduced.
- No unrelated PR-description content changed.

## Reporting Results

Report:

- The user-validated Atlas cluster where testing was performed.
- What was deployed.
- What was tested.
- What passed or failed.
- Exact artifact paths.
- Cleanup status.
- Any caveats, including unrelated deployments observed during the test window.

Never claim that a screenshot proves more than its visible command output.
