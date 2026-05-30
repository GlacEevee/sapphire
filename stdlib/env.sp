# stdlib/env.sp — Environment and platform detection

fn os()          { return Env.os() }
fn arch()        { return Env.arch() }
fn home()        { return Env.home() }
fn user()        { return Env.user() }
fn hostname()    { return Env.hostname() }
fn cwd()         { return Env.cwd() }
fn tmp()         { return Env.tmp() }

fn get(key)          { return Env.get(key) }
fn set(key, val)     { return Env.set(key, val) }
fn has(key)          { return Env.has(key) }
fn all()             { return Env.all() }

fn is_windows()  { return Env.os() == "windows" }
fn is_mac()      { return Env.os() == "macos" }
fn is_linux()    { return Env.os() == "linux" }
fn is_pi()       { return Env.is_pi() }

fn ruby_version()   { return Env.ruby_version() }
fn node_version()   { return Env.node_version() }
fn has_node()       { return Env.has_node() }
