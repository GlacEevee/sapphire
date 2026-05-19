# stdlib/media.sp — Photo and video viewer for Sapphire
# Works headless over SSH on Raspberry Pi (framebuffer, no X needed)
# Requires: fim (images), mpv (video) — install with Media.setup()

# ── Images ────────────────────────────────────────────────────────────────────

# View a photo. Uses framebuffer (fim) when headless, feh when X is available.
fn view(path) {
  let ok = Media.show_image(path)
  if ok == false {
    println("Tip: run media.setup() to install required tools")
  }
}

# View a photo as ASCII art — works over any SSH connection, no framebuffer needed
fn view_ascii(path) {
  let ok = Media.show_image_ascii(path, 100)
  if ok == false {
    println("Tip: install viu with 'cargo install viu' or jp2a with 'sudo apt install jp2a'")
  }
}

# View multiple images as a slideshow
fn slideshow(paths, delay) {
  if delay == nil { delay = 3 }
  println("Starting slideshow (" + str(paths.length) + " images, " + str(delay) + "s each)...")
  Media.slideshow(paths, delay)
}

# Get info about an image file
fn image_info(path) {
  return Media.image_info(path)
}

# ── Video ─────────────────────────────────────────────────────────────────────

# Play a video. Uses mpv --vo=drm when headless (no X needed on Pi).
fn play(path) {
  let ok = Media.play_video(path)
  if ok == false {
    println("Tip: run media.setup() to install mpv")
  }
}

# Get info about a video file (duration, format, size)
fn video_info(path) {
  return Media.video_info(path)
}

# ── Utilities ─────────────────────────────────────────────────────────────────

# Check if the environment has a display (X11/Wayland)
fn has_display() {
  return Media.has_display()
}

# Check if running headless (SSH with no display)
fn is_headless() {
  return Media.has_display() == false
}

# Print environment info
fn status() {
  if Media.has_display() {
    println("Display: X11/Wayland available")
  } else {
    println("Display: headless (framebuffer mode)")
  }
  if Media.has_cmd("fim")    { println("Images:  fim ✓") }
  elif Media.has_cmd("feh")  { println("Images:  feh ✓") }
  else                        { println("Images:  no viewer found — run media.setup()") }
  if Media.has_cmd("mpv")    { println("Video:   mpv ✓") }
  elif Media.has_cmd("vlc")  { println("Video:   vlc ✓") }
  else                        { println("Video:   no player found — run media.setup()") }
  if Media.has_cmd("viu")    { println("ASCII:   viu ✓") }
  elif Media.has_cmd("jp2a") { println("ASCII:   jp2a ✓") }
  else                        { println("ASCII:   no terminal viewer found") }
}

# Install all recommended tools for headless Pi (runs apt-get)
fn setup() {
  Media.setup()
}
