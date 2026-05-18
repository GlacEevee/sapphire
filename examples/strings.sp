# stdlib/strings.sp — String utilities for Sapphire

fn is_alpha(s) {
  let chars = s.chars
  let ok = true
  for c in chars {
    let code = str(c)
    if not (c >= "a" and c <= "z") and not (c >= "A" and c <= "Z") {
      ok = false
      break
    }
  }
  return ok
}

fn is_digit(s) {
  return s >= "0" and s <= "9"
}

fn repeat_str(s, n) {
  return s.repeat(n)
}

fn center(s, width, pad = " ") {
  let total = width - s.length
  if total <= 0 { return s }
  let left = total / 2
  let right = total - left
  return pad.repeat(left) + s + pad.repeat(right)
}

fn wrap(s, width) {
  let words = s.split(" ")
  let lines = []
  let line = ""
  for word in words {
    if line.length + word.length + 1 > width and not line.empty? {
      lines.push(line.trim)
      line = word + " "
    } else {
      line = line + word + " "
    }
  }
  if not line.empty? {
    lines.push(line.trim)
  }
  return lines.join("\n")
}

fn format_number(n, decimals = 2) {
  return str(Math.round(n, decimals))
}

fn title_case(s) {
  let words = s.split(" ")
  let result = words.map({ |w| w.capitalize })
  return result.join(" ")
}

fn count_substr(s, sub) {
  let count = 0
  let i = 0
  while i <= s.length - sub.length {
    if s.slice(i, sub.length) == sub {
      count += 1
    }
    i += 1
  }
  return count
}
