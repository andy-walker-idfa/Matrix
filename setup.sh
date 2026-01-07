#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "═══════════════════════════════════════════════════════"
echo "  Configuration Generator"
echo "═══════════════════════════════════════════════════════"
echo

# Function to extract variables from template files
extract_template_vars() {
    local template_file=$1
    if [ -f "$template_file" ]; then
        # Extract ${VAR_NAME} patterns and return unique sorted list
        grep -oE '\$\{[A-Z_]+\}' "$template_file" | sed 's/\${\(.*\)}/\1/' | sort -u
    fi
}

# Function to check if variable exists in .env
check_env_var() {
    local var_name=$1
    if [ -f ".env" ]; then
        grep -q "^${var_name}=" .env 2>/dev/null
        return $?
    fi
    return 1
}

# Function to get value from .env
get_env_var() {
    local var_name=$1
    if [ -f ".env" ]; then
        grep "^${var_name}=" .env 2>/dev/null | cut -d'=' -f2-
    fi
}

# Function to add or update variable in .env
add_or_update_env() {
    local var_name=$1
    local var_value=$2
    
    if check_env_var "$var_name"; then
        # Variable exists, update it
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^${var_name}=.*|${var_name}=${var_value}|" .env
        else
            sed -i "s|^${var_name}=.*|${var_name}=${var_value}|" .env
        fi
    else
        # Variable doesn't exist, append it
        echo "${var_name}=${var_value}" >> .env
    fi
}

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "Creating new .env file..."
    touch .env
    NEW_ENV=true
else
    echo "Found existing .env file"
    NEW_ENV=false
fi

echo
echo "Scanning template files for required variables..."
echo

# Collect all templates to process
declare -A TEMPLATES
TEMPLATES["element-web/config.json"]="element-web/config.json.template"
TEMPLATES["element-call/config.json"]="element-call/config.json.template"

# Collect all unique variables from all templates
ALL_VARS=()
for template in "${TEMPLATES[@]}"; do
    if [ -f "$template" ]; then
        while IFS= read -r var; do
            # Add to array if not already present
            if [[ ! " ${ALL_VARS[@]} " =~ " ${var} " ]]; then
                ALL_VARS+=("$var")
            fi
        done < <(extract_template_vars "$template")
    fi
done

# Sort variables
IFS=$'\n' ALL_VARS=($(sort <<<"${ALL_VARS[*]}"))
unset IFS

if [ ${#ALL_VARS[@]} -eq 0 ]; then
    echo "No variables found in templates!"
    exit 1
fi

echo "Found variables: ${ALL_VARS[*]}"
echo

# Process each variable
for var_name in "${ALL_VARS[@]}"; do
    if check_env_var "$var_name"; then
        existing_value=$(get_env_var "$var_name")
        echo "✓ $var_name = $existing_value"
        read -p "  Keep this value? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            read -p "  Enter new value for $var_name: " new_value
            if [ -n "$new_value" ]; then
                add_or_update_env "$var_name" "$new_value"
            fi
        fi
    else
        echo "✗ $var_name is not set"
        read -p "  Enter value for $var_name: " new_value
        if [ -n "$new_value" ]; then
            add_or_update_env "$var_name" "$new_value"
        else
            echo "  ⚠ Warning: $var_name left empty"
        fi
    fi
done

# Load all variables from .env
echo
echo "Loading environment variables..."
set -a
source .env
set +a

echo
echo "═══════════════════════════════════════════════════════"
echo "Generating configuration files..."
echo "═══════════════════════════════════════════════════════"

# Generate configs from templates
for output in "${!TEMPLATES[@]}"; do
    template="${TEMPLATES[$output]}"
    if [ -f "$template" ]; then
        envsubst < "$template" > "$output"
        echo "✓ Generated $output"
    else
        echo "⚠ Template not found: $template"
    fi
done

echo
echo "═══════════════════════════════════════════════════════"
echo "✅ Setup complete!"
echo "═══════════════════════════════════════════════════════"
echo
echo "Variables configured:"
for var_name in "${ALL_VARS[@]}"; do
    value=$(get_env_var "$var_name")
    echo "  $var_name = $value"
done
echo
if [ "$NEW_ENV" = true ]; then
    echo "Next steps:"
    echo "1. Review .env file"
    echo "2. Generate Synapse signing key if needed"
    echo "3. Start containers: docker-compose up -d"
else
    echo "Configuration updated."
    echo "Restart containers: docker-compose restart"
fi
echo
