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
| doc-writing | `doc-writer` | `ai-gw-anthropic-200k/anthropic/claude-sonnet-5` |
| doc-review | `doc-reviewer` | `ai-gw-anthropic-200k/anthropic/claude-sonnet-5` |
| code-development | `code-development` | `ai-gw-openai/openai/gpt-5.6-sol` |
| code-review | `code-review` | `ai-gw-anthropic-200k/anthropic/claude-sonnet-5` |
| incident-investigation | `incident-investigator` | `ai-gw-anthropic-200k/anthropic/claude-sonnet-5` |
| general | `general-session` | `ai-gw-openai/openai/gpt-5.6-sol` |

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
   - `interactive: true`.
6. If the invocation includes image attachments, set `fork: true` so the child inherits them. Otherwise set `fork: false` and use the explicit handoff.
7. Tell the user which session launched and that they can work with it in its Herdr surface.

Do not perform the routed work in the current session. Do not silently launch. Do not override the named agent's model or thinking level in the `subagent` call. If classification is genuinely ambiguous, ask one short clarification question before presenting confirmation.
