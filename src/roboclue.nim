import httpclient
import strutils
import asyncdispatch
import os
import strformat

const
  B_MAGENTA = "\e[95m"
  B_GREEN = "\e[92m"
  B_RED = "\e[91m"
  B_CYAN = "\e[96m"
  B_BLUE = "\e[94m"
  RESET = "\e[0m"
  PROGRAM_NAME = "roboclue"


proc banner() =
  echo fmt"{B_CYAN}      {PROGRAM_NAME} {RESET} - {B_GREEN} Fast robots.txt audit {RESET}"
  echo fmt"Version:{B_GREEN} 1.0 {RESET}"
  echo fmt"Author:{B_MAGENTA}  Nong Hoang Tu {RESET}"
  echo fmt"Gitlab:{B_BLUE}  https://nest.parrot.sh/packages/tools/roboclue  {RESET}"
  echo fmt"License:{B_GREEN} GPL-2"


proc usage() =
  echo fmt"{B_RED}Usage: {B_CYAN}{PROGRAM_NAME} {RESET}[{B_BLUE}-t delayTime{RESET}] <{B_MAGENTA}URL or -f urlList{RESET}>"


proc help() =
  banner()
  usage()


proc formatURL(url: string): string =
  result = url
  if not url.startsWith("http"):
    result = "http://" & result
  if not url.endsWith("/") and not url.endsWith("robots.txt"):
    result &= "/"
  return result


proc addRobotToUrl(url: string): string =
  result = url
  if not url.endsWith("robots.txt"):
    result &= "robots.txt"
  return result


proc checkSleepTime(t: string): int =
  try:
    result = parseInt(t)
    if result >= 0:
      return result
    else:
      return 0
  except:
    return 0


proc checkRobot(url: string, delay = 0) =
  let
    client = newAsyncHttpClient()
  echo B_CYAN, "[*] Checking robots.txt", RESET
  let
    resp = waitfor client.get(addRobotToUrl(url))
  if resp.status.startsWith("200"):
    echo B_GREEN, addRobotToUrl(url), " ", resp.status, RESET
    echo B_CYAN, "[*] Checking URL from robots.txt", RESET
    for line in waitfor(resp.body).split("\n"):
      if line.startsWith("Disallow:") or line.startsWith("Allow:"):
        if ": /" in line:
          let
            path = line.split(": /")[1].replace("\n", "").replace("\r", "")
          if path != "":
            let
              checkBranch = if not path.startsWith("http"): url.replace("robots.txt", "") & path else: path
              respcheckBranch = waitfor client.get(checkBranch)
            if respcheckBranch.status.startsWith("200"):
              echo B_GREEN, checkBranch, " ", respcheckBranch.status, RESET
            elif respcheckBranch.status.startsWith("30"):
              echo B_CYAN, checkBranch, " ", respcheckBranch.status, RESET
            elif respcheckBranch.status.startsWith("404"):
              echo B_RED, checkBranch, " ", respcheckBranch.status, RESET
            else:
              echo B_MAGENTA, checkBranch, " ", respcheckBranch.status, RESET
            if delay > 0:
              sleep(delay * 1000)
  else:
    echo B_RED, addRobotToUrl(url), " ", resp.status, RESET
  client.close()


proc getUserOptions() =
  var
    url, filePath = ""
    setDelay = "0"
  if paramCount() == 0:
    help()
  elif paramCount() == 1:
    case paramStr(1)
    of "-h":
      help()
    of "--help":
      help()
    of "-help":
      help()
    of "help":
      help()
    else:
      url = formatURL(paramStr(1))
      checkRobot(url, checkSleepTime(setDelay))
  else:
    var i = 1
    while i < paramCount():
      if paramStr(i) == "-f":
        filePath = paramStr(i + 1)
        i += 1
      elif paramStr(i) == "-t":
        setDelay = paramStr(i + 1)
        i += 1
      else:
        url = formatURL(paramStr(i))
      i += 1

    if url == "" and filePath == "":
      echo B_RED, "[x] No URL was provided!", RESET
      usage()
    if url != "":
      banner()
      checkRobot(url, checkSleepTime(setDelay))
    elif filePath != "":
      if fileExists(filePath):
        banner()
        for line in lines(filePath):
          if not isEmptyOrWhitespace(line):
            checkRobot(formatURL(line), checkSleepTime(setDelay))
      else:
        echo B_RED, "[x] File not found! ", filePath, RESET
    # else:
    #   echo B_RED, "[x] Invalid option!", RESET

getUserOptions()
