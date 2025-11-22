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