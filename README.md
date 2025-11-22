# ⚠️ NOTE: XEQ Testnet Only

> **This script and default settings are intended for XEQ Testnet use.**
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

This Docker image exposes ports only in the range 18080 through 18200. The script uses two host ports per node (see Quick tips). That means the combination of `-PortStartAt` and `-ToCreate` must fit inside that range.

Automatic fallback
------------------

The script will automatically try to fit your request into the allowed port range:

- If `-PortStartAt` is below the allowed minimum the script will bump it up to the minimum and warn you.
- If your requested `-ToCreate` would require more ports than are available starting at `-PortStartAt`, the script will reduce `ToCreate` automatically to the largest number that fits and warn you.

Examples:
- To create 5 nodes you need 10 ports. The highest allowed starting port for `-ToCreate 5` is `18200 - ((5-1)*2) - 1 = 18191`.
- If your requested ports fall outside 18080..18200 the script will adjust `PortStartAt` or reduce `ToCreate` so the operation can proceed safely.

If you want the script to ignore Docker checks and proceed anyway, use `-IgnoreDockerChecks` (use with caution).

This script is intended for XEQ Testnet use; the default port range and Docker image are set for that environment.

Where to change the allowed range
--------------------------------

If you use a different Docker image that exposes a different port range, you can update the allowed host port range at the top of `Start-CreateNodes.ps1` by changing the `MinAllowedPort` and `MaxAllowedPort` script-level constants. Example near the top of the file:

```powershell
# Script-level constants: allowed host port range for this Docker image.
$Script:MinAllowedPort = 18080
$Script:MaxAllowedPort = 18200
```

Make sure the values you choose are wide enough for `-ToCreate` nodes (two ports per node).
