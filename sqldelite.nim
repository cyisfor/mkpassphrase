import sqlite3
import strutils

#proc createFunction*(c: PSqlite3, name: string, nArg: int, fnc: Tcreate_function_func_func) =
#  create_function(c,name,nArg,SQLITE_UTF8,nil,fnc,nil,nil);

type CheckDB* = PSqlite3
type CheckStmt* = tuple
  db: CheckDB
  st: PStmt
  
type DBError* = object of IOError
  res: cint

proc check(db: CheckDB, res: cint) =
  case(res):
    of SQLITE_OK,SQLITE_DONE,SQLITE_ROW:
      return
    else:
      raise newException(DBError,$db.errmsg())

proc check(st: CheckStmt, res: cint) {.inline.} =
  check(st.db,res)
      
proc Bind*(st: CheckStmt, idx: int, val: int) =
  st.check(bind_int(st.st,idx.cint,val.cint))

proc step*(st: CheckStmt) =
  st.check(step(st.st))

proc reset*(st: CheckStmt) =
  st.check(reset(st.st))

proc column*(st: CheckStmt, idx: int): string =
  return $column_text(st.st,idx.cint)
  
proc open*(location: string, db: var CheckDB) =
  var res = sqlite3.open(location,db.PSqlite3)
  if (res != SQLITE_OK):
    raise newException(DBError,"Could not open")

proc withPrep*(db: CheckDB, sql: string, actions: proc(st: CheckStmt)) =
  var st: CheckStmt
  st.db = db
  db.check(prepare_v2(db,sql,sql.len.cint,st.st,nil))
  try:
    actions(st)
  finally:
    db.check(finalize(st.st))

proc exec*(db: CheckDB, sql: string) =
  withPrep(db,sql,proc(st: CheckStmt) =
            db.check(step(st.st)))
      
proc getValue*(st: CheckStmt): int =
  assert(1==column_count(st.st))
  defer: st.db.check(reset(st.st))
  var res = step(st.st)
  case res:
    of SQLITE_ROW:
      return column_int(st.st,0);
    else:
      raise DBError(msg:"Didn't return a single row",res:res)

proc getValue*(db: CheckDB, sql: string): int =
  var val = 0
  proc setit(st: CheckStmt) =
    val = st.getValue()  
  withPrep(db,sql,setit)
  return val
