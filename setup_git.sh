#!/bin/bash
# Zestify — Git Setup Script
# Run this once from the project root to initialize and push to GitHub

set -e

echo "🍋 Zestify Git Setup"
echo "===================="

# 1. Init local repo
git init
git add .
git commit -m "🍋 Initial commit — Zestify macOS file converter

- Menu bar resident app (LSUIElement)
- Radial wheel UI with SwiftUI pie-menu
- Shift+Drag → Format Wheel (JPEG, PNG, WebP, HEIC, MP4, MP3, PDF, GIF)
- Option+Shift+Drag → Tools Wheel (Compress, Strip Metadata, Resize, QR)
- GlobalEventMonitor with 300ms debounce (false positive protection)
- Drag pasteboard check before showing wheel
- ConversionEngine using AVFoundation + CoreImage
- Batch processing + macOS notifications
- MIT License"

echo ""
echo "✅ Local commit done!"
echo ""

# 2. Push to GitHub
echo "Now create a repo at: https://github.com/new"
echo "Name it: Zestify"
echo ""
read -p "Enter your GitHub username: " GH_USER

git remote add origin "https://github.com/$GH_USER/Zestify.git"
git branch -M main
git push -u origin main

echo ""
echo "🎉 Done! Zestify is now on GitHub:"
echo "   https://github.com/$GH_USER/Zestify"
