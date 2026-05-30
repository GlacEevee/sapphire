# stdlib/yml.sp — YAML read/write support

fn load(path) {
  return Yml.load(path)
}

fn load_str(text) {
  return Yml.load_str(text)
}

fn dump(data) {
  return Yml.dump(data)
}

fn save(path, data) {
  return Yml.save(path, data)
}

fn parse(text) {
  return Yml.load_str(text)
}
