# stdlib/colors.sp — Terminal color and style helpers
# Works on any OS with ANSI support (Linux, macOS, Windows 10+)

fn red(s)     { return "\e[31m" + str(s) + "\e[0m" }
fn green(s)   { return "\e[32m" + str(s) + "\e[0m" }
fn yellow(s)  { return "\e[33m" + str(s) + "\e[0m" }
fn blue(s)    { return "\e[34m" + str(s) + "\e[0m" }
fn magenta(s) { return "\e[35m" + str(s) + "\e[0m" }
fn cyan(s)    { return "\e[36m" + str(s) + "\e[0m" }
fn white(s)   { return "\e[37m" + str(s) + "\e[0m" }
fn gray(s)    { return "\e[90m" + str(s) + "\e[0m" }

fn bold(s)      { return "\e[1m"  + str(s) + "\e[0m" }
fn dim(s)       { return "\e[2m"  + str(s) + "\e[0m" }
fn italic(s)    { return "\e[3m"  + str(s) + "\e[0m" }
fn underline(s) { return "\e[4m"  + str(s) + "\e[0m" }
fn blink(s)     { return "\e[5m"  + str(s) + "\e[0m" }
fn inverse(s)   { return "\e[7m"  + str(s) + "\e[0m" }

fn bg_red(s)     { return "\e[41m" + str(s) + "\e[0m" }
fn bg_green(s)   { return "\e[42m" + str(s) + "\e[0m" }
fn bg_yellow(s)  { return "\e[43m" + str(s) + "\e[0m" }
fn bg_blue(s)    { return "\e[44m" + str(s) + "\e[0m" }
fn bg_magenta(s) { return "\e[45m" + str(s) + "\e[0m" }
fn bg_cyan(s)    { return "\e[46m" + str(s) + "\e[0m" }

fn strip(s) { return Str.gsub(s, "\e\\[[0-9;]*m", "") }

fn success(s) { return green("✓ " + str(s)) }
fn error(s)   { return red("✗ " + str(s)) }
fn warn(s)    { return yellow("⚠ " + str(s)) }
fn info(s)    { return cyan("i " + str(s)) }
