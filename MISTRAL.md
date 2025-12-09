# Mistral AI Provider

This guide explains how to use Mistral AI as your zsh-ai provider.

## Setup

1. Get your Mistral API key from [console.mistral.ai](https://console.mistral.ai/)

2. Configure zsh-ai to use Mistral by adding these lines to your `~/.zshrc`:

```bash
export MISTRAL_API_KEY="your-api-key-here"
export ZSH_AI_PROVIDER="mistral"
```

3. (Optional) Customize the model and URL:

```bash
# Default: mistral-small-latest
export ZSH_AI_MISTRAL_MODEL="mistral-large-latest"

# Default: https://api.mistral.ai/v1/chat/completions
export ZSH_AI_MISTRAL_URL="https://api.mistral.ai/v1/chat/completions"
```

## Available Models

Mistral AI offers several models:

- **mistral-small-latest** (default) - Fast and cost-effective for simple tasks
- **mistral-medium-latest** - Balanced performance and cost
- **mistral-large-latest** - Most capable model for complex tasks
- **codestral-latest** - Optimized for code generation

## Usage

Once configured, use zsh-ai as usual:

```bash
# Method 1: Comment syntax (recommended)
$ # find all python files modified today
$ find . -name "*.py" -mtime 0

# Method 2: Direct command
$ zsh-ai "show disk usage sorted by size"
$ du -sh * | sort -h
```

## Features

Mistral AI provider in zsh-ai supports:

- ✅ Context-aware command generation
- ✅ Project type detection
- ✅ Git status awareness
- ✅ Fast response times
- ✅ Competitive pricing
- ✅ OpenAI-compatible API

## Troubleshooting

### "Failed to connect to Mistral API"
- Check your internet connection
- Verify your API key is correct
- Ensure the API endpoint is accessible

### "API Error: Invalid API key"
- Verify your `MISTRAL_API_KEY` is set correctly
- Check that the API key is still valid in your Mistral console
- Make sure there are no extra spaces in the key

### "Unable to parse response"
- Install `jq` for better reliability: `brew install jq`
- Check if the model name is correct
- Verify your API key has proper permissions

## Pricing

Mistral AI pricing (as of 2024):

- **mistral-small**: ~$0.10 per 1M input tokens
- **mistral-medium**: ~$2.70 per 1M input tokens  
- **mistral-large**: ~$8.00 per 1M input tokens

zsh-ai uses minimal tokens per request (typically <500 tokens), making it very cost-effective.

## Comparison with Other Providers

| Feature | Mistral | Claude | GPT-4 | Gemini | Ollama |
|---------|---------|--------|-------|--------|--------|
| Speed | ⚡⚡⚡ | ⚡⚡ | ⚡⚡ | ⚡⚡⚡ | ⚡⚡⚡⚡ |
| Cost | 💰 | 💰💰 | 💰💰💰 | 💰 | Free |
| Quality | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| Privacy | Cloud | Cloud | Cloud | Cloud | Local |

## Resources

- [Mistral AI Documentation](https://docs.mistral.ai/)
- [Mistral API Reference](https://docs.mistral.ai/api/)
- [Mistral Console](https://console.mistral.ai/)
- [Pricing Information](https://mistral.ai/technology/#pricing)

