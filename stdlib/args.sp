# stdlib/args.sp — CLI argument parser
# Usage: import args
#   parse()              parses Sys.args()
#   get("name")          get a flag value (--name value)
#   flag("verbose")      check if a boolean flag exists (--verbose)
#   positional()         get positional arguments
#   require("name")      get flag or exit with error
#   help(text)           print help and exit

fn parse() {
  return Args.parse()
}

fn get(name) {
  return Args.get(name)
}

fn get_or(name, default) {
  let v = Args.get(name)
  if v == nil { return default }
  return v
}

fn flag(name) {
  return Args.flag(name)
}

fn positional() {
  return Args.positional()
}

fn require(name) {
  let v = Args.get(name)
  if v == nil {
    println("Error: missing required argument --" + name)
    Sys.exit(1)
  }
  return v
}

fn help(text) {
  println(text)
  Sys.exit(0)
}

fn usage(text) {
  println("Usage: " + text)
  Sys.exit(1)
}
