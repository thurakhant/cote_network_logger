#!/bin/bash

echo "🚀 Building coTe Network Dashboard (Pure Flutter Web)"
echo "================================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}📦 Building Flutter web dashboard...${NC}"

# Build the Flutter web dashboard
flutter build web --target lib/dashboard/dashboard_app.dart --output build/dashboard_web --release

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Flutter web dashboard built successfully!${NC}"
    echo ""
    echo -e "${YELLOW}🎯 How to use:${NC}"
    echo "1. Run your Flutter app with CoteNetworkLogger()"
    echo "2. Open browser to: http://localhost:3000"
    echo "3. See beautiful pure Flutter dashboard!"
    echo ""
    echo -e "${GREEN}✨ Features:${NC}"
    echo "   ✅ Pure Flutter Web (no HTML/CSS/JS)"
    echo "   ✅ Real-time tracking only (no storage)"
    echo "   ✅ Perfect scrolling in Flutter widgets"
    echo "   ✅ Material Design 3 UI"
    echo "   ✅ Auto-cleanup of old logs"
    echo ""
    echo -e "${BLUE}📁 Files created:${NC}"
    echo "   → build/dashboard_web/index.html"
    echo "   → build/dashboard_web/main.dart.js"
    echo "   → build/dashboard_web/flutter.js"
else
    echo -e "${RED}❌ Flutter web build failed!${NC}"
    echo "Make sure you have Flutter web enabled:"
    echo "flutter config --enable-web"
    exit 1
fi 