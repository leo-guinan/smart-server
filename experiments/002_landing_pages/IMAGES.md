# Landing Page Images

## Current Images (SVG)

All images are programmatically generated SVG files for optimal performance:

### 1. Lever Diagram (`/assets/lever-diagram.svg`)
**Used in:** Solution section  
**Purpose:** Visual metaphor for leverage - small effort creates massive time savings  
**Size:** 2KB

**Description:**
- Lever with fulcrum
- Small force (blue circle) on left
- Large clock (representing time) on right
- Shows mechanical advantage concept

### 2. Compound Savings Chart (`/assets/compound-savings.svg`)
**Used in:** Proof section (case studies variant)  
**Purpose:** Show time savings growing exponentially over months  
**Size:** 2.8KB

**Description:**
- Line graph with curved growth
- X-axis: Months (1, 3, 6, 9, 12)
- Y-axis: Hours saved
- Data points: 10h → 30h → 60h → 120h → 200h
- Shaded area under curve

### 3. Savings Curve (`/assets/savings-curve.svg`)
**Used in:** Proof section (compound savings variant)  
**Purpose:** Simplified exponential growth visualization  
**Size:** 1.6KB

**Description:**
- Clean exponential curve
- "Compounding Gains" annotation
- Grid background
- Shaded growth area

## Regenerating Images

```bash
cd /opt/smart/experiments/002_landing_pages
bash generate_images.sh
```

This creates/updates all SVG files in `public/assets/`.

## Adding New Images

### Option 1: Add to generate_images.sh

Edit `generate_images.sh` and add a new SVG:

```bash
cat > "${ASSETS_DIR}/my-new-image.svg" << 'EOF'
<svg viewBox="0 0 400 300" xmlns="http://www.w3.org/2000/svg">
  <!-- Your SVG content -->
</svg>
EOF
```

### Option 2: AI-Generated Images (Future)

For photo-realistic or complex illustrations:

#### Install Stable Diffusion (Local)
```bash
# Install Ollama if not already installed
curl -fsSL https://ollama.com/install.sh | sh

# Note: Ollama doesn't have great image models yet
# Alternative: Use Stability AI API or local Stable Diffusion
```

#### Use Stable Diffusion API
```bash
#!/usr/bin/env bash
# generate_ai_images.sh

API_KEY="your-stability-api-key"

curl -X POST "https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text_prompts": [
      {"text": "minimalist diagram of a lever lifting a clock, tech startup style, clean vector art"}
    ],
    "cfg_scale": 7,
    "height": 512,
    "width": 512,
    "samples": 1
  }' \
  -o lever-diagram.png
```

#### Use DALL-E (OpenAI)
```bash
#!/usr/bin/env bash

API_KEY="your-openai-api-key"

curl https://api.openai.com/v1/images/generations \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "dall-e-3",
    "prompt": "A minimalist tech illustration showing time savings compounding exponentially, professional business style, clean and modern",
    "n": 1,
    "size": "1024x1024"
  }'
```

## Image Optimization

For any PNG/JPG images added:

```bash
# Install optimization tools
apt-get install optipng jpegoptim

# Optimize
optipng -o7 image.png
jpegoptim --strip-all --max=85 image.jpg
```

For SVG:
```bash
# Install SVGO
npm install -g svgo

# Optimize
svgo image.svg -o image-optimized.svg
```

## Image Best Practices

1. **Use SVG when possible** - Scalable, small, perfect for diagrams
2. **Optimize file sizes** - Every KB matters on mobile
3. **Lazy load images** - Use `loading="lazy"` attribute
4. **Alt text** - Always include for accessibility
5. **Responsive** - Use `max-width: 100%` for mobile

## Current Image Usage

```html
<!-- Solution section -->
<img src="/assets/lever-diagram.svg" alt="Small lever lifting massive clock labeled TIME" />

<!-- Proof section (case studies) -->
<img src="/assets/compound-savings.svg" alt="Graph showing Time Saved compounding over months" />

<!-- Proof section (compound savings) -->
<img src="/assets/savings-curve.svg" alt="Exponential curve of time savings" />
```

## Performance Metrics

| Image | Format | Size | Load Time (3G) |
|-------|--------|------|----------------|
| lever-diagram | SVG | 2.0 KB | <100ms |
| compound-savings | SVG | 2.8 KB | <100ms |
| savings-curve | SVG | 1.6 KB | <100ms |
| **Total** | | **6.4 KB** | **<300ms** |

## Future Enhancements

### 1. Dynamic Image Generation
Generate images on-the-fly based on user data:
- Personalized savings charts
- Custom ROI calculations
- Client-specific examples

### 2. A/B Test Images
Test different visual styles:
- Minimal vs detailed
- Illustration vs photo
- Dark vs light theme

### 3. Animated SVGs
Add subtle animations:
- Lever moving
- Chart lines drawing
- Numbers counting up

### 4. Localization
Generate images for different languages:
- Translated labels
- Culture-specific visuals
- Regional color preferences

## Tools & Resources

### SVG Creation
- **Code**: Manual SVG writing (current approach)
- **Design**: Figma, Sketch, Adobe Illustrator
- **Online**: SVG-edit.org, Method Draw

### AI Image Generation
- **Stable Diffusion**: Local or API
- **DALL-E**: OpenAI API
- **Midjourney**: Discord bot
- **Leonardo.ai**: Web interface

### Optimization
- **SVGO**: SVG optimization
- **ImageOptim**: Mac app for all formats
- **TinyPNG**: Online PNG/JPG compression

## Contributing

To add new images:
1. Create or generate the image
2. Add to `generate_images.sh`
3. Test locally: `bash generate_images.sh`
4. Commit and push
5. Deploy: `git pull && bash generate_images.sh`

---

**Current status**: All required images generated ✅  
**Performance**: 6.4KB total, <300ms load time ✅  
**Accessibility**: All images have proper alt text ✅

