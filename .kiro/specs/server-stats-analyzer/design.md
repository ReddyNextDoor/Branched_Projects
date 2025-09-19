# Design Document

## Overview

The server-stats.sh script will be a standalone bash script that collects and displays essential server performance metrics. The design prioritizes portability, reliability, and clear output formatting. The script will use standard Linux commands and /proc filesystem entries that are available across most Linux distributions without requiring additional package installations.

## Architecture

The script follows a modular function-based architecture:

```
server-stats.sh
├── Main execution flow
├── CPU usage collection function
├── Memory usage collection function  
├── Disk usage collection function
├── Top processes collection functions
├── Additional stats collection functions (stretch goals)
├── Output formatting functions
└── Error handling utilities
```

The script will execute functions sequentially and format output in a readable dashboard-style display.

## Components and Interfaces

### Core Functions

#### `get_cpu_usage()`
- **Purpose**: Calculate current CPU usage percentage
- **Method**: Read `/proc/stat` and calculate CPU utilization over a brief sampling period
- **Fallback**: Use `top` command in batch mode if /proc/stat is unavailable
- **Output**: CPU usage as percentage (e.g., "CPU Usage: 45.2%")

#### `get_memory_usage()`
- **Purpose**: Collect memory statistics including free, used, and percentages
- **Method**: Parse `/proc/meminfo` or use `free` command
- **Calculations**: 
  - Used = Total - Available (accounting for buffers/cache)
  - Percentage = (Used / Total) * 100
- **Output**: Memory statistics with absolute values and percentages

#### `get_disk_usage()`
- **Purpose**: Display disk space usage for root filesystem
- **Method**: Use `df` command targeting root filesystem (/)
- **Output**: Disk usage showing used, available space and percentage

#### `get_top_cpu_processes()`
- **Purpose**: Identify top 5 CPU-consuming processes
- **Method**: Use `ps` command with CPU sorting or `top` in batch mode
- **Output**: Process list with PID, name, and CPU percentage

#### `get_top_memory_processes()`
- **Purpose**: Identify top 5 memory-consuming processes  
- **Method**: Use `ps` command with memory sorting
- **Output**: Process list with PID, name, and memory usage

### Stretch Goal Functions

#### `get_system_info()`
- OS version: Parse `/etc/os-release` or use `uname`
- Uptime: Read `/proc/uptime` or use `uptime` command
- Load average: Parse `/proc/loadavg` or use `uptime`

#### `get_user_info()`
- Logged in users: Use `who` or `w` command
- Failed logins: Parse `/var/log/auth.log` or `/var/log/secure` (with permission checks)

## Data Models

### System Stats Structure
```bash
# Global variables to store collected data
CPU_USAGE=""
MEMORY_TOTAL=""
MEMORY_USED=""
MEMORY_FREE=""
MEMORY_PERCENT=""
DISK_TOTAL=""
DISK_USED=""
DISK_AVAILABLE=""
DISK_PERCENT=""
TOP_CPU_PROCESSES=""
TOP_MEMORY_PROCESSES=""
```

### Process Information Format
```
PID    PROCESS_NAME    CPU%    MEM%
1234   apache2         15.2    8.5
5678   mysql           12.1    25.3
```

## Error Handling

### Command Availability Checks
- Test for command existence using `command -v` before execution
- Provide fallback methods when primary commands are unavailable
- Display informative error messages for missing critical commands

### Permission Handling
- Check read permissions for /proc files before accessing
- Handle cases where certain system files are restricted
- Gracefully skip optional features that require elevated permissions

### Data Validation
- Validate numeric outputs from system commands
- Handle cases where commands return unexpected formats
- Provide default values or "N/A" for unavailable metrics

## Testing Strategy

### Unit Testing Approach
- Test individual functions with mock data
- Verify output formatting consistency
- Test error handling scenarios

### Integration Testing
- Test script execution on different Linux distributions:
  - Ubuntu/Debian
  - CentOS/RHEL
  - Alpine Linux
- Verify compatibility with different kernel versions
- Test with various system loads and configurations

### Performance Testing
- Measure script execution time
- Ensure minimal system impact during data collection
- Test behavior under high system load

## Output Format Design

The script will produce a clean, dashboard-style output:

```
=== Server Performance Stats ===

CPU Usage: 23.5%

Memory Usage:
  Total: 8.0 GB
  Used:  5.2 GB (65.0%)
  Free:  2.8 GB (35.0%)

Disk Usage (/):
  Total: 50.0 GB  
  Used:  32.1 GB (64.2%)
  Free:  17.9 GB (35.8%)

Top 5 Processes by CPU:
  PID    Process         CPU%
  1234   apache2         15.2%
  5678   mysql           12.1%
  9012   node            8.7%
  3456   python3         5.3%
  7890   nginx           3.1%

Top 5 Processes by Memory:
  PID    Process         Memory
  5678   mysql           2.1 GB
  1234   apache2         1.8 GB
  9012   node            0.9 GB
  3456   python3         0.5 GB
  7890   nginx           0.3 GB

=== Additional System Info ===
OS: Ubuntu 20.04.3 LTS
Uptime: 15 days, 3:42
Load Average: 1.23, 1.45, 1.67
Logged in Users: 3
```

## Implementation Considerations

### Portability
- Use POSIX-compliant bash features where possible
- Avoid GNU-specific command options
- Test command availability before use
- Provide multiple methods for data collection

### Performance
- Minimize system calls and command executions
- Use efficient parsing methods for /proc files
- Implement brief sampling periods for CPU calculations
- Cache results when multiple functions need same data

### Security
- Avoid executing user-provided input
- Handle file permissions gracefully
- Don't require root privileges for basic functionality
- Sanitize any dynamic command construction