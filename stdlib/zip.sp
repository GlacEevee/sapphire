# stdlib/zip.sp — Zip archive creation and extraction

fn create(zip_path, files)       { return Zip.create(zip_path, files) }
fn extract(zip_path, dest)       { return Zip.extract(zip_path, dest) }
fn extract_file(zip_path, file, dest) { return Zip.extract_file(zip_path, file, dest) }
fn list(zip_path)                { return Zip.list(zip_path) }
fn add(zip_path, file)           { return Zip.add(zip_path, file) }
fn contains(zip_path, file)      { return Zip.contains(zip_path, file) }
