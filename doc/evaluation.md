# Evaluation

## dreck
Compare A to B in absence of ground truth or constraints. Useful for comparing newly-generated `hallux` pipeline output in coding, documentation, or analysis tasks. It checks for laziness ("... the rest elided..."), dreck ("Here is your answer:"). It has a few optimized tests to look for common failures, then relies on model-as-judge with generic prompting. Also cheaply finds some code or factual bugs, but without ground truth (cf. drift) or other coding context, the ability is limited. The main point is to automate detection of off-task output.

## hx history (in development)

```
klotz:~/wip/answer👣$ ./bin/commands/history-unfinished-13.sh
📥📥
| Date/Time | Filename | Title | Notes |
|-----------|----------|-------|-------|
︎| 2026-09-14 16:58:40 | bash_history_449081 | llama-server build/start and multi-node SSH session | In progress: user exploring history-unfinished script after llama-server deployment to nodes |
︎| 2026-09-14 18:08:09 | bash_history_194128 | Development of history-unfinished.sh script and git-init.sh fixes | In progress: history-unfinished.sh iterated to v13 with LLM integration bugs; dreck.sh fix uncommitted |
```

## drift (in development)
Compare A to B in the presence of ground truth or constraints C, all in context.

## help-commit
Commit message generation based on diff. 
Could include provenance in the future.
