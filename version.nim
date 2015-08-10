import sqldelite;

type Upgrade* = tuple
  version: int
  doit: proc ()

proc upgrades*(db: CheckDB, upgrades: varargs[Upgrade]) =
  var version: int
  try:
    version = db.getValue("SELECT version FROM version")
  except DBError:
    try: db.exec("CREATE TABLE version (version INTEGER PRIMARY KEY)")
    except DBError:
      echo("Table already exist?")
    db.withPrep("INSERT INTO version (version) VALUES (?)") do (st: CheckStmt):
      st.Bind(1,0)
      st.step()
    version = 0

  # nested functions using a varargs is "illegal" -_-
  var nimsux: seq[Upgrade] = newSeq[Upgrade](upgrades.len)
  for i in countup(0,upgrades.len-1):
    nimsux[i] = upgrades[i]

  db.withPrep("UPDATE version SET version = ?") do (st: CheckStmt):
    for upgrade in nimsux:
      if (upgrade.version > version):
        upgrade.doit()
        version = upgrade.version
        echo("version ",version," done")
        st.Bind(1,version)
        st.step()
        st.reset()
