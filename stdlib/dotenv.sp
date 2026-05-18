# stdlib/dotenv.sp — .env file loader for Sapphire
# Install with: sph install dotenv

fn dotenv_load(path) {
  if path == nil { path = ".env" }
  let ok = Sys.load_env(path)
  if ok == nil {
    println("[dotenv] Warning: could not load: " + path)
    return false
  }
  return true
}

fn dotenv_get(key, fallback) {
  let val = Sys.env(key)
  if val == nil { return fallback }
  return val
}

fn dotenv_require(key) {
  let val = Sys.env(key)
  if val == nil {
    println("[dotenv] Error: required variable '" + key + "' is not set.")
    println("         Add it to your .env file:  " + key + "=your_value")
    exit(1)
  }
  return val
}
