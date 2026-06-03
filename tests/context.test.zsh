#!/usr/bin/env zsh

# Load test helper
source "${0:A:h}/test_helper.zsh"

# Load the context module
source "$PLUGIN_DIR/lib/context.zsh"

# Test functions

# Project type detection tests
test_detects_nodejs_project() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    touch package.json
    local output=$(_zsh_ai_detect_project_type)
    assert_equals "$output" "node"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_detects_rust_project() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    touch Cargo.toml
    local output=$(_zsh_ai_detect_project_type)
    assert_equals "$output" "rust"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_detects_python_project_requirements() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    touch requirements.txt
    local output=$(_zsh_ai_detect_project_type)
    assert_equals "$output" "python"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_detects_python_project_setup() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    touch setup.py
    local output=$(_zsh_ai_detect_project_type)
    assert_equals "$output" "python"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_detects_python_project_pyproject() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    touch pyproject.toml
    local output=$(_zsh_ai_detect_project_type)
    assert_equals "$output" "python"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_detects_ruby_project() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    touch Gemfile
    local output=$(_zsh_ai_detect_project_type)
    assert_equals "$output" "ruby"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_detects_go_project() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    touch go.mod
    local output=$(_zsh_ai_detect_project_type)
    assert_equals "$output" "go"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_detects_php_project() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    touch composer.json
    local output=$(_zsh_ai_detect_project_type)
    assert_equals "$output" "php"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_detects_java_project_pom() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    touch pom.xml
    local output=$(_zsh_ai_detect_project_type)
    assert_equals "$output" "java"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_detects_java_project_gradle() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    touch build.gradle
    local output=$(_zsh_ai_detect_project_type)
    assert_equals "$output" "java"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_detects_docker_project_compose() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    touch docker-compose.yml
    local output=$(_zsh_ai_detect_project_type)
    assert_equals "$output" "docker"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_detects_docker_project_dockerfile() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    touch Dockerfile
    local output=$(_zsh_ai_detect_project_type)
    assert_equals "$output" "docker"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_returns_unknown_for_unrecognized_project() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    touch random.txt
    local output=$(_zsh_ai_detect_project_type)
    assert_equals "$output" "unknown"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

# Git context tests
test_returns_empty_for_non_git_directory() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    local output=$(_zsh_ai_get_git_context)
    assert_equals "$output" ""
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_gets_git_context_for_repository() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    git init >/dev/null 2>&1
    git checkout -b test-branch >/dev/null 2>&1
    local output=$(_zsh_ai_get_git_context)
    assert_contains "$output" "Git: branch=test-branch"
    assert_contains "$output" "status=clean"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_detects_dirty_git_status() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    git init >/dev/null 2>&1
    touch test.txt
    git add test.txt
    local output=$(_zsh_ai_get_git_context)
    assert_contains "$output" "status=dirty"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

# Directory context tests
test_shows_current_directory_in_context() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    local output=$(_zsh_ai_get_directory_context)
    assert_contains "$output" "Current directory: $TEST_DIR"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_lists_files_when_less_than_20() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    touch file1.txt file2.txt file3.txt
    local output=$(_zsh_ai_get_directory_context)
    assert_contains "$output" "Files: file1.txt, file2.txt, file3.txt"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_truncates_file_list_at_10_files() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    for i in {1..15}; do
        touch "file$i.txt"
    done
    local output=$(_zsh_ai_get_directory_context)
    assert_contains "$output" "Files:"
    assert_contains "$output" "... and 5 more"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_shows_file_count_for_many_files() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    for i in {1..25}; do
        touch "file$i.txt"
    done
    local output=$(_zsh_ai_get_directory_context)
    assert_contains "$output" "Files: 25 files in directory"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

# Context building tests
test_builds_complete_context() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    touch package.json
    git init >/dev/null 2>&1
    local output=$(_zsh_ai_build_context)
    assert_contains "$output" "Current directory:"
    assert_contains "$output" "Project type: node"
    assert_contains "$output" "Git:"
    assert_contains "$output" "OS:"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_builds_context_without_git() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    touch requirements.txt
    local output=$(_zsh_ai_build_context)
    assert_contains "$output" "Current directory:"
    assert_contains "$output" "Project type: python"
    assert_contains "$output" "OS:"
    assert_not_contains "$output" "Git:"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_builds_context_for_unknown_project() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    touch random.txt
    local output=$(_zsh_ai_build_context)
    assert_contains "$output" "Current directory:"
    assert_not_contains "$output" "Project type:"
    assert_contains "$output" "OS:"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

test_includes_os_information() {
    setup_test_env
    local TEST_DIR=$(create_test_dir)
    cd "$TEST_DIR"
    
    local output=$(_zsh_ai_build_context)
    local os_name=$(uname -s)
    assert_contains "$output" "OS: $os_name"
    
    cd - >/dev/null 2>&1
    cleanup_test_dir "$TEST_DIR"
    teardown_test_env
}

# Run tests
echo "Running context tests..."
run_test "Detects Node.js project" test_detects_nodejs_project
run_test "Detects Rust project" test_detects_rust_project
run_test "Detects Python project with requirements.txt" test_detects_python_project_requirements
run_test "Detects Python project with setup.py" test_detects_python_project_setup
run_test "Detects Python project with pyproject.toml" test_detects_python_project_pyproject
run_test "Detects Ruby project" test_detects_ruby_project
run_test "Detects Go project" test_detects_go_project
run_test "Detects PHP project" test_detects_php_project
run_test "Detects Java project with pom.xml" test_detects_java_project_pom
run_test "Detects Java project with build.gradle" test_detects_java_project_gradle
run_test "Detects Docker project with docker-compose.yml" test_detects_docker_project_compose
run_test "Detects Docker project with Dockerfile" test_detects_docker_project_dockerfile
run_test "Returns unknown for unrecognized project" test_returns_unknown_for_unrecognized_project
run_test "Returns empty string for non-git directory" test_returns_empty_for_non_git_directory
run_test "Gets git context for git repository" test_gets_git_context_for_repository
run_test "Detects dirty git status" test_detects_dirty_git_status
run_test "Shows current directory in context" test_shows_current_directory_in_context
run_test "Lists files when less than 20" test_lists_files_when_less_than_20
run_test "Truncates file list at 10 files" test_truncates_file_list_at_10_files
run_test "Shows file count for directories with many files" test_shows_file_count_for_many_files
run_test "Builds complete context" test_builds_complete_context
run_test "Builds context without git" test_builds_context_without_git
run_test "Builds context for unknown project" test_builds_context_for_unknown_project
run_test "Includes OS information" test_includes_os_information
finish_tests
