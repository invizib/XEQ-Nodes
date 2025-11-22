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

# Script-level constants: allowed host port range for this Docker image.
# Change these values here if you use a different image exposing another range.
$Script:MinAllowedPort = 18081
$Script:MaxAllowedPort = 18200

function Test-PortAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateRange(1, 65535)]
        [int]$Port
    )

    try {
        $addr = [System.Net.IPAddress]::Loopback
        $listener = [System.Net.Sockets.TcpListener]::new($addr, $Port)
        $listener.Start()
        $listener.Stop()
        return $true
    }
    catch {
        return $false
    }
}

function Test-PortPublishedByDocker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateRange(1, 65535)]
        [int]$Port
    )

    try {
        $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
        if (-not $dockerCmd) {
            return [pscustomobject]@{ Published = $false; Error = 'Docker CLI not found in PATH' }
        }

        $psOutput = & docker ps -q 2>&1
        if ($LASTEXITCODE -ne 0) {
            $err = $psOutput -join "`n"
            return [pscustomobject]@{ Published = $false; Error = "docker ps failed: $err" }
        }

        $containerIds = $psOutput | Where-Object { $_ -ne '' }
        if (-not $containerIds) { return [pscustomobject]@{ Published = $false; Error = $null } }

        foreach ($id in $containerIds) {
            $portOutput = & docker port $id 2>&1
            if ($LASTEXITCODE -ne 0) {
                # If docker port fails for this container, capture but keep checking others
                continue
            }
            if ($portOutput -and ($portOutput -match ":$Port\b")) {
                return [pscustomobject]@{ Published = $true; Error = $null }
            }
        }

        return [pscustomobject]@{ Published = $false; Error = $null }
    }
    catch {
        $err = $_.Exception.Message
        return [pscustomobject]@{ Published = $false; Error = "Exception while checking Docker ports: $err" }
    }
}

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
        ,
        [Parameter(Mandatory=$false, HelpMessage="If set, ignore Docker CLI/daemon errors and proceed anyway.")]
        [Switch]$IgnoreDockerChecks
    )

    try {
        # Basic sanity checks
        if ($PortStartAt -gt 65534) { throw "PortStartAt must allow two ports per node (max 65534)." }

        # Enforce Docker image port exposure limits using script-level constants
        $MinAllowedPort = $Script:MinAllowedPort
        $MaxAllowedPort = $Script:MaxAllowedPort

        # Calculate the last host port that would be used by the final node
        $lastPort = $PortStartAt + (($ToCreate - 1) * 2) + 1

        # Automatic fallback behavior:
        # - If PortStartAt is below MinAllowedPort, bump it to MinAllowedPort and warn.
        # - If the requested number of nodes would exceed MaxAllowedPort, reduce ToCreate to fit.
        if ($PortStartAt -lt $MinAllowedPort) {
            Write-Warning "PortStartAt $PortStartAt is below minimum allowed port $MinAllowedPort. Adjusting to $MinAllowedPort."
            $PortStartAt = $MinAllowedPort
            $lastPort = $PortStartAt + (($ToCreate - 1) * 2) + 1
        }

        $allowedNodes = [math]::Floor((($MaxAllowedPort - $PortStartAt + 1) / 2))
        if ($allowedNodes -lt 1) {
            throw "No available ports in range $MinAllowedPort-$MaxAllowedPort for the given PortStartAt=$PortStartAt. Adjust PortStartAt or change the allowed port constants."
        }

        if ($ToCreate -gt $allowedNodes) {
            Write-Warning "Requested ToCreate=$ToCreate requires $($ToCreate*2) ports but only $($allowedNodes*2) ports are available starting at $PortStartAt within $MinAllowedPort-$MaxAllowedPort."
            Write-Warning "Automatically reducing ToCreate to $allowedNodes to fit the allowed port range."
            $ToCreate = $allowedNodes
            # Recompute lastPort after reducing ToCreate
            $lastPort = $PortStartAt + (($ToCreate - 1) * 2) + 1
        }

        $currentPath = (Get-Location).ProviderPath
        $dataRoot = Join-Path -Path $currentPath -ChildPath "nodes-data"

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

            # Create node folder (skip on DryRun)
            if (-not $DryRun) {
                New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
            } else {
                Write-Verbose "DryRun: would create $folderPath"
            }

            $port1 = $PortStartAt + ($i * 2)
            $port2 = $port1 + 1

            # Verify host ports are available (try binding to loopback) and not already
            # published by another Docker container. This detects local and Docker-level conflicts.
            $port1Available = Test-PortAvailable -Port $port1
            $port2Available = Test-PortAvailable -Port $port2

            $port1PublishedRes = Test-PortPublishedByDocker -Port $port1
            $port2PublishedRes = Test-PortPublishedByDocker -Port $port2

            # If Docker checks returned errors (docker CLI missing, permission or daemon errors), surface them.
            foreach ($res in @($port1PublishedRes, $port2PublishedRes)) {
                if ($res -and $res.Error) {
                    Write-Error "Docker check error: $($res.Error)"
                    if ($IgnoreDockerChecks) {
                        Write-Warning "Ignoring Docker check errors due to -IgnoreDockerChecks. Published-port detection unavailable: $($res.Error)"
                        # if ignoring, allow execution to continue but treat Published as $false
                        continue
                    }

                    # Abort only when actually executing containers. For DryRun/preview we
                    # should not abort — allow local port checks to be shown.
                    if ($Execute -and -not $DryRun) {
                        Write-Error "Docker checks failed and -IgnoreDockerChecks not set; aborting run."
                        return
                    } else {
                        Write-Warning "Preview: Docker check error; published-port detection unavailable: $($res.Error)"
                        # In preview/dry-run mode, continue to the rest of the checks so the user
                        # can see local port availability and the generated command.
                        continue
                    }
                }
            }

            $port1Published = $port1PublishedRes.Published
            $port2Published = $port2PublishedRes.Published

            $conflictDetails = @()
            if (-not $port1Available) { $conflictDetails += "$port1 (bound locally)" }
            if ($port1Published)    { $conflictDetails += "$port1 (published by Docker)" }
            if (-not $port2Available) { $conflictDetails += "$port2 (bound locally)" }
            if ($port2Published)    { $conflictDetails += "$port2 (published by Docker)" }

            if ($conflictDetails.Count -gt 0) {
                $conflictList = $conflictDetails -join ', '
                Write-Warning "Port conflict for node $nodeName`: $conflictList"

                if ($Execute -and -not $DryRun) {
                    Write-Error "Cannot create container $nodeName`: $conflictList. Skipping."
                    continue
                } else {
                    Write-Host "DRY RUN / preview: port conflict for $nodeName ($conflictList). Command will be shown but container won't be created."
                    # Continue to build and print the command so the preview shows what would be run.
                }
            }

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

        Write-Host "Create Nodes completed."
    }
    catch {
        Write-Error "Create Nodes failed: $_"
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
        [Switch]$Overwrite,

        [Parameter()]
        [Switch]$IgnoreDockerChecks
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
    if ($IgnoreDockerChecks) { $splat.IgnoreDockerChecks = $true }

    # Call Start-CreateNodes in dry-run mode (no filesystem changes, no docker)
    Start-CreateNodes @splat

    Write-Host ""
    Write-Host "Preview completed. No containers or folders were created."
}
