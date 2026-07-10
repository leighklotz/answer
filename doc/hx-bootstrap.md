# hx-bootstrap

## Overview

The `hx-bootstrap` script is a shell initialization utility designed for interactive terminal sessions. 

In Bash, running a standard executable or script cannot modify the environment variables of your current shell (the parent process). To allow the Answer framework to inject specific configuration settings, aliases, and pipeline behaviors into your **active** terminal session, `hx-bootstrap` defines an `hx` function that uses the `source` command.

## Installation

To enable seamless integration with your interactive shell, add the following line to your `.bashrc` (for Bash) or `.zshrc` (for Zsh):

```bash
# Replace /path/to/answer/bin with the actual absolute path to your installation
source /path/to/answer/bin/commands/hx-bootstrap.sh
```

After adding this line, restart your terminal or run `source ~/.bashrc`.

## Usage in Interactive Shells

Once bootstrapped, you can use the `hx` command within your shell to activate the framework's environment:

```bash
 $ hx enable
 🦶$ help 2+3=
 ✨
 5
 🦶$
```
