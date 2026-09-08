# hx-bootstrap

## Overview

The `hx-bootstrap` script is a shell initialization utility designed for interactive terminal sessions. 

Because standard executable scripts cannot modify the environment variables of your current (parent) shell, this script must be **sourced**. Sourcing it defines an `hx` function in your active session, which allows you to configure environment variables and persistent prompt settings that remain valid throughout your entire terminal session.

**Requirement:** Bash 4+ is required.

## Installation

To enable seamless integration with your interactive shell, add the following line to your `.bashrc`:

```bash
# Replace /path/to/answer/bin with the actual absolute path to your installation
source /path/to/answer/bin/commands/hx-bootstrap.sh
```

After adding this line, restart your terminal or run `source ~/.bashrc`.

## Usage in Interactive Shells

Once bootstrapped, you can use the `hx` command within your shell to activate the framework's environment:

### Initialization (`enable`)
The `enable` command sets up core environment variables (like updating your `PATH`), configures a customized prompt via sourcing configuration scripts, and summarizes current workspace/model status.

```bash
 $ hx enable
 👣 hallux [server] [model] [hallux root] [bash history file]
 👣$ help 2+3=
 ✨
 5
 👣$
```
 
