# media_demo.sp — Sapphire media viewer demo
import media

# Check what's available
status()
println("")

# First time setup — installs fim, mpv, jp2a via apt
# setup()

# View an image (framebuffer, no X needed)
view("photo.png")

# View as ASCII art — works over plain SSH
# view_ascii("photo.png")

# Play a video
# play("video.mp4")

# Slideshow
# slideshow(["photo1.jpg", "photo2.jpg"], 4)

# Get image info
# let info = image_info("photo.png")
# println("Width: " + str(info["width"]))

# Get video info
# let info = video_info("clip.mp4")
# println("Duration: " + str(info["duration"]) + "s")
