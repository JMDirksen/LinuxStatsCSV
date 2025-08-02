#!/bin/bash
cd "$(dirname "$0")"

# Config
interval_minutes=60  # The interval this script runs at (as configured in cron)
keep_hours=24        # Statistics history length

# Calculate how many records should be kept in the csv file
keep_records=$(($keep_hours * 60 / $interval_minutes))

# Create stats.csv with headers if it doesn't exist
if [ ! -f stats.csv ]; then
  echo "DateTime,CPU %,Memory %,Swap %,Disk activity %,Disk space %,Uptime (/100d) %" > stats.csv
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

# Get max activity of all disk devices
disk_devices=$(lsblk -no KNAME,TYPE,PKNAME | awk '$2=="disk" && $3=="" {print $1}')
max_disk_activity_percent=0
for device in $disk_devices; do
    device_tmp_file="disk_io_ms_${device}.tmp"
    last_disk_io_ms=$(cat "$device_tmp_file" 2>/dev/null || echo 0)
    current_disk_io_ms=$(awk -v dev="$device" '$3==dev {print $14}' /proc/diskstats 2>/dev/null)
    echo "$current_disk_io_ms" > "$device_tmp_file"
    diff_disk_io_ms=$(calc "$current_disk_io_ms - $last_disk_io_ms")
    disk_activity_percent=$(round $(calc "$diff_disk_io_ms / ($interval_minutes * 60 * 1000) * 100"))
    if [ $disk_activity_percent -gt 100 ] || [ $disk_activity_percent -lt 0 ]; then
        disk_activity_percent=0
    fi
    if [ "$disk_activity_percent" -gt "$max_disk_activity_percent" ]; then
        max_disk_activity_percent="$disk_activity_percent"
    fi
done

# Get disk space percentage
dsk_space_percent=$(df / | tail -1 | field 5 | tr -d '%')

# Get uptime percentage
uptime_minutes=$(awk '{print int($1 / 60)}' /proc/uptime)
uptime_percent=$(round $(calc "$uptime_minutes / (100 * 24 * 60) * 100"))

# Prepare CSV line and write to stats.csv
csv="$dt,$cpu_percent,$mem_percent,$swp_percent,$max_disk_activity_percent,$dsk_space_percent,$uptime_percent"
echo "$csv" >> stats.csv

# Limit stats.csv to the keep_records number of records
total_lines=$(wc -l < stats.csv)
if [ "$total_lines" -gt "$(($keep_records + 1))" ]; then
  { head -n 1 stats.csv; tail -n +2 stats.csv | tail -n $keep_records; } > stats.tmp && mv stats.tmp stats.csv
fi

# Print the output to the console
echo "DateTime: $dt"
echo "CPU: $cpu_percent%"
echo "Memory: $mem_percent%"
echo "Swap: $swp_percent%"
echo "Disk activity: $max_disk_activity_percent%"
echo "Disk space: $dsk_space_percent%"
echo "Uptime: $uptime_percent%"
