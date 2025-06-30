#!/usr/bin/env zsh

# Configuration and validation for zsh-ai

# Set default values for configuration
: ${ZSH_AI_PROVIDER:="anthropic"}  # Default to anthropic for backwards compatibility
: ${ZSH_AI_OLLAMA_MODEL:="llama3.2"}  # Popular fast model
: ${ZSH_AI_OLLAMA_URL:="http://localhost:11434"}  # Default Ollama URL

# Provider validation
_zsh_ai_validate_config() {
    local providers=()
    
    # Check which providers are configured
    if [[ -n "$ANTHROPIC_API_KEY" ]]; then
        providers+=("anthropic")
    fi
    
    if [[ -n "$GROQ_API_KEY" ]]; then
        providers+=("groq")
    fi
    
    if [[ -n "$GEMINI_API_KEY" ]]; then
        providers+=("gemini")
    fi
    
    if _zsh_ai_check_ollama; then
        providers+=("ollama")
    fi
    
    # debug
    # echo "zsh-ai: Available providers: ${(j:, :)providers}"
    # echo "zsh-ai: Current provider: $ZSH_AI_PROVIDER"
    
    # Log relevant configuration based on current provider
    case "$ZSH_AI_PROVIDER" in
        "anthropic")
            if [[ -z "$ANTHROPIC_API_KEY" ]]; then
                echo "zsh-ai: Error: ANTHROPIC_API_KEY not set"
                return 1
            fi
            ;;
        "groq")
            if [[ -z "$GROQ_API_KEY" ]]; then
                echo "zsh-ai: Error: GROQ_API_KEY not set"
                return 1
            fi
            ;;
        "gemini")
            if [[ -z "$GEMINI_API_KEY" ]]; then
                echo "zsh-ai: Error: GEMINI_API_KEY not set"
                return 1
            fi
            ;;
        "ollama")
            if ! _zsh_ai_check_ollama; then
                echo "zsh-ai: Error: Cannot connect to Ollama at $ZSH_AI_OLLAMA_URL"
                return 1
            fi
            ;;
        *)
            echo "zsh-ai: Error: Invalid provider '$ZSH_AI_PROVIDER'. Use 'anthropic', 'ollama', 'groq' or 'gemini'."
            return 1
            ;;
    esac

    return 0
}