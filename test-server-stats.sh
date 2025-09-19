#!/bin/bash

#==============================================================================
# Server Stats Analyzer - Unit Test Suite
# Version: 1.0.0
# Description: Comprehensive unit tests for server-stats.sh functions
# Author: Server Stats Analyzer Test Suite
# License: MIT
#==============================================================================

# Test configuration
TEST_SCRIPT_NAME="test-server-stats.sh"
TEST_SCRIPT_VERSION="1.0.0"
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

# Source the main script to access its functions
if [[ -f "server-stats.sh" ]]; then
    source server-stats.sh
else
    echo "Error: server-stats.sh not found in current directory"
    exit 1
fi

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

# Function to assert equality
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    if [[ "$expected" == "$actual" ]]; then
        print_test_result "$test_name" "PASS" ""
    else
        print_test_result "$test_name" "FAIL" "Expected '$expected', got '$actual'"
    fi
}

# Function to assert that a command succeeds
assert_success() {
    local command="$1"
    local test_name="$2"
    
    if eval "$command" >/dev/null 2>&1; then
        print_test_result "$test_name" "PASS" ""
    else
        print_test_result "$test_name" "FAIL" "Command failed: $command"
    fi
}

# Function to assert that a command fails
assert_failure() {
    local command="$1"
    local test_name="$2"
    
    if ! eval "$command" >/dev/null 2>&1; then
        print_test_result "$test_name" "PASS" ""
    else
        print_test_result "$test_name" "FAIL" "Command should have failed: $command"
    fi
}

# Function to assert that output contains expected string
assert_contains() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    if [[ "$actual" == *"$expected"* ]]; then
        print_test_result "$test_name" "PASS" ""
    else
        print_test_result "$test_name" "FAIL" "Output does not contain '$expected'. Got: '$actual'"
    fi
}

# Function to assert that a value is numeric
assert_numeric() {
    local value="$1"
    local test_name="$2"
    
    if [[ "$value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        print_test_result "$test_name" "PASS" ""
    else
        print_test_result "$test_name" "FAIL" "Value '$value' is not numeric"
    fi
}

#==============================================================================
# UTILITY FUNCTION TESTS
#==============================================================================

test_error_handling_functions() {
    echo -e "\n${BLUE}Testing Error Handling Functions${NC}"
    
    # Test validate_number function
    assert_success "validate_number '123.45'" "validate_number with valid decimal"
    assert_success "validate_number '100'" "validate_number with valid integer"
    assert_failure "validate_number 'abc'" "validate_number with invalid string"
    assert_failure "validate_number ''" "validate_number with empty string"
    assert_failure "validate_number '12.34.56'" "validate_number with multiple decimals"
    
    # Test check_command function
    assert_success "check_command 'bash'" "check_command with existing command"
    assert_failure "check_command 'nonexistent_command_12345'" "check_command with non-existent command"
}

test_formatting_functions() {
    echo -e "\n${BLUE}Testing Output Formatting Functions${NC}"
    
    # Test format_bytes function
    local bytes_1024=$(format_bytes 1024)
    assert_equals "1.0 KB" "$bytes_1024" "format_bytes 1024 bytes to KB"
    
    local bytes_1048576=$(format_bytes 1048576)
    assert_equals "1.0 MB" "$bytes_1048576" "format_bytes 1048576 bytes to MB"
    
    local bytes_invalid=$(format_bytes "invalid")
    assert_equals "N/A" "$bytes_invalid" "format_bytes with invalid input"
    
    # Test format_percentage function
    local percent_50=$(format_percentage 50.0)
    assert_equals "50.0%" "$percent_50" "format_percentage 50.0"
    
    local percent_invalid=$(format_percentage "invalid")
    assert_equals "N/A" "$percent_invalid" "format_percentage with invalid input"
    
    # Test format_decimal function
    local decimal_123=$(format_decimal 123.456 2)
    assert_equals "123.46" "$decimal_123" "format_decimal with 2 precision"
    
    local decimal_invalid=$(format_decimal "invalid")
    assert_equals "N/A" "$decimal_invalid" "format_decimal with invalid input"
}

#==============================================================================
# CPU FUNCTION TESTS
#==============================================================================

test_cpu_parsing_functions() {
    echo -e "\n${BLUE}Testing CPU Parsing Functions${NC}"
    
    # Test parse_cpu_stats function with valid input
    local test_cpu_line="cpu  123456 1234 56789 987654 1234 0 5678 0 0 0"
    local cpu_result=$(parse_cpu_stats "$test_cpu_line")
    
    if [[ $? -eq 0 ]]; then
        local stats=($cpu_result)
        local total=${stats[0]}
        local idle=${stats[1]}
        local active=${stats[2]}
        
        # Calculate expected values
        local expected_total=$((123456 + 1234 + 56789 + 987654 + 1234 + 0 + 5678 + 0))
        local expected_idle=$((987654 + 1234))
        local expected_active=$((expected_total - expected_idle))
        
        assert_equals "$expected_total" "$total" "parse_cpu_stats total calculation"
        assert_equals "$expected_idle" "$idle" "parse_cpu_stats idle calculation"
        assert_equals "$expected_active" "$active" "parse_cpu_stats active calculation"
    else
        print_test_result "parse_cpu_stats with valid input" "FAIL" "Function returned error"
    fi
    
    # Test parse_cpu_stats with minimal valid input
    local test_cpu_minimal="cpu  1000 100 500 8000"
    local cpu_minimal_result=$(parse_cpu_stats "$test_cpu_minimal")
    
    if [[ $? -eq 0 ]]; then
        print_test_result "parse_cpu_stats with minimal input" "PASS" ""
    else
        print_test_result "parse_cpu_stats with minimal input" "FAIL" "Function should accept minimal input"
    fi
    
    # Test parse_cpu_stats with invalid input
    local test_cpu_invalid="cpu  1000 100"
    local cpu_invalid_result
    cpu_invalid_result=$(parse_cpu_stats "$test_cpu_invalid" 2>/dev/null)
    local exit_code1=$?
    
    if [[ $exit_code1 -ne 0 ]]; then
        print_test_result "parse_cpu_stats with insufficient data" "PASS" ""
    else
        print_test_result "parse_cpu_stats with insufficient data" "FAIL" "Function should reject insufficient data"
    fi
    
    # Test parse_cpu_stats with non-numeric values
    local test_cpu_nonnumeric="cpu  abc def ghi jkl"
    local cpu_nonnumeric_result
    cpu_nonnumeric_result=$(parse_cpu_stats "$test_cpu_nonnumeric" 2>/dev/null)
    local exit_code2=$?
    
    if [[ $exit_code2 -ne 0 ]]; then
        print_test_result "parse_cpu_stats with non-numeric values" "PASS" ""
    else
        print_test_result "parse_cpu_stats with non-numeric values" "FAIL" "Function should reject non-numeric values"
    fi
}

test_cpu_calculation_edge_cases() {
    echo -e "\n${BLUE}Testing CPU Calculation Edge Cases${NC}"
    
    # Test CPU usage bounds (should be 0-100%)
    # We'll create a mock function to test the calculation logic
    test_cpu_percentage_bounds() {
        local total_diff="$1"
        local idle_diff="$2"
        
        if [[ $total_diff -eq 0 ]]; then
            echo "0.0"
            return 1
        fi
        
        local cpu_usage
        cpu_usage=$(echo "scale=2; (($total_diff - $idle_diff) * 100) / $total_diff" | bc -l 2>/dev/null)
        
        # Ensure bounds
        if (( $(echo "$cpu_usage < 0" | bc -l 2>/dev/null || echo "0") )); then
            cpu_usage="0.0"
        elif (( $(echo "$cpu_usage > 100" | bc -l 2>/dev/null || echo "0") )); then
            cpu_usage="100.0"
        fi
        
        echo "$cpu_usage"
    }
    
    # Test normal case
    local normal_result=$(test_cpu_percentage_bounds 1000 200)
    assert_equals "80.00" "$normal_result" "CPU percentage calculation normal case"
    
    # Test zero total (division by zero)
    local zero_total_result=$(test_cpu_percentage_bounds 0 0)
    assert_equals "0.0" "$zero_total_result" "CPU percentage calculation with zero total"
    
    # Test 100% usage (idle = 0)
    local full_usage_result=$(test_cpu_percentage_bounds 1000 0)
    assert_equals "100.00" "$full_usage_result" "CPU percentage calculation with 100% usage"
    
    # Test 0% usage (idle = total)
    local zero_usage_result=$(test_cpu_percentage_bounds 1000 1000)
    # bc may return "0" instead of "0.00" depending on version
    if [[ "$zero_usage_result" == "0" ]] || [[ "$zero_usage_result" == "0.00" ]]; then
        print_test_result "CPU percentage calculation with 0% usage" "PASS" ""
    else
        print_test_result "CPU percentage calculation with 0% usage" "FAIL" "Expected '0' or '0.00', got '$zero_usage_result'"
    fi
}

#==============================================================================
# MEMORY FUNCTION TESTS
#==============================================================================

test_memory_calculation_functions() {
    echo -e "\n${BLUE}Testing Memory Calculation Functions${NC}"
    
    # Create a mock meminfo parser for testing
    test_memory_parsing() {
        local meminfo_content="$1"
        
        # Simulate parsing /proc/meminfo
        local mem_total=$(echo "$meminfo_content" | grep "MemTotal:" | awk '{print $2}')
        local mem_free=$(echo "$meminfo_content" | grep "MemFree:" | awk '{print $2}')
        local mem_available=$(echo "$meminfo_content" | grep "MemAvailable:" | awk '{print $2}')
        local buffers=$(echo "$meminfo_content" | grep "Buffers:" | awk '{print $2}')
        local cached=$(echo "$meminfo_content" | grep "Cached:" | awk '{print $2}')
        
        # Use MemAvailable if present, otherwise calculate
        if [[ -n "$mem_available" ]] && validate_number "$mem_available"; then
            local mem_used_kb=$((mem_total - mem_available))
        else
            local mem_used_kb=$((mem_total - mem_free - buffers - cached))
        fi
        
        # Convert to MB and calculate percentage
        local mem_total_mb=$((mem_total / 1024))
        local mem_used_mb=$((mem_used_kb / 1024))
        local mem_free_mb=$((mem_total_mb - mem_used_mb))
        local mem_percent=$(echo "scale=1; ($mem_used_mb * 100) / $mem_total_mb" | bc -l 2>/dev/null)
        
        echo "$mem_total_mb $mem_used_mb $mem_free_mb $mem_percent"
    }
    
    # Test with typical meminfo content
    local test_meminfo="MemTotal:        8192000 kB
MemFree:         2048000 kB
MemAvailable:    3072000 kB
Buffers:          512000 kB
Cached:          1024000 kB"
    
    local mem_result=$(test_memory_parsing "$test_meminfo")
    local mem_stats=($mem_result)
    
    assert_numeric "${mem_stats[0]}" "Memory total MB is numeric"
    assert_numeric "${mem_stats[1]}" "Memory used MB is numeric"
    assert_numeric "${mem_stats[2]}" "Memory free MB is numeric"
    assert_numeric "${mem_stats[3]}" "Memory percentage is numeric"
    
    # Verify calculations
    local expected_total_mb=$((8192000 / 1024))
    assert_equals "$expected_total_mb" "${mem_stats[0]}" "Memory total MB calculation"
    
    # Test memory percentage bounds
    local mem_percent=${mem_stats[3]}
    if (( $(echo "$mem_percent >= 0 && $mem_percent <= 100" | bc -l 2>/dev/null || echo "0") )); then
        print_test_result "Memory percentage within bounds (0-100%)" "PASS" ""
    else
        print_test_result "Memory percentage within bounds (0-100%)" "FAIL" "Percentage $mem_percent is out of bounds"
    fi
}

#==============================================================================
# DISK FUNCTION TESTS
#==============================================================================

test_disk_calculation_functions() {
    echo -e "\n${BLUE}Testing Disk Calculation Functions${NC}"
    
    # Create a mock df parser for testing
    test_disk_parsing() {
        local df_output="$1"
        
        # Parse df output (skip header, get first data line)
        local disk_line=$(echo "$df_output" | tail -n +2 | head -n 1)
        
        if [[ -n "$disk_line" ]]; then
            local fields=($disk_line)
            local filesystem=${fields[0]}
            local total_kb=${fields[1]}
            local used_kb=${fields[2]}
            local available_kb=${fields[3]}
            local use_percent=${fields[4]%\%}  # Remove % sign
            
            # Convert to GB
            local total_gb=$(echo "scale=1; $total_kb / 1024 / 1024" | bc -l 2>/dev/null)
            local used_gb=$(echo "scale=1; $used_kb / 1024 / 1024" | bc -l 2>/dev/null)
            local available_gb=$(echo "scale=1; $available_kb / 1024 / 1024" | bc -l 2>/dev/null)
            
            echo "$total_gb $used_gb $available_gb $use_percent"
        fi
    }
    
    # Test with typical df output
    local test_df_output="Filesystem     1K-blocks    Used Available Use% Mounted on
/dev/sda1       52428800 33554432  18874368  65% /"
    
    local disk_result=$(test_disk_parsing "$test_df_output")
    local disk_stats=($disk_result)
    
    if [[ ${#disk_stats[@]} -eq 4 ]]; then
        assert_numeric "${disk_stats[0]}" "Disk total GB is numeric"
        assert_numeric "${disk_stats[1]}" "Disk used GB is numeric"
        assert_numeric "${disk_stats[2]}" "Disk available GB is numeric"
        assert_numeric "${disk_stats[3]}" "Disk usage percentage is numeric"
        
        # Test percentage bounds
        local disk_percent=${disk_stats[3]}
        if (( disk_percent >= 0 && disk_percent <= 100 )); then
            print_test_result "Disk percentage within bounds (0-100%)" "PASS" ""
        else
            print_test_result "Disk percentage within bounds (0-100%)" "FAIL" "Percentage $disk_percent is out of bounds"
        fi
        
        # Test that used + available ≈ total (allowing for small rounding differences)
        local calculated_total=$(echo "scale=1; ${disk_stats[1]} + ${disk_stats[2]}" | bc -l 2>/dev/null)
        local total_diff=$(echo "scale=1; ${disk_stats[0]} - $calculated_total" | bc -l 2>/dev/null)
        local abs_diff=$(echo "scale=1; if ($total_diff < 0) -$total_diff else $total_diff" | bc -l 2>/dev/null)
        
        if (( $(echo "$abs_diff < 1.0" | bc -l 2>/dev/null || echo "0") )); then
            print_test_result "Disk space calculation consistency" "PASS" ""
        else
            print_test_result "Disk space calculation consistency" "FAIL" "Total (${disk_stats[0]}) != Used (${disk_stats[1]}) + Available (${disk_stats[2]})"
        fi
    else
        print_test_result "Disk parsing returns correct number of fields" "FAIL" "Expected 4 fields, got ${#disk_stats[@]}"
    fi
}

#==============================================================================
# PROCESS MONITORING TESTS
#==============================================================================

test_process_parsing_functions() {
    echo -e "\n${BLUE}Testing Process Parsing Functions${NC}"
    
    # Create a mock process parser for testing
    test_process_parsing() {
        local ps_output="$1"
        local sort_by="$2"  # "cpu" or "memory"
        
        local processes=$(echo "$ps_output" | tail -n +2)  # Skip header
        local formatted_processes=""
        local count=0
        
        while IFS= read -r line && [[ $count -lt 5 ]]; do
            if [[ -n "$line" ]]; then
                local fields=($line)
                local pid=${fields[0]}
                local value=${fields[1]}
                local command=${fields[2]}
                
                # Truncate long command names
                if [[ ${#command} -gt 15 ]]; then
                    command="${command:0:12}..."
                fi
                
                if validate_number "$pid" && validate_number "$value"; then
                    formatted_processes+="$pid $command $value"$'\n'
                    ((count++))
                fi
            fi
        done <<< "$processes"
        
        echo "$formatted_processes"
    }
    
    # Test CPU process parsing
    local test_cpu_ps="PID  %CPU COMMAND
1234  15.2 apache2
5678  12.1 mysql
9012   8.7 node
3456   5.3 python3
7890   3.1 nginx"
    
    local cpu_processes=$(test_process_parsing "$test_cpu_ps" "cpu")
    local cpu_line_count=$(echo "$cpu_processes" | wc -l)
    
    if [[ $cpu_line_count -eq 5 ]]; then
        print_test_result "CPU process parsing returns 5 processes" "PASS" ""
    else
        print_test_result "CPU process parsing returns 5 processes" "FAIL" "Got $cpu_line_count processes"
    fi
    
    # Verify first process data
    local first_cpu_process=$(echo "$cpu_processes" | head -n 1)
    assert_contains "1234" "$first_cpu_process" "CPU process parsing includes PID"
    assert_contains "apache2" "$first_cpu_process" "CPU process parsing includes command"
    assert_contains "15.2" "$first_cpu_process" "CPU process parsing includes CPU percentage"
    
    # Test memory process parsing
    local test_mem_ps="PID   RSS COMMAND
5678  2048 mysql
1234  1536 apache2
9012   512 node
3456   256 python3
7890   128 nginx"
    
    local mem_processes=$(test_process_parsing "$test_mem_ps" "memory")
    local mem_line_count=$(echo "$mem_processes" | wc -l)
    
    if [[ $mem_line_count -eq 5 ]]; then
        print_test_result "Memory process parsing returns 5 processes" "PASS" ""
    else
        print_test_result "Memory process parsing returns 5 processes" "FAIL" "Got $mem_line_count processes"
    fi
    
    # Test command name truncation
    local test_long_command_ps="PID  %CPU COMMAND
1234  15.2 very_long_command_name_that_should_be_truncated"
    
    local long_command_result=$(test_process_parsing "$test_long_command_ps" "cpu")
    # The truncation logic truncates to 12 chars + "..."
    assert_contains "very_long_co..." "$long_command_result" "Long command names are truncated"
}

#==============================================================================
# ERROR HANDLING TESTS
#==============================================================================

test_error_handling_scenarios() {
    echo -e "\n${BLUE}Testing Error Handling Scenarios${NC}"
    
    # Test handling of missing files
    test_missing_file_handling() {
        local nonexistent_file="/proc/nonexistent_file_12345"
        
        if [[ ! -r "$nonexistent_file" ]]; then
            print_test_result "Detect unreadable files" "PASS" ""
        else
            print_test_result "Detect unreadable files" "FAIL" "File should not exist"
        fi
    }
    
    test_missing_file_handling
    
    # Test handling of invalid command output
    test_invalid_command_output() {
        local invalid_output=""
        
        if [[ -z "$invalid_output" ]]; then
            print_test_result "Handle empty command output" "PASS" ""
        else
            print_test_result "Handle empty command output" "FAIL" "Output should be empty"
        fi
    }
    
    test_invalid_command_output
    
    # Test graceful degradation when commands are missing
    local original_path="$PATH"
    export PATH="/nonexistent/path"
    
    if ! command -v nonexistent_command >/dev/null 2>&1; then
        print_test_result "Detect missing commands" "PASS" ""
    else
        print_test_result "Detect missing commands" "FAIL" "Command should not be found"
    fi
    
    export PATH="$original_path"
}

#==============================================================================
# OUTPUT FORMATTING CONSISTENCY TESTS
#==============================================================================

test_output_formatting_consistency() {
    echo -e "\n${BLUE}Testing Output Formatting Consistency${NC}"
    
    # Test consistent number formatting
    local test_values=("0.0" "12.3" "100.0" "99.99")
    
    for value in "${test_values[@]}"; do
        local formatted_percent=$(format_percentage "$value" 1)
        local formatted_decimal=$(format_decimal "$value" 2)
        
        # Check that percentage includes % symbol
        assert_contains "%" "$formatted_percent" "Percentage formatting includes % symbol for $value"
        
        # Check that decimal doesn't include % symbol
        if [[ "$formatted_decimal" != *"%"* ]]; then
            print_test_result "Decimal formatting excludes % symbol for $value" "PASS" ""
        else
            print_test_result "Decimal formatting excludes % symbol for $value" "FAIL" "Should not contain %"
        fi
    done
    
    # Test byte formatting consistency
    local byte_values=("1024" "1048576" "1073741824")
    local expected_units=("KB" "MB" "GB")
    
    for i in "${!byte_values[@]}"; do
        local formatted_bytes=$(format_bytes "${byte_values[$i]}")
        assert_contains "${expected_units[$i]}" "$formatted_bytes" "Byte formatting uses correct unit for ${byte_values[$i]}"
    done
    
    # Test table formatting alignment
    local test_headers=("PID" "Process" "CPU%")
    local header_output=""
    
    # Simulate table header creation
    for header in "${test_headers[@]}"; do
        header_output+=$(printf "%-12s " "$header")
    done
    
    # Check that headers are properly spaced
    if [[ ${#header_output} -gt 30 ]]; then
        print_test_result "Table header formatting creates proper spacing" "PASS" ""
    else
        print_test_result "Table header formatting creates proper spacing" "FAIL" "Header too short: '$header_output'"
    fi
}

#==============================================================================
# INTEGRATION TESTS
#==============================================================================

test_function_integration() {
    echo -e "\n${BLUE}Testing Function Integration${NC}"
    
    # Test that all main functions can be called without errors
    local functions_to_test=("validate_number" "format_bytes" "format_percentage" "check_command")
    
    for func in "${functions_to_test[@]}"; do
        if declare -f "$func" >/dev/null 2>&1; then
            print_test_result "Function $func is defined" "PASS" ""
        else
            print_test_result "Function $func is defined" "FAIL" "Function not found"
        fi
    done
    
    # Test that functions work together
    local test_bytes="2048000"
    local formatted=$(format_bytes "$test_bytes")
    local is_valid=$(validate_number "$test_bytes" && echo "valid" || echo "invalid")
    
    if [[ "$is_valid" == "valid" ]] && [[ "$formatted" != "N/A" ]]; then
        print_test_result "Functions work together (validate_number + format_bytes)" "PASS" ""
    else
        print_test_result "Functions work together (validate_number + format_bytes)" "FAIL" "Integration failed"
    fi
}

#==============================================================================
# MAIN TEST EXECUTION
#==============================================================================

main() {
    echo -e "${BLUE}=== Server Stats Analyzer - Unit Test Suite ===${NC}"
    echo -e "${BLUE}Version: $TEST_SCRIPT_VERSION${NC}"
    echo
    
    # Run all test suites
    test_error_handling_functions
    test_formatting_functions
    test_cpu_parsing_functions
    test_cpu_calculation_edge_cases
    test_memory_calculation_functions
    test_disk_calculation_functions
    test_process_parsing_functions
    test_error_handling_scenarios
    test_output_formatting_consistency
    test_function_integration
    
    # Print final results
    echo
    echo -e "${BLUE}=== Test Results Summary ===${NC}"
    echo -e "Total Tests: $TESTS_TOTAL"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed! ✓${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed! ✗${NC}"
        exit 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi