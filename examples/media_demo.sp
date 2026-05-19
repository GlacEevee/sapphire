# media_demo.sp — Sapphire media viewer demo
import media

# Check what's available
media.status()
println("")

# View a single image
# media.view("/home/foxie/Pictures/photo.jpg")

# View as ASCII art (works over plain SSH, no framebuffer needed)
# media.view_ascii("/home/foxie/Pictures/photo.jpg")

# Play a video
# media.play("/home/foxie/Videos/clip.mp4")

# Slideshow
# let photos = [
#   "/home/foxie/Pictures/1.jpg",
#   "/home/foxie/Pictures/2.jpg",
#   "/home/foxie/Pictures/3.jpg"
# ]
# media.slideshow(photos, 4)

# Get image info
# let info = media.image_info("/home/foxie/Pictures/photo.jpg")
# println("Width:  " + str(info["width"]))
# println("Height: " + str(info["height"]))

# Get video info
# let info = media.video_info("/home/foxie/Videos/clip.mp4")
# println("Duration: " + str(info["duration"]) + "s")
# println("Format:   " + info["format"])

# First time? Install everything:
# media.setup()
