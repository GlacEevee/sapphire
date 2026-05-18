# stdlib/strings.sp — String utilities for Sapphire

fn capitalize_words(s) {
  let words = s.split(" ")
  let result = words.map({ |w|
    if w.length == 0 { return w }
    return w[0].upcase + w.slice(1, w.length)
  })
  return result.join(" ")
}

fn count_occurrences(haystack, needle) {
  let count = 0
  let i = 0
  while i <= haystack.length - needle.length {
    if haystack.slice(i, needle.length) == needle {
      count += 1
    }
    i += 1
  }
  return count
}

fn is_palindrome(s) {
  let clean = s.downcase.trim
  return clean == clean.reverse
}

fn repeat(s, n) {
  return s.repeat(n)
}

fn truncate(s, max_len, suffix) {
  if s.length <= max_len { return s }
  return s.slice(0, max_len - suffix.length) + suffix
}

fn format_number(n) {
  let s = str(n)
  return s
}

fn indent(text, spaces) {
  let pad = " ".repeat(spaces)
  let lines = text.lines
  return lines.map({ |l| pad + l }).join("\n")
}

fn strip_prefix(s, prefix) {
  if s.starts_with?(prefix) {
    return s.slice(prefix.length, s.length - prefix.length)
  }
  return s
}

fn strip_suffix(s, suffix) {
  if s.ends_with?(suffix) {
    return s.slice(0, s.length - suffix.length)
  }
  return s
}

fn join_lines(arr) {
  return arr.join("\n")
}

fn words(s) {
  return s.trim.split(" ")
}
