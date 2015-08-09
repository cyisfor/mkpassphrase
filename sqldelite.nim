import sqlite3
import strutils

#proc createFunction*(c: PSqlite3, name: string, nArg: int, fnc: Tcreate_function_func_func) =
#  create_function(c,name,nArg,SQLITE_UTF8,nil,fnc,nil,nil);

type CheckDB* = PSqlite3
type CheckStmt* = tuple
  db: CheckDB
  st: PStmt
  
type DBError* = ref object of IOError
  res: cint
  columns: cint
  index: int

proc check(db: CheckDB, res: cint) =
  case(res):
    of SQLITE_OK,SQLITE_DONE,SQLITE_ROW:
      return
    else:
      raise DBError(msg: $db.errmsg())

proc check(st: CheckStmt, res: cint) {.inline.} =
  check(st.db,res)
      
proc Bind*(st: CheckStmt, idx: int, val: int) =
  st.check(bind_int(st.st,idx.cint,val.cint))

proc Bind*(st: CheckStmt, idx: int, val: string) =
  st.check(bind_text(st.st,idx.cint,val, val.len.cint, nil))

proc step*(st: CheckStmt) =
  st.check(step(st.st))
  
proc reset*(st: CheckStmt) =
  st.check(reset(st.st))

proc get*(st: CheckStmt) =
  var res = step(st.st)
  if(res == SQLITE_DONE):
    st.reset()
    raise DBError(msg: "No results?")
  st.check(res)

proc column*(st: CheckStmt, idx: int): string =
  var res = column_text(st.st,idx.cint)
  if(res == nil):
    raise DBError(msg: "No column at index $1" % [$idx], index: idx, columns: column_count(st.st))
  return $res
  
proc open*(location: string, db: var CheckDB) =
  var res = sqlite3.open(location,db.PSqlite3)
  if (res != SQLITE_OK):
    raise DBError(msg: "Could not open")

proc withPrep*(db: CheckDB, sql: string, actions: proc(st: CheckStmt)) =
  var st: CheckStmt
  st.db = db
  db.check(prepare_v2(db,sql,sql.len.cint,st.st,nil))
  try:
    actions(st)
  finally:
    db.check(finalize(st.st))

template withTransaction*(db: expr, actions: stmt) =
  db.withPrep("BEGIN",
  proc(begin: CheckStmt) =
    db.withPrep("ROLLBACK",
    proc(rollback: CheckStmt) =
      db.withPrep("COMMIT",
      proc(commit: CheckStmt) =
        begin.step()
        try:
          actions
          commit.step()
        except:
          rollback.step()
          raise)))
    
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
