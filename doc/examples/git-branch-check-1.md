# Check Git Branches
```bash
klotz@tensor:~/wip/solon👣$ ask does main have commits not on prompt-format-2 | tools git
💬︎🚀git branch -a🚀git log prompt-format-2..main --oneline🚀git rev-list --count prompt-format-2..main🚀git rev-list --count main..prompt-format-2✨
No, `main` does not have any commits that are not on `prompt-format-2`. In fact, `prompt-format-2` is actually ahead of `main` by 45 commits.
klotz@tensor:~/wip/solon👣$
```
