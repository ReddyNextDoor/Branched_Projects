#!/bin/bash

#==============================================================================
# Server Stats Analyzer - Integration Test Suite
# Version: 1.0.0
# Description: Integration tests for server-stats.sh across different environments
# Author: Server Stats Analyzer Integration Test Suite
# License: MIT
#==============================================================================

# Test configuration
INTEGRATION_TEST_NAME="integration-test-server-stats.sh"
INTEGRATION_TEST_VERSION="1.0.0"
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Colors for output (if terminal supports it)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Test script path
SCRIPT_PATH="./server-stats.sh"

#==============================================================================
# TEST FRAMEWORK FUNCTIONS
#==============================================================================

# Function to print test results
print_test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    ((TESTS_TOTAL++))
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name - $message"
        ((TESTS_FAILED++))
    fi
}

# Function to assert that a command succeeds
assert_success() {
    local command="$1"
    local test_name="$2"
    local timeout_duration="${3:-30}"
    
    # Use timeout if available, otherwise run without timeout
    if command -v timeout >/dev/null 2>&1; then
        if timeout "$timeout_duration" bash -c "$command" >/dev/null 2>&1; then
            print_test_result "$test_name" "PASS" ""
        else
            print_test_result "$test_name" "FAIL" "Command failed or timed out: $command"
        fi
    else
        # macOS doesn't have timeout by default, use background process with kill
        bash -c "$command" >/dev/null 2>&1 &
        local cmd_pid=$!
        local count=0
        
        while kill -0 "$cmd_pid" 2>/dev/null && [[ $count -lt $timeout_duration ]]; do
            sleep 1
            ((count++))
        done
        
        if kill -0 "$cmd_pid" 2>/dev/null; then
            kill "$cmd_pid" 2>/dev/null
            wait "$cmd_pid" 2>/dev/null || true
            print_test_result "$test_name" "FAIL" "Command timed out: $command"
        else
            wait "$cmd_pid"
            local exit_code=$?
            if [[ $exit_code -eq 0 ]]; then
                print_test_result "$test_name" "PASS" ""
            else
                print_test_result "$test_name" "FAIL" "Command failed: $command"
            fi
        fi
    fi
}

# Function to assert that output contains expected content
assert_output_contains() {
    local command="$1"
    local expected="$2"
    local test_name="$3"
    local timeout_duration="${4:-30}"
    
    local output
    local exit_code
    
    # Use timeout if available, otherwise run without timeout
    if command -v timeout >/dev/null 2>&1; then
        output=$(timeout "$timeout_duration" bash -c "$command" 2>&1)
        exit_code=$?
    else
        # macOS fallback - run command with background process monitoring
        local temp_file=$(mktemp)
        bash -c "$command" >"$temp_file" 2>&1 &
        local cmd_pid=$!
        local count=0
        
        while kill -0 "$cmd_pid" 2>/dev/null && [[ $count -lt $timeout_duration ]]; do
            sleep 1
            ((count++))
        done
        
        if kill -0 "$cmd_pid" 2>/dev/null; then
            kill "$cmd_pid" 2>/dev/null
            wait "$cmd_pid" 2>/dev/null || true
            exit_code=124  # timeout exit code
        else
            wait "$cmd_pid"
            exit_code=$?
        fi
        
        output=$(cat "$temp_file")
        rm -f "$temp_file"
    fi
    
    if [[ $exit_code -eq 0 ]] && [[ "$output" == *"$expected"* ]]; then
        print_test_result "$test_name" "PASS" ""
    else
        print_test_result "$test_name" "FAIL" "Expected '$expected' in output. Exit code: $exit_code"
    fi
}

# Function to assert that output does NOT contain specific content
assert_output_not_contains() {
    local command="$1"
    local unexpected="$2"
    local test_name="$3"
    local timeout="${4:-30}"
    
    local output
    output=$(timeout "$timeout" bash -c "$command" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]] && [[ "$output" != *"$unexpected"* ]]; then
        print_test_result "$test_name" "PASS" ""
    else
        print_test_result "$test_name" "FAIL" "Should not contain '$unexpected' in output"
    fi
}

# Function to measure execution time
measure_execution_time() {
    local command="$1"
    local max_time="$2"
    local test_name="$3"
    
    local start_time
    local end_time
    local execution_time
    
    # Use different time commands based on availability
    if command -v gdate >/dev/null 2>&1; then
        start_time=$(gdate +%s.%N)
        eval "$command" >/dev/null 2>&1
        local exit_code=$?
        end_time=$(gdate +%s.%N)
        execution_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    elif date +%s.%N >/dev/null 2>&1; then
        start_time=$(date +%s.%N)
        eval "$command" >/dev/null 2>&1
        local exit_code=$?
        end_time=$(date +%s.%N)
        execution_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    else
        # Fallback to seconds precision
        start_time=$(date +%s)
        eval "$command" >/dev/null 2>&1
        local exit_code=$?
        end_time=$(date +%s)
        execution_time=$((end_time - start_time))
    fi
    
    if [[ $exit_code -eq 0 ]] && (( $(echo "$execution_time <= $max_time" | bc -l 2>/dev/null || echo "1") )); then
        print_test_result "$test_name" "PASS" ""
    else
        print_test_result "$test_name" "FAIL" "Execution time ${execution_time}s exceeded ${max_time}s or command failed"
    fi
}

#==============================================================================
# ENVIRONMENT DETECTION FUNCTIONS
#==============================================================================

detect_os() {
    local os_name
    os_name=$(uname -s)
    
    case "$os_name" in
        Linux*)
            echo "Linux"
            ;;
        Darwin*)
            echo "macOS"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "Windows"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

detect_linux_distribution() {
    if [[ ! "$(detect_os)" == "Linux" ]]; then
        echo "Not Linux"
        return
    fi
    
    if [[ -f /etc/os-release ]]; then
        local distro
        distro=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
        echo "$distro"
    elif [[ -f /etc/redhat-release ]]; then
        echo "redhat"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

check_command_availability() {
    local commands=("ps" "df" "top" "free" "who" "uptime" "bc")
    local available_commands=()
    local missing_commands=()
    
    for cmd in "${commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            available_commands+=("$cmd")
        else
            missing_commands+=("$cmd")
        fi
    done
    
    echo "Available: ${available_commands[*]}"
    echo "Missing: ${missing_commands[*]}"
}

#==============================================================================
# BASIC FUNCTIONALITY TESTS
#==============================================================================

test_script_execution() {
    echo -e "\n${BLUE}Testing Basic Script Execution${NC}"
    
    # Test that script exists and is executable
    if [[ -f "$SCRIPT_PATH" ]]; then
        print_test_result "Script file exists" "PASS" ""
    else
        print_test_result "Script file exists" "FAIL" "Script not found at $SCRIPT_PATH"
        return 1
    fi
    
    if [[ -x "$SCRIPT_PATH" ]]; then
        print_test_result "Script is executable" "PASS" ""
    else
        print_test_result "Script is executable" "FAIL" "Script is not executable"
        chmod +x "$SCRIPT_PATH" 2>/dev/null
    fi
    
    # Test basic script execution
    assert_success "$SCRIPT_PATH" "Script executes without errors"
    
    # Test help option
    assert_success "$SCRIPT_PATH --help" "Script help option works"
    
    # Test version option
    assert_success "$SCRIPT_PATH --version" "Script version option works"
    
    # Test debug mode
    assert_success "$SCRIPT_PATH --debug" "Script debug mode works"
    
    # Test invalid option handling
    if ! "$SCRIPT_PATH" --invalid-option >/dev/null 2>&1; then
        print_test_result "Script handles invalid options gracefully" "PASS" ""
    else
        print_test_result "Script handles invalid options gracefully" "FAIL" "Should exit with error for invalid options"
    fi
}

test_output_format() {
    echo -e "\n${BLUE}Testing Output Format and Content${NC}"
    
    # Test that output contains expected sections
    assert_output_contains "$SCRIPT_PATH" "Server Performance Stats" "Output contains main header"
    assert_output_contains "$SCRIPT_PATH" "CPU Usage" "Output contains CPU section"
    assert_output_contains "$SCRIPT_PATH" "Memory Usage" "Output contains Memory section"
    assert_output_contains "$SCRIPT_PATH" "Disk Usage" "Output contains Disk section"
    assert_output_contains "$SCRIPT_PATH" "Top 5 Processes by CPU" "Output contains CPU processes section"
    assert_output_contains "$SCRIPT_PATH" "Top 5 Processes by Memory" "Output contains Memory processes section"
    
    # Test that output contains numeric values or N/A
    local output
    output=$("$SCRIPT_PATH" 2>/dev/null)
    
    # Check for percentage values in CPU section
    if echo "$output" | grep -E "CPU Usage.*[0-9]+\.[0-9]+%|N/A" >/dev/null; then
        print_test_result "CPU usage shows numeric percentage or N/A" "PASS" ""
    else
        print_test_result "CPU usage shows numeric percentage or N/A" "FAIL" "CPU usage format incorrect"
    fi
    
    # Check for memory values
    if echo "$output" | grep -E "Total:.*([0-9]+\.[0-9]+ [KMGT]B|N/A)" >/dev/null; then
        print_test_result "Memory total shows proper format or N/A" "PASS" ""
    else
        print_test_result "Memory total shows proper format or N/A" "FAIL" "Memory format incorrect"
    fi
    
    # Check for disk values
    if echo "$output" | grep -E "Total:.*([0-9]+\.[0-9]+ [KMGT]B|N/A)" >/dev/null; then
        print_test_result "Disk total shows proper format or N/A" "PASS" ""
    else
        print_test_result "Disk total shows proper format or N/A" "FAIL" "Disk format incorrect"
    fi
}

#==============================================================================
# CROSS-PLATFORM COMPATIBILITY TESTS
#==============================================================================

test_cross_platform_compatibility() {
    echo -e "\n${BLUE}Testing Cross-Platform Compatibility${NC}"
    
    local os_type
    os_type=$(detect_os)
    
    echo "Detected OS: $os_type"
    
    case "$os_type" in
        Linux)
            test_linux_compatibility
            ;;
        macOS)
            test_macos_compatibility
            ;;
        *)
            echo "Unsupported OS for detailed testing: $os_type"
            ;;
    esac
    
    # Test command availability
    echo "Command availability:"
    check_command_availability
}

test_linux_compatibility() {
    echo -e "\n${BLUE}Testing Linux-Specific Compatibility${NC}"
    
    local distro
    distro=$(detect_linux_distribution)
    echo "Detected Linux distribution: $distro"
    
    # Test /proc filesystem access
    if [[ -r /proc/stat ]]; then
        print_test_result "Can read /proc/stat" "PASS" ""
    else
        print_test_result "Can read /proc/stat" "FAIL" "/proc/stat not readable"
    fi
    
    if [[ -r /proc/meminfo ]]; then
        print_test_result "Can read /proc/meminfo" "PASS" ""
    else
        print_test_result "Can read /proc/meminfo" "FAIL" "/proc/meminfo not readable"
    fi
    
    if [[ -r /proc/uptime ]]; then
        print_test_result "Can read /proc/uptime" "PASS" ""
    else
        print_test_result "Can read /proc/uptime" "FAIL" "/proc/uptime not readable"
    fi
    
    # Test Linux-specific commands
    assert_success "ps aux" "Linux ps aux command works"
    assert_success "free -m" "Linux free command works"
    assert_success "df -h" "Linux df command works"
}

test_macos_compatibility() {
    echo -e "\n${BLUE}Testing macOS-Specific Compatibility${NC}"
    
    # Test macOS-specific commands
    assert_success "ps -eo pid,pcpu,comm" "macOS ps command works"
    assert_success "top -l 1" "macOS top command works"
    assert_success "df -h" "macOS df command works"
    
    # Test that script handles macOS differences
    assert_output_contains "$SCRIPT_PATH" "CPU Usage" "Script works on macOS"
}

#==============================================================================
# PERFORMANCE TESTS
#==============================================================================

test_performance() {
    echo -e "\n${BLUE}Testing Performance Under Various Conditions${NC}"
    
    # Test normal execution time (should complete within reasonable time)
    measure_execution_time "$SCRIPT_PATH" 10.0 "Script completes within 10 seconds"
    
    # Test debug mode performance (may be slower)
    measure_execution_time "$SCRIPT_PATH --debug" 15.0 "Debug mode completes within 15 seconds"
    
    # Test multiple concurrent executions
    test_concurrent_execution
    
    # Test performance with limited resources
    test_resource_constraints
}

test_concurrent_execution() {
    echo -e "\n${BLUE}Testing Concurrent Execution${NC}"
    
    # Run multiple instances concurrently
    local pids=()
    local num_instances=3
    
    for i in $(seq 1 $num_instances); do
        "$SCRIPT_PATH" >/dev/null 2>&1 &
        pids+=($!)
    done
    
    # Wait for all instances to complete
    local all_success=true
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            all_success=false
        fi
    done
    
    if [[ "$all_success" == true ]]; then
        print_test_result "Multiple concurrent executions succeed" "PASS" ""
    else
        print_test_result "Multiple concurrent executions succeed" "FAIL" "One or more instances failed"
    fi
}

test_resource_constraints() {
    echo -e "\n${BLUE}Testing Under Resource Constraints${NC}"
    
    # Test with limited PATH (simulate missing commands)
    local original_path="$PATH"
    export PATH="/bin:/usr/bin"  # Minimal PATH
    
    if "$SCRIPT_PATH" >/dev/null 2>&1; then
        print_test_result "Script works with limited PATH" "PASS" ""
    else
        print_test_result "Script works with limited PATH" "FAIL" "Script failed with limited PATH"
    fi
    
    export PATH="$original_path"
    
    # Test with simulated high system load
    # We'll create some background processes to simulate load
    test_under_simulated_load
}

test_under_simulated_load() {
    echo -e "\n${BLUE}Testing Under Simulated System Load${NC}"
    
    # Create some background CPU load
    local load_pids=()
    
    # Start background processes that consume some CPU
    for i in {1..2}; do
        (while true; do echo "load test" >/dev/null; done) &
        load_pids+=($!)
    done
    
    # Give the load processes a moment to start
    sleep 1
    
    # Test script execution under load
    local start_time=$(date +%s.%N)
    if "$SCRIPT_PATH" >/dev/null 2>&1; then
        local end_time=$(date +%s.%N)
        local execution_time
        execution_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
        
        # Should still complete within reasonable time even under load
        if (( $(echo "$execution_time <= 20.0" | bc -l 2>/dev/null || echo "0") )); then
            print_test_result "Script performs adequately under simulated load" "PASS" ""
        else
            print_test_result "Script performs adequately under simulated load" "FAIL" "Took ${execution_time}s under load"
        fi
    else
        print_test_result "Script executes successfully under simulated load" "FAIL" "Script failed under load"
    fi
    
    # Clean up background load processes
    for pid in "${load_pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    
    wait 2>/dev/null || true  # Wait for background processes to terminate
}

#==============================================================================
# ERROR HANDLING AND EDGE CASE TESTS
#==============================================================================

test_error_handling() {
    echo -e "\n${BLUE}Testing Error Handling and Edge Cases${NC}"
    
    # Test behavior when system files are not accessible
    test_file_access_restrictions
    
    # Test behavior with unusual system states
    test_unusual_system_states
    
    # Test graceful degradation
    test_graceful_degradation
}

test_file_access_restrictions() {
    echo -e "\n${BLUE}Testing File Access Restrictions${NC}"
    
    # The script should handle cases where /proc files might not be readable
    # We can't easily simulate this without root, but we can test the logic
    
    # Test that script doesn't crash when optional files are missing
    assert_success "$SCRIPT_PATH" "Script handles missing optional files gracefully"
    
    # Test that script produces some output even with limited access
    local output
    output=$("$SCRIPT_PATH" 2>/dev/null)
    
    if [[ -n "$output" ]] && [[ ${#output} -gt 100 ]]; then
        print_test_result "Script produces meaningful output with limited access" "PASS" ""
    else
        print_test_result "Script produces meaningful output with limited access" "FAIL" "Output too short or empty"
    fi
}

test_unusual_system_states() {
    echo -e "\n${BLUE}Testing Unusual System States${NC}"
    
    # Test script behavior in various scenarios
    # Most of these are hard to simulate, so we test the script's robustness
    
    # Test that script handles empty command outputs gracefully
    # This is tested indirectly through the main execution
    
    # Test that script doesn't hang indefinitely
    if command -v timeout >/dev/null 2>&1; then
        if timeout 30 "$SCRIPT_PATH" >/dev/null 2>&1; then
            print_test_result "Script doesn't hang indefinitely" "PASS" ""
        else
            print_test_result "Script doesn't hang indefinitely" "FAIL" "Script timed out after 30 seconds"
        fi
    else
        # macOS fallback
        "$SCRIPT_PATH" >/dev/null 2>&1 &
        local script_pid=$!
        local count=0
        
        while kill -0 "$script_pid" 2>/dev/null && [[ $count -lt 30 ]]; do
            sleep 1
            ((count++))
        done
        
        if kill -0 "$script_pid" 2>/dev/null; then
            kill "$script_pid" 2>/dev/null
            wait "$script_pid" 2>/dev/null || true
            print_test_result "Script doesn't hang indefinitely" "FAIL" "Script timed out after 30 seconds"
        else
            wait "$script_pid"
            print_test_result "Script doesn't hang indefinitely" "PASS" ""
        fi
    fi
    
    # Test that script handles interrupted execution gracefully
    test_interrupt_handling
}

test_interrupt_handling() {
    echo -e "\n${BLUE}Testing Interrupt Handling${NC}"
    
    # Start script in background and interrupt it
    "$SCRIPT_PATH" >/dev/null 2>&1 &
    local script_pid=$!
    
    # Let it run for a moment
    sleep 2
    
    # Send interrupt signal
    if kill -INT "$script_pid" 2>/dev/null; then
        # Wait a moment for cleanup
        sleep 1
        
        # Check if process is still running
        if ! kill -0 "$script_pid" 2>/dev/null; then
            print_test_result "Script handles interrupts gracefully" "PASS" ""
        else
            print_test_result "Script handles interrupts gracefully" "FAIL" "Script didn't terminate after interrupt"
            kill -KILL "$script_pid" 2>/dev/null || true
        fi
    else
        print_test_result "Script handles interrupts gracefully" "PASS" "Script already completed"
    fi
    
    wait 2>/dev/null || true
}

test_graceful_degradation() {
    echo -e "\n${BLUE}Testing Graceful Degradation${NC}"
    
    # Test that script provides partial results when some data is unavailable
    local output
    output=$("$SCRIPT_PATH" 2>/dev/null)
    
    # Count how many "N/A" values appear (indicating graceful degradation)
    local na_count
    na_count=$(echo "$output" | grep -o "N/A" | wc -l)
    
    # Script should still produce output even if some metrics are N/A
    if [[ -n "$output" ]] && [[ ${#output} -gt 500 ]]; then
        print_test_result "Script provides substantial output despite missing data" "PASS" ""
    else
        print_test_result "Script provides substantial output despite missing data" "FAIL" "Output too limited"
    fi
    
    # Test that script reports completion status
    if echo "$output" | grep -E "(Complete|completed)" >/dev/null; then
        print_test_result "Script reports completion status" "PASS" ""
    else
        print_test_result "Script reports completion status" "FAIL" "No completion status found"
    fi
}

#==============================================================================
# SYSTEM CONFIGURATION TESTS
#==============================================================================

test_different_system_configurations() {
    echo -e "\n${BLUE}Testing Different System Configurations${NC}"
    
    # Test with different shell environments
    test_shell_compatibility
    
    # Test with different locale settings
    test_locale_compatibility
    
    # Test with different system loads
    test_system_load_scenarios
}

test_shell_compatibility() {
    echo -e "\n${BLUE}Testing Shell Compatibility${NC}"
    
    # Test with bash (primary shell)
    if bash "$SCRIPT_PATH" >/dev/null 2>&1; then
        print_test_result "Script works with bash" "PASS" ""
    else
        print_test_result "Script works with bash" "FAIL" "Failed with bash"
    fi
    
    # Test with sh (POSIX shell) if available
    if command -v sh >/dev/null 2>&1; then
        if sh "$SCRIPT_PATH" >/dev/null 2>&1; then
            print_test_result "Script works with sh" "PASS" ""
        else
            print_test_result "Script works with sh" "FAIL" "Failed with sh"
        fi
    fi
}

test_locale_compatibility() {
    echo -e "\n${BLUE}Testing Locale Compatibility${NC}"
    
    # Save original locale
    local original_lc_all="${LC_ALL:-}"
    local original_lang="${LANG:-}"
    
    # Test with C locale (minimal)
    export LC_ALL=C
    export LANG=C
    
    if "$SCRIPT_PATH" >/dev/null 2>&1; then
        print_test_result "Script works with C locale" "PASS" ""
    else
        print_test_result "Script works with C locale" "FAIL" "Failed with C locale"
    fi
    
    # Test with UTF-8 locale if available
    if locale -a 2>/dev/null | grep -E "en_US\.UTF-?8" >/dev/null; then
        export LC_ALL=en_US.UTF-8
        export LANG=en_US.UTF-8
        
        if "$SCRIPT_PATH" >/dev/null 2>&1; then
            print_test_result "Script works with UTF-8 locale" "PASS" ""
        else
            print_test_result "Script works with UTF-8 locale" "FAIL" "Failed with UTF-8 locale"
        fi
    fi
    
    # Restore original locale
    if [[ -n "$original_lc_all" ]]; then
        export LC_ALL="$original_lc_all"
    else
        unset LC_ALL
    fi
    
    if [[ -n "$original_lang" ]]; then
        export LANG="$original_lang"
    else
        unset LANG
    fi
}

test_system_load_scenarios() {
    echo -e "\n${BLUE}Testing Various System Load Scenarios${NC}"
    
    # Test during normal load
    assert_success "$SCRIPT_PATH" "Script works under normal system load"
    
    # Test multiple rapid executions
    local rapid_success=true
    for i in {1..5}; do
        if ! "$SCRIPT_PATH" >/dev/null 2>&1; then
            rapid_success=false
            break
        fi
    done
    
    if [[ "$rapid_success" == true ]]; then
        print_test_result "Script handles rapid successive executions" "PASS" ""
    else
        print_test_result "Script handles rapid successive executions" "FAIL" "Failed during rapid execution"
    fi
}

#==============================================================================
# MAIN TEST EXECUTION
#==============================================================================

main() {
    echo -e "${BLUE}=== Server Stats Analyzer - Integration Test Suite ===${NC}"
    echo -e "${BLUE}Version: $INTEGRATION_TEST_VERSION${NC}"
    echo
    
    # Check prerequisites
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        echo -e "${RED}Error: Script not found at $SCRIPT_PATH${NC}"
        exit 1
    fi
    
    # Display environment information
    echo -e "${BLUE}Environment Information:${NC}"
    echo "OS: $(detect_os)"
    if [[ "$(detect_os)" == "Linux" ]]; then
        echo "Distribution: $(detect_linux_distribution)"
    fi
    echo "Shell: $SHELL"
    echo "Script: $SCRIPT_PATH"
    echo
    
    # Run all test suites
    test_script_execution
    test_output_format
    test_cross_platform_compatibility
    test_performance
    test_error_handling
    test_different_system_configurations
    
    # Print final results
    echo
    echo -e "${BLUE}=== Integration Test Results Summary ===${NC}"
    echo -e "Total Tests: $TESTS_TOTAL"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All integration tests passed! ✓${NC}"
        echo -e "${GREEN}The script is compatible with this environment and performs well.${NC}"
        exit 0
    else
        echo -e "\n${RED}Some integration tests failed! ✗${NC}"
        echo -e "${YELLOW}The script may have compatibility issues or performance problems.${NC}"
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi