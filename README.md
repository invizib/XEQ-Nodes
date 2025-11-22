# Start-CreateNodes

This is a small PowerShell script. It helps you make many folders called "nodes" and can show or run Docker commands to start small programs (containers).

Think of it like a helper that: creates a folder for each toy, gives each toy two numbered ports, and can start the toy if you ask it to.

What it does (easy):
- Makes folders for each node and a data folder inside each.
- Shows the Docker command it would run (preview), or actually runs it if you say `-Execute`.
- Checks if the ports it wants to use are free on your computer so it doesn't break anything.
- Checks if Docker already uses a port so it won't try to use the same one.

Simple words about errors:
- If the script can't talk to Docker (Docker missing or not running), it will stop so nothing bad happens.
- If you still want it to keep going even when Docker checks fail, add `-IgnoreDockerChecks` and it will continue but won't know if ports are used by Docker.

How to try (short):
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

Quick tips:
- The script uses two ports per node: the first is `PortStartAt + (i*2)` and the second is `+1`.
- Use `-Overwrite` if you want it to remove old folders and make new ones.
- Use `-DryRun` or `Test-CreateNodesPreview` when you only want to see what would happen.

Be safe: this script changes files and can start Docker containers. Only run it if you understand and have permission.

Main script file: `Start-CreateNodes.ps1`. Edit the invocation at the top of that file if you don't want it to run automatically.
