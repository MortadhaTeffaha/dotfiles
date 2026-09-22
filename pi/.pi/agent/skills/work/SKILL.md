---
name: work
description: Explicitly route a work request into a model-specific Pi session running in Herdr. Invoke only with /skill:work; never activate automatically.
disable-model-invocation: true
---

# Work Session Router

Route one explicitly supplied work request into a dedicated Herdr-backed Pi session. This workflow applies only to the current `/skill:work` invocation. After launch or cancellation, return to normal assistant behavior and do not route later requests unless the user invokes `/skill:work` again.

## Input

Arguments after `/skill:work` are the work request. For example:

```text
/skill:work implement retry handling for the API client
```

If no request was supplied, ask the user what they want to work on before classifying. Preserve the complete request verbatim for handoff and note whether the invocation includes image attachments.

## Session types

Classify the primary desired outcome into exactly one type:

1. `doc-writing` — draft or substantially rewrite documentation, proposals, runbooks, design documents, or explanations.
2. `doc-review` — review an existing document for correctness, clarity, structure, omissions, or readiness.
3. `code-development` — implement or change code, configuration, infrastructure, tests, or developer tooling.
4. `code-review` — review an existing diff, branch, commit, or pull request without owning implementation.
5. `incident-investigation` — diagnose an operational problem, outage, regression, alert, or unexplained production behavior.
6. `general` — learning, research, one-off operations, or work outside the specialized flows above.

Use these named agents and their configured profile models:

| Session type | Agent | Model |
|---|---|---|
| doc-writing | `doc-writer` | `ai-gw-baseten/baseten/zai-org/GLM-5.2` |
| doc-review | `doc-reviewer` | `ai-gw-baseten/baseten/zai-org/GLM-5.2` |
| code-development | `code-development` | `ai-gw-baseten/baseten/zai-org/GLM-5.2` |
| code-review | `code-review` | `ai-gw-baseten/baseten/zai-org/GLM-5.2` |
| incident-investigation | `incident-investigator` | `ai-gw-baseten/baseten/zai-org/GLM-5.2` |
| general | `general-session` | `ai-gw-baseten/baseten/zai-org/GLM-5.2` |

## Routing protocol

1. Classify using the primary outcome, not isolated keywords.
2. Before launching, call `ask_user_question` and show:
   - selected session type;
   - selected named agent;
   - configured model;
   - a one-sentence objective.
3. Offer `Launch session (Recommended)`, `Choose another type`, and `Cancel`.
4. If the user chooses another type, ask them to select from the six types and confirm the revised route.
5. Only after confirmation, call `subagent` with:
   - the selected named agent;
   - the original request and objective in `task`;
   - the current working directory;
   - `interactive: true` — the session MUST stay open after the initial task completes so the user can continue the conversation in its Herdr pane.
6. If the invocation includes image attachments, set `fork: true` so the child inherits them. Otherwise set `fork: false` and use the explicit handoff.
7. Tell the user which session launched and which Herdr pane it is running in. The session is interactive and stays open — the user works directly in that pane.
8. **Do NOT wait for or expect a completion report.** Interactive sessions do not auto-exit, so the harness will not deliver a result back to this session. Do not poll, do not write wait loops, do not tail log files. Your routing job is done after launch — end your turn.
9. If the user later asks how the session is doing, check its status using the `herdr` CLI (there is no Herdr MCP server — use bash commands directly):
   - `herdr agent list` — lists all agents with their `agent_status` (`idle`, `working`, `blocked`, `done`). Match by the session name you gave the subagent.
   - `herdr agent read <pane_id>` — reads the agent's terminal output to see what it did and found.
   - `herdr agent wait <pane_id> --until idle --timeout <ms>` — optionally wait for the agent to finish if it's still `working`.
   - Report the status and a summary of the output to the user. Do not just tell them to check the pane — actually fetch and relay the information.

Do not perform the routed work in the current session. Do not silently launch. Do not override the named agent's model or thinking level in the `subagent` call. The launched session must NOT auto-exit after completing the initial task — it stays open for the user to continue interacting. If classification is genuinely ambiguous, ask one short clarification question before presenting confirmation.
