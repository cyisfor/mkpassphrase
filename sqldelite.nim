import sqlite3

#proc createFunction*(c: PSqlite3, name: string, nArg: int, fnc: Tcreate_function_func_func) =
#  create_function(c,name,nArg,SQLITE_UTF8,nil,fnc,nil,nil);

proc withPrep*(db: PSqlite3, sql: string, actions: proc(st: PStmt)) =
  var st: PStmt
  var res = prepare_v2(db,sql,sql.len.cint,st,nil)
  if (res != SQLITE_OK):
    raise newException(SystemError,"bad prep?")
  try:
    actions(st)
  finally:
    assert(SQLITE_OK==finalize(st))

proc exec*(db: PSqlite3, sql: string) =
  withPrep(db,sql,proc(st: PStmt) =
            assert(SQLITE_OK==step(st)))
      
proc getValue*(st: PStmt): int =
  assert(1==column_count(st))
  defer: assert(SQLITE_OK==reset(st))
  case step(st):
    of SQLITE_ROW:
      return column_int(st,0);
    else:
      raise newException(ValueError,"Didn't return a single row.")

proc getValue*(db: PSqlite3, sql: string): tuple[v: int, ok: bool] =
  var val = 0
  proc setit(st: PStmt) =
    val = st.getValue()  
  withPrep(db,sql,setit)
  return (val,true)
