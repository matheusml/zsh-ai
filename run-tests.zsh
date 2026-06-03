#!/usr/bin/env zsh

# Test runner for zsh-ai
# Runs all test files and reports results

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
FAILED_FILES=()

# Run test file and capture results
run_test_file() {
    local test_file="$1"
    echo -e "${YELLOW}Running ${test_file}...${NC}"
    
    # Run test and capture output
    local output
    local exit_code
    
    output=$(zsh "$test_file" 2>&1)
    exit_code=$?
    
    # Display output
    echo "$output"
    
    # Count test results from output
    local passed=$(echo "$output" | grep -c "✓")
    local failed=$(echo "$output" | grep -c "✗")
    
    # Update totals
    if [[ $passed -gt 0 || $failed -gt 0 ]]; then
        TOTAL_TESTS=$((TOTAL_TESTS + passed + failed))
        TOTAL_PASSED=$((TOTAL_PASSED + passed))
        TOTAL_FAILED=$((TOTAL_FAILED + failed))
    fi
    
    # Track failed files
    if [[ $exit_code -ne 0 || $failed -gt 0 ]]; then
        FAILED_FILES+=("$test_file")
    fi
    
    echo ""
}

# Main function
main() {
    local test_dir="${1:-tests}"
    
    echo -e "${BLUE}Running zsh-ai tests...${NC}"
    echo ""
    
    # Find all test files
    local test_files=($test_dir/**/*.test.zsh(N))
    
    if [[ ${#test_files} -eq 0 ]]; then
        echo -e "${YELLOW}No test files found in $test_dir${NC}"
        exit 1
    fi
    
    # Run each test file
    for test_file in $test_files; do
        run_test_file "$test_file"
    done
    
    # Summary
    echo "================================"
    echo -e "${BLUE}Test Summary:${NC}"
    echo -e "  Total Tests: $TOTAL_TESTS"
    echo -e "  ${GREEN}Passed: $TOTAL_PASSED${NC}"
    echo -e "  ${RED}Failed: $TOTAL_FAILED${NC}"
    
    if [[ ${#FAILED_FILES} -gt 0 ]]; then
        echo -e "\n${RED}Failed test files:${NC}"
        for file in $FAILED_FILES; do
            echo "  - $file"
        done
    fi
    echo "================================"
    
    # Exit based on results
    if [[ $TOTAL_FAILED -gt 0 || ${#FAILED_FILES} -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run if executed directly
if [[ "${ZSH_EVAL_CONTEXT}" == "toplevel" ]]; then
    main "$@"
fi
