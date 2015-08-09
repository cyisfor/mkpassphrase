import sqldelite;

type Upgrade* = tuple
  version: int
  doit: proc ()

proc upgrades*(db: CheckDB, upgrades: varargs[Upgrade]):
  var version: int
  try:
    version = db.getValue("SELECT version FROM version")
  except DBError:
    try: db.exec("CREATE TABLE version (version INTEGER PRIMARY KEY)")
    except DBError:
      echo("Table already exist?")
    db.withPrep("INSERT INTO version (version) VALUES (?)",
                proc(st: CheckStmt) =
                  st.Bind(1,0)
                  st.step())
    version = 0

  proc doUpgrades(st: CheckStmt):
    for upgrade in upgrades:
      if (upgrade.version > version):
        upgrade.doit()
        version = upgrade.version
        echo("version ",version," done")
        st.Bind(1,version)
        st.step()
        st.reset()
  db.withPrep("UPDATE version SET version = ?",doUpgrades)


