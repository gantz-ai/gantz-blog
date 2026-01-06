#!/bin/bash

# Convert devto-*.md files to Hugo format with front matter

SOURCE_DIR="/Users/huynhphuchuy/Desktop/Gantz/blog-posts"
DEST_DIR="/Users/huynhphuchuy/Desktop/Gantz/gantz-blog/content/posts"

# Counter for date offset (so posts have different dates)
counter=0

for file in "$SOURCE_DIR"/devto-*.md; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        # Remove 'devto-' prefix
        newname="${filename#devto-}"

        # Extract title from first line (assuming # Title format)
        title=$(head -1 "$file" | sed 's/^# //')

        # Calculate date (going backwards from today)
        date=$(date -v-${counter}d +%Y-%m-%d)

        # Create new file with front matter
        cat > "$DEST_DIR/$newname" << EOF
+++
title = '$title'
date = $date
draft = false
tags = ['agents', 'ai', 'mcp']
+++

EOF

        # Append original content (skip first line which is the title)
        tail -n +2 "$file" >> "$DEST_DIR/$newname"

        echo "Converted: $filename -> $newname"
        ((counter++))
    fi
done

echo ""
echo "Converted $counter posts to Hugo format"
