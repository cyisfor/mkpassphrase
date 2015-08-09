import sqldelite

import sqlite3
import rdstdin
import strutils
import math
import os

var location : string = joinPath(getHomeDir(),".local","words.sqlite");

var db : CheckDB;
sqldelite.open(location,db)

var version: int
try:
  version = db.getValue("SELECT version FROM version")
except DBError:
  echo getCurrentExceptionMsg()
  try: db.exec("CREATE TABLE version (version INTEGER PRIMARY KEY)")
  except DBError:
    echo("Table already exist?")
  db.withPrep("INSERT INTO version (version) VALUES (?)",
  proc(st: CheckStmt) =
    st.Bind(1,0)
    st.step())
  version = 0

type Upgrade = tuple
  version: int
  doit: proc ()

proc initDB() {.closure.} =
  var words = "/usr/share/dict/words";
  if(not fileExists(words)):
    words = "/usr/share/dict/cracklib-small"; # don't ask
  db.exec("""CREATE TABLE words
(id INTEGER PRIMARY KEY,
  word TEXT UNIQUE)""")
  withTransaction(db):
    db.withPrep("INSERT INTO words (word) VALUES (?)",
              proc(insert: CheckStmt) =
                for line in lines(words):
                  if (find(line,'\'')>0): continue
                  var word = line.strip(false,true)
                  echo "found word ", word
                  insert.Bind(1,word)
                  insert.step()
                  insert.reset())

const upgrades: seq[Upgrade] = @[(version:1,doit:initDB)];

proc doUpgrades(st: CheckStmt) =
  for upgrade in upgrades:
    if (upgrade.version > version):
      upgrade.doit()
      version = upgrade.version
      echo("version ",version," done")
      st.Bind(1,version)
      st.step()
      st.reset()
db.withPrep("UPDATE version SET version = ?",doUpgrades)

var master: string = readPasswordFromStdin("Master Passphrase:")

proc stringToInteger(s: string): int =
  var i: int = 0
  for c in s:
    i = (i + c.int) * 0x100;
    return i
    
proc reseed(newseed: string) =
  var derp = newseed & master
  randomize(stringToInteger(derp))

var sep: string = ""
if (existsEnv("sep")):
  sep = getEnv("sep")

var punct = [":","? ","! ",",",". "]

var numwords = 0
if existsEnv("num"):
  numwords = parseInt(getEnv("num"))

proc doit(high: int, select: CheckStmt) =
  var first = false
  while true:
    var resource = readLineFromStdin("Resource:")
    reseed(resource)
    select.Bind(1,random(high))
    select.step()
    select.reset()
    var word: string = select.column(1)
    if (first):
      first = false
      word[0] = toUpper(word[0])
    elif (sep == ""):
      word[0] = toUpper(word[0])
    else:
      if (random(10)>6):
        var p = random(punct)
        write(stdout,p)
        if (p.len == 2):
          word[0] = toUpper(word[0])
    write(stdout,word)
  if (sep != ""):
    write(stdout,random(punct))
  
db.withPrep("SELECT word FROM words WHERE id = ?",
proc(select: CheckStmt) =
  var high = 0
  db.withPrep("SELECT MAX(id) FROM words",
  proc(count: CheckStmt) =
    high = count.getValue())
  echo("found ",high," words")
  doit(high,select))

  
