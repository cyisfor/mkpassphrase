import sqldelite

import sqlite3
import rdstdin
import strutils
import math
import os

var location : string = joinPath(getHomeDir(),".local","words.sqlite");

var db : PSqlite3;
assert(0==sqlite3.open(location,db))

var (version,ok) = db.getValue("SELECT version FROM version")
if (not ok):
  db.exec("CREATE TABLE version (version INTEGER PRIMARY KEY)")
  db.withPrep("INSERT INTO version (version) VALUES (?)",
  proc(st: PStmt) =
    assert(SQLITE_OK==bind_int(st,1,0)))
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
  for line in lines(words):
    if (find(line,'\'')>0): continue
    var word = line.strip(false,true)
    echo "found word", word

const upgrades: seq[tuple[version: int, doit: proc()]] = @[(version:0,doit:initDB)];

proc doUpgrades(st: PStmt) =
  for upgrade in upgrades:
    if (upgrade.version > version):
      upgrade.doit()
      version = upgrade.version
      assert(SQLITE_OK==bind_int(st,1.cint,version.cint))
      assert(SQLITE_OK==step(st))
      assert(SQLITE_OK==reset(st))
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

var sep: ref string = nil
if (existsEnv("sep")):
  sep = getEnv("sep")

var punct = [":","? ","! ",",",". "]

var numwords = 0
if existsEnv("num"):
  numwords = parseInt(getEnv("num"))

proc doit(high int, select: PStmt) =
  while true:
    resource = readLineFromStdin("Resource:")
    reseed(resource)
    bind_int(select,1,random(high))
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
  
db.withPrep("SELECT word FROM words WHERE id = ?",
proc(select: PStmt) =
  var high = 0
  db.withPrep("SELECT MAX(id) FROM words",
  proc(count: PStmt) =
    high = count)
  doit(high,select)

  
