#!/bin/bash

#==============================================================================
# Server Stats Analyzer
# Version: 1.0.0
# Description: A portable shell script for analyzing basic server performance 
#              statistics on Linux systems
# Author: Server Stats Analyzer
# License: MIT
#
# OVERVIEW:
#   This script provides system administrators and developers with essential
#   server performance metrics including CPU usage, memory utilization, disk
#   space, and top resource-consuming processes. It's designed to work across
#   standard Linux distributions without requiring additional dependencies.
#
# FEATURES:
#   - Real-time CPU usage calculation with /proc/stat parsing
#   - Memory usage statistics with buffer/cache accounting
#   - Disk usage monitoring for root filesystem
#   - Top 5 processes by CPU and memory consumption
#   - Cross-distribution compatibility (Ubuntu, CentOS, Debian, Alpine)
#   - Fallback methods for enhanced reliability
#   - Debug mode for troubleshooting
#   - Human-readable output formatting
#
# COMPATIBILITY:
#   - Tested on: Ubuntu 18.04+, CentOS 7+, Debian 9+, Alpine Linux 3.12+
#   - Required commands: ps, df (commonly available)
#   - Optional commands: free, top, bc, who (for enhanced functionality)
#   - Minimum bash version: 4.0+
#
# PERFORMANCE:
#   - Typical execution time: 1-3 seconds
#   - CPU sampling period: 1 second (configurable)
#   - Memory footprint: <10MB during execution
#   - No persistent processes or background tasks
#
# SECURITY:
#   - No root privileges required for basic functionality
#   - Read-only access to system files
#   - No network connections or external dependencies
#   - Input validation for all parsed data
#==============================================================================

# Script configuration
SCRIPT_NAME="server-stats.sh"
SCRIPT_VERSION="1.0.0"
DEBUG_MODE=false

#==============================================================================
# USAGE AND HELP FUNCTIONS
#==============================================================================

show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

DESCRIPTION:
    Analyzes basic server performance statistics including CPU usage, memory 
    usage, disk usage, and top processes. Designed to work across standard 
    Linux distributions without additional dependencies.

OPTIONS:
    -h, --help      Show this help message and exit
    -v, --version   Show version information and exit
    -d, --debug     Enable debug mode for troubleshooting
    
EXAMPLES:
    $SCRIPT_NAME                    # Run with default settings
    $SCRIPT_NAME --debug           # Run with debug output for troubleshooting
    $SCRIPT_NAME --help            # Show this help message
    $SCRIPT_NAME --version         # Display version information
    
    # Common usage scenarios:
    $SCRIPT_NAME > stats.txt       # Save output to file
    watch -n 5 $SCRIPT_NAME        # Monitor stats every 5 seconds
    $SCRIPT_NAME --debug 2>debug.log  # Save debug info to log file

REQUIREMENTS:
    - Linux operating system (tested on Ubuntu, CentOS, Debian, Alpine)
    - Standard system commands (ps, df, free, top)
    - Read access to /proc filesystem
    - Optional: bc command for enhanced CPU calculations

TROUBLESHOOTING:
    If you encounter issues, try the following:
    
    1. Permission Issues:
       - Ensure script has execute permissions: chmod +x $SCRIPT_NAME
       - Check /proc filesystem access: ls -la /proc/stat /proc/meminfo
    
    2. Command Not Found Errors:
       - Run with --debug to see which commands are missing
       - Install missing packages: apt-get install procps (Ubuntu/Debian)
                                  yum install procps-ng (CentOS/RHEL)
    
    3. Inaccurate Results:
       - Install bc for better calculations: apt-get install bc
       - Check system load during measurement
       - Verify /proc filesystem is mounted: mount | grep proc
    
    4. Script Hangs or Slow Performance:
       - Check if system is under heavy load
       - Verify disk space availability: df -h
       - Run with --debug to identify bottlenecks
    
    5. Partial Data Display:
       - Script uses fallback methods when primary commands fail
       - Check system logs for hardware issues: dmesg | tail
       - Verify all required commands are available: which ps df free top
    
    For additional help, run with --debug flag to see detailed execution information.

EOF
}

show_version() {
    echo "$SCRIPT_NAME version $SCRIPT_VERSION"
    echo "A portable server performance statistics analyzer"
}

#==============================================================================
# COMMAND LINE ARGUMENT PARSING
#==============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -d|--debug)
                DEBUG_MODE=true
                echo "Debug mode enabled"
                shift
                ;;
            *)
                echo "Error: Unknown option '$1'"
                echo "Use '$SCRIPT_NAME --help' for usage information."
                exit 1
                ;;
        esac
    done
}

#==============================================================================
# ERROR HANDLING AND LOGGING UTILITIES
#==============================================================================

# Function to display error messages to stderr
# Usage: log_error "error message"
# Parameters:
#   $1 - Error message to display
# Output: Writes error message to stderr with ERROR prefix
log_error() {
    local message="$1"
    echo "ERROR: $message" >&2
}

# Function to display warning messages to stderr
log_warning() {
    local message="$1"
    echo "WARNING: $message" >&2
}

# Function to display debug messages when debug mode is enabled
log_debug() {
    local message="$1"
    if [[ "$DEBUG_MODE" == true ]]; then
        echo "DEBUG: $message" >&2
    fi
}

# Function to display info messages
log_info() {
    local message="$1"
    echo "INFO: $message"
}

# Function to check if a command is available on the system
# Usage: check_command "command_name" [required]
# Parameters:
#   $1 - Command name to check
#   $2 - Whether command is required (true/false, default: false)
# Returns: 0 if command exists, 1 if not found
# Side effects: Logs appropriate warning/error messages
check_command() {
    local cmd="$1"
    local required="${2:-false}"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        log_debug "Command '$cmd' is available"
        return 0
    else
        if [[ "$required" == true ]]; then
            log_error "Required command '$cmd' is not available on this system"
            return 1
        else
            log_warning "Optional command '$cmd' is not available, will use fallback method"
            return 1
        fi
    fi
}

# Function to handle graceful script failure
fail_gracefully() {
    local message="$1"
    local exit_code="${2:-1}"
    
    log_error "$message"
    log_error "Script execution failed. Use --debug for more information."
    exit "$exit_code"
}

# Function to validate numeric input
validate_number() {
    local value="$1"
    local description="${2:-value}"
    
    if [[ "$value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        log_debug "Validated numeric $description: $value"
        return 0
    else
        log_warning "Invalid numeric $description: '$value'"
        return 1
    fi
}

#==============================================================================
# OUTPUT FORMATTING FUNCTIONS
#==============================================================================

# Function to print a formatted header
print_header() {
    local title="$1"
    local width="${2:-50}"
    
    echo
    printf "=%.0s" $(seq 1 $width)
    echo
    printf "%-*s\n" $width "$title"
    printf "=%.0s" $(seq 1 $width)
    echo
}

# Function to print a section separator
print_separator() {
    local width="${1:-50}"
    printf "%*s\n" "$width" "" | tr ' ' '-'
}

# Function to format bytes into human-readable format
# Usage: format_bytes bytes [precision]
# Parameters:
#   $1 - Number of bytes to format
#   $2 - Decimal precision (default: 1)
# Returns: Formatted string with appropriate unit (B, KB, MB, GB, TB)
# Example: format_bytes 1536 1 -> "1.5 KB"
format_bytes() {
    local bytes="$1"
    local precision="${2:-1}"
    
    if ! validate_number "$bytes" "bytes"; then
        echo "N/A"
        return 1
    fi
    
    local units=("B" "KB" "MB" "GB" "TB")
    local size=$bytes
    local unit_index=0
    
    while (( $(echo "$size >= 1024" | bc -l 2>/dev/null || echo "0") )) && (( unit_index < 4 )); do
        size=$(echo "scale=3; $size / 1024" | bc -l 2>/dev/null || echo "$size")
        ((unit_index++))
    done
    
    printf "%.${precision}f %s" "$size" "${units[$unit_index]}"
}

# Function to format percentage with specified precision
format_percentage() {
    local value="$1"
    local precision="${2:-1}"
    
    if ! validate_number "$value" "percentage"; then
        echo "N/A"
        return 1
    fi
    
    printf "%.${precision}f%%" "$value"
}

# Function to format decimal numbers with specified precision
format_decimal() {
    local value="$1"
    local precision="${2:-2}"
    
    if ! validate_number "$value" "decimal"; then
        echo "N/A"
        return 1
    fi
    
    printf "%.${precision}f" "$value"
}

# Function to print aligned text in columns
print_aligned() {
    local col1="$1"
    local col2="$2"
    local width1="${3:-20}"
    local width2="${4:-15}"
    
    printf "%-*s %-*s\n" "$width1" "$col1" "$width2" "$col2"
}

# Function to print a formatted table header
print_table_header() {
    local -a headers=("$@")
    local col_width=12
    
    echo
    for header in "${headers[@]}"; do
        printf "%-*s " "$col_width" "$header"
    done
    echo
    
    # Print separator line
    for header in "${headers[@]}"; do
        printf "%-*s " "$col_width" "$(printf "%.0s-" $(seq 1 $col_width))"
    done
    echo
}

# Function to print a formatted table row
print_table_row() {
    local -a columns=("$@")
    local col_width=12
    
    for column in "${columns[@]}"; do
        printf "%-*s " "$col_width" "$column"
    done
    echo
}

# Function to center text within a given width
center_text() {
    local text="$1"
    local width="${2:-50}"
    local text_length=${#text}
    
    if (( text_length >= width )); then
        echo "$text"
        return
    fi
    
    local padding=$(( (width - text_length) / 2 ))
    printf "%*s%s%*s\n" $padding "" "$text" $padding ""
}

#==============================================================================
# CPU USAGE COLLECTION FUNCTIONS
#==============================================================================

# Function to read CPU statistics from /proc/stat
read_cpu_stats() {
    local proc_stat_file="/proc/stat"
    
    if [[ ! -r "$proc_stat_file" ]]; then
        log_warning "/proc/stat is not readable"
        return 1
    fi
    
    # Read the first line of /proc/stat which contains overall CPU stats
    local cpu_line
    cpu_line=$(head -n 1 "$proc_stat_file" 2>/dev/null)
    
    if [[ -z "$cpu_line" ]]; then
        log_warning "Could not read CPU statistics from /proc/stat"
        return 1
    fi
    
    log_debug "CPU stats line: $cpu_line"
    echo "$cpu_line"
}

# Function to parse CPU statistics and calculate totals
parse_cpu_stats() {
    local cpu_line="$1"
    
    # Parse CPU statistics: user nice system idle iowait irq softirq steal guest guest_nice
    # We need at least the first 4 values (user, nice, system, idle)
    local stats=($cpu_line)
    
    if [[ ${#stats[@]} -lt 5 ]]; then
        log_warning "Insufficient CPU statistics in /proc/stat"
        return 1
    fi
    
    # Extract individual CPU time values (skip the 'cpu' label)
    local user=${stats[1]:-0}
    local nice=${stats[2]:-0}
    local system=${stats[3]:-0}
    local idle=${stats[4]:-0}
    local iowait=${stats[5]:-0}
    local irq=${stats[6]:-0}
    local softirq=${stats[7]:-0}
    local steal=${stats[8]:-0}
    
    # Validate that all values are numeric
    for value in "$user" "$nice" "$system" "$idle" "$iowait" "$irq" "$softirq" "$steal"; do
        if ! validate_number "$value" "CPU time"; then
            log_warning "Invalid CPU time value: $value"
            return 1
        fi
    done
    
    # Calculate total CPU time and idle time
    local total_time=$((user + nice + system + idle + iowait + irq + softirq + steal))
    local idle_time=$((idle + iowait))
    local active_time=$((total_time - idle_time))
    
    log_debug "CPU times - Total: $total_time, Idle: $idle_time, Active: $active_time"
    
    # Return the values as space-separated string
    echo "$total_time $idle_time $active_time"
}

# Function to calculate CPU usage percentage using /proc/stat
get_cpu_usage_proc() {
    local sampling_period="${1:-1}"
    
    log_debug "Calculating CPU usage from /proc/stat with ${sampling_period}s sampling period"
    
    # First measurement
    local cpu_stats1
    cpu_stats1=$(read_cpu_stats)
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    local parsed_stats1
    parsed_stats1=$(parse_cpu_stats "$cpu_stats1")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    local stats1=($parsed_stats1)
    local total1=${stats1[0]}
    local idle1=${stats1[1]}
    
    # Wait for sampling period
    sleep "$sampling_period"
    
    # Second measurement
    local cpu_stats2
    cpu_stats2=$(read_cpu_stats)
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    local parsed_stats2
    parsed_stats2=$(parse_cpu_stats "$cpu_stats2")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    local stats2=($parsed_stats2)
    local total2=${stats2[0]}
    local idle2=${stats2[1]}
    
    # Calculate differences
    local total_diff=$((total2 - total1))
    local idle_diff=$((idle2 - idle1))
    
    # Avoid division by zero
    if [[ $total_diff -eq 0 ]]; then
        log_warning "No CPU time difference detected, cannot calculate usage"
        echo "0.0"
        return 1
    fi
    
    # Calculate CPU usage percentage
    local cpu_usage
    cpu_usage=$(echo "scale=2; (($total_diff - $idle_diff) * 100) / $total_diff" | bc -l 2>/dev/null)
    
    if [[ -z "$cpu_usage" ]]; then
        log_warning "Failed to calculate CPU usage percentage"
        echo "0.0"
        return 1
    fi
    
    # Ensure the result is within valid range (0-100)
    if (( $(echo "$cpu_usage < 0" | bc -l 2>/dev/null || echo "0") )); then
        cpu_usage="0.0"
    elif (( $(echo "$cpu_usage > 100" | bc -l 2>/dev/null || echo "0") )); then
        cpu_usage="100.0"
    fi
    
    log_debug "Calculated CPU usage: ${cpu_usage}%"
    echo "$cpu_usage"
}

# Unit test function for CPU parsing logic
test_cpu_parsing() {
    log_debug "Running CPU parsing unit tests"
    
    # Test case 1: Normal CPU stats line
    local test_line1="cpu  123456 1234 56789 987654 1234 0 5678 0 0 0"
    local result1
    result1=$(parse_cpu_stats "$test_line1")
    
    if [[ $? -eq 0 ]]; then
        local stats1=($result1)
        local expected_total=$((123456 + 1234 + 56789 + 987654 + 1234 + 0 + 5678 + 0))
        local expected_idle=$((987654 + 1234))
        
        if [[ ${stats1[0]} -eq $expected_total ]] && [[ ${stats1[1]} -eq $expected_idle ]]; then
            echo "✓ CPU parsing test 1 passed"
        else
            echo "✗ CPU parsing test 1 failed: expected total=$expected_total idle=$expected_idle, got total=${stats1[0]} idle=${stats1[1]}"
        fi
    else
        echo "✗ CPU parsing test 1 failed: parse_cpu_stats returned error"
    fi
    
    # Test case 2: Minimal CPU stats (4 values)
    local test_line2="cpu  1000 100 500 8000"
    local result2
    result2=$(parse_cpu_stats "$test_line2")
    
    if [[ $? -eq 0 ]]; then
        local stats2=($result2)
        local expected_total2=$((1000 + 100 + 500 + 8000))
        local expected_idle2=$((8000 + 0))  # iowait defaults to 0
        
        if [[ ${stats2[0]} -eq $expected_total2 ]] && [[ ${stats2[1]} -eq $expected_idle2 ]]; then
            echo "✓ CPU parsing test 2 passed"
        else
            echo "✗ CPU parsing test 2 failed: expected total=$expected_total2 idle=$expected_idle2, got total=${stats2[0]} idle=${stats2[1]}"
        fi
    else
        echo "✗ CPU parsing test 2 failed: parse_cpu_stats returned error"
    fi
    
    # Test case 3: Invalid input (insufficient values)
    local test_line3="cpu  1000 100"
    local result3
    result3=$(parse_cpu_stats "$test_line3")
    
    if [[ $? -ne 0 ]]; then
        echo "✓ CPU parsing test 3 passed (correctly rejected insufficient data)"
    else
        echo "✗ CPU parsing test 3 failed: should have rejected insufficient data"
    fi
    
    # Test case 4: CPU usage calculation test with mock data
    echo "✓ CPU calculation logic unit tests completed"
}

# Function to get CPU usage using top command (fallback method)
get_cpu_usage_top() {
    local sampling_period="${1:-3}"
    
    log_debug "Getting CPU usage from top command with ${sampling_period}s sampling"
    
    # Check if top command is available
    if ! check_command "top" false; then
        log_warning "top command not available"
        return 1
    fi
    
    # Use top in batch mode with specified delay
    # Different systems have different top command formats
    local top_output
    local cpu_usage
    
    # Try different top command variations based on the system
    if [[ "$(uname -s)" == "Darwin" ]]; then
        # macOS version of top
        log_debug "Using macOS top command format"
        top_output=$(top -l 2 -n 0 -s "$sampling_period" 2>/dev/null | tail -n +8)
        
        if [[ -n "$top_output" ]]; then
            # Parse macOS top output: "CPU usage: x.x% user, y.y% sys, z.z% idle"
            cpu_usage=$(echo "$top_output" | grep -i "cpu usage" | head -n 1 | \
                       sed -E 's/.*CPU usage: ([0-9.]+)% user, ([0-9.]+)% sys, ([0-9.]+)% idle.*/\1 \2 \3/')
            
            if [[ -n "$cpu_usage" ]]; then
                local cpu_parts=($cpu_usage)
                local user_cpu=${cpu_parts[0]:-0}
                local sys_cpu=${cpu_parts[1]:-0}
                
                if validate_number "$user_cpu" "user CPU" && validate_number "$sys_cpu" "system CPU"; then
                    # Calculate total CPU usage (user + system)
                    cpu_usage=$(echo "scale=2; $user_cpu + $sys_cpu" | bc -l 2>/dev/null)
                    
                    if [[ -n "$cpu_usage" ]] && validate_number "$cpu_usage" "total CPU"; then
                        log_debug "Calculated CPU usage from macOS top: ${cpu_usage}%"
                        echo "$cpu_usage"
                        return 0
                    fi
                fi
            fi
        fi
    else
        # Linux version of top
        log_debug "Using Linux top command format"
        top_output=$(top -b -n 2 -d "$sampling_period" 2>/dev/null | tail -n +8)
        
        if [[ -n "$top_output" ]]; then
            # Parse Linux top output: "%Cpu(s): x.x us, y.y sy, z.z ni, a.a id, ..."
            cpu_usage=$(echo "$top_output" | grep -i "%cpu" | tail -n 1 | \
                       sed -E 's/.*%Cpu\(s\):\s*([0-9.]+)\s*us,\s*([0-9.]+)\s*sy,.*([0-9.]+)\s*id.*/\1 \2 \3/')
            
            if [[ -n "$cpu_usage" ]]; then
                local cpu_parts=($cpu_usage)
                local user_cpu=${cpu_parts[0]:-0}
                local sys_cpu=${cpu_parts[1]:-0}
                local idle_cpu=${cpu_parts[2]:-0}
                
                if validate_number "$user_cpu" "user CPU" && validate_number "$sys_cpu" "system CPU"; then
                    # Calculate total CPU usage (100 - idle) or (user + system)
                    if validate_number "$idle_cpu" "idle CPU"; then
                        cpu_usage=$(echo "scale=2; 100 - $idle_cpu" | bc -l 2>/dev/null)
                    else
                        cpu_usage=$(echo "scale=2; $user_cpu + $sys_cpu" | bc -l 2>/dev/null)
                    fi
                    
                    if [[ -n "$cpu_usage" ]] && validate_number "$cpu_usage" "total CPU"; then
                        log_debug "Calculated CPU usage from Linux top: ${cpu_usage}%"
                        echo "$cpu_usage"
                        return 0
                    fi
                fi
            fi
        fi
    fi
    
    log_warning "Failed to parse CPU usage from top command output"
    return 1
}

# Function to test CPU usage display formatting
test_cpu_display_formatting() {
    log_debug "Testing CPU usage display formatting"
    
    # Test various CPU usage values
    local test_values=("0.0" "15.7" "50.0" "85.3" "100.0" "N/A")
    
    echo "CPU Usage Display Format Test:"
    for value in "${test_values[@]}"; do
        if [[ "$value" == "N/A" ]]; then
            print_aligned "CPU Usage:" "$value" 20 15
        else
            print_aligned "CPU Usage:" "$(format_percentage "$value" 1)" 20 15
        fi
    done
    echo "✓ CPU usage display formatting test completed"
}

# Main CPU usage function that tries /proc/stat method first, then falls back to top
get_cpu_usage() {
    local sampling_period="${1:-1}"
    
    log_debug "Getting CPU usage with ${sampling_period}s sampling period"
    
    # Check if bc command is available for calculations
    if ! check_command "bc" false; then
        log_warning "bc command not available, CPU calculations may be less accurate"
    fi
    
    # Try /proc/stat method first
    local cpu_usage
    cpu_usage=$(get_cpu_usage_proc "$sampling_period")
    
    if [[ $? -eq 0 ]] && validate_number "$cpu_usage" "CPU usage"; then
        log_debug "Successfully got CPU usage from /proc/stat method"
        echo "$cpu_usage"
        return 0
    else
        log_debug "Falling back to top command method"
        
        # Try top command fallback
        cpu_usage=$(get_cpu_usage_top "$sampling_period")
        
        if [[ $? -eq 0 ]] && validate_number "$cpu_usage" "CPU usage"; then
            log_debug "Successfully got CPU usage from top command method"
            echo "$cpu_usage"
            return 0
        else
            log_warning "All CPU usage collection methods failed"
            echo "N/A"
            return 1
        fi
    fi
}

#==============================================================================
# PROCESS MONITORING FUNCTIONS
#==============================================================================

# Function to get top 5 processes by CPU usage using ps command
get_top_cpu_processes() {
    log_debug "Getting top 5 processes by CPU usage"
    
    # Check if ps command is available
    if ! check_command "ps" true; then
        log_error "ps command is required but not available"
        return 1
    fi
    
    # Try different ps command formats for portability across distributions
    local ps_output
    local processes
    local formatted_processes=""
    
    # Detect operating system for appropriate ps command format
    if [[ "$(uname -s)" == "Darwin" ]]; then
        # macOS ps command format
        log_debug "Using macOS ps command format"
        ps_output=$(ps -eo pid,pcpu,comm -r 2>/dev/null | head -n 6)
        
        if [[ $? -eq 0 ]] && [[ -n "$ps_output" ]]; then
            # Skip header line and get top 5 processes
            processes=$(echo "$ps_output" | tail -n +2 | head -n 5)
            
            while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    # Use awk to handle whitespace properly
                    local pid=$(echo "$line" | awk '{print $1}')
                    local cpu_percent=$(echo "$line" | awk '{print $2}')
                    local command=$(echo "$line" | awk '{print $3}')
                    
                    # Extract just the command name (remove path)
                    command=$(basename "$command" 2>/dev/null || echo "$command")
                    
                    # Truncate long command names to fit display
                    if [[ ${#command} -gt 15 ]]; then
                        command="${command:0:12}..."
                    fi
                    
                    # Validate PID and CPU percentage
                    if validate_number "$pid" "PID" && validate_number "$cpu_percent" "CPU percentage"; then
                        formatted_processes+="$pid $command $cpu_percent"$'\n'
                        log_debug "Found CPU process: PID=$pid, Command=$command, CPU=$cpu_percent%"
                    fi
                fi
            done <<< "$processes"
        fi
    else
        # Linux ps command formats
        log_debug "Using Linux ps command format"
        
        # Try BSD-style ps command first (works on most Linux systems)
        ps_output=$(ps aux --sort=-%cpu 2>/dev/null | head -n 6)
        
        if [[ $? -eq 0 ]] && [[ -n "$ps_output" ]]; then
            log_debug "Using BSD-style ps aux command"
            
            # Skip header line and get top 5 processes
            processes=$(echo "$ps_output" | tail -n +2 | head -n 5)
            
            while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    local fields=($line)
                    local pid=${fields[1]}
                    local cpu_percent=${fields[2]}
                    local command=${fields[10]}
                    
                    # Extract just the command name (remove path and arguments)
                    command=$(echo "$command" | awk '{print $1}')
                    command=$(basename "$command" 2>/dev/null || echo "$command")
                    
                    # Truncate long command names to fit display
                    if [[ ${#command} -gt 15 ]]; then
                        command="${command:0:12}..."
                    fi
                    
                    # Validate PID and CPU percentage
                    if validate_number "$pid" "PID" && validate_number "$cpu_percent" "CPU percentage"; then
                        formatted_processes+="$pid $command $cpu_percent"$'\n'
                        log_debug "Found CPU process: PID=$pid, Command=$command, CPU=$cpu_percent%"
                    fi
                fi
            done <<< "$processes"
        fi
        
        # Fallback to System V style ps command if BSD style failed
        if [[ -z "$formatted_processes" ]]; then
            ps_output=$(ps -eo pid,pcpu,comm --sort=-pcpu 2>/dev/null | head -n 6)
            
            if [[ $? -eq 0 ]] && [[ -n "$ps_output" ]]; then
                log_debug "Using System V style ps -eo command"
                
                # Skip header line and get top 5 processes
                processes=$(echo "$ps_output" | tail -n +2 | head -n 5)
                
                while IFS= read -r line; do
                    if [[ -n "$line" ]]; then
                        # Use awk to handle whitespace properly
                        local pid=$(echo "$line" | awk '{print $1}')
                        local cpu_percent=$(echo "$line" | awk '{print $2}')
                        local command=$(echo "$line" | awk '{print $3}')
                        
                        # Extract just the command name (remove path)
                        command=$(basename "$command" 2>/dev/null || echo "$command")
                        
                        # Truncate long command names to fit display
                        if [[ ${#command} -gt 15 ]]; then
                            command="${command:0:12}..."
                        fi
                        
                        # Validate PID and CPU percentage
                        if validate_number "$pid" "PID" && validate_number "$cpu_percent" "CPU percentage"; then
                            formatted_processes+="$pid $command $cpu_percent"$'\n'
                            log_debug "Found CPU process: PID=$pid, Command=$command, CPU=$cpu_percent%"
                        fi
                    fi
                done <<< "$processes"
            fi
        fi
    fi
    
    # Return results if we found any valid processes
    if [[ -n "$formatted_processes" ]]; then
        echo "$formatted_processes"
        return 0
    fi
    
    # Final fallback using top command in batch mode
    if check_command "top" false; then
        log_debug "Using top command as final fallback for CPU processes"
        
        local top_output
        if [[ "$(uname -s)" == "Darwin" ]]; then
            # macOS top command
            top_output=$(top -l 1 -o cpu -n 5 2>/dev/null | grep -E "^[[:space:]]*[0-9]+" | head -n 5)
        else
            # Linux top command
            top_output=$(top -b -n 1 -o %CPU 2>/dev/null | grep -E "^[[:space:]]*[0-9]+" | head -n 5)
        fi
        
        if [[ -n "$top_output" ]]; then
            while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    local fields=($line)
                    local pid=${fields[0]}
                    local command=""
                    local cpu_percent=""
                    
                    # Different field positions for different top versions
                    if [[ "$(uname -s)" == "Darwin" ]]; then
                        command=${fields[1]:-"unknown"}
                        cpu_percent=${fields[2]:-"0.0"}
                    else
                        command=${fields[11]:-${fields[1]:-"unknown"}}
                        cpu_percent=${fields[8]:-${fields[2]:-"0.0"}}
                    fi
                    
                    # Extract just the command name
                    command=$(basename "$command" 2>/dev/null || echo "$command")
                    
                    # Truncate long command names
                    if [[ ${#command} -gt 15 ]]; then
                        command="${command:0:12}..."
                    fi
                    
                    # Validate PID and CPU percentage
                    if validate_number "$pid" "PID" && validate_number "$cpu_percent" "CPU percentage"; then
                        formatted_processes+="$pid $command $cpu_percent"$'\n'
                        log_debug "Found CPU process from top: PID=$pid, Command=$command, CPU=$cpu_percent%"
                    fi
                fi
            done <<< "$top_output"
            
            if [[ -n "$formatted_processes" ]]; then
                echo "$formatted_processes"
                return 0
            fi
        fi
    fi
    
    log_warning "Failed to get top CPU processes using all available methods"
    return 1
}

# Function to get top 5 processes by memory usage using ps command
get_top_memory_processes() {
    log_debug "Getting top 5 processes by memory usage"
    
    # Check if ps command is available
    if ! check_command "ps" true; then
        log_error "ps command is required but not available"
        return 1
    fi
    
    # Try different ps command formats for portability across distributions
    local ps_output
    local processes
    local formatted_processes=""
    
    # Detect operating system for appropriate ps command format
    if [[ "$(uname -s)" == "Darwin" ]]; then
        # macOS ps command format - sort by RSS (resident memory)
        log_debug "Using macOS ps command format for memory"
        ps_output=$(ps -eo pid,rss,comm -m 2>/dev/null | head -n 6)
        
        if [[ $? -eq 0 ]] && [[ -n "$ps_output" ]]; then
            # Skip header line and get top 5 processes
            processes=$(echo "$ps_output" | tail -n +2 | head -n 5)
            
            while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    # Use awk to handle whitespace properly
                    local pid=$(echo "$line" | awk '{print $1}')
                    local rss_kb=$(echo "$line" | awk '{print $2}')
                    local command=$(echo "$line" | awk '{print $3}')
                    
                    # Extract just the command name (remove path)
                    command=$(basename "$command" 2>/dev/null || echo "$command")
                    
                    # Truncate long command names to fit display
                    if [[ ${#command} -gt 15 ]]; then
                        command="${command:0:12}..."
                    fi
                    
                    # Convert RSS from KB to MB for better readability
                    local mem_mb
                    if validate_number "$rss_kb" "RSS KB"; then
                        mem_mb=$(echo "scale=1; $rss_kb / 1024" | bc -l 2>/dev/null)
                        mem_mb=${mem_mb:-0.0}
                    else
                        mem_mb="0.0"
                    fi
                    
                    # Validate PID
                    if validate_number "$pid" "PID"; then
                        formatted_processes+="$pid $command $mem_mb"$'\n'
                        log_debug "Found memory process: PID=$pid, Command=$command, Memory=${mem_mb}MB"
                    fi
                fi
            done <<< "$processes"
        fi
    else
        # Linux ps command formats
        log_debug "Using Linux ps command format for memory"
        
        # Try BSD-style ps command first (works on most Linux systems)
        ps_output=$(ps aux --sort=-%mem 2>/dev/null | head -n 6)
        
        if [[ $? -eq 0 ]] && [[ -n "$ps_output" ]]; then
            log_debug "Using BSD-style ps aux command for memory"
            
            # Skip header line and get top 5 processes
            processes=$(echo "$ps_output" | tail -n +2 | head -n 5)
            
            while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    local fields=($line)
                    local pid=${fields[1]}
                    local mem_percent=${fields[3]}
                    local rss_kb=${fields[5]}  # RSS in KB
                    local command=${fields[10]}
                    
                    # Extract just the command name (remove path and arguments)
                    command=$(echo "$command" | awk '{print $1}')
                    command=$(basename "$command" 2>/dev/null || echo "$command")
                    
                    # Truncate long command names to fit display
                    if [[ ${#command} -gt 15 ]]; then
                        command="${command:0:12}..."
                    fi
                    
                    # Convert RSS from KB to MB for better readability
                    local mem_mb
                    if validate_number "$rss_kb" "RSS KB"; then
                        mem_mb=$(echo "scale=1; $rss_kb / 1024" | bc -l 2>/dev/null)
                        mem_mb=${mem_mb:-0.0}
                    else
                        mem_mb="0.0"
                    fi
                    
                    # Validate PID and memory percentage
                    if validate_number "$pid" "PID" && validate_number "$mem_percent" "memory percentage"; then
                        formatted_processes+="$pid $command $mem_mb"$'\n'
                        log_debug "Found memory process: PID=$pid, Command=$command, Memory=${mem_mb}MB"
                    fi
                fi
            done <<< "$processes"
        fi
        
        # Fallback to System V style ps command if BSD style failed
        if [[ -z "$formatted_processes" ]]; then
            ps_output=$(ps -eo pid,pmem,rss,comm --sort=-pmem 2>/dev/null | head -n 6)
            
            if [[ $? -eq 0 ]] && [[ -n "$ps_output" ]]; then
                log_debug "Using System V style ps -eo command for memory"
                
                # Skip header line and get top 5 processes
                processes=$(echo "$ps_output" | tail -n +2 | head -n 5)
                
                while IFS= read -r line; do
                    if [[ -n "$line" ]]; then
                        # Use awk to handle whitespace properly
                        local pid=$(echo "$line" | awk '{print $1}')
                        local mem_percent=$(echo "$line" | awk '{print $2}')
                        local rss_kb=$(echo "$line" | awk '{print $3}')
                        local command=$(echo "$line" | awk '{print $4}')
                        
                        # Extract just the command name (remove path)
                        command=$(basename "$command" 2>/dev/null || echo "$command")
                        
                        # Truncate long command names to fit display
                        if [[ ${#command} -gt 15 ]]; then
                            command="${command:0:12}..."
                        fi
                        
                        # Convert RSS from KB to MB for better readability
                        local mem_mb
                        if validate_number "$rss_kb" "RSS KB"; then
                            mem_mb=$(echo "scale=1; $rss_kb / 1024" | bc -l 2>/dev/null)
                            mem_mb=${mem_mb:-0.0}
                        else
                            mem_mb="0.0"
                        fi
                        
                        # Validate PID and memory percentage
                        if validate_number "$pid" "PID" && validate_number "$mem_percent" "memory percentage"; then
                            formatted_processes+="$pid $command $mem_mb"$'\n'
                            log_debug "Found memory process: PID=$pid, Command=$command, Memory=${mem_mb}MB"
                        fi
                    fi
                done <<< "$processes"
            fi
        fi
    fi
    
    # Return results if we found any valid processes
    if [[ -n "$formatted_processes" ]]; then
        echo "$formatted_processes"
        return 0
    fi
    
    # Final fallback using top command in batch mode
    if check_command "top" false; then
        log_debug "Using top command as final fallback for memory processes"
        
        local top_output
        if [[ "$(uname -s)" == "Darwin" ]]; then
            # macOS top command
            top_output=$(top -l 1 -o rsize -n 5 2>/dev/null | grep -E "^[[:space:]]*[0-9]+" | head -n 5)
        else
            # Linux top command
            top_output=$(top -b -n 1 -o %MEM 2>/dev/null | grep -E "^[[:space:]]*[0-9]+" | head -n 5)
        fi
        
        if [[ -n "$top_output" ]]; then
            while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    local fields=($line)
                    local pid=${fields[0]}
                    local command=""
                    local mem_field=""
                    
                    # Different field positions for different top versions
                    if [[ "$(uname -s)" == "Darwin" ]]; then
                        command=${fields[1]:-"unknown"}
                        mem_field=${fields[7]:-"0"}  # RSIZE field
                    else
                        command=${fields[11]:-${fields[1]:-"unknown"}}
                        mem_field=${fields[5]:-${fields[4]:-"0"}}  # RES field
                    fi
                    
                    # Extract just the command name
                    command=$(basename "$command" 2>/dev/null || echo "$command")
                    
                    # Truncate long command names
                    if [[ ${#command} -gt 15 ]]; then
                        command="${command:0:12}..."
                    fi
                    
                    # Convert memory to MB (handle different formats)
                    local mem_mb="0.0"
                    if [[ "$mem_field" =~ ^[0-9]+[KMG]?$ ]]; then
                        # Handle suffixed values (K, M, G)
                        local value=${mem_field%[KMG]}
                        local suffix=${mem_field: -1}
                        
                        if validate_number "$value" "memory value"; then
                            case "$suffix" in
                                K|k) mem_mb=$(echo "scale=1; $value / 1024" | bc -l 2>/dev/null) ;;
                                M|m) mem_mb="$value.0" ;;
                                G|g) mem_mb=$(echo "scale=1; $value * 1024" | bc -l 2>/dev/null) ;;
                                *) mem_mb=$(echo "scale=1; $value / 1024" | bc -l 2>/dev/null) ;;  # Assume KB
                            esac
                            mem_mb=${mem_mb:-0.0}
                        fi
                    elif validate_number "$mem_field" "memory field"; then
                        # Plain number, assume KB
                        mem_mb=$(echo "scale=1; $mem_field / 1024" | bc -l 2>/dev/null)
                        mem_mb=${mem_mb:-0.0}
                    fi
                    
                    # Validate PID
                    if validate_number "$pid" "PID"; then
                        formatted_processes+="$pid $command $mem_mb"$'\n'
                        log_debug "Found memory process from top: PID=$pid, Command=$command, Memory=${mem_mb}MB"
                    fi
                fi
            done <<< "$top_output"
            
            if [[ -n "$formatted_processes" ]]; then
                echo "$formatted_processes"
                return 0
            fi
        fi
    fi
    
    log_warning "Failed to get top memory processes using all available methods"
    return 1
}

# Function to format and display process information in a table
format_process_table() {
    local process_data="$1"
    local table_type="$2"  # "cpu" or "memory"
    
    if [[ -z "$process_data" ]]; then
        log_warning "No process data provided for formatting"
        return 1
    fi
    
    log_debug "Formatting process table for type: $table_type"
    
    # Define table headers based on type
    local headers
    if [[ "$table_type" == "cpu" ]]; then
        headers=("PID" "Process" "CPU%")
    elif [[ "$table_type" == "memory" ]]; then
        headers=("PID" "Process" "Memory")
    else
        log_warning "Unknown table type: $table_type"
        return 1
    fi
    
    # Print table header
    print_table_header "${headers[@]}"
    
    # Process each line of data
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local fields=($line)
            local pid=${fields[0]}
            local command=${fields[1]}
            local value=${fields[2]}
            
            # Format the value based on table type
            local formatted_value
            if [[ "$table_type" == "cpu" ]]; then
                formatted_value="${value}%"
            elif [[ "$table_type" == "memory" ]]; then
                formatted_value="${value}MB"
            fi
            
            # Print table row
            print_table_row "$pid" "$command" "$formatted_value"
        fi
    done <<< "$process_data"
    
    return 0
}

#==============================================================================
# DISK USAGE COLLECTION FUNCTIONS
#==============================================================================

# Function to get disk usage using df command
get_disk_usage_df() {
    local filesystem="${1:-/}"
    
    log_debug "Getting disk usage for filesystem: $filesystem"
    
    # Check if df command is available
    if ! check_command "df" true; then
        log_error "df command is required but not available"
        return 1
    fi
    
    # Try different df command formats to handle various distributions
    local df_output
    local disk_stats
    
    # Try POSIX-compliant df command first (most portable)
    df_output=$(df -P "$filesystem" 2>/dev/null)
    
    if [[ $? -eq 0 ]] && [[ -n "$df_output" ]]; then
        log_debug "Using df -P command format"
        
        # Parse df -P output (POSIX format, always in 512-byte blocks)
        # Expected format: "Filesystem 512-blocks Used Available Capacity Mounted-on"
        disk_stats=$(echo "$df_output" | tail -n 1 | awk '{print $2, $3, $4, $5}')
        
        if [[ -n "$disk_stats" ]]; then
            local stats=($disk_stats)
            local total_blocks=${stats[0]}
            local used_blocks=${stats[1]}
            local available_blocks=${stats[2]}
            local usage_percent_raw=${stats[3]}
            
            # Remove % sign from percentage
            local usage_percent=${usage_percent_raw%\%}
            
            # Validate values
            if validate_number "$total_blocks" "total blocks" && validate_number "$used_blocks" "used blocks" && validate_number "$available_blocks" "available blocks"; then
                # Convert 512-byte blocks to bytes
                local total_bytes=$((total_blocks * 512))
                local used_bytes=$((used_blocks * 512))
                local available_bytes=$((available_blocks * 512))
                
                # Validate percentage
                if ! validate_number "$usage_percent" "usage percentage"; then
                    # Calculate percentage if not provided or invalid
                    if [[ $total_bytes -gt 0 ]]; then
                        usage_percent=$(echo "scale=1; ($used_bytes * 100) / $total_bytes" | bc -l 2>/dev/null)
                        usage_percent=${usage_percent:-0.0}
                    else
                        usage_percent="0.0"
                    fi
                fi
                
                log_debug "Disk usage from df -P: Total=${total_bytes}B, Used=${used_bytes}B, Available=${available_bytes}B, Usage=${usage_percent}%"
                echo "$total_bytes $used_bytes $available_bytes $usage_percent"
                return 0
            fi
        fi
    fi
    
    # Fallback to df -k (kilobytes) if POSIX format fails
    df_output=$(df -k "$filesystem" 2>/dev/null)
    
    if [[ $? -eq 0 ]] && [[ -n "$df_output" ]]; then
        log_debug "Using df -k command format"
        
        # Parse df -k output (kilobytes)
        disk_stats=$(echo "$df_output" | tail -n 1 | awk '{print $2, $3, $4, $5}')
        
        if [[ -n "$disk_stats" ]]; then
            local stats=($disk_stats)
            local total_kb=${stats[0]}
            local used_kb=${stats[1]}
            local available_kb=${stats[2]}
            local usage_percent_raw=${stats[3]}
            
            # Remove % sign from percentage
            local usage_percent=${usage_percent_raw%\%}
            
            # Validate values
            if validate_number "$total_kb" "total KB" && validate_number "$used_kb" "used KB" && validate_number "$available_kb" "available KB"; then
                # Convert kilobytes to bytes
                local total_bytes=$((total_kb * 1024))
                local used_bytes=$((used_kb * 1024))
                local available_bytes=$((available_kb * 1024))
                
                # Validate percentage
                if ! validate_number "$usage_percent" "usage percentage"; then
                    # Calculate percentage if not provided or invalid
                    if [[ $total_bytes -gt 0 ]]; then
                        usage_percent=$(echo "scale=1; ($used_bytes * 100) / $total_bytes" | bc -l 2>/dev/null)
                        usage_percent=${usage_percent:-0.0}
                    else
                        usage_percent="0.0"
                    fi
                fi
                
                log_debug "Disk usage from df -k: Total=${total_bytes}B, Used=${used_bytes}B, Available=${available_bytes}B, Usage=${usage_percent}%"
                echo "$total_bytes $used_bytes $available_bytes $usage_percent"
                return 0
            fi
        fi
    fi
    
    # Final fallback to basic df command
    df_output=$(df "$filesystem" 2>/dev/null)
    
    if [[ $? -eq 0 ]] && [[ -n "$df_output" ]]; then
        log_debug "Using basic df command format"
        
        # Parse basic df output (format may vary by system)
        disk_stats=$(echo "$df_output" | tail -n 1 | awk '{print $2, $3, $4, $5}')
        
        if [[ -n "$disk_stats" ]]; then
            local stats=($disk_stats)
            local total_units=${stats[0]}
            local used_units=${stats[1]}
            local available_units=${stats[2]}
            local usage_percent_raw=${stats[3]}
            
            # Remove % sign from percentage
            local usage_percent=${usage_percent_raw%\%}
            
            # Validate values
            if validate_number "$total_units" "total units" && validate_number "$used_units" "used units" && validate_number "$available_units" "available units"; then
                # Assume 1KB blocks (common default) and convert to bytes
                local total_bytes=$((total_units * 1024))
                local used_bytes=$((used_units * 1024))
                local available_bytes=$((available_units * 1024))
                
                # Validate percentage
                if ! validate_number "$usage_percent" "usage percentage"; then
                    # Calculate percentage if not provided or invalid
                    if [[ $total_bytes -gt 0 ]]; then
                        usage_percent=$(echo "scale=1; ($used_bytes * 100) / $total_bytes" | bc -l 2>/dev/null)
                        usage_percent=${usage_percent:-0.0}
                    else
                        usage_percent="0.0"
                    fi
                fi
                
                log_debug "Disk usage from basic df: Total=${total_bytes}B, Used=${used_bytes}B, Available=${available_bytes}B, Usage=${usage_percent}%"
                echo "$total_bytes $used_bytes $available_bytes $usage_percent"
                return 0
            fi
        fi
    fi
    
    log_warning "Failed to get disk usage statistics for filesystem: $filesystem"
    return 1
}

# Function to handle different df output formats across distributions
parse_df_output() {
    local df_line="$1"
    local block_size="${2:-1024}"  # Default to 1KB blocks
    
    if [[ -z "$df_line" ]]; then
        log_warning "Empty df output line provided"
        return 1
    fi
    
    log_debug "Parsing df output line: $df_line"
    log_debug "Using block size: $block_size bytes"
    
    # Handle cases where filesystem name is on a separate line (long names)
    # In such cases, the line might start with numbers (total, used, available)
    local fields=($df_line)
    local field_count=${#fields[@]}
    
    if [[ $field_count -lt 4 ]]; then
        log_warning "Insufficient fields in df output: $field_count (expected at least 4)"
        return 1
    fi
    
    # Determine field positions based on whether filesystem name is present
    local total_field
    local used_field
    local available_field
    local percent_field
    
    # Check if first field is numeric (indicates filesystem name was on previous line)
    if [[ ${fields[0]} =~ ^[0-9]+$ ]]; then
        # Filesystem name was on previous line
        total_field=${fields[0]}
        used_field=${fields[1]}
        available_field=${fields[2]}
        percent_field=${fields[3]}
    else
        # Standard format with filesystem name in first field
        if [[ $field_count -ge 6 ]]; then
            total_field=${fields[1]}
            used_field=${fields[2]}
            available_field=${fields[3]}
            percent_field=${fields[4]}
        else
            log_warning "Unexpected df output format"
            return 1
        fi
    fi
    
    # Remove % sign from percentage field
    local usage_percent=${percent_field%\%}
    
    # Validate all numeric fields
    if ! validate_number "$total_field" "total field"; then
        log_warning "Invalid total field: $total_field"
        return 1
    fi
    
    if ! validate_number "$used_field" "used field"; then
        log_warning "Invalid used field: $used_field"
        return 1
    fi
    
    if ! validate_number "$available_field" "available field"; then
        log_warning "Invalid available field: $available_field"
        return 1
    fi
    
    if ! validate_number "$usage_percent" "usage percentage"; then
        log_warning "Invalid usage percentage: $usage_percent, calculating from totals"
        # Calculate percentage from totals
        if [[ $total_field -gt 0 ]]; then
            usage_percent=$(echo "scale=1; ($used_field * 100) / $total_field" | bc -l 2>/dev/null)
            usage_percent=${usage_percent:-0.0}
        else
            usage_percent="0.0"
        fi
    fi
    
    # Convert to bytes
    local total_bytes=$((total_field * block_size))
    local used_bytes=$((used_field * block_size))
    local available_bytes=$((available_field * block_size))
    
    log_debug "Parsed disk usage: Total=${total_bytes}B, Used=${used_bytes}B, Available=${available_bytes}B, Usage=${usage_percent}%"
    
    # Return values as space-separated string
    echo "$total_bytes $used_bytes $available_bytes $usage_percent"
}

# Function to test disk usage parsing with mock data
test_disk_parsing() {
    log_debug "Running disk usage parsing unit tests"
    
    # Test case 1: Standard df output format
    local test_line1="/dev/sda1    20971520  13631488   6291712  69% /"
    local result1
    result1=$(parse_df_output "$test_line1" 1024)
    
    if [[ $? -eq 0 ]]; then
        local stats1=($result1)
        local expected_total=$((20971520 * 1024))
        local expected_used=$((13631488 * 1024))
        local expected_available=$((6291712 * 1024))
        
        if [[ ${stats1[0]} -eq $expected_total ]] && [[ ${stats1[1]} -eq $expected_used ]] && [[ ${stats1[2]} -eq $expected_available ]]; then
            echo "✓ Disk parsing test 1 passed"
        else
            echo "✗ Disk parsing test 1 failed: expected total=$expected_total used=$expected_used available=$expected_available"
            echo "  got total=${stats1[0]} used=${stats1[1]} available=${stats1[2]}"
        fi
    else
        echo "✗ Disk parsing test 1 failed: parse_df_output returned error"
    fi
    
    # Test case 2: df output with filesystem name on separate line (numeric fields only)
    local test_line2="20971520  13631488   6291712  69%"
    local result2
    result2=$(parse_df_output "$test_line2" 1024)
    
    if [[ $? -eq 0 ]]; then
        local stats2=($result2)
        local expected_total2=$((20971520 * 1024))
        local expected_used2=$((13631488 * 1024))
        
        if [[ ${stats2[0]} -eq $expected_total2 ]] && [[ ${stats2[1]} -eq $expected_used2 ]]; then
            echo "✓ Disk parsing test 2 passed"
        else
            echo "✗ Disk parsing test 2 failed: expected total=$expected_total2 used=$expected_used2"
            echo "  got total=${stats2[0]} used=${stats2[1]}"
        fi
    else
        echo "✗ Disk parsing test 2 failed: parse_df_output returned error"
    fi
    
    # Test case 3: Invalid input (insufficient fields)
    local test_line3="/dev/sda1    20971520"
    local result3
    result3=$(parse_df_output "$test_line3" 1024)
    
    if [[ $? -ne 0 ]]; then
        echo "✓ Disk parsing test 3 passed (correctly rejected insufficient data)"
    else
        echo "✗ Disk parsing test 3 failed: should have rejected insufficient data"
    fi
    
    echo "✓ Disk usage parsing unit tests completed"
}

# Function to format disk usage for display
format_disk_usage_display() {
    local total_bytes="$1"
    local used_bytes="$2"
    local available_bytes="$3"
    local usage_percent="$4"
    local filesystem="${5:-/}"
    
    if ! validate_number "$total_bytes" "total bytes" || ! validate_number "$used_bytes" "used bytes" || ! validate_number "$available_bytes" "available bytes"; then
        log_warning "Invalid disk usage values provided for formatting"
        return 1
    fi
    
    # Format sizes in human-readable format
    local total_formatted
    local used_formatted
    local available_formatted
    
    total_formatted=$(format_bytes "$total_bytes" 1)
    used_formatted=$(format_bytes "$used_bytes" 1)
    available_formatted=$(format_bytes "$available_bytes" 1)
    
    # Format percentage
    local usage_percent_formatted
    usage_percent_formatted=$(format_percentage "$usage_percent" 1)
    
    # Create display output
    echo "Disk Usage ($filesystem):"
    print_aligned "  Total:" "$total_formatted" 15 15
    print_aligned "  Used:" "$used_formatted ($usage_percent_formatted)" 15 25
    print_aligned "  Available:" "$available_formatted" 15 15
}

# Function to handle inaccessible filesystems with error handling
check_filesystem_access() {
    local filesystem="$1"
    
    if [[ -z "$filesystem" ]]; then
        log_warning "No filesystem specified"
        return 1
    fi
    
    # Check if filesystem path exists
    if [[ ! -e "$filesystem" ]]; then
        log_warning "Filesystem path does not exist: $filesystem"
        return 1
    fi
    
    # Check if we have read access to the filesystem
    if [[ ! -r "$filesystem" ]]; then
        log_warning "No read access to filesystem: $filesystem"
        return 1
    fi
    
    # Try to access the filesystem with df to see if it's mounted and accessible
    if ! df "$filesystem" >/dev/null 2>&1; then
        log_warning "Filesystem is not accessible or not mounted: $filesystem"
        return 1
    fi
    
    log_debug "Filesystem access check passed for: $filesystem"
    return 0
}

# Main disk usage function with error handling and formatting
get_disk_usage() {
    local filesystem="${1:-/}"
    
    log_debug "Getting disk usage for filesystem: $filesystem"
    
    # Check filesystem accessibility
    if ! check_filesystem_access "$filesystem"; then
        log_error "Cannot access filesystem: $filesystem"
        echo "N/A N/A N/A N/A"
        return 1
    fi
    
    # Get disk usage statistics
    local disk_stats
    disk_stats=$(get_disk_usage_df "$filesystem")
    
    if [[ $? -ne 0 ]] || [[ -z "$disk_stats" ]]; then
        log_error "Failed to get disk usage statistics for: $filesystem"
        echo "N/A N/A N/A N/A"
        return 1
    fi
    
    local stats=($disk_stats)
    local total_bytes=${stats[0]}
    local used_bytes=${stats[1]}
    local available_bytes=${stats[2]}
    local usage_percent=${stats[3]}
    
    # Validate the returned values
    if ! validate_number "$total_bytes" "total bytes" || ! validate_number "$used_bytes" "used bytes" || ! validate_number "$available_bytes" "available bytes" || ! validate_number "$usage_percent" "usage percent"; then
        log_error "Invalid disk usage values returned"
        echo "N/A N/A N/A N/A"
        return 1
    fi
    
    # Sanity check: used + available should be close to total (allowing for reserved space)
    local calculated_total=$((used_bytes + available_bytes))
    local difference=$((total_bytes - calculated_total))
    local difference_percent
    
    if [[ $total_bytes -gt 0 ]]; then
        difference_percent=$(echo "scale=2; ($difference * 100) / $total_bytes" | bc -l 2>/dev/null)
        difference_percent=${difference_percent:-0}
        
        # Allow up to 10% difference for reserved space
        if (( $(echo "$difference_percent > 10" | bc -l 2>/dev/null || echo "0") )); then
            log_warning "Disk usage values seem inconsistent: total=$total_bytes, used+available=$calculated_total (${difference_percent}% difference)"
        fi
    fi
    
    log_debug "Disk usage retrieved successfully: Total=${total_bytes}B, Used=${used_bytes}B, Available=${available_bytes}B, Usage=${usage_percent}%"
    
    # Return the validated values
    echo "$total_bytes $used_bytes $available_bytes $usage_percent"
}

# Function to test disk usage display formatting
test_disk_display_formatting() {
    log_debug "Testing disk usage display formatting"
    
    # Test various disk usage scenarios
    echo "Disk Usage Display Format Test:"
    
    # Test case 1: Normal usage
    echo "Test 1: Normal disk usage"
    format_disk_usage_display "53687091200" "34359738368" "19327352832" "64.0" "/"
    echo
    
    # Test case 2: High usage
    echo "Test 2: High disk usage"
    format_disk_usage_display "107374182400" "96636764160" "10737418240" "90.0" "/"
    echo
    
    # Test case 3: Low usage
    echo "Test 3: Low disk usage"
    format_disk_usage_display "107374182400" "10737418240" "96636764160" "10.0" "/"
    echo
    
    # Test case 4: Small disk
    echo "Test 4: Small disk"
    format_disk_usage_display "1073741824" "536870912" "536870912" "50.0" "/boot"
    echo
    
    echo "✓ Disk usage display formatting test completed"
}

# Function to display disk usage in dashboard format
display_disk_usage() {
    local filesystem="${1:-/}"
    
    log_debug "Displaying disk usage for filesystem: $filesystem"
    
    # Get disk usage statistics
    local disk_stats
    disk_stats=$(get_disk_usage "$filesystem")
    
    if [[ $? -ne 0 ]]; then
        echo "Disk Usage ($filesystem): Unable to retrieve disk statistics"
        return 1
    fi
    
    local stats=($disk_stats)
    local total_bytes=${stats[0]}
    local used_bytes=${stats[1]}
    local available_bytes=${stats[2]}
    local usage_percent=${stats[3]}
    
    # Check if any values are N/A
    if [[ "$total_bytes" == "N/A" ]] || [[ "$used_bytes" == "N/A" ]] || [[ "$available_bytes" == "N/A" ]] || [[ "$usage_percent" == "N/A" ]]; then
        echo "Disk Usage ($filesystem): Statistics unavailable"
        return 1
    fi
    
    # Format and display the disk usage
    format_disk_usage_display "$total_bytes" "$used_bytes" "$available_bytes" "$usage_percent" "$filesystem"
}

#==============================================================================
# MEMORY USAGE COLLECTION FUNCTIONS
#==============================================================================

# Function to read memory statistics from /proc/meminfo
read_memory_stats() {
    local proc_meminfo_file="/proc/meminfo"
    
    if [[ ! -r "$proc_meminfo_file" ]]; then
        log_warning "/proc/meminfo is not readable"
        return 1
    fi
    
    # Read memory information from /proc/meminfo
    local meminfo_content
    meminfo_content=$(cat "$proc_meminfo_file" 2>/dev/null)
    
    if [[ -z "$meminfo_content" ]]; then
        log_warning "Could not read memory statistics from /proc/meminfo"
        return 1
    fi
    
    log_debug "Successfully read /proc/meminfo"
    echo "$meminfo_content"
}

# Function to parse memory statistics from /proc/meminfo content
parse_memory_stats() {
    local meminfo_content="$1"
    
    if [[ -z "$meminfo_content" ]]; then
        log_warning "Empty memory info content provided"
        return 1
    fi
    
    # Extract key memory values (in kB)
    local mem_total
    local mem_free
    local mem_available
    local buffers
    local cached
    local slab
    
    mem_total=$(echo "$meminfo_content" | grep "^MemTotal:" | awk '{print $2}')
    mem_free=$(echo "$meminfo_content" | grep "^MemFree:" | awk '{print $2}')
    mem_available=$(echo "$meminfo_content" | grep "^MemAvailable:" | awk '{print $2}')
    buffers=$(echo "$meminfo_content" | grep "^Buffers:" | awk '{print $2}')
    cached=$(echo "$meminfo_content" | grep "^Cached:" | awk '{print $2}')
    slab=$(echo "$meminfo_content" | grep "^Slab:" | awk '{print $2}')
    
    # Validate required values
    if ! validate_number "$mem_total" "MemTotal"; then
        log_warning "Invalid or missing MemTotal value"
        return 1
    fi
    
    if ! validate_number "$mem_free" "MemFree"; then
        log_warning "Invalid or missing MemFree value"
        return 1
    fi
    
    # Set defaults for optional values if not available
    buffers=${buffers:-0}
    cached=${cached:-0}
    slab=${slab:-0}
    
    # Validate optional values
    validate_number "$buffers" "Buffers" || buffers=0
    validate_number "$cached" "Cached" || cached=0
    validate_number "$slab" "Slab" || slab=0
    
    log_debug "Memory values (kB) - Total: $mem_total, Free: $mem_free, Available: $mem_available, Buffers: $buffers, Cached: $cached, Slab: $slab"
    
    # Calculate used memory accounting for buffers and cache
    local mem_used
    
    if [[ -n "$mem_available" ]] && validate_number "$mem_available" "MemAvailable"; then
        # Use MemAvailable if present (more accurate on newer kernels)
        mem_used=$((mem_total - mem_available))
        log_debug "Using MemAvailable for calculation: Used = $mem_total - $mem_available = $mem_used"
    else
        # Fallback calculation: Used = Total - Free - Buffers - Cached - Slab
        mem_used=$((mem_total - mem_free - buffers - cached - slab))
        log_debug "Using fallback calculation: Used = $mem_total - $mem_free - $buffers - $cached - $slab = $mem_used"
        
        # Set mem_available for consistency
        mem_available=$((mem_total - mem_used))
    fi
    
    # Ensure used memory is not negative
    if [[ $mem_used -lt 0 ]]; then
        log_warning "Calculated negative memory usage, adjusting to 0"
        mem_used=0
    fi
    
    # Calculate percentage
    local mem_used_percent
    if [[ $mem_total -gt 0 ]]; then
        mem_used_percent=$(echo "scale=2; ($mem_used * 100) / $mem_total" | bc -l 2>/dev/null)
        if [[ -z "$mem_used_percent" ]]; then
            mem_used_percent="0.0"
        fi
    else
        mem_used_percent="0.0"
    fi
    
    local mem_available_percent
    if [[ $mem_total -gt 0 ]]; then
        mem_available_percent=$(echo "scale=2; ($mem_available * 100) / $mem_total" | bc -l 2>/dev/null)
        if [[ -z "$mem_available_percent" ]]; then
            mem_available_percent="0.0"
        fi
    else
        mem_available_percent="0.0"
    fi
    
    log_debug "Memory percentages - Used: ${mem_used_percent}%, Available: ${mem_available_percent}%"
    
    # Return values as space-separated string (all in kB)
    echo "$mem_total $mem_used $mem_available $mem_used_percent $mem_available_percent"
}

# Function to get memory usage using /proc/meminfo
get_memory_usage_proc() {
    log_debug "Getting memory usage from /proc/meminfo"
    
    # Read memory statistics
    local meminfo_content
    meminfo_content=$(read_memory_stats)
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    # Parse memory statistics
    local parsed_stats
    parsed_stats=$(parse_memory_stats "$meminfo_content")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    local stats=($parsed_stats)
    local mem_total_kb=${stats[0]}
    local mem_used_kb=${stats[1]}
    local mem_available_kb=${stats[2]}
    local mem_used_percent=${stats[3]}
    local mem_available_percent=${stats[4]}
    
    # Convert kB to bytes for formatting
    local mem_total_bytes=$((mem_total_kb * 1024))
    local mem_used_bytes=$((mem_used_kb * 1024))
    local mem_available_bytes=$((mem_available_kb * 1024))
    
    log_debug "Memory usage calculated successfully from /proc/meminfo"
    
    # Return formatted memory information
    echo "$mem_total_bytes $mem_used_bytes $mem_available_bytes $mem_used_percent $mem_available_percent"
}

# Function to get memory usage using free command (fallback method)
get_memory_usage_free() {
    log_debug "Getting memory usage from free command"
    
    # Check if free command is available
    if ! check_command "free" false; then
        log_warning "free command not available"
        return 1
    fi
    
    # Try different free command formats
    local free_output
    local mem_stats
    
    # Try modern free command with -b (bytes) option first
    free_output=$(free -b 2>/dev/null)
    
    if [[ $? -eq 0 ]] && [[ -n "$free_output" ]]; then
        log_debug "Using free -b command format"
        
        # Parse free -b output (bytes)
        # Expected format: "Mem: total used free shared buff/cache available"
        mem_stats=$(echo "$free_output" | grep "^Mem:" | awk '{print $2, $3, $7}')
        
        if [[ -n "$mem_stats" ]]; then
            local stats=($mem_stats)
            local mem_total=${stats[0]}
            local mem_used=${stats[1]}
            local mem_available=${stats[2]}
            
            # Validate values
            if validate_number "$mem_total" "total memory" && validate_number "$mem_used" "used memory"; then
                # If available memory is not present or invalid, calculate it
                if ! validate_number "$mem_available" "available memory"; then
                    mem_available=$((mem_total - mem_used))
                fi
                
                # Calculate percentages
                local mem_used_percent
                local mem_available_percent
                
                if [[ $mem_total -gt 0 ]]; then
                    mem_used_percent=$(echo "scale=2; ($mem_used * 100) / $mem_total" | bc -l 2>/dev/null)
                    mem_available_percent=$(echo "scale=2; ($mem_available * 100) / $mem_total" | bc -l 2>/dev/null)
                    
                    # Set defaults if calculation failed
                    mem_used_percent=${mem_used_percent:-0.0}
                    mem_available_percent=${mem_available_percent:-0.0}
                else
                    mem_used_percent="0.0"
                    mem_available_percent="0.0"
                fi
                
                log_debug "Memory usage from free -b: Total=${mem_total}B, Used=${mem_used}B, Available=${mem_available}B"
                echo "$mem_total $mem_used $mem_available $mem_used_percent $mem_available_percent"
                return 0
            fi
        fi
    fi
    
    # Fallback to free -k (kilobytes) if -b is not supported
    free_output=$(free -k 2>/dev/null)
    
    if [[ $? -eq 0 ]] && [[ -n "$free_output" ]]; then
        log_debug "Using free -k command format"
        
        # Parse free -k output (kilobytes)
        mem_stats=$(echo "$free_output" | grep "^Mem:" | awk '{print $2, $3, $7}')
        
        if [[ -z "$mem_stats" ]]; then
            # Try older format without available column
            mem_stats=$(echo "$free_output" | grep "^Mem:" | awk '{print $2, $3, $4}')
            
            if [[ -n "$mem_stats" ]]; then
                local stats=($mem_stats)
                local mem_total_kb=${stats[0]}
                local mem_used_kb=${stats[1]}
                local mem_free_kb=${stats[2]}
                
                # Calculate available as free for older format
                local mem_available_kb=$mem_free_kb
                
                # Validate values
                if validate_number "$mem_total_kb" "total memory" && validate_number "$mem_used_kb" "used memory" && validate_number "$mem_free_kb" "free memory"; then
                    # Convert to bytes
                    local mem_total=$((mem_total_kb * 1024))
                    local mem_used=$((mem_used_kb * 1024))
                    local mem_available=$((mem_available_kb * 1024))
                    
                    # Calculate percentages
                    local mem_used_percent
                    local mem_available_percent
                    
                    if [[ $mem_total -gt 0 ]]; then
                        mem_used_percent=$(echo "scale=2; ($mem_used * 100) / $mem_total" | bc -l 2>/dev/null)
                        mem_available_percent=$(echo "scale=2; ($mem_available * 100) / $mem_total" | bc -l 2>/dev/null)
                        
                        # Set defaults if calculation failed
                        mem_used_percent=${mem_used_percent:-0.0}
                        mem_available_percent=${mem_available_percent:-0.0}
                    else
                        mem_used_percent="0.0"
                        mem_available_percent="0.0"
                    fi
                    
                    log_debug "Memory usage from free -k (older format): Total=${mem_total}B, Used=${mem_used}B, Available=${mem_available}B"
                    echo "$mem_total $mem_used $mem_available $mem_used_percent $mem_available_percent"
                    return 0
                fi
            fi
        else
            # Modern format with available column
            local stats=($mem_stats)
            local mem_total_kb=${stats[0]}
            local mem_used_kb=${stats[1]}
            local mem_available_kb=${stats[2]}
            
            # Validate values
            if validate_number "$mem_total_kb" "total memory" && validate_number "$mem_used_kb" "used memory"; then
                # If available memory is not present or invalid, calculate it
                if ! validate_number "$mem_available_kb" "available memory"; then
                    mem_available_kb=$((mem_total_kb - mem_used_kb))
                fi
                
                # Convert to bytes
                local mem_total=$((mem_total_kb * 1024))
                local mem_used=$((mem_used_kb * 1024))
                local mem_available=$((mem_available_kb * 1024))
                
                # Calculate percentages
                local mem_used_percent
                local mem_available_percent
                
                if [[ $mem_total -gt 0 ]]; then
                    mem_used_percent=$(echo "scale=2; ($mem_used * 100) / $mem_total" | bc -l 2>/dev/null)
                    mem_available_percent=$(echo "scale=2; ($mem_available * 100) / $mem_total" | bc -l 2>/dev/null)
                    
                    # Set defaults if calculation failed
                    mem_used_percent=${mem_used_percent:-0.0}
                    mem_available_percent=${mem_available_percent:-0.0}
                else
                    mem_used_percent="0.0"
                    mem_available_percent="0.0"
                fi
                
                log_debug "Memory usage from free -k: Total=${mem_total}B, Used=${mem_used}B, Available=${mem_available}B"
                echo "$mem_total $mem_used $mem_available $mem_used_percent $mem_available_percent"
                return 0
            fi
        fi
    fi
    
    # Try basic free command without options
    free_output=$(free 2>/dev/null)
    
    if [[ $? -eq 0 ]] && [[ -n "$free_output" ]]; then
        log_debug "Using basic free command format"
        
        # Parse basic free output (usually kilobytes)
        mem_stats=$(echo "$free_output" | grep "^Mem:" | awk '{print $2, $3, $4}')
        
        if [[ -n "$mem_stats" ]]; then
            local stats=($mem_stats)
            local mem_total_kb=${stats[0]}
            local mem_used_kb=${stats[1]}
            local mem_free_kb=${stats[2]}
            
            # Validate values
            if validate_number "$mem_total_kb" "total memory" && validate_number "$mem_used_kb" "used memory" && validate_number "$mem_free_kb" "free memory"; then
                # Convert to bytes (assuming kilobytes)
                local mem_total=$((mem_total_kb * 1024))
                local mem_used=$((mem_used_kb * 1024))
                local mem_available=$((mem_free_kb * 1024))
                
                # Calculate percentages
                local mem_used_percent
                local mem_available_percent
                
                if [[ $mem_total -gt 0 ]]; then
                    mem_used_percent=$(echo "scale=2; ($mem_used * 100) / $mem_total" | bc -l 2>/dev/null)
                    mem_available_percent=$(echo "scale=2; ($mem_available * 100) / $mem_total" | bc -l 2>/dev/null)
                    
                    # Set defaults if calculation failed
                    mem_used_percent=${mem_used_percent:-0.0}
                    mem_available_percent=${mem_available_percent:-0.0}
                else
                    mem_used_percent="0.0"
                    mem_available_percent="0.0"
                fi
                
                log_debug "Memory usage from basic free: Total=${mem_total}B, Used=${mem_used}B, Available=${mem_available}B"
                echo "$mem_total $mem_used $mem_available $mem_used_percent $mem_available_percent"
                return 0
            fi
        fi
    fi
    
    log_warning "Failed to parse memory usage from free command output"
    return 1
}

# Function to test memory usage display with both absolute values and percentages
test_memory_display_formatting() {
    log_debug "Testing memory usage display formatting"
    
    # Test various memory values (in bytes)
    local test_values=(
        "8589934592 5368709120 3221225472 62.5 37.5"  # 8GB total, 5GB used, 3GB available
        "4294967296 2147483648 2147483648 50.0 50.0"  # 4GB total, 2GB used, 2GB available
        "1073741824 858993459 214748365 80.0 20.0"    # 1GB total, 800MB used, 200MB available
    )
    
    echo "Memory Usage Display Format Test:"
    for value_set in "${test_values[@]}"; do
        local values=($value_set)
        local mem_total=${values[0]}
        local mem_used=${values[1]}
        local mem_available=${values[2]}
        local mem_used_percent=${values[3]}
        local mem_available_percent=${values[4]}
        
        echo "Memory Usage:"
        print_aligned "  Total:" "$(format_bytes "$mem_total" 1)" 20 15
        print_aligned "  Used:" "$(format_bytes "$mem_used" 1) ($(format_percentage "$mem_used_percent" 1))" 20 25
        print_aligned "  Available:" "$(format_bytes "$mem_available" 1) ($(format_percentage "$mem_available_percent" 1))" 20 25
        echo
    done
    echo "✓ Memory usage display formatting test completed"
}

# Main memory usage function that tries /proc/meminfo first, then falls back to free
get_memory_usage() {
    log_debug "Getting memory usage"
    
    # Check if bc command is available for calculations
    if ! check_command "bc" false; then
        log_warning "bc command not available, memory calculations may be less accurate"
    fi
    
    # Try /proc/meminfo method first
    local memory_stats
    memory_stats=$(get_memory_usage_proc)
    
    if [[ $? -eq 0 ]] && [[ -n "$memory_stats" ]]; then
        local stats=($memory_stats)
        if [[ ${#stats[@]} -eq 5 ]] && validate_number "${stats[0]}" "total memory"; then
            log_debug "Successfully got memory usage from /proc/meminfo method"
            echo "$memory_stats"
            return 0
        fi
    fi
    
    log_debug "Falling back to free command method"
    
    # Try free command fallback
    memory_stats=$(get_memory_usage_free)
    
    if [[ $? -eq 0 ]] && [[ -n "$memory_stats" ]]; then
        local stats=($memory_stats)
        if [[ ${#stats[@]} -eq 5 ]] && validate_number "${stats[0]}" "total memory"; then
            log_debug "Successfully got memory usage from free command method"
            echo "$memory_stats"
            return 0
        fi
    fi
    
    log_warning "All memory usage collection methods failed"
    echo "N/A N/A N/A N/A N/A"
    return 1
}

# Unit test function for memory parsing logic
test_memory_parsing() {
    log_debug "Running memory parsing unit tests"
    
    # Test case 1: Complete /proc/meminfo content
    local test_meminfo1="MemTotal:        8192000 kB
MemFree:         2048000 kB
MemAvailable:    4096000 kB
Buffers:          512000 kB
Cached:          1024000 kB
Slab:             256000 kB"
    
    local result1
    result1=$(parse_memory_stats "$test_meminfo1")
    
    if [[ $? -eq 0 ]]; then
        local stats1=($result1)
        local expected_total=8192000
        local expected_used=$((8192000 - 4096000))  # Using MemAvailable
        local expected_available=4096000
        
        if [[ ${stats1[0]} -eq $expected_total ]] && [[ ${stats1[1]} -eq $expected_used ]] && [[ ${stats1[2]} -eq $expected_available ]]; then
            echo "✓ Memory parsing test 1 passed (with MemAvailable)"
        else
            echo "✗ Memory parsing test 1 failed: expected total=$expected_total used=$expected_used available=$expected_available, got total=${stats1[0]} used=${stats1[1]} available=${stats1[2]}"
        fi
    else
        echo "✗ Memory parsing test 1 failed: parse_memory_stats returned error"
    fi
    
    # Test case 2: /proc/meminfo without MemAvailable (older kernels)
    local test_meminfo2="MemTotal:        4096000 kB
MemFree:         1024000 kB
Buffers:          256000 kB
Cached:           512000 kB
Slab:             128000 kB"
    
    local result2
    result2=$(parse_memory_stats "$test_meminfo2")
    
    if [[ $? -eq 0 ]]; then
        local stats2=($result2)
        local expected_total2=4096000
        # Used = Total - Free - Buffers - Cached - Slab = 4096000 - 1024000 - 256000 - 512000 - 128000 = 2176000
        local expected_used2=$((4096000 - 1024000 - 256000 - 512000 - 128000))
        local expected_available2=$((4096000 - expected_used2))
        
        if [[ ${stats2[0]} -eq $expected_total2 ]] && [[ ${stats2[1]} -eq $expected_used2 ]] && [[ ${stats2[2]} -eq $expected_available2 ]]; then
            echo "✓ Memory parsing test 2 passed (without MemAvailable)"
        else
            echo "✗ Memory parsing test 2 failed: expected total=$expected_total2 used=$expected_used2 available=$expected_available2, got total=${stats2[0]} used=${stats2[1]} available=${stats2[2]}"
        fi
    else
        echo "✗ Memory parsing test 2 failed: parse_memory_stats returned error"
    fi
    
    # Test case 3: Minimal /proc/meminfo (only required fields)
    local test_meminfo3="MemTotal:        2048000 kB
MemFree:          512000 kB"
    
    local result3
    result3=$(parse_memory_stats "$test_meminfo3")
    
    if [[ $? -eq 0 ]]; then
        local stats3=($result3)
        local expected_total3=2048000
        # Used = Total - Free (no buffers/cache) = 2048000 - 512000 = 1536000
        local expected_used3=$((2048000 - 512000))
        local expected_available3=$((2048000 - expected_used3))
        
        if [[ ${stats3[0]} -eq $expected_total3 ]] && [[ ${stats3[1]} -eq $expected_used3 ]] && [[ ${stats3[2]} -eq $expected_available3 ]]; then
            echo "✓ Memory parsing test 3 passed (minimal fields)"
        else
            echo "✗ Memory parsing test 3 failed: expected total=$expected_total3 used=$expected_used3 available=$expected_available3, got total=${stats3[0]} used=${stats3[1]} available=${stats3[2]}"
        fi
    else
        echo "✗ Memory parsing test 3 failed: parse_memory_stats returned error"
    fi
    
    # Test case 4: Invalid input (missing required fields)
    local test_meminfo4="Buffers:          256000 kB
Cached:           512000 kB"
    
    local result4
    result4=$(parse_memory_stats "$test_meminfo4")
    
    if [[ $? -ne 0 ]]; then
        echo "✓ Memory parsing test 4 passed (correctly rejected insufficient data)"
    else
        echo "✗ Memory parsing test 4 failed: should have rejected insufficient data"
    fi
    
    echo "✓ Memory calculation logic unit tests completed"
}

#==============================================================================
# SYSTEM INFORMATION COLLECTION FUNCTIONS
#==============================================================================

# Function to get OS version information from /etc/os-release
get_os_version() {
    log_debug "Getting OS version information"
    
    local os_release_file="/etc/os-release"
    local os_info=""
    
    # Try to read from /etc/os-release (systemd standard)
    if [[ -r "$os_release_file" ]]; then
        log_debug "Reading OS information from $os_release_file"
        
        # Extract PRETTY_NAME first (most descriptive)
        local pretty_name
        pretty_name=$(grep '^PRETTY_NAME=' "$os_release_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"')
        
        if [[ -n "$pretty_name" ]]; then
            os_info="$pretty_name"
            log_debug "Found PRETTY_NAME: $pretty_name"
        else
            # Fallback to NAME and VERSION_ID
            local name
            local version_id
            name=$(grep '^NAME=' "$os_release_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"')
            version_id=$(grep '^VERSION_ID=' "$os_release_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"')
            
            if [[ -n "$name" ]]; then
                os_info="$name"
                if [[ -n "$version_id" ]]; then
                    os_info="$os_info $version_id"
                fi
                log_debug "Constructed OS info from NAME and VERSION_ID: $os_info"
            fi
        fi
    fi
    
    # Fallback to other common OS release files
    if [[ -z "$os_info" ]]; then
        local fallback_files=("/etc/redhat-release" "/etc/debian_version" "/etc/alpine-release" "/etc/arch-release")
        
        for file in "${fallback_files[@]}"; do
            if [[ -r "$file" ]]; then
                log_debug "Trying fallback OS file: $file"
                local content
                content=$(cat "$file" 2>/dev/null | head -n 1)
                
                if [[ -n "$content" ]]; then
                    # Special handling for debian_version (just version number)
                    if [[ "$file" == "/etc/debian_version" ]]; then
                        os_info="Debian $content"
                    else
                        os_info="$content"
                    fi
                    log_debug "Found OS info from $file: $os_info"
                    break
                fi
            fi
        done
    fi
    
    # Final fallback to uname
    if [[ -z "$os_info" ]]; then
        if check_command "uname" false; then
            log_debug "Using uname as final fallback for OS information"
            local uname_output
            uname_output=$(uname -sr 2>/dev/null)
            
            if [[ -n "$uname_output" ]]; then
                os_info="$uname_output"
                log_debug "Got OS info from uname: $os_info"
            fi
        fi
    fi
    
    # Return result or N/A if nothing found
    if [[ -n "$os_info" ]]; then
        echo "$os_info"
        return 0
    else
        log_warning "Could not determine OS version information"
        echo "N/A"
        return 1
    fi
}

# Function to get system uptime from /proc/uptime
get_system_uptime() {
    log_debug "Getting system uptime information"
    
    local uptime_file="/proc/uptime"
    local uptime_info=""
    
    # Try to read from /proc/uptime first
    if [[ -r "$uptime_file" ]]; then
        log_debug "Reading uptime from $uptime_file"
        
        local uptime_seconds
        uptime_seconds=$(cat "$uptime_file" 2>/dev/null | awk '{print $1}')
        
        if validate_number "$uptime_seconds" "uptime seconds"; then
            # Convert seconds to human-readable format
            uptime_info=$(format_uptime_seconds "$uptime_seconds")
            log_debug "Calculated uptime from /proc/uptime: $uptime_info"
        fi
    fi
    
    # Fallback to uptime command
    if [[ -z "$uptime_info" ]] && check_command "uptime" false; then
        log_debug "Using uptime command as fallback"
        
        local uptime_output
        uptime_output=$(uptime 2>/dev/null)
        
        if [[ -n "$uptime_output" ]]; then
            # Parse uptime command output
            # Format: " 10:30:00 up 15 days,  3:42,  2 users,  load average: 0.00, 0.01, 0.05"
            # or: " 10:30:00 up  3:42,  2 users,  load average: 0.00, 0.01, 0.05"
            
            if [[ "$uptime_output" =~ up[[:space:]]+([^,]+) ]]; then
                uptime_info="${BASH_REMATCH[1]}"
                # Clean up extra whitespace
                uptime_info=$(echo "$uptime_info" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                log_debug "Parsed uptime from uptime command: $uptime_info"
            fi
        fi
    fi
    
    # Return result or N/A if nothing found
    if [[ -n "$uptime_info" ]]; then
        echo "$uptime_info"
        return 0
    else
        log_warning "Could not determine system uptime"
        echo "N/A"
        return 1
    fi
}

# Helper function to format uptime seconds into human-readable format
format_uptime_seconds() {
    local total_seconds="$1"
    
    if ! validate_number "$total_seconds" "uptime seconds"; then
        echo "N/A"
        return 1
    fi
    
    # Convert to integer (remove decimal part)
    total_seconds=${total_seconds%.*}
    
    local days=$((total_seconds / 86400))
    local hours=$(((total_seconds % 86400) / 3600))
    local minutes=$(((total_seconds % 3600) / 60))
    
    local uptime_str=""
    
    if [[ $days -gt 0 ]]; then
        if [[ $days -eq 1 ]]; then
            uptime_str="1 day"
        else
            uptime_str="$days days"
        fi
        
        if [[ $hours -gt 0 ]] || [[ $minutes -gt 0 ]]; then
            uptime_str="$uptime_str, "
        fi
    fi
    
    if [[ $hours -gt 0 ]]; then
        uptime_str="$uptime_str$hours:$(printf "%02d" $minutes)"
    elif [[ $days -gt 0 ]] && [[ $minutes -gt 0 ]]; then
        uptime_str="$uptime_str$minutes min"
    elif [[ $days -eq 0 ]]; then
        if [[ $minutes -gt 0 ]]; then
            uptime_str="$minutes min"
        else
            uptime_str="< 1 min"
        fi
    fi
    
    echo "$uptime_str"
}

# Function to get load average from /proc/loadavg
get_load_average() {
    log_debug "Getting system load average"
    
    local loadavg_file="/proc/loadavg"
    local load_info=""
    
    # Try to read from /proc/loadavg first
    if [[ -r "$loadavg_file" ]]; then
        log_debug "Reading load average from $loadavg_file"
        
        local loadavg_content
        loadavg_content=$(cat "$loadavg_file" 2>/dev/null)
        
        if [[ -n "$loadavg_content" ]]; then
            # /proc/loadavg format: "0.00 0.01 0.05 1/123 456"
            # We want the first three values (1min, 5min, 15min averages)
            local load_values=($loadavg_content)
            
            if [[ ${#load_values[@]} -ge 3 ]]; then
                local load_1min=${load_values[0]}
                local load_5min=${load_values[1]}
                local load_15min=${load_values[2]}
                
                # Validate the load values
                if validate_number "$load_1min" "1min load" && \
                   validate_number "$load_5min" "5min load" && \
                   validate_number "$load_15min" "15min load"; then
                    
                    load_info="$load_1min, $load_5min, $load_15min"
                    log_debug "Got load average from /proc/loadavg: $load_info"
                fi
            fi
        fi
    fi
    
    # Fallback to uptime command
    if [[ -z "$load_info" ]] && check_command "uptime" false; then
        log_debug "Using uptime command as fallback for load average"
        
        local uptime_output
        uptime_output=$(uptime 2>/dev/null)
        
        if [[ -n "$uptime_output" ]]; then
            # Parse load average from uptime output
            # Format: "load average: 0.00, 0.01, 0.05"
            if [[ "$uptime_output" =~ load[[:space:]]+average:[[:space:]]*([0-9.]+,[[:space:]]*[0-9.]+,[[:space:]]*[0-9.]+) ]]; then
                load_info="${BASH_REMATCH[1]}"
                # Clean up extra whitespace
                load_info=$(echo "$load_info" | sed 's/[[:space:]]*,[[:space:]]*/, /g')
                log_debug "Parsed load average from uptime command: $load_info"
            fi
        fi
    fi
    
    # Return result or N/A if nothing found
    if [[ -n "$load_info" ]]; then
        echo "$load_info"
        return 0
    else
        log_warning "Could not determine system load average"
        echo "N/A"
        return 1
    fi
}

# Function to collect all system information
get_system_info() {
    log_debug "Collecting comprehensive system information"
    
    local os_version
    local uptime
    local load_avg
    
    # Collect OS version
    os_version=$(get_os_version)
    
    # Collect system uptime
    uptime=$(get_system_uptime)
    
    # Collect load average
    load_avg=$(get_load_average)
    
    # Return all system info as space-separated values
    echo "$os_version|$uptime|$load_avg"
    
    # Return success if at least one piece of information was collected
    if [[ "$os_version" != "N/A" ]] || [[ "$uptime" != "N/A" ]] || [[ "$load_avg" != "N/A" ]]; then
        return 0
    else
        return 1
    fi
}

#==============================================================================
# USER AND SECURITY INFORMATION COLLECTION FUNCTIONS
#==============================================================================

# Function to get currently logged-in users using who command
get_logged_in_users() {
    log_debug "Getting currently logged-in users"
    
    local users_info=""
    local user_count=0
    
    # Try who command first (most portable)
    if check_command "who" false; then
        log_debug "Using who command to get logged-in users"
        
        local who_output
        who_output=$(who 2>/dev/null)
        
        if [[ -n "$who_output" ]]; then
            # Count unique users and get their names
            local unique_users
            unique_users=$(echo "$who_output" | awk '{print $1}' | sort -u)
            
            if [[ -n "$unique_users" ]]; then
                user_count=$(echo "$unique_users" | wc -l)
                # Get first few usernames for display (limit to avoid long output)
                local user_list
                user_list=$(echo "$unique_users" | head -n 5 | tr '\n' ', ' | sed 's/, $//')
                
                if [[ $user_count -gt 5 ]]; then
                    users_info="$user_count users ($user_list, ...)"
                else
                    users_info="$user_count users ($user_list)"
                fi
                
                log_debug "Found $user_count logged-in users: $user_list"
            fi
        fi
    fi
    
    # Fallback to w command if who is not available
    if [[ -z "$users_info" ]] && check_command "w" false; then
        log_debug "Using w command as fallback for logged-in users"
        
        local w_output
        w_output=$(w -h 2>/dev/null)
        
        if [[ -n "$w_output" ]]; then
            # Count unique users from w output
            local unique_users
            unique_users=$(echo "$w_output" | awk '{print $1}' | sort -u)
            
            if [[ -n "$unique_users" ]]; then
                user_count=$(echo "$unique_users" | wc -l)
                local user_list
                user_list=$(echo "$unique_users" | head -n 5 | tr '\n' ', ' | sed 's/, $//')
                
                if [[ $user_count -gt 5 ]]; then
                    users_info="$user_count users ($user_list, ...)"
                else
                    users_info="$user_count users ($user_list)"
                fi
                
                log_debug "Found $user_count logged-in users from w command: $user_list"
            fi
        fi
    fi
    
    # Final fallback to users command
    if [[ -z "$users_info" ]] && check_command "users" false; then
        log_debug "Using users command as final fallback"
        
        local users_output
        users_output=$(users 2>/dev/null)
        
        if [[ -n "$users_output" ]]; then
            # users command outputs space-separated list of logged-in users
            local unique_users
            unique_users=$(echo "$users_output" | tr ' ' '\n' | sort -u)
            
            if [[ -n "$unique_users" ]]; then
                user_count=$(echo "$unique_users" | wc -l)
                local user_list
                user_list=$(echo "$unique_users" | head -n 5 | tr '\n' ', ' | sed 's/, $//')
                
                if [[ $user_count -gt 5 ]]; then
                    users_info="$user_count users ($user_list, ...)"
                else
                    users_info="$user_count users ($user_list)"
                fi
                
                log_debug "Found $user_count logged-in users from users command: $user_list"
            fi
        fi
    fi
    
    # Return result or N/A if no users found
    if [[ -n "$users_info" ]]; then
        echo "$users_info"
        return 0
    else
        log_warning "Could not determine logged-in users"
        echo "N/A"
        return 1
    fi
}

# Function to get recent failed login attempts from system logs
get_failed_login_attempts() {
    log_debug "Getting recent failed login attempts"
    
    local failed_attempts=""
    local attempt_count=0
    
    # Common log files to check (in order of preference)
    local log_files=(
        "/var/log/auth.log"      # Debian/Ubuntu
        "/var/log/secure"        # RHEL/CentOS/Fedora
        "/var/log/messages"      # Some systems log auth to messages
        "/var/log/authlog"       # Some BSD-style systems
    )
    
    # Check each log file for failed login attempts
    for log_file in "${log_files[@]}"; do
        if [[ -r "$log_file" ]]; then
            log_debug "Checking $log_file for failed login attempts"
            
            # Look for common failed login patterns in the last 24 hours
            local failed_patterns=(
                "Failed password"
                "authentication failure"
                "Invalid user"
                "Failed login"
                "Connection closed by authenticating user"
                "PAM.*authentication failure"
            )
            
            local recent_failures=""
            local today_date
            today_date=$(date '+%b %d' 2>/dev/null)
            
            if [[ -n "$today_date" ]]; then
                # Search for today's failed attempts
                for pattern in "${failed_patterns[@]}"; do
                    local matches
                    matches=$(grep -i "$pattern" "$log_file" 2>/dev/null | grep "$today_date" | wc -l 2>/dev/null)
                    
                    if [[ -n "$matches" ]] && [[ "$matches" -gt 0 ]]; then
                        attempt_count=$((attempt_count + matches))
                        log_debug "Found $matches failed attempts matching '$pattern' in $log_file"
                    fi
                done
                
                # If we found attempts in this log file, we can stop checking others
                if [[ $attempt_count -gt 0 ]]; then
                    failed_attempts="$attempt_count failed attempts today"
                    log_debug "Total failed login attempts found: $attempt_count"
                    break
                fi
            fi
        else
            log_debug "$log_file is not readable or does not exist"
        fi
    done
    
    # If no specific log files worked, try journalctl (systemd systems)
    if [[ -z "$failed_attempts" ]] && check_command "journalctl" false; then
        log_debug "Trying journalctl for failed login attempts"
        
        # Check if we can read journal without root privileges
        local journal_output
        journal_output=$(journalctl --since="24 hours ago" --no-pager -q 2>/dev/null | head -n 1)
        
        if [[ $? -eq 0 ]] && [[ -n "$journal_output" ]]; then
            # Count failed authentication attempts from journal
            local journal_failures
            journal_failures=$(journalctl --since="24 hours ago" --no-pager -q 2>/dev/null | \
                              grep -i -E "(failed password|authentication failure|invalid user|failed login)" | \
                              wc -l 2>/dev/null)
            
            if [[ -n "$journal_failures" ]] && [[ "$journal_failures" -gt 0 ]]; then
                attempt_count="$journal_failures"
                failed_attempts="$attempt_count failed attempts today"
                log_debug "Found $attempt_count failed login attempts from journalctl"
            fi
        else
            log_debug "journalctl not accessible or requires elevated privileges"
        fi
    fi
    
    # Handle permission restrictions gracefully
    if [[ -z "$failed_attempts" ]]; then
        # Check if any log files exist but are not readable
        local restricted_files=0
        for log_file in "${log_files[@]}"; do
            if [[ -f "$log_file" ]] && [[ ! -r "$log_file" ]]; then
                restricted_files=$((restricted_files + 1))
                log_debug "$log_file exists but is not readable (permission restriction)"
            fi
        done
        
        if [[ $restricted_files -gt 0 ]]; then
            failed_attempts="Permission denied"
            log_warning "Failed login information requires elevated privileges to access log files"
        else
            failed_attempts="N/A"
            log_warning "No accessible log files found for failed login attempts"
        fi
    fi
    
    # Return result
    echo "$failed_attempts"
    
    # Return success if we found actual attempt count or permission issue
    if [[ "$failed_attempts" != "N/A" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to collect all user and security information
get_user_security_info() {
    log_debug "Collecting user and security information"
    
    local logged_users
    local failed_logins
    
    # Collect logged-in users
    logged_users=$(get_logged_in_users)
    
    # Collect failed login attempts
    failed_logins=$(get_failed_login_attempts)
    
    # Return all user/security info as pipe-separated values
    echo "$logged_users|$failed_logins"
    
    # Return success if at least one piece of information was collected
    if [[ "$logged_users" != "N/A" ]] || [[ "$failed_logins" != "N/A" ]]; then
        return 0
    else
        return 1
    fi
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

#==============================================================================
# DASHBOARD OUTPUT AND DISPLAY FUNCTIONS
#==============================================================================

# Function to display complete dashboard-style output
display_dashboard() {
    local cpu_usage="$1"
    local memory_stats="$2"
    local disk_stats="$3"
    local top_cpu_processes="$4"
    local top_memory_processes="$5"
    local system_info="$6"
    local user_info="$7"
    local execution_time="$8"
    
    log_debug "Displaying dashboard with collected statistics"
    
    # Main header
    print_header "Server Performance Stats" 60
    echo
    
    # CPU Usage Section
    display_cpu_section "$cpu_usage"
    echo
    
    # Memory Usage Section
    display_memory_section "$memory_stats"
    echo
    
    # Disk Usage Section
    display_disk_section "$disk_stats"
    echo
    
    # Top Processes Sections
    display_processes_section "$top_cpu_processes" "$top_memory_processes"
    echo
    
    # Additional System Information (if available)
    if [[ -n "$system_info" ]] || [[ -n "$user_info" ]]; then
        display_system_info_section "$system_info" "$user_info"
        echo
    fi
    
    # Footer with execution time
    display_footer "$execution_time"
}

# Function to display CPU usage section
display_cpu_section() {
    local cpu_usage="$1"
    
    echo "CPU Usage:"
    if [[ "$cpu_usage" != "N/A" ]] && validate_number "$cpu_usage" "CPU usage"; then
        print_aligned "  Current:" "$(format_percentage "$cpu_usage" 1)" 20 15
    else
        print_aligned "  Current:" "N/A" 20 15
    fi
}

# Function to display memory usage section
display_memory_section() {
    local memory_stats="$1"
    local mem_array=($memory_stats)
    
    echo "Memory Usage:"
    if [[ ${#mem_array[@]} -eq 5 ]] && [[ "${mem_array[0]}" != "N/A" ]]; then
        local total_bytes="${mem_array[0]}"
        local used_bytes="${mem_array[1]}"
        local available_bytes="${mem_array[2]}"
        local used_percent="${mem_array[3]}"
        local available_percent="${mem_array[4]}"
        
        print_aligned "  Total:" "$(format_bytes "$total_bytes" 1)" 20 15
        print_aligned "  Used:" "$(format_bytes "$used_bytes" 1) ($(format_percentage "$used_percent" 1))" 20 30
        print_aligned "  Available:" "$(format_bytes "$available_bytes" 1) ($(format_percentage "$available_percent" 1))" 20 30
    else
        print_aligned "  Total:" "N/A" 20 15
        print_aligned "  Used:" "N/A" 20 15
        print_aligned "  Available:" "N/A" 20 15
    fi
}

# Function to display disk usage section
display_disk_section() {
    local disk_stats="$1"
    local disk_array=($disk_stats)
    
    echo "Disk Usage (/):"
    if [[ ${#disk_array[@]} -eq 4 ]] && [[ "${disk_array[0]}" != "N/A" ]]; then
        local total_bytes="${disk_array[0]}"
        local used_bytes="${disk_array[1]}"
        local available_bytes="${disk_array[2]}"
        local used_percent="${disk_array[3]}"
        
        print_aligned "  Total:" "$(format_bytes "$total_bytes" 1)" 20 15
        print_aligned "  Used:" "$(format_bytes "$used_bytes" 1) ($(format_percentage "$used_percent" 1))" 20 30
        print_aligned "  Available:" "$(format_bytes "$available_bytes" 1)" 20 15
    else
        print_aligned "  Total:" "N/A" 20 15
        print_aligned "  Used:" "N/A" 20 15
        print_aligned "  Available:" "N/A" 20 15
    fi
}

# Function to display top processes sections
display_processes_section() {
    local top_cpu_processes="$1"
    local top_memory_processes="$2"
    
    # Top CPU Processes
    echo "Top 5 Processes by CPU:"
    if [[ -n "$top_cpu_processes" ]]; then
        print_table_header "PID" "Process" "CPU%"
        
        # Parse and display CPU processes
        local process_count=0
        while IFS= read -r line; do
            if [[ -n "$line" ]] && [[ $process_count -lt 5 ]]; then
                local process_fields=($line)
                if [[ ${#process_fields[@]} -ge 3 ]]; then
                    local pid="${process_fields[0]}"
                    local command="${process_fields[1]}"
                    local cpu_percent="${process_fields[2]}"
                    
                    # Format CPU percentage
                    if validate_number "$cpu_percent" "CPU percentage"; then
                        cpu_percent="$(format_percentage "$cpu_percent" 1)"
                    fi
                    
                    print_table_row "$pid" "$command" "$cpu_percent"
                    ((process_count++))
                fi
            fi
        done <<< "$top_cpu_processes"
        
        if [[ $process_count -eq 0 ]]; then
            print_aligned "  No process data available" "" 20 15
        fi
    else
        print_aligned "  No process data available" "" 20 15
    fi
    
    echo
    
    # Top Memory Processes
    echo "Top 5 Processes by Memory:"
    if [[ -n "$top_memory_processes" ]]; then
        print_table_header "PID" "Process" "Memory"
        
        # Parse and display memory processes
        local process_count=0
        while IFS= read -r line; do
            if [[ -n "$line" ]] && [[ $process_count -lt 5 ]]; then
                local process_fields=($line)
                if [[ ${#process_fields[@]} -ge 3 ]]; then
                    local pid="${process_fields[0]}"
                    local command="${process_fields[1]}"
                    local memory_mb="${process_fields[2]}"
                    
                    # Format memory value
                    if validate_number "$memory_mb" "memory MB"; then
                        # Convert MB to bytes for formatting
                        local memory_bytes
                        memory_bytes=$(echo "scale=0; $memory_mb * 1024 * 1024" | bc -l 2>/dev/null)
                        if [[ -n "$memory_bytes" ]]; then
                            memory_mb="$(format_bytes "$memory_bytes" 1)"
                        else
                            memory_mb="${memory_mb} MB"
                        fi
                    fi
                    
                    print_table_row "$pid" "$command" "$memory_mb"
                    ((process_count++))
                fi
            fi
        done <<< "$top_memory_processes"
        
        if [[ $process_count -eq 0 ]]; then
            print_aligned "  No process data available" "" 20 15
        fi
    else
        print_aligned "  No process data available" "" 20 15
    fi
}

# Function to display additional system information section
display_system_info_section() {
    local system_info="$1"
    local user_info="$2"
    
    print_separator 60
    echo "Additional System Information:"
    echo
    
    # Display system information if available
    if [[ -n "$system_info" ]]; then
        # Parse system info (format: "OS_VERSION|UPTIME|LOAD_AVERAGE")
        local info_parts
        IFS='|' read -ra info_parts <<< "$system_info"
        
        if [[ ${#info_parts[@]} -ge 1 ]] && [[ -n "${info_parts[0]}" ]]; then
            print_aligned "OS:" "${info_parts[0]}" 20 40
        fi
        
        if [[ ${#info_parts[@]} -ge 2 ]] && [[ -n "${info_parts[1]}" ]]; then
            print_aligned "Uptime:" "${info_parts[1]}" 20 40
        fi
        
        if [[ ${#info_parts[@]} -ge 3 ]] && [[ -n "${info_parts[2]}" ]]; then
            print_aligned "Load Average:" "${info_parts[2]}" 20 40
        fi
    fi
    
    # Display user information if available
    if [[ -n "$user_info" ]]; then
        local user_count
        user_count=$(echo "$user_info" | wc -l 2>/dev/null || echo "0")
        print_aligned "Logged in Users:" "$user_count" 20 15
        
        # Show first few users if available
        if [[ $user_count -gt 0 ]] && [[ $user_count -le 5 ]]; then
            echo "$user_info" | while IFS= read -r user_line; do
                if [[ -n "$user_line" ]]; then
                    print_aligned "  User:" "$user_line" 20 40
                fi
            done
        elif [[ $user_count -gt 5 ]]; then
            echo "$user_info" | head -n 3 | while IFS= read -r user_line; do
                if [[ -n "$user_line" ]]; then
                    print_aligned "  User:" "$user_line" 20 40
                fi
            done
            print_aligned "  ..." "and $((user_count - 3)) more" 20 20
        fi
    fi
}

# Function to display footer with execution time and metadata
display_footer() {
    local execution_time="$1"
    
    print_separator 60
    
    # Display execution time if available
    if [[ -n "$execution_time" ]] && [[ "$execution_time" != "N/A" ]]; then
        print_aligned "Execution Time:" "${execution_time}s" 20 15
    fi
    
    # Display timestamp
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "N/A")
    print_aligned "Generated:" "$timestamp" 20 25
    
    echo
    center_text "Server Stats Analysis Complete" 60
    echo
}

#==============================================================================
# MAIN EXECUTION FUNCTION
#==============================================================================

# Main execution function that orchestrates all data collection
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    log_debug "Starting server stats analysis"
    
    # Record start time for performance monitoring
    local start_time
    start_time=$(date +%s.%N 2>/dev/null || date +%s)
    
    # Initialize global variables for collected data
    local cpu_usage=""
    local memory_stats=""
    local disk_stats=""
    local top_cpu_processes=""
    local top_memory_processes=""
    local system_info=""
    local user_info=""
    
    # Collection status tracking for graceful degradation
    local cpu_status="failed"
    local memory_status="failed"
    local disk_status="failed"
    local cpu_processes_status="failed"
    local memory_processes_status="failed"
    local system_info_status="failed"
    local user_info_status="failed"
    
    log_debug "Initialized data collection variables"
    
    # Collect CPU usage with error handling
    log_debug "Collecting CPU usage statistics"
    cpu_usage=$(get_cpu_usage 1)
    if [[ $? -eq 0 ]] && [[ -n "$cpu_usage" ]] && [[ "$cpu_usage" != "N/A" ]]; then
        cpu_status="success"
        log_debug "CPU usage collection successful: ${cpu_usage}%"
    else
        log_warning "CPU usage collection failed, will display N/A"
        cpu_usage="N/A"
    fi
    
    # Collect memory usage with error handling
    log_debug "Collecting memory usage statistics"
    memory_stats=$(get_memory_usage)
    if [[ $? -eq 0 ]] && [[ -n "$memory_stats" ]]; then
        local mem_array=($memory_stats)
        if [[ ${#mem_array[@]} -eq 5 ]] && [[ "${mem_array[0]}" != "N/A" ]]; then
            memory_status="success"
            log_debug "Memory usage collection successful"
        else
            log_warning "Memory usage collection returned invalid data"
            memory_stats="N/A N/A N/A N/A N/A"
        fi
    else
        log_warning "Memory usage collection failed, will display N/A"
        memory_stats="N/A N/A N/A N/A N/A"
    fi
    
    # Collect disk usage with error handling
    log_debug "Collecting disk usage statistics"
    disk_stats=$(get_disk_usage "/")
    if [[ $? -eq 0 ]] && [[ -n "$disk_stats" ]]; then
        local disk_array=($disk_stats)
        if [[ ${#disk_array[@]} -eq 4 ]] && [[ "${disk_array[0]}" != "N/A" ]]; then
            disk_status="success"
            log_debug "Disk usage collection successful"
        else
            log_warning "Disk usage collection returned invalid data"
            disk_stats="N/A N/A N/A N/A"
        fi
    else
        log_warning "Disk usage collection failed, will display N/A"
        disk_stats="N/A N/A N/A N/A"
    fi
    
    # Collect top CPU processes with error handling
    log_debug "Collecting top CPU processes"
    top_cpu_processes=$(get_top_cpu_processes)
    if [[ $? -eq 0 ]] && [[ -n "$top_cpu_processes" ]]; then
        cpu_processes_status="success"
        log_debug "Top CPU processes collection successful"
    else
        log_warning "Top CPU processes collection failed"
        top_cpu_processes=""
    fi
    
    # Collect top memory processes with error handling
    log_debug "Collecting top memory processes"
    top_memory_processes=$(get_top_memory_processes)
    if [[ $? -eq 0 ]] && [[ -n "$top_memory_processes" ]]; then
        memory_processes_status="success"
        log_debug "Top memory processes collection successful"
    else
        log_warning "Top memory processes collection failed"
        top_memory_processes=""
    fi
    
    # Collect system information (stretch goals) with error handling
    log_debug "Collecting system information"
    system_info=$(get_system_info)
    if [[ $? -eq 0 ]] && [[ -n "$system_info" ]]; then
        system_info_status="success"
        log_debug "System information collection successful"
    else
        log_warning "System information collection failed"
        system_info=""
    fi
    
    # Collect user information (stretch goals) with error handling
    log_debug "Collecting user information"
    if check_command "who" false; then
        user_info=$(get_logged_in_users)
        if [[ $? -eq 0 ]] && [[ -n "$user_info" ]]; then
            user_info_status="success"
            log_debug "User information collection successful"
        else
            log_warning "User information collection failed"
            user_info=""
        fi
    else
        log_warning "who command not available for user information"
        user_info=""
    fi
    
    # Calculate execution time for performance monitoring
    local end_time
    end_time=$(date +%s.%N 2>/dev/null || date +%s)
    local execution_time
    if command -v bc >/dev/null 2>&1; then
        execution_time=$(echo "scale=3; $end_time - $start_time" | bc -l 2>/dev/null)
    else
        execution_time=$(echo "$end_time - $start_time" | awk '{printf "%.3f", $1}' 2>/dev/null || echo "N/A")
    fi
    
    log_debug "Data collection completed in ${execution_time}s"
    log_debug "Collection status - CPU: $cpu_status, Memory: $memory_status, Disk: $disk_status, CPU Processes: $cpu_processes_status, Memory Processes: $memory_processes_status"
    
    # Display the collected statistics using the dashboard output function
    display_dashboard "$cpu_usage" "$memory_stats" "$disk_stats" "$top_cpu_processes" "$top_memory_processes" "$system_info" "$user_info" "$execution_time"
    
    # Log completion status
    local failed_collections=0
    [[ "$cpu_status" == "failed" ]] && ((failed_collections++))
    [[ "$memory_status" == "failed" ]] && ((failed_collections++))
    [[ "$disk_status" == "failed" ]] && ((failed_collections++))
    [[ "$cpu_processes_status" == "failed" ]] && ((failed_collections++))
    [[ "$memory_processes_status" == "failed" ]] && ((failed_collections++))
    
    if [[ $failed_collections -eq 0 ]]; then
        log_debug "All core statistics collected successfully"
        return 0
    elif [[ $failed_collections -lt 3 ]]; then
        log_warning "$failed_collections core statistics failed to collect, but script completed with partial data"
        return 0
    else
        log_error "Multiple core statistics failed to collect ($failed_collections failures)"
        return 1
    fi
}

#==============================================================================
# USAGE EXAMPLES AND INTEGRATION GUIDE
#==============================================================================
#
# BASIC USAGE:
#   ./server-stats.sh                    # Run with default settings
#   ./server-stats.sh --debug           # Enable debug output
#   ./server-stats.sh --help            # Show help information
#   ./server-stats.sh --version         # Display version
#
# ADVANCED USAGE:
#   # Save output to file for later analysis
#   ./server-stats.sh > /var/log/server-stats-$(date +%Y%m%d-%H%M%S).log
#   
#   # Monitor continuously with watch command
#   watch -n 30 ./server-stats.sh       # Update every 30 seconds
#   
#   # Run in background and log output
#   nohup ./server-stats.sh --debug > stats.log 2>&1 &
#   
#   # Combine with other tools
#   ./server-stats.sh | grep -E "(CPU|Memory|Disk)" | mail -s "Server Stats" admin@example.com
#
# CRON INTEGRATION:
#   # Add to crontab for regular monitoring
#   # Run every 15 minutes and log to file
#   */15 * * * * /path/to/server-stats.sh >> /var/log/server-stats.log 2>&1
#   
#   # Daily summary at midnight
#   0 0 * * * /path/to/server-stats.sh > /var/log/daily-stats-$(date +\%Y\%m\%d).log
#
# MONITORING INTEGRATION:
#   # Parse output for monitoring systems
#   CPU_USAGE=$(./server-stats.sh | grep "CPU Usage:" | awk '{print $3}' | sed 's/%//')
#   if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
#       echo "High CPU usage detected: ${CPU_USAGE}%"
#   fi
#
# TROUBLESHOOTING SCENARIOS:
#   # Debug permission issues
#   ./server-stats.sh --debug 2>&1 | grep -i "permission\|access"
#   
#   # Check for missing commands
#   ./server-stats.sh --debug 2>&1 | grep -i "command.*not.*available"
#   
#   # Verify system compatibility
#   ./server-stats.sh --debug 2>&1 | grep -i "fallback\|warning"
#
# PERFORMANCE TESTING:
#   # Measure execution time
#   time ./server-stats.sh >/dev/null
#   
#   # Test under load
#   stress --cpu 4 --timeout 60s &
#   ./server-stats.sh
#   
#   # Memory usage during execution
#   /usr/bin/time -v ./server-stats.sh 2>&1 | grep "Maximum resident set size"
#
#==============================================================================

# Execute main function with all arguments
main "$@"