# stdlib/io.sp — I/O helpers for Sapphire

fn read_lines(path) {
  let content = IO.read_file(path)
  if content == nil { return nil }
  return content.lines
}

fn write_lines(path, lines) {
  let content = lines.join("\n")
  IO.write_file(path, content)
}

fn append_file(path, content) {
  let existing = IO.read_file(path)
  if existing == nil {
    IO.write_file(path, content)
  } else {
    IO.write_file(path, existing + content)
  }
}

fn prompt(msg) {
  return IO.read_line(msg)
}

fn confirm(msg) {
  let answer = IO.read_line(msg + " [y/n]: ")
  return answer == "y" or answer == "yes"
}

fn print_table(headers, rows) {
  # Calculate column widths
  let widths = headers.map({ |h| h.length })
  rows.each({ |row|
    row.each({ |cell, i|
      let clen = str(cell).length
      if clen > widths[i] {
        widths[i] = clen
      }
    })
  })
  # Print header
  let header_row = headers.map({ |h, i| h.pad_end(widths[i]) }).join(" | ")
  println(header_row)
  let sep = widths.map({ |w| "-".repeat(w) }).join("-+-")
  println(sep)
  # Print rows
  rows.each({ |row|
    let line = row.map({ |cell, i| str(cell).pad_end(widths[i]) }).join(" | ")
    println(line)
  })
}
