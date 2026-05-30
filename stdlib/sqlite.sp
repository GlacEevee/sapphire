# stdlib/sqlite.sp — Embedded SQLite database

fn open(path)    { return Sqlite.open(path) }
fn memory()      { return Sqlite.open(":memory:") }

fn query(db, sql)          { return Sqlite.query(db, sql) }
fn query_one(db, sql)      { return Sqlite.query_one(db, sql) }
fn execute(db, sql)        { return Sqlite.execute(db, sql) }
fn execute_params(db, sql, params) { return Sqlite.execute_params(db, sql, params) }
fn close(db)               { return Sqlite.close(db) }

fn create_table(db, name, cols) { return Sqlite.create_table(db, name, cols) }
fn insert(db, table, data)      { return Sqlite.insert(db, table, data) }
fn select_all(db, table)        { return Sqlite.select_all(db, table) }
fn select_where(db, table, col, val) { return Sqlite.select_where(db, table, col, val) }
fn update(db, table, data, where_col, where_val) { return Sqlite.update(db, table, data, where_col, where_val) }
fn delete_where(db, table, col, val) { return Sqlite.delete_where(db, table, col, val) }
fn tables(db)              { return Sqlite.tables(db) }
