#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CN_MIRRORS_CONFIG="${ROOT_DIR}/config/cn-mirrors.yml"

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: yq is required but not installed. Please install yq to continue."
    exit 1
fi

# Check if CN mirrors config exists
if [[ ! -f "$CN_MIRRORS_CONFIG" ]]; then
    echo "Error: CN mirrors configuration file not found at $CN_MIRRORS_CONFIG"
    exit 1
fi

# Function to get mirror URL from config
get_mirror_url() {
    local original_url="$1"
    local registry=""
    local image_path=""
    
    # Extract registry and image path
    if [[ "$original_url" =~ ^gcr\.io/(.+)$ ]]; then
        registry="gcr.io"
        image_path="${BASH_REMATCH[1]}"
    elif [[ "$original_url" =~ ^ghcr\.io/(.+)$ ]]; then
        registry="ghcr.io"
        image_path="${BASH_REMATCH[1]}"
    elif [[ "$original_url" =~ ^registry\.k8s\.io/(.+)$ ]]; then
        registry="registry.k8s.io"
        image_path="${BASH_REMATCH[1]}"
    elif [[ "$original_url" =~ ^quay\.io/(.+)$ ]]; then
        registry="quay.io"
        image_path="${BASH_REMATCH[1]}"
    else
        echo "$original_url"
        return
    fi
    
    # Get mirror registry from config
    local mirror_registry=$(yq eval ".mirrors.\"$registry\"" "$CN_MIRRORS_CONFIG")
    
    if [[ "$mirror_registry" == "null" ]]; then
        echo "$original_url"
        return
    fi
    
    echo "${mirror_registry}/${image_path}"
}

# Function to process YAML files
process_yaml_files() {
    local directory="$1"
    
    find "$directory" -name "*.yaml" -o -name "*.yml" | while read -r file; do
        echo "Processing $file..."
        
        # Create temporary file
        local temp_file=$(mktemp)
        
        # Process the file
        yq eval '
            (.. | select(type == "string" and (test("^gcr\\.io/") or test("^ghcr\\.io/") or test("^registry\\.k8s\\.io/") or test("^quay\\.io/")))) |= 
            (
                . as $url |
                if test("^gcr\\.io/") then
                    ($url | capture("^gcr\\.io/(?<path>.+)$") | "'"$(yq eval '.mirrors."gcr.io"' "$CN_MIRRORS_CONFIG")"'/" + .path)
                elif test("^ghcr\\.io/") then
                    ($url | capture("^ghcr\\.io/(?<path>.+)$") | "'"$(yq eval '.mirrors."ghcr.io"' "$CN_MIRRORS_CONFIG")"'/" + .path)
                elif test("^registry\\.k8s\\.io/") then
                    ($url | capture("^registry\\.k8s\\.io/(?<path>.+)$") | "'"$(yq eval '.mirrors."registry.k8s.io"' "$CN_MIRRORS_CONFIG")"'/" + .path)
                elif test("^quay\\.io/") then
                    ($url | capture("^quay\\.io/(?<path>.+)$") | "'"$(yq eval '.mirrors."quay.io"' "$CN_MIRRORS_CONFIG")"'/" + .path)
                else
                    $url
                end
            )
        ' "$file" > "$temp_file"
        
        # Replace original file if changes were made
        if ! cmp -s "$file" "$temp_file"; then
            mv "$temp_file" "$file"
            echo "Updated $file"
        else
            rm "$temp_file"
        fi
    done
}

# Function to process Dockerfile
process_dockerfile() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        return
    fi
    
    echo "Processing $file..."
    
    # Create temporary file
    local temp_file=$(mktemp)
    
    # Process FROM statements in Dockerfile
    while IFS= read -r line; do
        if [[ "$line" =~ ^FROM[[:space:]]+(.*) ]]; then
            local image="${BASH_REMATCH[1]}"
            local mirror_image=$(get_mirror_url "$image")
            if [[ "$mirror_image" != "$image" ]]; then
                echo "FROM $mirror_image"
            else
                echo "$line"
            fi
        else
            echo "$line"
        fi
    done < "$file" > "$temp_file"
    
    # Replace original file if changes were made
    if ! cmp -s "$file" "$temp_file"; then
        mv "$temp_file" "$file"
        echo "Updated $file"
    else
        rm "$temp_file"
    fi
}

# Function to process docker-compose files
process_docker_compose() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        return
    fi
    
    echo "Processing $file..."
    
    # Create temporary file
    local temp_file=$(mktemp)
    
    # Process image references in docker-compose files
    yq eval '
        (.. | select(key == "image" and type == "string" and (test("^gcr\\.io/") or test("^ghcr\\.io/") or test("^registry\\.k8s\\.io/") or test("^quay\\.io/")))) |= 
        (
            . as $url |
            if test("^gcr\\.io/") then
                ($url | capture("^gcr\\.io/(?<path>.+)$") | "'"$(yq eval '.mirrors."gcr.io"' "$CN_MIRRORS_CONFIG")"'/" + .path)
            elif test("^ghcr\\.io/") then
                ($url | capture("^ghcr\\.io/(?<path>.+)$") | "'"$(yq eval '.mirrors."ghcr.io"' "$CN_MIRRORS_CONFIG")"'/" + .path)
            elif test("^registry\\.k8s\\.io/") then
                ($url | capture("^registry\\.k8s\\.io/(?<path>.+)$") | "'"$(yq eval '.mirrors."registry.k8s.io"' "$CN_MIRRORS_CONFIG")"'/" + .path)
            elif test("^quay\\.io/") then
                ($url | capture("^quay\\.io/(?<path>.+)$") | "'"$(yq eval '.mirrors."quay.io"' "$CN_MIRRORS_CONFIG")"'/" + .path)
            else
                $url
            end
        )
    ' "$file" > "$temp_file"
    
    # Replace original file if changes were made
    if ! cmp -s "$file" "$temp_file"; then
        mv "$temp_file" "$file"
        echo "Updated $file"
    else
        rm "$temp_file"
    fi
}

# Main processing
main() {
    echo "Starting image localization process..."
    
    # Process Kubernetes manifests
    if [[ -d "$ROOT_DIR/deploy" ]]; then
        echo "Processing Kubernetes manifests in deploy/"
        process_yaml_files "$ROOT_DIR/deploy"
    fi
    
    # Process Helm charts
    if [[ -d "$ROOT_DIR/charts" ]]; then
        echo "Processing Helm charts in charts/"
        process_yaml_files "$ROOT_DIR/charts"
    fi
    
    # Process example configurations
    if [[ -d "$ROOT_DIR/examples" ]]; then
        echo "Processing examples in examples/"
        process_yaml_files "$ROOT_DIR/examples"
    fi
    
    # Process config directory
    if [[ -d "$ROOT_DIR/config" ]]; then
        echo "Processing config files in config/"
        process_yaml_files "$ROOT_DIR/config"
    fi
    
    # Process Dockerfiles
    find "$ROOT_DIR" -name "Dockerfile*" | while read -r dockerfile; do
        process_dockerfile "$dockerfile"
    done
    
    # Process docker-compose files
    find "$ROOT_DIR" -name "docker-compose*.yml" -o -name "docker-compose*.yaml" | while read -r compose_file; do
        process_docker_compose "$compose_file"
    done
    
    echo "Image localization completed successfully!"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Replace gcr.io/ghcr.io/registry.k8s.io/quay.io images with CN mirrors"
            echo ""
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo ""
            echo "This script will process all YAML files, Dockerfiles, and docker-compose"
            echo "files in the project and replace foreign registry images with CN mirrors"
            echo "based on the mapping defined in config/cn-mirrors.yml"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main