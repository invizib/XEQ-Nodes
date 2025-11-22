# ⚠️ NOTE: XEQ Testnet Only

> **This script and default settings are intended for Equilibria Testnet use.**
> This is a work in progress, I'll try to update for each phase of the testnet.
> Change port ranges or Docker image if you use it for another network.

# Start-CreateNodes

This is a small PowerShell script. It helps you make many folders called "nodes" and can show or run Docker commands to start small programs (containers).

Think of it like a helper that: creates a folder for each toy, gives each toy two numbered ports, and can start the toy if you ask it to.

What it does:
- Makes folders for each node and a data folder inside each.
- Shows the Docker command it would run (preview), or actually runs it if you say `-Execute`.
- Checks if the ports it wants to use are free on your computer so it doesn't break anything.
- Checks if Docker already uses a port so it won't try to use the same one.

Simple words about errors:
- If the script can't talk to Docker (Docker missing or not running), it will stop so nothing bad happens.
- If you still want it to keep going even when Docker checks fail, add `-IgnoreDockerChecks` and it will continue but won't know if ports are used by Docker.

How to try (WhatIf):
- To only look (do not change files or run Docker):

```powershell
. ./Start-CreateNodes.ps1
Test-CreateNodesPreview -StartAt 1 -ToCreate 3 -PortStartAt 18150
```

- To actually create folders and try to start containers (be careful):

```powershell
. ./Start-CreateNodes.ps1
Start-CreateNodes -StartAt 1 -ToCreate 2 -PortStartAt 18150 -Execute
```

If Docker errors stop the script and you want to ignore them (use with caution):

```powershell
Start-CreateNodes -StartAt 1 -ToCreate 2 -PortStartAt 18150 -Execute -IgnoreDockerChecks
```

## Using on Windows (PowerShell)

The PowerShell script `Start-CreateNodes.ps1` works on Windows PowerShell 5.1+ and PowerShell Core.

### Preview (dry-run):

⚠️ **Remember: `-PortStartAt` must be between 18081 and 18200** (allows for two ports per node).

```powershell
. ./Start-CreateNodes.ps1
Test-CreateNodesPreview -StartAt 1 -ToCreate 3 -PortStartAt 18150
```

### Create folders and run containers:

```powershell
. ./Start-CreateNodes.ps1
Start-CreateNodes -StartAt 1 -ToCreate 2 -PortStartAt 18150 -Execute
```

### With automatic folder replacement:

```powershell
. ./Start-CreateNodes.ps1
Start-CreateNodes -StartAt 1 -ToCreate 2 -PortStartAt 18150 -Execute -Overwrite
```

### Ignore Docker checks (if Docker is not running):

```powershell
. ./Start-CreateNodes.ps1
Start-CreateNodes -StartAt 1 -ToCreate 2 -PortStartAt 18150 -Execute -IgnoreDockerChecks
```

## Using on Linux/Debian (Bash)

The Bash script `start-create-nodes.sh` works on Linux and other Unix-like systems with Bash 4+.

### Make executable:

```bash
chmod +x start-create-nodes.sh
```

### Preview (dry-run):

⚠️ **Remember: `--port-start-at` must be between 18081 and 18200** (allows for two ports per node).

```bash
./start-create-nodes.sh --start-at 1 --to-create 3 --port-start-at 18150 --dry-run
```

### Create folders and run containers:

```bash
./start-create-nodes.sh --start-at 1 --to-create 2 --port-start-at 18150 --execute
```

### With automatic folder replacement:

```bash
./start-create-nodes.sh --start-at 1 --to-create 2 --port-start-at 18150 --execute --overwrite
```

### Ignore Docker checks (if Docker is not running):

```bash
./start-create-nodes.sh --start-at 1 --to-create 2 --port-start-at 18150 --execute --ignore-docker-checks
```

Quick tips:
- The script uses two ports per node: the first is `PortStartAt + (i*2)` and the second is `+1`.
- Use `-Overwrite` if you want it to remove old folders and make new ones.
- Use `-DryRun` or `Test-CreateNodesPreview` when you only want to see what would happen.

Be safe: this script changes files and can start Docker containers. Only run it if you understand and have permission.

Main script file: `Start-CreateNodes.ps1`. Edit the invocation at the top of that file if you don't want it to run automatically.

Port limits
----------

**⚠️ Critical: This Docker image exposes ports only in the range 18081–18200.**

The script uses **two host ports per node**. That means:
- `-PortStartAt` (or `--port-start-at`) must be **between 18081 and 18200**.
- Each node requires 2 consecutive ports. For example:
  - Node 1 starting at 18150 uses ports 18150, 18151
  - Node 2 starting at 18150 uses ports 18152, 18153
  - Node 3 starting at 18150 uses ports 18154, 18155

**If your chosen `-PortStartAt` and `-ToCreate` would exceed port 18200, the script automatically reduces `-ToCreate` to fit and warns you.**

Automatic fallback behavior
----------------------------

The script automatically adjusts your input to fit the allowed port range (18081–18200):

**If `-PortStartAt` is too low:**
- Below 18081 → Script bumps to 18081 and warns you.

**If `-ToCreate` is too high:**
- If your nodes would exceed port 18200 → Script reduces `-ToCreate` and warns you.

**Examples:**
- To create 5 nodes, you need 10 ports (5 × 2). The **highest safe starting port** is `18200 - 9 = 18191`.
  - `--port-start-at 18191 --to-create 5` uses ports 18191–18200 ✓
  - `--port-start-at 18196 --to-create 5` would need ports 18196–18205 (exceeds 18200), so script reduces to `--to-create 2`
- Starting at 18150 with `--to-create 26` would need 52 ports → Script reduces to the maximum that fits (25 nodes).

If you want the script to ignore Docker checks and proceed anyway, use `-IgnoreDockerChecks` (use with caution).

This script is intended for XEQ Testnet use; the default port range and Docker image are set for that environment.

Where to change the allowed range
--------------------------------

If you use a different Docker image that exposes a different port range, you can update the allowed host port range at the top of `Start-CreateNodes.ps1` by changing the `MinAllowedPort` and `MaxAllowedPort` script-level constants. Example near the top of the file:

```powershell
# Script-level constants: allowed host port range for this Docker image.
$Script:MinAllowedPort = 18081
$Script:MaxAllowedPort = 18200
```

Make sure the values you choose are wide enough for `-ToCreate` nodes (two ports per node).
