<#
.SYNOPSIS
  Create multiple node folders and corresponding docker run commands.

.DESCRIPTION
  Creates directories and prints (or runs with -Execute) docker run commands
  for multiple nodes with incrementing names and ports. Includes safety checks
  and supports overwriting existing folders.

.EXAMPLE
  Start-CreateNodes -StartAt 1 -ToCreate 3 -PortStartAt 18150 -Prefix 'Node'
  (prints docker commands)

  Start-CreateNodes -StartAt 1 -ToCreate 3 -PortStartAt 18150 -Prefix 'Node' -Execute -Overwrite
  (executes docker run and recreates folders if necessary)
#>

# Example invocation (uncomment to use):
# Start-CreateNodes -StartAt 1 -ToCreate 3 -PortStartAt 18150 -Prefix "Node" -Execute

Start-CreateNodes -StartAt 1 -ToCreate 5 -PortStartAt 18150 -Execute

function Start-CreateNodes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0, HelpMessage="Starting index for node numbering.")]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$StartAt,

        [Parameter(Mandatory=$true, Position=1, HelpMessage="Number of nodes to create.")]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ToCreate,

        [Parameter(Mandatory=$true, Position=2, HelpMessage="Starting host port (first node will use this and the next).")]
        [ValidateRange(1, 65535)]
        [int]$PortStartAt,

        [Parameter(Mandatory=$false, Position=3, HelpMessage="Prefix for node names (default: Node).")]
        [ValidateNotNullOrEmpty()]
        [string]$Prefix = "Node",

        [Parameter(Mandatory=$false, Position=4, HelpMessage="Docker image to run.")]
        [ValidateNotNullOrEmpty()]
        [string]$DockerPackage = "glutinous165/equilibria-node:latest",

        [Parameter(Mandatory=$false, HelpMessage="If set, the script will actually run docker; otherwise it will print the command.")]
        [Switch]$Execute,

        [Parameter(Mandatory=$false, HelpMessage="If set, existing node folders will be removed and recreated.")]
        [Switch]$Overwrite,

        [Parameter(Mandatory=$false, HelpMessage="If set, the script will not modify the filesystem; perform a dry-run.")]
        [Switch]$DryRun
    )

    try {
        # Basic sanity checks
        if ($PortStartAt -gt 65534) { throw "PortStartAt must allow two ports per node (max 65534)." }

        $currentPath = (Get-Location).ProviderPath
        $dataRoot = Join-Path -Path $currentPath -ChildPath "data"

        if (-not $DryRun) {
            if (-not (Test-Path -Path $dataRoot)) {
                New-Item -Path $dataRoot -ItemType Directory -Force | Out-Null
            }
        } else {
            Write-Verbose "DryRun: would ensure data root exists at $dataRoot"
        }

        for ($i = 0; $i -lt $ToCreate; $i++) {
            $nodeNumber = $StartAt + $i
            $nodeName = "{0}{1}" -f $Prefix, $nodeNumber
            $folderPath = Join-Path -Path $currentPath -ChildPath $nodeName
            $hostDataPath = Join-Path -Path $dataRoot -ChildPath $nodeName

            if (Test-Path -Path $folderPath) {
                if ($Overwrite) {
                    if (-not $DryRun) {
                        Write-Verbose "Removing existing folder: $folderPath"
                        Remove-Item -Path $folderPath -Recurse -Force -ErrorAction Stop
                    } else {
                        Write-Verbose "DryRun: would remove existing folder: $folderPath"
                    }
                } else {
                    Write-Warning "Folder '$folderPath' already exists. Use -Overwrite to replace. Skipping node $nodeName."
                    continue
                }
            }

            # Create node folder and data volume folder (skip on DryRun)
            if (-not $DryRun) {
                New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
                New-Item -Path $hostDataPath -ItemType Directory -Force | Out-Null
            } else {
                Write-Verbose "DryRun: would create $folderPath and $hostDataPath"
            }

            $port1 = $PortStartAt + ($i * 2)
            $port2 = $port1 + 1

            $dockerArgs = @(
                'run', '-dit',
                '--name', $nodeName,
                '--restart', 'unless-stopped',
                '-p', "`"$port1`:$port1`"",
                '-p', "`"$port2`:$port2`"",
                '-v', "`"$hostDataPath`:/data`"",
                $DockerPackage,
                '--testnet',
                '--data-dir=/data',
                "--p2p-bind-port=$port1",
                "--rpc-bind-port=$port2",
                '--add-exclusive-node=84.247.143.210:18080',
                '--log-level=1'
            )

            if ($Execute) {
                Write-Host "Creating Docker container: $nodeName (ports $port1,$port2) ..."
                try {
                    if (-not $DryRun) {
                        & docker @dockerArgs 2>&1 | ForEach-Object { Write-Verbose $_ }
                        Write-Host "Container $nodeName created."
                    } else {
                        Write-Verbose "DryRun: would run docker @dockerArgs"
                    }
                } catch {
                    Write-Error "Failed to create container $nodeName`: $_"
                }
            } else {
                $cmdLine = 'docker ' + ($dockerArgs -join ' ')
                Write-Host "DRY RUN: $cmdLine"
            }
        }

        Write-Host "Create-Nodes completed."
    }
    catch {
        Write-Error "Create-Nodes failed: $_"
        throw
    }
}
function Test-CreateNodesPreview {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$StartAt = 1,

        [Parameter(Position=1)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ToCreate = 3,

        [Parameter(Position=2)]
        [ValidateRange(1, 65535)]
        [int]$PortStartAt = 18162,

        [Parameter(Position=3)]
        [ValidateNotNullOrEmpty()]
        [string]$Prefix = "Node",

        [Parameter(Position=4)]
        [ValidateNotNullOrEmpty()]
        [string]$DockerPackage = "glutinous165/equilibria-node:latest",

        [Parameter()]
        [Switch]$Overwrite
    )

    Write-Host "=== Test: Create nodes preview ==="
    Write-Host "Parameters: StartAt=$StartAt, ToCreate=$ToCreate, PortStartAt=$PortStartAt, Prefix=$Prefix, DockerPackage=$DockerPackage, Overwrite=$Overwrite"
    Write-Host ""

    $splat = @{
        StartAt       = $StartAt
        ToCreate      = $ToCreate
        PortStartAt   = $PortStartAt
        Prefix        = $Prefix
        DockerPackage = $DockerPackage
        DryRun        = $true
    }
    if ($Overwrite) { $splat.Overwrite = $true }

    # Call Start-CreateNodes in dry-run mode (no filesystem changes, no docker)
    Start-CreateNodes @splat

    Write-Host ""
    Write-Host "Preview completed. No containers or folders were created."
}
