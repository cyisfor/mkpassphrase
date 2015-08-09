import sqlite3

#proc createFunction*(c: PSqlite3, name: string, nArg: int, fnc: Tcreate_function_func_func) =
#  create_function(c,name,nArg,SQLITE_UTF8,nil,fnc,nil,nil);

type CheckDB: PSqlite3
type CheckStmt: PStmt

proc check(db: CheckDB, res: int) =
  case(res):
    of SQLITE_OK,SQLITE_DONE,SQLITE_ROW: return
  else:
    raise newException(SystemError,db.errmsg())

proc withPrep*(db: CheckDB, sql: string, actions: proc(st: CheckStmt)) =
  var st: CheckStmt
  var res = prepare_v2(db,sql,sql.len.cint,st,nil)
  if (res != SQLITE_OK):
    raise newException(SystemError,"bad prep?")
  try:
    actions(st)
  finally:
    assert(SQLITE_OK==finalize(st))

proc exec*(db: CheckDB, sql: string) =
  withPrep(db,sql,proc(st: CheckStmt) =
            assert(SQLITE_OK==step(st)))
      
proc getValue*(st: CheckStmt): int =
  assert(1==column_count(st))
  defer: assert(SQLITE_OK==reset(st))
  case step(st):
    of SQLITE_ROW:
      return column_int(st,0);
    else:
      raise newException(ValueError,"Didn't return a single row.")

proc getValue*(db: CheckDB, sql: string): tuple[v: int, ok: bool] =
  var val = 0
  proc setit(st: CheckStmt) =
    val = st.getValue()  
  withPrep(db,sql,setit)
  return (val,true)
