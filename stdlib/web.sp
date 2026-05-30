# stdlib/web.sp — Web server package (requires Node.js)
# Install Node: sudo apt-get install nodejs npm

fn create(port) {
  if port == nil { port = 3000 }
  if Env.has_node() == false {
    println("[Sapphire] web package requires Node.js.")
    println("  Install: sudo apt-get install nodejs npm")
    return nil
  }
  return Web.create(port)
}

fn get(path, body)    { return Web.get(path, body) }
fn post(path, handler){ return Web.post(path, handler) }
fn static(dir)        { return Web.serve_static(dir) }
fn listen(port)       {
  if port == nil { port = 3000 }
  Web.listen(port)
  println("Server running on http://localhost:" + str(port))
}
fn stop()             { return Web.stop() }
