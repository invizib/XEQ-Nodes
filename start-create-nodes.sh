#!/usr/bin/env bash
# start-create-nodes.sh
# Bash wrapper to create node folders and run docker containers

set -u

PROGNAME=$(basename "$0")

# Default values
START_AT=1
TO_CREATE=1
PORT_START_AT=18150
PREFIX="Node"
DOCKER_PACKAGE="ghcr.io/equilibriahorizon/equilibria-node:latest"
EXECUTE=0
OVERWRITE=0
DRY_RUN=0
IGNORE_DOCKER_CHECKS=0

# Port limits for the Docker image (change if needed)
MIN_ALLOWED_PORT=18081
MAX_ALLOWED_PORT=18200

usage() {
  cat <<EOF
Usage: $PROGNAME [options]

Options:
  --start-at N           Starting index for node numbering (default: $START_AT)
  --to-create N          Number of nodes to create (default: $TO_CREATE)
  --port-start-at N      Starting host port (default: $PORT_START_AT)
  --prefix STR           Prefix for node names (default: $PREFIX)
  --docker-package STR   Docker image to run (default: $DOCKER_PACKAGE)
  --execute              Actually run docker (otherwise print commands)
  --overwrite            Remove and recreate existing node folders
  --dry-run              Do not modify filesystem or run docker (preview)
  --ignore-docker-checks Ignore Docker CLI/daemon errors and proceed
  -h, --help             Show this help and exit

Example:
  $PROGNAME --start-at 1 --to-create 3 --port-start-at 18150 --prefix Node --dry-run
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --start-at)
      START_AT="$2"; shift 2;;
    --to-create)
      TO_CREATE="$2"; shift 2;;
    --port-start-at)
      PORT_START_AT="$2"; shift 2;;
    --prefix)
      PREFIX="$2"; shift 2;;
    --docker-package)
      DOCKER_PACKAGE="$2"; shift 2;;
    --execute)
      EXECUTE=1; shift;;
    --overwrite)
      OVERWRITE=1; shift;;
    --dry-run)
      DRY_RUN=1; shift;;
    --ignore-docker-checks)
      IGNORE_DOCKER_CHECKS=1; shift;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown option: $1" >&2; usage; exit 2;;
  esac
done

# Basic validation
if ! [[ "$START_AT" =~ ^[0-9]+$ && "$TO_CREATE" =~ ^[0-9]+$ && "$PORT_START_AT" =~ ^[0-9]+$ ]]; then
  echo "Error: --start-at, --to-create and --port-start-at must be integers." >&2
  exit 2
fi

START_AT=${START_AT}
TO_CREATE=${TO_CREATE}
PORT_START_AT=${PORT_START_AT}

# Ensure PORT_START_AT is treated as an integer (coerce strings like "18150\r")
PORT_START_AT=$((PORT_START_AT))
if (( PORT_START_AT > 65534 )); then
  echo "Error: PortStartAt must allow two ports per node (max 65534)." >&2
  exit 2
fi

# Automatic fallback: adjust PortStartAt and ToCreate to fit allowed range
if (( PORT_START_AT < MIN_ALLOWED_PORT )); then
  echo "Warning: PortStartAt $PORT_START_AT is below minimum $MIN_ALLOWED_PORT. Adjusting to $MIN_ALLOWED_PORT." >&2
  PORT_START_AT=$MIN_ALLOWED_PORT
fi

allowed_nodes=$(( (MAX_ALLOWED_PORT - PORT_START_AT + 1) / 2 ))
if (( allowed_nodes < 1 )); then
  echo "Error: No available ports in range $MIN_ALLOWED_PORT-$MAX_ALLOWED_PORT for PortStartAt=$PORT_START_AT." >&2
  exit 2
fi

if (( TO_CREATE > allowed_nodes )); then
  echo "Warning: Requested ToCreate=$TO_CREATE needs $((TO_CREATE*2)) ports but only $((allowed_nodes*2)) ports available starting at $PORT_START_AT within $MIN_ALLOWED_PORT-$MAX_ALLOWED_PORT." >&2
  echo "Automatically reducing ToCreate to $allowed_nodes to fit the allowed port range." >&2
  TO_CREATE=$allowed_nodes
fi

# Helper: check if host TCP port is in use (returns 0 if free, 1 if in use)
check_port_available() {
  local port=$1
  # Return 1 if listening on local interfaces
  # Prefer `ss` and parse its output to avoid relying on exit codes alone
  if command -v ss >/dev/null 2>&1; then
    if ss -ltn | awk '{print $4}' | grep -E ":[.]?$port$" >/dev/null 2>&1; then
      return 1
    fi
  fi

  # If available, use lsof to detect LISTEN sockets
  if command -v lsof >/dev/null 2>&1; then
    if lsof -iTCP:"$port" -sTCP:LISTEN -P -n >/dev/null 2>&1; then
      return 1
    fi
  fi

  # Fallback to nc (attempt to connect to localhost)
  if command -v nc >/dev/null 2>&1; then
    if nc -z 127.0.0.1 "$port" >/dev/null 2>&1; then
      return 1
    fi
  fi

  return 0
}

# Helper: check if Docker publishes the port. Returns:
# 0 -> published, 2 -> docker CLI missing or error, 1 -> not published
check_port_published_by_docker() {
  local port=$1
  if ! command -v docker >/dev/null 2>&1; then
    return 2
  fi
  # Capture docker ps output and check for errors
  local psout
  if ! psout=$(docker ps -q 2>&1); then
    echo "Docker error: $psout" >&2
    return 2
  fi
  if [[ -z "$psout" ]]; then
    return 1
  fi
  # iterate containers
  while read -r cid; do
    if [[ -z "$cid" ]]; then continue; fi
    if docker port "$cid" 2>/dev/null | grep -E ":$port\b" >/dev/null 2>&1; then
      return 0
    fi
  done <<< "$psout"
  return 1
}

# Main loop
CURRENT_DIR=$(pwd)

for (( i=0; i<TO_CREATE; i++ )); do
  nodeNumber=$(( START_AT + i ))
  nodeName="${PREFIX}${nodeNumber}"
  folderPath="$CURRENT_DIR/$nodeName"

  if [[ -d "$folderPath" ]]; then
    if (( OVERWRITE == 1 )); then
      if (( DRY_RUN == 0 )); then
        echo "Removing existing folder: $folderPath"
        rm -rf "$folderPath" || { echo "Failed to remove $folderPath" >&2; continue; }
      else
        echo "Dry run: would remove existing folder: $folderPath"
      fi
    else
      echo "Warning: Folder '$folderPath' already exists. Use --overwrite to replace. Skipping node $nodeName." >&2
      continue
    fi
  fi

  if (( DRY_RUN == 0 )); then
    mkdir -p "$folderPath" || { echo "Failed to create $folderPath" >&2; continue; }
  else
    echo "Dry run: would create $folderPath"
  fi

  port1=$(( PORT_START_AT + (i * 2) ))
  port2=$(( port1 + 1 ))

  # Debug: show computed ports in dry-run to help diagnose allocation issues
  if (( DRY_RUN == 1 )); then
    echo "DEBUG: node=$nodeName computed ports: $port1, $port2"
  fi
  # Check local availability
  check_port_available "$port1"
  p1_local_ok=$?
  check_port_available "$port2"
  p2_local_ok=$?

  # Check Docker published
  check_port_published_by_docker "$port1"
  p1_docker_res=$?
  check_port_published_by_docker "$port2"
  p2_docker_res=$?

  conflictDetails=()
  # Local bound
  if (( p1_local_ok != 0 )); then
    conflictDetails+=("$port1 (bound locally)")
  fi
  if (( p2_local_ok != 0 )); then
    conflictDetails+=("$port2 (bound locally)")
  fi
  # Docker published
  if (( p1_docker_res == 0 )); then
    conflictDetails+=("$port1 (published by Docker)")
  elif (( p1_docker_res == 2 )); then
    echo "Docker check error for port $port1" >&2
    if (( IGNORE_DOCKER_CHECKS == 1 )); then
      echo "Ignoring Docker check errors due to --ignore-docker-checks." >&2
    else
      if (( EXECUTE == 1 && DRY_RUN == 0 )); then
        echo "Docker checks failed; aborting run." >&2
        exit 1
      else
        echo "Preview: Docker check error for port $port1; published-port detection unavailable." >&2
      fi
    fi
  fi
  if (( p2_docker_res == 0 )); then
    conflictDetails+=("$port2 (published by Docker)")
  elif (( p2_docker_res == 2 )); then
    echo "Docker check error for port $port2" >&2
    if (( IGNORE_DOCKER_CHECKS == 1 )); then
      echo "Ignoring Docker check errors due to --ignore-docker-checks." >&2
    else
      if (( EXECUTE == 1 && DRY_RUN == 0 )); then
        echo "Docker checks failed; aborting run." >&2
        exit 1
      else
        echo "Preview: Docker check error for port $port2; published-port detection unavailable." >&2
      fi
    fi
  fi

  if (( ${#conflictDetails[@]} > 0 )); then
    conflictList=$(IFS=", "; echo "${conflictDetails[*]}")
    echo "Port conflict for node $nodeName: $conflictList" >&2
    if (( EXECUTE == 1 && DRY_RUN == 0 )); then
      echo "Cannot create container $nodeName: $conflictList. Skipping." >&2
      continue
    else
      echo "DRY RUN / preview: port conflict for $nodeName ($conflictList). Command will be shown but container won't be created."
    fi
  fi

  dockerCmd=(docker run -dit --name "$nodeName" --restart unless-stopped -p "$port1:$port1" -p "$port2:$port2" -v "$folderPath:/data" "$DOCKER_PACKAGE" --testnet --data-dir=/data "--p2p-bind-port=$port1" "--rpc-bind-port=$port2" --add-exclusive-node=84.247.143.210:18080 --log-level=3)

  if (( EXECUTE == 1 )); then
    echo "Creating Docker container: $nodeName (ports $port1,$port2) ..."
    if (( DRY_RUN == 0 )); then
      if ! "${dockerCmd[@]}" 2>&1 | while IFS= read -r line; do echo "$line"; done; then
        echo "Failed to create container $nodeName" >&2
      else
        echo "Container $nodeName created."
      fi
    else
      echo "Dry run: would run: ${dockerCmd[*]}"
    fi
  else
    # Print DRY RUN command
    cmdLine="docker ${dockerCmd[*]:1}"
    echo "DRY RUN: $cmdLine"
  fi

done

echo "Create-Nodes completed."

exit 0
