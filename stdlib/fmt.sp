# stdlib/fmt.sp — convenience wrappers around the built-in fmt object
# Already available as `fmt` with no import needed.
# This file re-exports everything as top-level functions for projects
# that prefer a functional style.

fn sprintf(template, *args) {
  return fmt.sprintf(template, *args)
}

fn pad_left(s, len, ch) {
  return fmt.pad_left(s, len, ch)
}

fn pad_right(s, len, ch) {
  return fmt.pad_right(s, len, ch)
}

fn center(s, len, ch) {
  return fmt.center(s, len, ch)
}

fn truncate(s, max, suffix) {
  return fmt.truncate(s, max, suffix)
}

fn comma(n) {
  return fmt.comma(n)
}

fn plural(n, word, plural_word) {
  return fmt.plural(n, word, plural_word)
}

fn duration(secs) {
  return fmt.duration(secs)
}

fn bytes(n) {
  return fmt.bytes(n)
}

fn table(rows, headers) {
  return fmt.table(rows, headers)
}

fn strip_ansi(s) {
  return fmt.strip_ansi(s)
}
