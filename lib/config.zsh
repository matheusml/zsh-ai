#!/usr/bin/env zsh

# Configuration and validation for zsh-ai

# Set default values for configuration
: ${ZSH_AI_PROVIDER:="anthropic"}  # Default to anthropic for backwards compatibility
: ${ZSH_AI_OLLAMA_MODEL:="llama3.2"}  # Popular fast model
: ${ZSH_AI_OLLAMA_URL:="http://localhost:11434"}  # Default Ollama URL
: ${ZSH_AI_GEMINI_MODEL:="gemini-2.5-flash"}  # Fast Gemini 2.5 model
: ${ZSH_AI_OPENAI_MODEL:="gpt-4o"}  # Default to GPT-4o
: ${ZSH_AI_OPENAI_URL:="https://api.openai.com/v1/chat/completions"}  # Default to OpenAI
: ${ZSH_AI_ANTHROPIC_MODEL:="claude-haiku-4-5"}  # Default Anthropic model
: ${ZSH_AI_GROK_MODEL:="grok-4-1-fast-non-reasoning"}  # Default Grok model
: ${ZSH_AI_GROK_URL:="https://api.x.ai/v1/chat/completions"}  # Default Grok URL
: ${ZSH_AI_MISTRAL_MODEL:="mistral-small-latest"}  # Default Mistral model
: ${ZSH_AI_MISTRAL_URL:="https://api.mistral.ai/v1/chat/completions"}  # Default Mistral URL

# Optional: Extend the system prompt with custom instructions
# ZSH_AI_PROMPT_EXTEND - Add custom instructions to the AI prompt without replacing the core prompt
# Example: export ZSH_AI_PROMPT_EXTEND="Always prefer ripgrep (rg) over grep. Use modern CLI tools when available."

# Provider validation
_zsh_ai_validate_config() {
    if [[ "$ZSH_AI_PROVIDER" != "anthropic" ]] && [[ "$ZSH_AI_PROVIDER" != "ollama" ]] && [[ "$ZSH_AI_PROVIDER" != "gemini" ]] && [[ "$ZSH_AI_PROVIDER" != "openai" ]] && [[ "$ZSH_AI_PROVIDER" != "grok" ]] && [[ "$ZSH_AI_PROVIDER" != "mistral" ]]; then
        echo "zsh-ai: Error: Invalid provider '$ZSH_AI_PROVIDER'. Use 'anthropic', 'ollama', 'gemini', 'openai', 'grok', or 'mistral'."
        return 1
    fi

    # Check requirements based on provider
    if [[ "$ZSH_AI_PROVIDER" == "anthropic" ]]; then
        if [[ -z "$ANTHROPIC_API_KEY" ]]; then
            echo "zsh-ai: Warning: ANTHROPIC_API_KEY not set. Plugin will not function."
            echo "zsh-ai: Set ANTHROPIC_API_KEY or use ZSH_AI_PROVIDER=ollama for local models."
            return 1
        fi
    elif [[ "$ZSH_AI_PROVIDER" == "gemini" ]]; then
        if [[ -z "$GEMINI_API_KEY" ]]; then
            echo "zsh-ai: Warning: GEMINI_API_KEY not set. Plugin will not function."
            echo "zsh-ai: Set GEMINI_API_KEY or use ZSH_AI_PROVIDER=ollama for local models."
            return 1
        fi
    elif [[ "$ZSH_AI_PROVIDER" == "openai" ]]; then
        if [[ -z "$OPENAI_API_KEY" ]]; then
            echo "zsh-ai: Warning: OPENAI_API_KEY not set. Plugin will not function."
            echo "zsh-ai: Set OPENAI_API_KEY or use ZSH_AI_PROVIDER=ollama for local models."
            return 1
        fi
    elif [[ "$ZSH_AI_PROVIDER" == "grok" ]]; then
        if [[ -z "$XAI_API_KEY" ]]; then
            echo "zsh-ai: Warning: XAI_API_KEY not set. Plugin will not function."
            echo "zsh-ai: Set XAI_API_KEY or use ZSH_AI_PROVIDER=ollama for local models."
            return 1
        fi
    elif [[ "$ZSH_AI_PROVIDER" == "mistral" ]]; then
        if [[ -z "$MISTRAL_API_KEY" ]]; then
            echo "zsh-ai: Warning: MISTRAL_API_KEY not set. Plugin will not function."
            echo "zsh-ai: Set MISTRAL_API_KEY or use ZSH_AI_PROVIDER=ollama for local models."
            return 1
        fi
    fi

    return 0
}