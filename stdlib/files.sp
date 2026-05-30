# stdlib/files.sp — File and directory utilities

fn read(path)        { return Files.read(path) }
fn write(path, data) { return Files.write(path, data) }
fn append(path, data){ return Files.append(path, data) }
fn delete(path)      { return Files.delete(path) }
fn exists(path)      { return Files.exists(path) }
fn copy(src, dest)   { return Files.copy(src, dest) }
fn move(src, dest)   { return Files.move(src, dest) }

fn mkdir(path)       { return Files.mkdir(path) }
fn rmdir(path)       { return Files.rmdir(path) }
fn ls(path)          { return Files.ls(path) }
fn ls_r(path)        { return Files.ls_r(path) }

fn glob(pattern)     { return Files.glob(pattern) }
fn basename(path)    { return Files.basename(path) }
fn dirname(path)     { return Files.dirname(path) }
fn extname(path)     { return Files.extname(path) }
fn join(a, b)        { return Files.join(a, b) }
fn expand(path)      { return Files.expand(path) }
fn size(path)        { return Files.size(path) }
fn is_dir(path)      { return Files.is_dir(path) }
fn is_file(path)     { return Files.is_file(path) }

fn watch(path, callback) { return Files.watch(path, callback) }
