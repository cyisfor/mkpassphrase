import sqlite3;
import sqldelite;
import rdstdin;

const location : string = joinPath(getHomeDir(),".local","words.sqlite");

var db : PSqlite3;
assert(0==sqlite3.open(location,db))

var version: int = db.getValue("SELECT version FROM version")
var version : int;
if (sversion == ""):
  db.exec("CREATE TABLE version (version INTEGER PRIMARY KEY)")
  db.withPrep("INSERT INTO version (version) VALUES (?)",
  proc(st: PStmt) =
    bind_int(st,1,0))
  version = 0

type Upgrade = tuple
  version: int
  doit: proc ()

proc initDB() =
  var words = "/usr/share/dict/words";
  if(!fileExists(words)):
    words = "/usr/share/dict/cracklib-small"; # don't ask
  db.exec(sql(r"CREATE TABLE words
(id INTEGER PRIMARY KEY,
  word TEXT UNIQUE)"))
  for line in lines(words):
    if (find(line,'\'')): continue
    var word = line.strip(false,true)
    echo "found word", word

const upgrades: Upgrade[] = [(0,initDB)];

proc doUpgrades(st: PStmt) =
  for upgrade in upgrades:
    if (upgrade.version > version):
      upgrade.doit()
      version = upgrade.version
      bind_integer(st,1,version)
      assert(SQLITE_OK==step(st))
      reset(st)
db.withPrep("UPDATE version SET version = ?",doUpgrades)

var master = readPasswordFromStdin("Master Passphrase:")

proc stringToInteger(s: string): int =
  var i: int = 0
  for c in s:
    i = (i | c) << 8;
    return i
    
proc reseed(newseed: string = "") =
  newseed += master
  randomize(stringToInteger(newseed))

proc myrandom(para1: Pcontext; para2: int32; 
              para3: PValueArg) {.cdecl.} =
  return random(1.0)

db.createFunction("myrandom",0,myrandom)

var sep: ref string = nil
if (existsEnv("sep")):
  sep = getEnv("sep")

var punct = [":","? ","! ",",",". "]

var numwords = 0
if existsEnv("num"):
  numwords = parseInt(getEnv("num"))

proc doit(select: PStmt) =
  bind_int(select,1,numwords)
  while true:
    resource = readLineFromStdin("Resource:")
    reseed(resource)
    step(select)
    reset(select)
    var word = column_text(select,1)
    if (first):
      first = false
      word[0] = toUpper(word[0])
    elif (sep == nil):
      word[0] = toUpper(word[0])
    else:
      if (random(10)>6):
        var p = random(punct)
        write(p)
        if (p.len == 2):
          word[0] = toUpper(word[0])
    write(word)
  if (sep != nil):
    write(random(punct))
  
db.withPrep("SELECT word FROM words ORDER BY myrandom() LIMIT ?",doit)
    
