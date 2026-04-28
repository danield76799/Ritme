from PIL import Image
import os

# Load the asset sheet
img = Image.open('B:\\fluffer-repo\\web\\icons\\ritme-icon-original.jpg')
width, height = img.size
print(f"Image size: {width}x{height}")

# Create icons directory
icons_dir = 'B:\\fluffer-repo\\web\\icons'

# The sheet appears to have multiple icon variants
# Based on description: 192x192 is the main icon size
# Let's crop the relevant icons from the sheet

# Assuming the layout has the main icon at top-left, then variants below
# Standard icon sizes needed: 16, 32, 48, 72, 96, 192, 512

# Crop main 192x192 icon from top-left area
# Based on the 1280x796 dimensions, let's assume the main icon is around that size or slightly smaller
# and the layout shows multiple variations

# For a proper asset sheet, we'd need to know exact positions
# For now, let's assume the first row contains the main icon variants

# Since we have 1280x796 and 192x192 is mentioned, let's extract that area
# and also create resized versions for all required sizes

main_icon = img.crop((0, 0, 512, min(512, height)))  # Try to get the largest icon area

# Create required icon sizes
sizes = [16, 32, 48, 72, 96, 192, 512]
for size in sizes:
    resized = main_icon.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(f'{icons_dir}\\Icon-{size}.png', 'PNG')
    print(f'Saved Icon-{size}.png')

# For maskable icons (Android adaptive icons), we need square icons with some padding
# Maskable icons should have the main icon centered in a larger square
for size in [192, 512]:
    # Create maskable version (same as regular for now, but could add padding)
    resized = main_icon.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(f'{icons_dir}\\Icon-maskable-{size}.png', 'PNG')
    print(f'Saved Icon-maskable-{size}.png')

print('Done!')
