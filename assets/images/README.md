# Background Images

This directory contains background images for the launcher app.

## Supported Formats
- JPG/JPEG
- PNG
- WebP

## Recommended Specifications
- **Resolution**: 1920x1080 or higher
- **Aspect Ratio**: 16:9 (widescreen)
- **File Size**: Under 5MB for optimal performance
- **Format**: JPG for photos, PNG for graphics with transparency

## Usage
1. Place your background image in this directory
2. Update the `background_image` path in `assets/config/app_settings.json`
3. The image will be automatically loaded as the app background

## Example
```json
{
  "background_image": "assets/images/my_background.jpg"
}
```

## Default Image
The app comes with a default background image. Replace it with your own image by:
1. Adding your image to this directory
2. Updating the config file
3. Rebuilding the app

**Note**: Make sure your image has good contrast with white text for readability.
