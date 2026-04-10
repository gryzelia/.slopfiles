# Best Practices for writing dotfiles

* When writing shell scripts, avoid fish-specific brace expansion bugs, always consider cross-platform compatibility (particularly macOS vs Linux).
* When dealing with files with unicode characters, ensure they are preserved after edits. Use Python workarounds if the Write tool strips Unicode.
* Before suggesting a new config option or feature addition, first check whether the functionality already exists or works by default. Read the existing config, source code, and documentation before proposing changes.
