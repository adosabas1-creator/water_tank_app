#!/data/data/com.termux/files/usr/bin/bash

################################################################################
# G4F Launcher for Termux (FAST VERSION)
# By jokukiller
# Version: 1.0.1-fast
# 
# This version prioritizes SPEED over features:
# - Minimal compilation
# - GUI mode only (no API server)
# - ~5-7 minute install time
# - Tested and working!
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[G4F-FAST]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }

################################################################################
# Fast Installation
################################################################################

clear
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ${CYAN}G4F Fast Installer for Termux${NC}"
echo "  ${GREEN}By jokukiller${NC}"
echo "  ${YELLOW}Speed-optimized: ~5-7 minute install${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if we're actually in Termux
if [[ -z "$TERMUX_VERSION" ]]; then
    error "This script is designed for Termux only!"
    info "For regular Linux, use: g4f_launcher.sh"
    exit 1
fi

success "Detected Termux $TERMUX_VERSION"
echo ""

################################################################################
# Step 1: Update & Install Python
################################################################################

log "=== STEP 1/5: PYTHON SETUP ==="

if command -v python &> /dev/null; then
    success "Python already installed: $(python --version)"
else
    log "Updating package lists..."
    pkg update -y || warn "Package update failed, continuing..."
    
    log "Installing Python..."
    pkg install python -y || { error "Python installation failed"; exit 1; }
    success "Python installed: $(python --version)"
fi
echo ""

################################################################################
# Step 2: Upgrade pip
################################################################################

log "=== STEP 2/5: PIP SETUP ==="

if python -m pip --version &> /dev/null; then
    success "pip already available"
    log "Upgrading pip..."
    python -m pip install --upgrade pip --quiet 2>/dev/null || warn "pip upgrade had issues"
else
    log "Installing pip..."
    python -m ensurepip --upgrade || {
        error "pip installation failed"
        exit 1
    }
fi
success "pip ready: $(python -m pip --version)"
echo ""

################################################################################
# Step 3: Install Critical Dependencies (GUI Mode)
################################################################################

log "=== STEP 3/5: DEPENDENCIES ==="
info "Installing minimal dependencies for GUI mode..."
echo ""

# Install the bare minimum that actually works
log "Installing flask (web GUI framework)..."
python -m pip install flask --quiet || warn "flask install had issues"

log "Installing aiohttp (async HTTP client)..."
python -m pip install aiohttp --quiet || warn "aiohttp install had issues"

log "Installing requests (HTTP library)..."
python -m pip install requests --quiet || warn "requests install had issues"

success "Core dependencies installed"
echo ""

################################################################################
# Step 4: Install Base G4F
################################################################################

log "=== STEP 4/5: G4F INSTALLATION ==="

if python -c "import g4f" 2>/dev/null; then
    success "g4f already installed!"
    log "Checking for updates..."
    python -m pip install -U g4f --quiet 2>/dev/null || warn "Update check skipped"
    success "g4f is ready!"
else
    info "Installing g4f (base version)..."
    warn "This may take 5-7 minutes on Termux"
    echo ""
    
    # Install g4f without extras, preferring binary wheels
    if python -m pip install g4f --prefer-binary 2>&1 | grep -E "(Downloading|Installing|Successfully installed)"; then
        echo ""
        success "g4f installed successfully!"
    else
        warn "Standard install had issues, trying alternative method..."
        
        # Try without build isolation
        python -m pip install --no-build-isolation g4f || {
            error "g4f installation failed completely"
            error "You may need to use the full installer: g4f_launcher.sh"
            exit 1
        }
        
        success "g4f installed (alternative method)"
    fi
fi
echo ""

################################################################################
# Step 5: Optional FFmpeg
################################################################################

log "=== STEP 5/5: OPTIONAL COMPONENTS ==="

if command -v ffmpeg &> /dev/null; then
    success "ffmpeg already installed"
else
    info "ffmpeg is optional (enables audio processing)"
    read -p "Install ffmpeg? (~20MB) [y/N]: " install_ff
    
    if [[ "$install_ff" =~ ^[Yy]$ ]]; then
        log "Installing ffmpeg..."
        pkg install ffmpeg -y && success "ffmpeg installed" || warn "ffmpeg install failed (optional)"
    else
        info "Skipping ffmpeg (optional)"
    fi
fi
echo ""

################################################################################
# Create Quick Launcher
################################################################################

log "Creating launcher shortcut..."

cat > ~/g4f-start << 'EOF'
#!/bin/bash
clear
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 Starting G4F Server (GUI Mode)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📱 Open in your browser:"
echo "   http://localhost:8080/chat/"
echo ""
echo "🌐 Or from another device on same network:"
echo "   http://$(ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}'):8080/chat/"
echo ""
echo "Press CTRL+C to stop"
echo ""
python -m g4f.cli gui --port 8080
EOF

chmod +x ~/g4f-start

success "Launcher created: ~/g4f-start"
echo ""

################################################################################
# Done!
################################################################################

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
success "FAST INSTALLATION COMPLETE! 🎉"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
info "✅ What got installed:"
echo "  • Python $(python --version 2>&1 | awk '{print $2}')"
echo "  • pip"
echo "  • g4f (base version)"
echo "  • flask, aiohttp, requests"
if [[ "$install_ff" =~ ^[Yy]$ ]]; then
    echo "  • ffmpeg"
fi
echo ""
warn "Note: This is GUI mode only (no API server)"
info "For full features with API, use: g4f_launcher.sh"
echo ""

# Installation stats
INSTALL_END=$(date +%s)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

info "📝 Quick Start Guide:"
echo ""
echo "  Start g4f:"
echo "    ${CYAN}~/g4f-start${NC}"
echo ""
echo "  Or manually:"
echo "    ${CYAN}python -m g4f.cli gui --port 8080${NC}"
echo ""
echo "  Stop server:"
echo "    ${CYAN}Press CTRL+C${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Start g4f server now? [Y/n]: " start_now

if [[ ! "$start_now" =~ ^[Nn]$ ]]; then
    echo ""
    log "Starting server in 2 seconds..."
    sleep 2
    ~/g4f-start
else
    echo ""
    success "Installation complete!"
    info "Run ${CYAN}~/g4f-start${NC} when you're ready!"
    echo ""
fi