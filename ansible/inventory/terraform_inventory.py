#!/usr/bin/env python3

import json
import os
import subprocess
import sys
from pathlib import Path


def resolve_repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def resolve_env() -> str:
    return os.environ.get("ANSIBLE_TF_ENV", "rke2")


def resolve_private_key() -> str:
    return os.path.expanduser("~/.ssh/homelab_vm")


def read_terraform_inventory(repo_root: Path, env_name: str) -> dict[str, dict[str, str]]:
    env_dir = repo_root / "terraform" / "envs" / env_name
    result = subprocess.run(
        ["terraform", f"-chdir={env_dir}", "output", "-json", "ansible_inventory"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        sys.stderr.write(
            f"Failed to resolve ansible_inventory for {env_dir}. Run 'make apply E={env_name}' first.\n"
        )
        if result.stderr:
            sys.stderr.write(result.stderr)
        raise SystemExit(result.returncode)

    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"Failed to parse ansible_inventory for {env_dir}: {exc}\n")
        raise SystemExit(1) from exc

    if not isinstance(payload, dict) or not payload:
        sys.stderr.write(f"Unexpected ansible_inventory payload for {env_dir}: {payload!r}\n")
        raise SystemExit(1)

    return payload


def build_inventory(hosts: dict[str, dict[str, str]]) -> dict[str, object]:
    inventory: dict[str, object] = {
        "_meta": {"hostvars": {}},
        "all": {"hosts": [], "children": []},
    }
    hostvars = inventory["_meta"]["hostvars"]
    all_hosts = inventory["all"]["hosts"]
    all_children = inventory["all"]["children"]

    for host, metadata in sorted(hosts.items()):
        role = metadata.get("role", "ungrouped")
        env_name = metadata.get("env", "unknown")

        all_hosts.append(host)
        hostvars[host] = {
            "ansible_host": metadata["ansible_host"],
            "ansible_user": "ubuntu",
            "ansible_ssh_private_key_file": resolve_private_key(),
            "homelab_env": env_name,
            "homelab_role": role,
        }

        for group_name in (env_name, role):
            if group_name not in inventory:
                inventory[group_name] = {"hosts": []}
                all_children.append(group_name)
            inventory[group_name]["hosts"].append(host)

    return inventory


def main() -> int:
    if len(sys.argv) >= 2 and sys.argv[1] == "--host":
        sys.stdout.write("{}")
        return 0

    if len(sys.argv) >= 2 and sys.argv[1] != "--list":
        sys.stderr.write("Usage: terraform_inventory.py [--list|--host <hostname>]\n")
        return 1

    repo_root = resolve_repo_root()
    env_name = resolve_env()
    hosts = read_terraform_inventory(repo_root, env_name)
    sys.stdout.write(json.dumps(build_inventory(hosts), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
