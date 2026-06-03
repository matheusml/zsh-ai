# Contributing to zsh-ai

Thanks for wanting to help! We love contributions from everyone. 💙

## Quick Start

1. Fork & clone the repo
2. Make your changes
3. Test your changes (see Testing section below)
4. Submit a pull request

That's it! We'll help you with the rest.

## Development

```bash
# Try out your changes
source zsh-ai.plugin.zsh

# The project uses GitHub Actions for testing
# Tests run automatically on PRs
```

## What We're Looking For

- 🐛 **Bug fixes** - Found something broken? Fix it!
- ✨ **New features** - Have an idea? Let's discuss it first (open an issue)
- 📝 **Documentation** - Help others understand the project
- 🧪 **Tests** - More tests = more confidence

## Code Style

Just follow the existing style you see in the codebase. When in doubt:
- Use meaningful names
- Keep functions small
- Add comments for tricky parts

## Testing

The project uses GitHub Actions for comprehensive testing. Tests will run automatically when you submit a PR.

To run tests locally:
```bash
# Run all tests
./run-tests.zsh

# Run tests from a specific directory
./run-tests.zsh tests/providers

# Run a single test file
zsh tests/config.test.zsh
```

### Writing Tests

Tests use a simple format:

```zsh
#!/usr/bin/env zsh

# Load test helper
source "${0:A:h}/test_helper.zsh"

# Test function
test_my_feature() {
    setup_test_env
    # Your test code here
    assert_equals "$actual" "$expected"
    teardown_test_env
}

# Run tests
echo "Running my tests..."
run_test "My feature works" test_my_feature
finish_tests
```

To manually verify your changes work:
```bash
# Source the plugin in your current shell
source zsh-ai.plugin.zsh

# Test the commands you modified
zsh-ai "your test query"
```

## Submitting PRs

Before submitting:
- [ ] Your changes work locally
- [ ] Code matches existing style
- [ ] Commit messages are clear

## Need Help?

- Open an issue with your question
- We're friendly and here to help!
- No question is too small

Thanks for contributing! 🎉
