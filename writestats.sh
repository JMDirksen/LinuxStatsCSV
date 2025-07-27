#!/bin/bash
cd "$(dirname "$0")"

# Create stats.csv with headers if it doesn't exist
if [ ! -f stats.csv ]; then
  echo "DT,CPU,Mem,Swp,Dsk" > stats.csv
fi

# Functions
# Calculate values
calc() { awk "BEGIN{print $*}"; }
# Round a number to a specified number of decimal places
round() { printf "%.${2}f" "$1"; }
# Extract a specific field from a line of text
field() { awk "{print \$${1}}"; }

# Get current datetime
dt=$(date +"%Y-%m-%d %H:%M")

# Get CPU usage percentage
cpu_load5=$(cat /proc/loadavg | field 2)
cpu_cores=$(nproc)
cpu_percent=$(round $(calc "$cpu_load5 * 100 / $cpu_cores"))

# Get memory usage percentage
mem_total=$(grep MemTotal /proc/meminfo | field 2)
mem_available=$(grep MemAvailable /proc/meminfo | field 2)
mem_used=$(calc "$mem_total - $mem_available")
mem_percent=$(round $(calc "$mem_used / $mem_total * 100"))

# Get swap usage percentage
swp_total=$(grep SwapTotal /proc/meminfo | field 2)
swp_free=$(grep SwapFree /proc/meminfo | field 2)
swp_used=$(calc "$swp_total - $swp_free")
swp_percent=$(round $(calc "$swp_used / $swp_total * 100"))

# Get disk usage percentage
dsk_percent=$(df / | tail -1 | field 5 | tr -d '%')

# Prepare CSV line and write to stats.csv
csv="$dt,$cpu_percent,$mem_percent,$swp_percent,$dsk_percent"
echo "$csv" >> stats.csv

# Limit stats.csv to the last 30 days of 5-minute intervals
limit_records=$((30*24*60/5)) # 30 days of 5-minute intervals
{ head -n 1 stats.csv; tail -n $limit_records stats.csv | sed '1d'; } > stats.tmp && mv stats.tmp stats.csv

# Print the output to the console
echo "DT: $dt, CPU: $cpu_percent%, Mem: $mem_percent%, Swp: $swp_percent%, Dsk: $dsk_percent%"
