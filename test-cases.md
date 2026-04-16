```bash
$ 4 ask 2+3=
2 + 3 = 5
```

```bash
$ ask 2+3= | answer
2 + 3 = 5
```

```bash
$ ask 2+3= | cat
[
  {
    "role": "user",
    "content": "2+3="
  }
]
```bash

```
$ ask 2+3= | cat | answer
5
```

```bash
$ ask 2+3= | cat | answer -t
2 + 3 = 5
[
  {
    "role": "user",
    "content": "2+3="
  },
  {
    "role": "assistant",
    "content": "2 + 3 = 5"
  }
]
```
