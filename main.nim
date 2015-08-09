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

echo("Passphrase Maker")
var master: string = readPasswordFromStdin("Master Passphrase:")

proc stringToInteger(s: string): int =
  var i: int = 0
  for c in s:
    #echo("doing ",i," ",c,"=",c.int)
    i = (i shl 8) or c.int;
  return i

#proc hexlen(x: BiggestInt): int =
#  return (ln(x.float) / ln(0x10) + 1).int  
    
proc reseed(newseed: string) =
  if (newseed == ""):
    randomize()
    return
  var derp = newseed & master
  var i = stringToInteger(derp)
  #echo("New seed: ",derp,"->",i,'/',toHex(abs(i),hexlen(abs(i))))
  randomize(i)

var sep: string = ""
if (existsEnv("sep")):
  sep = getEnv("sep")

var punct = [":","? ","! ",",",". "]

var numwords = 5
if existsEnv("num"):
  numwords = parseInt(getEnv("num"))

proc doit(high: int, select: CheckStmt) =
  while true:
    var resource = readLineFromStdin("Resource:")
    reseed(resource)
    var first = true
    for i in countup(1,numwords):
      select.Bind(1,random(high))
      select.get()
      defer: select.reset()
      var word: string = select.column(0)
      if (sep == ""):
        word[0] = toUpper(word[0])
      elif (first):
        first = false
      else:
        if (random(10)>6):
          var p = random(punct)
          write(stdout,p)
          if (p.len == 2):
            word[0] = toUpper(word[0])
        write(stdout,sep)
      write(stdout,word)

    if (sep != ""):
      write(stdout,random(punct))
    write(stdout,"\n")
  
db.withPrep("SELECT word FROM words WHERE id = ?",
proc(select: CheckStmt) =
  var high = 0
  db.withPrep("SELECT MAX(id) FROM words",
  proc(count: CheckStmt) =
    high = count.getValue())
  echo("found ",high," words")
  # log2(num^picked) = picked * log2(num)
  var bits = numwords.float*log2(high.float)
  echo(numwords," of those will produce ",formatFloat(bits)," bits of entropy. (use num= to set the amount)")
  if(sep != ""):
    var added = log2(((1 + punct.len * (10-6)) * numwords).float)
    echo("using punctuation, that adds ",formatFloat(added)," bits, for ",
         formatFloat(bits+added), " bits total.")
    echo("...but then you have to remember where the punctuation is.")
  doit(high,select))

  
