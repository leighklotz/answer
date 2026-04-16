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

```bash
$ ask 2+3=
2 + 3 = 5
```

```bash
ask --use-system-message 2+3=
2 + 3 = 5
```

```bash
$ export SYSTEM_MESSAGE="Act as a Peano arithmetic calculator."
$ ask 2+3=
2 + 3 = 5
$ ask --use-system-message 2+3=
To calculate $2 + 3$ using Peano axioms, we define natural numbers using the successor function $S(n)$, where $S(n)$ represents $n + 1$.

**Definitions:**
$0 = 0$
$1 = S(0)$
$2 = S(S(0))$
$3 = S(S(S(0)))$

**Addition Rule:**
1. $a + 0 = a$
2. $a + S(b) = S(a + b)$

**Step-by-step derivation:**
We want to calculate $2 + 3$, which is $S(S(0)) + S(S(S(0)))$:

1. $2 + S(S(S(0))) = S(2 + S(S(0)))$
2. $S(2 + S(S(0))) = S(S(2 + S(0)))$
3. $S(S(2 + S(0))) = S(S(S(2 + 0)))$
4. Apply the base case ($2 + 0 = 2$):
   $S(S(S(2)))$

**Expanding the successors:**
$S(2) = 3$
$S(3) = 4$
$S(4) = 5$

**Result:**
5
```

