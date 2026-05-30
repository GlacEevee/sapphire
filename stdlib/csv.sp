# stdlib/csv.sp — CSV read/write support

fn read(path) {
  return Csv.read(path)
}

fn read_headers(path) {
  return Csv.read_headers(path)
}

fn write(path, rows) {
  return Csv.write(path, rows)
}

fn write_headers(path, headers, rows) {
  return Csv.write_headers(path, headers, rows)
}

fn parse(text) {
  return Csv.parse(text)
}

fn stringify(rows) {
  return Csv.stringify(rows)
}

fn each(path, callback) {
  let rows = Csv.read(path)
  rows.each(fn(row) { callback(row) })
}
