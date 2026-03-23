#!/usr/bin/env python3

import json
import subprocess
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        sys.stderr.write("Usage: terraform-vm-names.py <terraform-env-dir>\n")
        return 1

    env_dir = Path(sys.argv[1])
    env_name = env_dir.name

    result = subprocess.run(
        ["terraform", f"-chdir={env_dir}", "output", "-json", "vm_names"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        sys.stderr.write(
            f"Failed to resolve vm_names for {env_dir}. Run 'make apply E={env_name}' first.\n"
        )
        if result.stderr:
            sys.stderr.write(result.stderr)
        return result.returncode

    try:
        names = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"Failed to parse terraform output vm_names for {env_dir}: {exc}\n")
        return 1

    if not isinstance(names, list) or not names:
        sys.stderr.write(f"No VM names found in terraform output for {env_dir}.\n")
        return 1

    if not all(isinstance(name, str) and name for name in names):
        sys.stderr.write(f"Unexpected vm_names payload for {env_dir}: {names!r}\n")
        return 1

    sys.stdout.write(" ".join(names))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
