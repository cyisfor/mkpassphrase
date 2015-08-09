import sqlite3;

proc createFunction*(c: PSqlite3, name: string, nArg: int, func: Tcreate_function_func_func) =
  create_function(c,name,arg,SQLITE_UTF8,func,nil,nil);

proc withPrep*(db: PSqlite3, sql: string, actions: proc(st: PStmt)) =
  var st: PStmt = nil
  try:
    var res = prepare_v2(db,sql,sql.cstr.len,st,nil)
    if (res != SQLITE_OK):
      raise RuntimeError("bad prep?")
      actions(st)
  finally:
    if(st):
      finalize(st)

proc exec*(db: PSqlite3, sql: string) =
  withPrep(db,sql,step)
      
proc getValue*(st: PStmt): int =
  assert(1==column_count(st))
  defer reset(st)
  case step(st)
of SQLITE_ROW:
  return column_int64(st,0);
else:
  raise ValueError("Didn't return a single row.")

proc getValue*(db: PSqlite3, sql: string): int =
  var val = 0
  proc setit(st: PStmt) =
    val = db.getValue(st)  
  withPrep(db,sql,setit)
  return val 
