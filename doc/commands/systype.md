# systype

**`systype`** is a system profiling utility designed to provide high-density hardware and software metadata as part of an LLM pipeline. It serves as "environment grounding" for the **Answer** toolchain, providing an AI model with the machine's specific technical constraints (CPU architecture, memory capacity, kernel version) so it can make informed reasoning about performance, system logs, or configuration settings based on reality rather than generic assumptions.

## Synopsis

```bash
systype [OPTIONS]
```

The command outputs a concise text summary of the host environment to `stdout`.

## Description

When used in a pipeline—often grouped with hardware benchmarks (`hdparam`, `iostat`) or process monitors (`ps`, `top`) via subshells or the `bx` command—`systype` provides the baseline "truth" of the current execution environment. This allows an LLM to perform comparative analysis; for example, it can compare a measured disk speed against the theoretical maximums known for your specific hardware architecture and interface.

By providing this metadata upfront, you enable the model to transition from general troubleshooting to precise system engineering (e.g., determining if a specific instruction set is available or if memory pressure is critical based on total capacity).

## Output Information

`systype` aggregates data typically found in `/proc`, `sysfs`, and via standard system utilities (`lscpu`, `free`, etc.). The output includes:

* **CPU:** Architecture (e.g., x86_64, aarch64), model name, core count (physical vs logical), and supported instruction sets.
* **Memory:** Total physical RAM capacity and available memory state.
* **Kernel & OS:** Kernel version, release number, and operating system distribution/version.

## Examples

**1. Contextualizing Hardware Benchmarks**
When running hardware tests, pipe the results into `help` alongside a query. The LLM uses your specific system specs to determine if the measured performance is within expected parameters for that hardware.
```bash
# Compares actual disk throughput against theoretical limits of your detected drive/interface
$ (systype; sudo hdparam -t --direct /dev/nvme0n1) | help "Are these good results for my hardware?"
```

**2. System Triage and Resource Analysis**
Provide a baseline of system resources when asking an LLM to audit process lists or resource consumption.
```bash
# Combines system specs with current process state for deep analysis
$ (systype; bx ps gauxww) | help "What do you notice that I should know as the owner of this server?"
```

**3. Verifying Driver and Kernel Compatibility**
When troubleshooting kernel-level issues or driver installations, provide your exact environment to ensure the AI's advice is compatible with your specific build.
```bash
# Check if a suggested solution matches your current kernel version and architecture
$ systype | ask "Based on my hardware, what are the best settings for power management?"
```

**4. Automated Environment Auditing**
Use `systype` to feed an LLM enough context to identify potential bottlenecks in complex system configurations.
```bash
# Analyze if current memory allocation is sufficient based on total RAM and running processes
$ (systype; free -m) | help "Is my system likely to swap under the current load?"
```
