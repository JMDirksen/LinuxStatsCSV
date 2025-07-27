#!/bin/bash
cd "$(dirname "$0")"

# Create stats.csv with headers if it doesn't exist
if [ ! -f stats.csv ]; then
  echo "DateTime,CPU %,Memory %,Swap %,Disk activity %,Disk full %,Uptime %" > stats.csv
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

# Get disk activity percentage
last_disk_io_ms=$(cat disk_io_ms.tmp 2>/dev/null || echo 0)
root_device=$(df / | tail -1 | awk '{print $1}')
if [[ "$root_device" == /dev/mapper/* ]]; then
  disk_device=$(lsblk -no KNAME "$root_device" | head -n 1)
else
  disk_device=$(basename "$root_device" | sed 's/[0-9]*$//')
fi
disk_io_ms=$(awk -v dev="$disk_device" '$3==dev {print $14}' /proc/diskstats)
echo "$disk_io_ms" > disk_io_ms.tmp
diff_disk_io_ms=$(calc "$disk_io_ms - $last_disk_io_ms")
# Convert diff to percentage over 5 minutes (300000 ms)
disk_activity_percent=$(round $(calc "$diff_disk_io_ms / 300000 * 100"))

# Get disk full percentage
dsk_full_percent=$(df / | tail -1 | field 5 | tr -d '%')

# Get uptime percentage
uptime_minutes=$(awk '{print int($1 / 60)}' /proc/uptime)
uptime_percent=$(round $(calc "$uptime_minutes / (30 * 24 * 60) * 100"))

# Prepare CSV line and write to stats.csv
csv="$dt,$cpu_percent,$mem_percent,$swp_percent,$disk_activity_percent,$dsk_full_percent,$uptime_percent"
echo "$csv" >> stats.csv

# Limit stats.csv to the last 30 days of 5-minute intervals when the file exceeds this limit
limit_records=$((30*24*60/5)) # 30 days of 5-minute intervals
total_lines=$(wc -l < stats.csv)
if [ "$total_lines" -gt "$((limit_records + 1))" ]; then
  { head -n 1 stats.csv; tail -n +2 stats.csv | tail -n $limit_records; } > stats.tmp && mv stats.tmp stats.csv
fi

# Print the output to the console
echo "DateTime: $dt"
echo "CPU: $cpu_percent%"
echo "Memory: $mem_percent%"
echo "Swap: $swp_percent%"
echo "Disk Activity: $disk_activity_percent%"
echo "Disk Full: $dsk_full_percent%"
echo "Uptime: $uptime_percent%"
