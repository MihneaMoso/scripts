#!/usr/bin/env bash

set -x

# Run this on linux and bash pls
# Download the nvim/ directory contents from github
# make backup of the existing .config/nvim directory
# move nvim/* in .config/nvim/
OWNER=MihneaMoso
REPO=.config

download_folder() {
  local url="$1"
  local dest="$2"
  mkdir -p "$dest"

  # Get directory contents
  contents=$(curl -s "$url")

  # Process each item
  echo "$contents" | jq -c '.[]' | while read item; do
    name=$(echo "$item" | jq -r '.name')
    type=$(echo "$item" | jq -r '.type')
    download_url=$(echo "$item" | jq -r '.download_url')

    if [ "$type" = "file" ] && [ "$download_url" != "null" ]; then
      # Download file
      curl -L "$download_url" -o "$dest/$name"
    elif [ "$type" = "dir" ]; then
      # Recursively download subdirectory
      subdir_url=$(echo "$item" | jq -r '.url')
      download_folder "$subdir_url" "$dest/$name"
    fi
  done
}

NVIM_PATH=$HOME/.config/nvim
echo "Making backup of existing neovim config..."
mv $NVIM_PATH "$NVIM_PATH.bak"
mkdir -p $NVIM_PATH
cd $NVIM_PATH

download_folder "https://api.github.com/repos/$OWNER/$REPO/contents/nvim/" "."
