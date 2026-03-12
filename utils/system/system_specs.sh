#!/usr/bin/env bash

# Purpose: generate a text report with host utilization and hardware details.
# Problem Solved: capture a reusable system summary for troubleshooting or capacity review.

set -euo pipefail

usage() {
    cat <<EOF
Usage:
  $0 [--output FILE]

Description:
  Generates a system summary report including load, CPU, memory, disk, and top processes.

Default output:
  system_summary_report.txt
EOF
}

OUTPUT="system_summary_report.txt"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            [[ $# -ge 2 ]] || {
                echo "Error: --output requires a value." >&2
                usage
                exit 1
            }
            OUTPUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

for dependency in awk bc df free lsblk lscpu ps top; do
    command -v "$dependency" >/dev/null 2>&1 || {
        echo "Error: required command '$dependency' is missing." >&2
        exit 1
    }
done

read_cpu_jiffies() {
    awk '/^cpu / {print $2, $3, $4, $5, $6, $7, $8}' /proc/stat
}

cpu_usage_percent() {
    if [[ -r /proc/stat ]]; then
        local cpu1 cpu2
        local user1 nice1 system1 idle1 iowait1 irq1 softirq1
        local user2 nice2 system2 idle2 iowait2 irq2 softirq2
        read -r user1 nice1 system1 idle1 iowait1 irq1 softirq1 <<< "$(read_cpu_jiffies)"
        sleep 0.2
        read -r user2 nice2 system2 idle2 iowait2 irq2 softirq2 <<< "$(read_cpu_jiffies)"
        local idle_delta total_delta
        idle_delta=$(((idle2 + iowait2) - (idle1 + iowait1)))
        total_delta=$(((user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2) - (user1 + nice1 + system1 + idle1 + iowait1 + irq1 + softirq1)))
        if (( total_delta > 0 )); then
            awk -v idle="$idle_delta" -v total="$total_delta" 'BEGIN { printf "%.2f", (1 - idle/total) * 100 }'
            return
        fi
    fi

    top -bn1 | awk -F'[:, ]+' '/Cpu\(s\)|%Cpu/ {for (i = 1; i <= NF; i++) if ($i == "id" || $i == "id,") {printf "%.2f", 100 - $(i-1); exit}}'
}

load_and_uptime_line() {
    if [[ -r /proc/uptime && -r /proc/loadavg ]]; then
        local total_seconds days hours minutes
        total_seconds="$(awk '{print int($1)}' /proc/uptime)"
        days=$((total_seconds / 86400))
        hours=$(((total_seconds % 86400) / 3600))
        minutes=$(((total_seconds % 3600) / 60))
        printf "Uptime: %dd %02dh %02dm, Load Average (1, 5, 15 min): %s\n" \
            "$days" "$hours" "$minutes" "$(awk '{print $1 ", " $2 ", " $3}' /proc/loadavg)"
        return
    fi

    uptime | awk -F', ' '{print "Uptime: " $1 ", Load Average (1, 5, 15 min): " $3 ", " $4 ", " $5}'
}

# Start report
echo "===== SYSTEM SUMMARY REPORT =====" > "$OUTPUT"
echo "Date: $(date)" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# System Load and Uptime
echo "===== SYSTEM LOAD AND UPTIME =====" >> "$OUTPUT"
load_and_uptime_line >> "$OUTPUT"
echo "" >> "$OUTPUT"

# System Utilization Summary
echo "===== SYSTEM UTILIZATION SUMMARY =====" >> "$OUTPUT"

# Get overall CPU utilization in percentage
cpu_util="$(cpu_usage_percent)"

# Get overall memory utilization in percentage
mem_util=$(free | awk 'NR==2{printf "%.2f", $3*100/$2 }')

# Get overall disk usage in percentage (root partition only)
disk_util=$(df -h / | awk 'NR==2 {print $5}')

# Display summary table
printf "%-20s %-20s\n" "Metric" "Utilization" >> "$OUTPUT"
printf "%-20s %-20s\n" "--------------------" "--------------------" >> "$OUTPUT"
printf "%-20s %-20s\n" "CPU Usage" "${cpu_util}%" >> "$OUTPUT"
printf "%-20s %-20s\n" "Memory Usage" "${mem_util}%" >> "$OUTPUT"
printf "%-20s %-20s\n" "Disk Usage (root)" "$disk_util" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# CPU Info
echo "===== CPU INFORMATION =====" >> "$OUTPUT"
lscpu | grep -E '^Model name|^CPU\(s\)|^Thread|^Core|MHz' >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Memory Details
echo "===== MEMORY INFORMATION =====" >> "$OUTPUT"
free -h | awk 'NR==1 || NR==2 {printf "%-10s %-10s %-10s %-10s %-10s %-10s\n", $1, $2, $3, $4, $5, $6}' >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Disk Allocation Info - Total Summary
echo "===== DISK ALLOCATION SUMMARY =====" >> "$OUTPUT"

# Calculate total storage, excluding loop devices and duplicate LVM entries
total_storage_bytes=$(lsblk -d -b -o NAME,SIZE | awk '$1 !~ /^loop/ {sum+=$2} END {print sum}')

# Use associative array to track unique LVM logical volumes
declare -A lvm_volumes
allocated_storage_bytes=0

while read -r name size mountpoint; do
  if [[ $name =~ ^loop ]]; then
    continue  # Skip loop devices
  elif [[ -n $mountpoint && $name =~ ubuntu--vg ]]; then
    # Track unique LVM logical volume names and add only once
    if [[ -z ${lvm_volumes[$name]:-} ]]; then
      allocated_storage_bytes=$((allocated_storage_bytes + size))
      lvm_volumes[$name]=1
    fi
  elif [[ -n $mountpoint ]]; then
    # Count non-LVM mounted partitions directly
    allocated_storage_bytes=$((allocated_storage_bytes + size))
  fi
done < <(lsblk -b -o NAME,SIZE,MOUNTPOINT | tail -n +2)

# Ensure unallocated storage matches total - allocated
unallocated_storage_bytes=$(echo "$total_storage_bytes - $allocated_storage_bytes" | bc)

# Function to dynamically format bytes to TiB, GiB, or MiB
format_storage() {
  local bytes=$1
  if (( bytes >= 1099511627776 )); then
    printf "%.2f TiB" "$(echo "$bytes / 1099511627776" | bc -l)"
  elif (( bytes >= 1073741824 )); then
    printf "%.2f GiB" "$(echo "$bytes / 1073741824" | bc -l)"
  else
    printf "%.2f MiB" "$(echo "$bytes / 1048576" | bc -l)"
  fi
}

# Display the formatted total, allocated, and unallocated storage
echo "Total Storage: $(format_storage "$total_storage_bytes")" >> "$OUTPUT"
echo "Allocated Storage: $(format_storage "$allocated_storage_bytes")" >> "$OUTPUT"
echo "Unallocated Storage: $(format_storage "$unallocated_storage_bytes")" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Disk Allocation Details - Showing specific devices (excluding loop)
echo "===== DISK ALLOCATION DETAILS =====" >> "$OUTPUT"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | awk '$1 !~ /^loop/' >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Top Processes
echo "===== TOP CPU PROCESSES =====" >> "$OUTPUT"
ps aux --sort=-%cpu | awk 'NR==1 || NR<=11 {printf "%-10s %-6s %-6s %.40s\n", $1, $3, $4, $11}' >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Report complete
echo "System Summary Report saved to $OUTPUT"
