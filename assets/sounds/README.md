# Adhan Audio Files

## Simple Setup

Just drop any MP3 adhan files into this folder! The app will automatically detect and display them.

### Naming Your Files

Name your files anything you like (without spaces):
- `adhan1.mp3`, `adhan2.mp3`, `adhan3.mp3`
- `makkah.mp3`, `madina.mp3`, `egypt.mp3`
- `fajr_adhan.mp3`, `regular_adhan.mp3`
- `my_favorite_adhan.mp3`

The filename (without .mp3) will be shown in the app.

### Example:
```
assets/sounds/
├── adhan1.mp3          → Shows as "Adhan 1"
├── makkah.mp3          → Shows as "Makkah"
├── beautiful_adhan.mp3 → Shows as "Beautiful Adhan"
└── sheikh_ali.mp3      → Shows as "Sheikh Ali"
```

## Finding Adhan Audio Files

**Best Free Sources:**

1. **Internet Archive**: https://archive.org/details/adhan
2. **IslamicFinder**: https://www.islamicfinder.org/
3. **YouTube + Converter**: Search "Makkah Adhan", "Madina Adhan", etc.
   - Use ytmp3.cc or similar to convert
4. **Freesound.org**: https://freesound.org/ (search "adhan")

## How to Use

1. Download adhan MP3 files
2. Rename them (no spaces, use underscore: `my_adhan.mp3`)
3. Copy to this folder: `assets/sounds/`
4. Rebuild app: `flutter run`
5. Go to Settings → Adhan & Sound
6. You'll see all your files listed
7. Tap ▶ to preview each one
8. Tap the card to select your favorite

## Requirements

- **Format**: MP3 (most compatible)
- **Duration**: 2-5 minutes recommended
- **Quality**: Clear audio, 128-192 kbps
- **Naming**: Use lowercase, no spaces (use underscores)

## Testing

1. Open app → Settings → Adhan & Sound
2. Each adhan will have a ▶ play button
3. Tap to preview before selecting
4. Selected adhan is marked with ✓

## Tips

- Start with 2-3 different adhans to test
- You can add more anytime
- Preview each to find your favorite
- Silent mode available if you prefer notifications only

## Note

The app searches for these common names automatically:
- adhan1, adhan2, adhan3, adhan4, adhan5
- makkah, madina, egypt, turkey, aqsa
- azan1, azan2, azan3
- fajr_adhan, regular_adhan

But you can use ANY filename - they'll all be detected!

