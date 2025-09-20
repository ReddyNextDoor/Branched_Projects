# Server Stats Analyzer - Advanced Configuration Guide

> **Note**: For basic usage and installation, see [README.md](README.md)

This guide covers advanced configuration, deployment scenarios, and detailed troubleshooting for system administrators and DevOps engineers.

## Advanced Configuration
   ```

3. **Verify installation**:
   ```bash
   ./server-stats.sh --version
   ```

## Usage

### Basic Usage
```bash
# Run with default settings
./server-stats.sh

# Enable debug mode for troubleshooting
./server-stats.sh --debug

# Show help information
./server-stats.sh --help

# Display version information
./server-stats.sh --version
```

### Advanced Usage Examples

#### File Output and Logging
```bash
# Save output to timestamped file
./server-stats.sh > server-stats-$(date +%Y%m%d-%H%M%S).log

# Append to daily log file
./server-stats.sh >> /var/log/server-stats-$(date +%Y%m%d).log

# Separate debug output
./server-stats.sh --debug > stats.log 2> debug.log
```

#### Continuous Monitoring
```bash
# Monitor every 30 seconds with watch
watch -n 30 ./server-stats.sh

# Run in background with nohup
nohup ./server-stats.sh --debug > stats.log 2>&1 &

# Monitor with custom interval loop
while true; do
    ./server-stats.sh
    echo "---"
    sleep 60
done
```

#### Integration with System Tools
```bash
# Email daily reports
./server-stats.sh | mail -s "Daily Server Stats" admin@example.com

# Filter specific metrics
./server-stats.sh | grep -E "(CPU|Memory|Disk)"

# Parse for monitoring systems
CPU_USAGE=$(./server-stats.sh | grep "CPU Usage:" | awk '{print $3}' | sed 's/%//')
```

### Cron Integration

Add to crontab for automated monitoring:

```bash
# Edit crontab
crontab -e

# Examples:
# Run every 15 minutes
*/15 * * * * /path/to/server-stats.sh >> /var/log/server-stats.log 2>&1

# Daily summary at midnight
0 0 * * * /path/to/server-stats.sh > /var/log/daily-stats-$(date +\%Y\%m\%d).log

# Hourly monitoring with email alerts
0 * * * * /path/to/server-stats.sh | grep -q "CPU Usage: [89][0-9]" && echo "High CPU" | mail -s "Alert" admin@example.com
```

## Output Format

The script produces a clean, dashboard-style output:

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
  ...

Top 5 Processes by Memory:
  PID    Process         Memory
  5678   mysql           2.1 GB
  1234   apache2         1.8 GB
  ...

=== Additional System Info ===
OS: Ubuntu 20.04.3 LTS
Uptime: 15 days, 3:42
Load Average: 1.23, 1.45, 1.67
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Permission Denied Errors
**Problem**: Script cannot access system files
```bash
ERROR: Cannot read /proc/stat
```

**Solutions**:
- Ensure script has execute permissions: `chmod +x server-stats.sh`
- Check /proc filesystem access: `ls -la /proc/stat /proc/meminfo`
- Verify /proc is mounted: `mount | grep proc`

#### 2. Command Not Found Errors
**Problem**: Required commands are missing
```bash
WARNING: Optional command 'free' is not available
```

**Solutions**:
- Install procps package:
  - Ubuntu/Debian: `apt-get install procps`
  - CentOS/RHEL: `yum install procps-ng`
  - Alpine: `apk add procps`
- Run with `--debug` to identify missing commands

#### 3. Inaccurate CPU Calculations
**Problem**: CPU usage shows as 0% or unrealistic values

**Solutions**:
- Install bc for precise calculations: `apt-get install bc`
- Check system load during measurement
- Verify CPU isn't idle during sampling period
- Run multiple times to confirm consistency

#### 4. Script Hangs or Slow Performance
**Problem**: Script takes too long to execute or appears to hang

**Solutions**:
- Check if system is under heavy load: `uptime`
- Verify disk space availability: `df -h`
- Run with `--debug` to identify bottlenecks
- Check for I/O wait issues: `iostat 1 5`

#### 5. Partial Data Display
**Problem**: Some statistics show as "N/A" or are missing

**Solutions**:
- Script uses fallback methods automatically
- Check system logs: `dmesg | tail`
- Verify command availability: `which ps df free top`
- Review debug output for specific failures

#### 6. Memory Usage Discrepancies
**Problem**: Memory values don't match other tools

**Solutions**:
- Different tools calculate "used" memory differently
- Script accounts for buffers/cache appropriately
- Compare with: `free -h` and `cat /proc/meminfo`
- Use `--debug` to see calculation details

### Debug Mode

Enable debug mode for detailed troubleshooting:

```bash
./server-stats.sh --debug
```

Debug output includes:
- Command availability checks
- File access verification
- Calculation steps and intermediate values
- Fallback method usage
- Performance timing information
- Error details and context

### Performance Optimization

#### Typical Performance Metrics
- Execution time: 1-3 seconds
- Memory usage: <10MB during execution
- CPU impact: Minimal (brief sampling only)
- Disk I/O: Read-only access to /proc files

#### Optimization Tips
- Install `bc` for faster calculations
- Ensure adequate system resources
- Avoid running during peak I/O periods
- Use appropriate sampling intervals for monitoring

## Integration Examples

### Monitoring System Integration

#### Nagios Plugin
```bash
#!/bin/bash
# Nagios plugin wrapper
OUTPUT=$(./server-stats.sh)
CPU=$(echo "$OUTPUT" | grep "CPU Usage:" | awk '{print $3}' | sed 's/%//')

if (( $(echo "$CPU > 90" | bc -l) )); then
    echo "CRITICAL - CPU usage: ${CPU}%"
    exit 2
elif (( $(echo "$CPU > 80" | bc -l) )); then
    echo "WARNING - CPU usage: ${CPU}%"
    exit 1
else
    echo "OK - CPU usage: ${CPU}%"
    exit 0
fi
```

#### Prometheus Metrics Export
```bash
#!/bin/bash
# Export metrics for Prometheus
./server-stats.sh | awk '
/CPU Usage:/ { print "server_cpu_usage_percent " $3 }
/Used:.*GB.*\(.*%\)/ { gsub(/[()%]/, "", $4); print "server_memory_usage_percent " $4 }
/Used:.*GB.*\(.*%\)/ { gsub(/GB/, "", $2); print "server_disk_usage_percent " $4 }
' | sed 's/%//' > /var/lib/prometheus/node-exporter/server-stats.prom
```

### Log Analysis

#### Parse Historical Data
```bash
# Extract CPU trends from logs
grep "CPU Usage:" /var/log/server-stats.log | \
awk '{print $1, $2, $5}' | \
sort -k1,2

# Memory usage over time
grep "Used:" /var/log/server-stats.log | \
grep "GB" | \
awk '{print $1, $2, $3, $4, $5}'
```

## Security Considerations

### Permissions
- Script requires only read access to system files
- No root privileges needed for basic functionality
- Uses standard system commands available to all users

### Data Privacy
- No network connections made
- No external dependencies downloaded
- Only reads publicly available system information
- No user data or sensitive information collected

### Best Practices
- Run with minimal necessary privileges
- Store logs in appropriate locations with proper permissions
- Regularly review and rotate log files
- Monitor script execution for unusual behavior

## Contributing and Support

### Reporting Issues
When reporting issues, please include:
- Operating system and version
- Script version (`./server-stats.sh --version`)
- Complete error message
- Debug output (`./server-stats.sh --debug`)
- System configuration details

### Feature Requests
Consider the following when requesting features:
- Maintain portability across distributions
- Avoid external dependencies
- Keep execution time minimal
- Preserve backward compatibility

## License

This script is released under the MIT License. See the script header for full license text.

## Changelog

### Version 1.0.0
- Initial release
- CPU, memory, and disk usage monitoring
- Process monitoring (top 5 by CPU and memory)
- Cross-distribution compatibility
- Debug mode and comprehensive error handling
- Fallback methods for enhanced reliability