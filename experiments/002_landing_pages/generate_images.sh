#!/usr/bin/env bash
# Generate images for landing page
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="${SCRIPT_DIR}/public/assets"

mkdir -p "$ASSETS_DIR"

echo "Generating landing page images..."

# 1. Lever diagram (for solution section)
cat > "${ASSETS_DIR}/lever-diagram.svg" << 'EOF'
<svg viewBox="0 0 400 300" xmlns="http://www.w3.org/2000/svg">
  <!-- Background -->
  <rect width="400" height="300" fill="#f9fafb"/>
  
  <!-- Ground -->
  <line x1="50" y1="220" x2="350" y2="220" stroke="#9ca3af" stroke-width="3"/>
  
  <!-- Fulcrum (triangle) -->
  <path d="M 120 220 L 140 180 L 100 220 Z" fill="#6366f1" stroke="#4f46e5" stroke-width="2"/>
  
  <!-- Lever (plank) -->
  <rect x="90" y="170" width="260" height="15" fill="#8b5cf6" stroke="#7c3aed" stroke-width="2" rx="3"/>
  
  <!-- Small effort (person/force on left) -->
  <circle cx="95" cy="150" r="15" fill="#3b82f6" stroke="#2563eb" stroke-width="2"/>
  <line x1="95" y1="165" x2="95" y2="175" stroke="#2563eb" stroke-width="3"/>
  
  <!-- Large load (clock on right) -->
  <g transform="translate(320, 100)">
    <!-- Clock circle -->
    <circle cx="0" cy="0" r="35" fill="#fbbf24" stroke="#f59e0b" stroke-width="3"/>
    <!-- Clock hands -->
    <line x1="0" y1="0" x2="0" y2="-20" stroke="#78350f" stroke-width="3" stroke-linecap="round"/>
    <line x1="0" y1="0" x2="15" y2="0" stroke="#78350f" stroke-width="2" stroke-linecap="round"/>
    <circle cx="0" cy="0" r="3" fill="#78350f"/>
  </g>
  
  <!-- Labels -->
  <text x="95" y="250" text-anchor="middle" font-family="system-ui" font-size="14" fill="#374151" font-weight="600">Small Effort</text>
  <text x="320" y="250" text-anchor="middle" font-family="system-ui" font-size="14" fill="#374151" font-weight="600">Massive Time Saved</text>
  
  <!-- Arrow showing leverage -->
  <path d="M 95 195 L 95 205" stroke="#ef4444" stroke-width="2" marker-end="url(#arrowdown)"/>
  <path d="M 320 145 L 320 155" stroke="#22c55e" stroke-width="2" marker-end="url(#arrowup)"/>
  
  <defs>
    <marker id="arrowdown" markerWidth="10" markerHeight="10" refX="5" refY="5" orient="auto">
      <polygon points="5,8 2,2 8,2" fill="#ef4444"/>
    </marker>
    <marker id="arrowup" markerWidth="10" markerHeight="10" refX="5" refY="5" orient="auto">
      <polygon points="5,2 2,8 8,8" fill="#22c55e"/>
    </marker>
  </defs>
</svg>
EOF

# 2. Compound savings chart
cat > "${ASSETS_DIR}/compound-savings.svg" << 'EOF'
<svg viewBox="0 0 500 300" xmlns="http://www.w3.org/2000/svg">
  <!-- Background -->
  <rect width="500" height="300" fill="#ffffff"/>
  
  <!-- Title -->
  <text x="250" y="30" text-anchor="middle" font-family="system-ui" font-size="18" fill="#1f2937" font-weight="700">Time Savings Compound Over Time</text>
  
  <!-- Axes -->
  <line x1="50" y1="250" x2="450" y2="250" stroke="#9ca3af" stroke-width="2"/>
  <line x1="50" y1="50" x2="50" y2="250" stroke="#9ca3af" stroke-width="2"/>
  
  <!-- Y-axis label -->
  <text x="20" y="150" text-anchor="middle" font-family="system-ui" font-size="12" fill="#6b7280" transform="rotate(-90 20 150)">Hours Saved</text>
  
  <!-- X-axis label -->
  <text x="250" y="280" text-anchor="middle" font-family="system-ui" font-size="12" fill="#6b7280">Months</text>
  
  <!-- Month labels -->
  <text x="100" y="268" text-anchor="middle" font-family="system-ui" font-size="11" fill="#6b7280">1</text>
  <text x="180" y="268" text-anchor="middle" font-family="system-ui" font-size="11" fill="#6b7280">3</text>
  <text x="260" y="268" text-anchor="middle" font-family="system-ui" font-size="11" fill="#6b7280">6</text>
  <text x="340" y="268" text-anchor="middle" font-family="system-ui" font-size="11" fill="#6b7280">9</text>
  <text x="420" y="268" text-anchor="middle" font-family="system-ui" font-size="11" fill="#6b7280">12</text>
  
  <!-- Compound growth curve -->
  <path d="M 50 240 Q 150 220, 200 180 T 350 100 T 450 60" 
        fill="none" 
        stroke="#8b5cf6" 
        stroke-width="4" 
        stroke-linecap="round"/>
  
  <!-- Area under curve -->
  <path d="M 50 240 Q 150 220, 200 180 T 350 100 T 450 60 L 450 250 L 50 250 Z" 
        fill="#8b5cf6" 
        fill-opacity="0.1"/>
  
  <!-- Data points -->
  <circle cx="100" cy="230" r="6" fill="#8b5cf6" stroke="#ffffff" stroke-width="2"/>
  <circle cx="180" cy="210" r="6" fill="#8b5cf6" stroke="#ffffff" stroke-width="2"/>
  <circle cx="260" cy="170" r="6" fill="#8b5cf6" stroke="#ffffff" stroke-width="2"/>
  <circle cx="340" cy="110" r="6" fill="#8b5cf6" stroke="#ffffff" stroke-width="2"/>
  <circle cx="420" cy="70" r="6" fill="#8b5cf6" stroke="#ffffff" stroke-width="2"/>
  
  <!-- Value labels -->
  <text x="100" y="220" text-anchor="middle" font-family="system-ui" font-size="10" fill="#7c3aed" font-weight="600">10h</text>
  <text x="180" y="200" text-anchor="middle" font-family="system-ui" font-size="10" fill="#7c3aed" font-weight="600">30h</text>
  <text x="260" y="160" text-anchor="middle" font-family="system-ui" font-size="10" fill="#7c3aed" font-weight="600">60h</text>
  <text x="340" y="100" text-anchor="middle" font-family="system-ui" font-size="10" fill="#7c3aed" font-weight="600">120h</text>
  <text x="420" y="60" text-anchor="middle" font-family="system-ui" font-size="10" fill="#7c3aed" font-weight="600">200h</text>
</svg>
EOF

# 3. Savings curve (simplified version)
cat > "${ASSETS_DIR}/savings-curve.svg" << 'EOF'
<svg viewBox="0 0 400 250" xmlns="http://www.w3.org/2000/svg">
  <!-- Background -->
  <rect width="400" height="250" fill="#f9fafb"/>
  
  <!-- Grid lines -->
  <line x1="40" y1="200" x2="360" y2="200" stroke="#e5e7eb" stroke-width="1"/>
  <line x1="40" y1="150" x2="360" y2="150" stroke="#e5e7eb" stroke-width="1"/>
  <line x1="40" y1="100" x2="360" y2="100" stroke="#e5e7eb" stroke-width="1"/>
  <line x1="40" y1="50" x2="360" y2="50" stroke="#e5e7eb" stroke-width="1"/>
  
  <!-- Axes -->
  <line x1="40" y1="30" x2="40" y2="210" stroke="#6b7280" stroke-width="2"/>
  <line x1="40" y1="210" x2="370" y2="210" stroke="#6b7280" stroke-width="2"/>
  
  <!-- Exponential curve -->
  <path d="M 40 200 L 80 190 L 120 175 L 160 150 L 200 115 L 240 75 L 280 45 L 320 30 L 360 25" 
        fill="none" 
        stroke="#10b981" 
        stroke-width="4" 
        stroke-linecap="round"/>
  
  <!-- Shaded area -->
  <path d="M 40 200 L 80 190 L 120 175 L 160 150 L 200 115 L 240 75 L 280 45 L 320 30 L 360 25 L 360 210 L 40 210 Z" 
        fill="#10b981" 
        fill-opacity="0.15"/>
  
  <!-- Labels -->
  <text x="200" y="235" text-anchor="middle" font-family="system-ui" font-size="12" fill="#374151" font-weight="600">Time →</text>
  <text x="15" y="120" text-anchor="middle" font-family="system-ui" font-size="12" fill="#374151" font-weight="600" transform="rotate(-90 15 120)">Value</text>
  
  <!-- Annotation -->
  <text x="280" y="60" font-family="system-ui" font-size="14" fill="#059669" font-weight="700">Compounding</text>
  <text x="280" y="78" font-family="system-ui" font-size="14" fill="#059669" font-weight="700">Gains</text>
</svg>
EOF

echo "✓ Generated lever-diagram.svg"
echo "✓ Generated compound-savings.svg"
echo "✓ Generated savings-curve.svg"
echo ""
echo "Images generated in: ${ASSETS_DIR}"

