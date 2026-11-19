#!/bin/bash
# Runs every time the World of Warplanes app is opened (called by Contents/MacOS/launcher,
# which then starts Sikarugir). Exit code 10 = don't start anything.
#
# Menu (list with Go / Cancel):
#        Play         game engine (CrossOver 23.7 + DXVK), resolution matched to the screen,
#                     Low Power automatic on battery at 50% or less
#        Game Center  switches to the Game Center engine (Wine 10 D3DMetal, needed to install,
#                     download and unpack updates), opens Game Center (or installs it the first
#                     time), and switches back by itself once everything from it has closed
#        Settings…    Play in Low Power, wrapper settings, game folder
#
# Engines live inside the app: SharedSupport/wine is the active one, the other is parked in
# SharedSupport/engines/game or SharedSupport/engines/gamecenter.
# Manual engine switch:  prelaunch.sh --use-mode game|gamecenter

HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$(cd "$HERE/../../.." && pwd)"
SS="$APP/Contents/SharedSupport"
ENGINE="$SS/wine"
DRIVE="$SS/prefix/drive_c"
PLIST="$APP/Contents/Info.plist"
PB=/usr/libexec/PlistBuddy
ICON="$APP/Contents/Resources/Configure.icns"
LOCK="${TMPDIR}$(printf '%s' "$APP" | sed 's|/|xKWx|g')/lockfile"
FLAG="${TMPDIR}wowp-low-power-next"             # made by "Low Power WoWp"
DEFAULT_GAME='/Games/World_of_Warplanes/WorldOfWarplanes.exe'
LOG="$HERE/athena.log"
TITLE="World of Warplanes"
log() { echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG"; }
say() { /usr/bin/osascript -e 'tell current application to activate' -e "display dialog \"$1\" buttons {\"OK\"} default button 1 with title \"$TITLE\" with icon (POSIX file \"$ICON\")" >/dev/null 2>&1; }

# --- where things are (they can differ between Macs) -------------------------------
wgc_path() {      # Windows-style path of Game Center, if installed
  local c
  for c in "/Program Files/Wargaming.net/GameCenter/wgc.exe" "/Program Files (x86)/Wargaming.net/GameCenter/wgc.exe"; do
    [ -f "$DRIVE$c" ] && { echo "$c"; return 0; }
  done
  return 1
}
game_path() {     # Windows-style path of WorldOfWarplanes.exe, if installed
  local cache="$HERE/game-path" p
  p="$(cat "$cache" 2>/dev/null)"; [ -n "$p" ] && [ -f "$DRIVE$p" ] && { echo "$p"; return 0; }
  [ -f "$DRIVE$DEFAULT_GAME" ] && { echo "$DEFAULT_GAME" > "$cache"; echo "$DEFAULT_GAME"; return 0; }
  p="$(find "$DRIVE" -maxdepth 6 -name WorldOfWarplanes.exe -not -path "$DRIVE/windows/*" 2>/dev/null | head -1)"
  [ -n "$p" ] || return 1
  p="${p#$DRIVE}"; echo "$p" > "$cache"; echo "$p"
}
PREFDIR="$DRIVE/users/Sikarugir/AppData/Roaming/Wargaming.net/World of Warplanes"
if [ ! -d "$PREFDIR" ]; then
  for d in "$DRIVE"/users/*/AppData/Roaming/Wargaming.net/"World of Warplanes"; do [ -d "$d" ] && { PREFDIR="$d"; break; }; done
fi
PREFS="$PREFDIR/preferences.xml"
BACKUP="$PREFDIR/normal-graphics-backup.json"   # made and deleted automatically
SESSION="$PREFDIR/low-power-session"
GP="$(game_path)"; GAMEDIR="$DRIVE$(dirname "${GP:-$DEFAULT_GAME}")"
CONF="$GAMEDIR/dxvk.conf"                       # exists only during a Low Power session

# --- engine switching ----------------------------------------------------------------
current_mode() { grep -qi 'sikarugir 10' "$ENGINE/version" 2>/dev/null && echo gamecenter || echo game; }
use_mode() {    # use_mode game|gamecenter
  local want="$1" have; have="$(current_mode)"
  if [ "$have" != "$want" ]; then
    mkdir -p "$SS/engines"
    if [ ! -d "$SS/engines/$want" ] || [ -e "$SS/engines/$have" ]; then
      log "engine switch $have->$want impossible"; say "Can't switch engines: the $want engine is missing from the app."; exit 10
    fi
    mv "$ENGINE" "$SS/engines/$have" && mv "$SS/engines/$want" "$ENGINE" || {
      log "engine switch $have->$want FAILED"; say "Engine switch failed. Restart your Mac, then try again."; exit 10; }
    log "engine switched $have->$want"
  fi
  if [ "$want" = gamecenter ]; then
    $PB -c "Set :'Program Name and Path' '$(wgc_path || echo '/Program Files/Wargaming.net/GameCenter/wgc.exe')'" -c "Set :D3DMETAL 1" "$PLIST"
  else
    $PB -c "Set :'Program Name and Path' '$(game_path || echo "$DEFAULT_GAME")'" -c "Set :D3DMETAL 0" "$PLIST"
  fi
}
watch_and_restore() {   # back to the game engine once everything from the app has closed
  nohup /bin/bash -c '
    engine="$0"; here="$1"
    for i in $(seq 1 90); do pgrep -f "wgc\.exe" >/dev/null && break; sleep 2; done
    quiet=0
    while [ $quiet -lt 3 ]; do
      if pgrep -f "$engine/" >/dev/null || pgrep -f "wgc\.exe|WorldOfWarplanes\.exe" >/dev/null; then quiet=0; else quiet=$((quiet+1)); fi
      sleep 5
    done
    /bin/bash "$here/prelaunch.sh" --restore-game-engine
  ' "$ENGINE" "$HERE" >/dev/null 2>&1 </dev/null &
  disown
}

if [ "$1" = "--restore-game-engine" ] || [ "$1" = "--use-mode" ]; then
  pgrep -f "$ENGINE/" >/dev/null && { echo "engine in use, quit the game/Game Center first"; log "switch skipped: engine in use"; exit 10; }
  if [ "$1" = "--use-mode" ]; then
    { [ "$2" = game ] || [ "$2" = gamecenter ]; } || { echo "usage: --use-mode game|gamecenter"; exit 10; }
    use_mode "$2"; echo "now: $(current_mode)"
  else
    use_mode game; log "back to game engine"
  fi
  exit 10
fi

# --- the app must run from a writable place (not the DMG or a quarantine copy) -------
case "$APP" in
  */AppTranslocation/*|/Volumes/*)
    say "Please drag WorldOfWarplanes into your Applications folder first, then open it from there."; exit 10 ;;
esac
if [ ! -w "$SS/prefix" ]; then say "This copy of the app can't be changed. Move it into your Applications folder and open it again."; exit 10; fi
if xattr "$APP/Contents/MacOS/launcher" 2>/dev/null | grep -q com.apple.quarantine; then
  xattr -dr com.apple.quarantine "$APP" 2>/dev/null; log "download quarantine removed"
fi

# --- Windows drive Z: = the Mac's disk (not shipped in the download, it would break the signature)
[ -e "$SS/prefix/dosdevices/z:" ] || ln -s / "$SS/prefix/dosdevices/z:" 2>/dev/null

# --- something from this app already running? ------------------------------------
mine=""; running=""
for pid in $(pgrep -f 'wine|\.exe'); do
  lsof -p "$pid" 2>/dev/null | grep -qF "$ENGINE" || continue
  mine="$mine $pid"
  cmd="$(ps -o command= -p "$pid")"
  case "$cmd" in
    *.exe*) printf '%s' "$cmd" | grep -qi 'windows\\system32' && continue
            case "$cmd" in *WorldOfWarplanes.exe*) running="the game";;
                           *wgc*) [ -z "$running" ] && running="Game Center";;
                           *) [ -z "$running" ] && running="a Windows program";; esac ;;
  esac
done
if [ -n "$running" ]; then
  rm -f "$FLAG"
  if [ "$running" = "Game Center" ]; then
    say "Game Center is still open (it may be installing or updating). Let it finish, then quit Game Center and open this app again to play."
  else
    say "World of Warplanes is already running ($running)."
  fi
  exit 10
fi
if [ -n "$mine" ]; then kill -9 $mine 2>/dev/null; sleep 1; fi    # stuck leftovers
rm -f "$LOCK"

# --- a Low Power session that never got cleaned up (crash, shutdown) --------------
if [ -f "$BACKUP" ] || [ -f "$CONF" ]; then
  rm -f "$CONF" "$SESSION"
  [ -f "$PREFS" ] && /usr/bin/python3 -I "$HERE/lowpower.py" restore "$PREFS" "$BACKUP"
fi

# --- helpers for Play ------------------------------------------------------------------
ensure_vulkan() {   # DXVK needs to find MoltenVK; the wrapper doesn't point to it by itself
  local icd="$HOME/.config/vulkan/icd.d/MoltenVK_icd.json" lib="$APP/Contents/Frameworks/libMVK.dylib" cur
  if [ -f "$icd" ]; then
    cur="$(/usr/bin/python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["ICD"]["library_path"])' "$icd" 2>/dev/null)"
    [ -n "$cur" ] && [ -f "$cur" ] && return
  fi
  mkdir -p "$(dirname "$icd")"
  printf '{\n    "file_format_version" : "1.0.0",\n    "ICD": {\n        "library_path": "%s",\n        "api_version" : "1.4.0",\n        "is_portability_driver" : false\n    }\n}\n' "$lib" > "$icd"
  log "vulkan icd written -> $lib"
}
prepare_prefs() {   # first launch: start from safe settings (graphics autodetect crashes under Wine)
  if [ ! -f "$PREFS" ] && [ -f "$HERE/starter-preferences.xml" ]; then
    mkdir -p "$PREFDIR"; cp "$HERE/starter-preferences.xml" "$PREFS"; log "starter preferences installed"
  fi
  [ -f "$PREFS" ] || return
  /usr/bin/python3 -I - "$PREFS" <<'PY'
import os, re, sys
p = sys.argv[1]; t = open(p, "rb").read().decode("latin-1"); o = t
for key, val in (("gsAutodetectEnabled", "false"), ("gsAutodetectInited2", "true")):
    t = re.sub(r"(<" + key + r">\s*)\w+(\s*</" + key + r">)", lambda m: m.group(1) + val + m.group(2), t, count=1)
if t != o:
    open(p + ".tmp", "wb").write(t.encode("latin-1")); os.replace(p + ".tmp", p)
PY
}
start_low_power() {
  [ -f "$PREFS" ] && [ -d "$GAMEDIR" ] || return
  local id="$$-$(date +%s)"
  printf '%s' "$id" > "$SESSION"
  printf 'd3d9.maxFrameRate = 30\r\n' > "$CONF"
  /usr/bin/python3 -I "$HERE/lowpower.py" apply "$PREFS" "$BACKUP"
  nohup /bin/bash -c '
    id="$0"; conf="$1"; prefs="$2"; backup="$3"; session="$4"; py="$5"
    for i in $(seq 1 90); do pgrep -f "WorldOfWarplanes\.exe" >/dev/null && break; sleep 2; done
    while pgrep -f "WorldOfWarplanes\.exe" >/dev/null; do sleep 5; done
    sleep 5
    [ "$(cat "$session" 2>/dev/null)" = "$id" ] || exit 0
    pgrep -f "WorldOfWarplanes\.exe" >/dev/null && exit 0
    rm -f "$conf" "$session"
    /usr/bin/python3 -I "$py" restore "$prefs" "$backup"
  ' "$id" "$CONF" "$PREFS" "$BACKUP" "$SESSION" "$HERE/lowpower.py" >/dev/null 2>&1 </dev/null &
  disown
}

install_game_center() {
  while true; do
    local b
    b=$(/usr/bin/osascript -e 'tell current application to activate' \
      -e "display dialog \"Game Center isn't installed yet.\" & return & return & \"1. Click Download and get the Wargaming Game Center installer from the World of Warplanes website for your region.\" & return & \"2. Click Choose Installer and pick the file you downloaded.\" buttons {\"Cancel\", \"Download…\", \"Choose Installer…\"} default button 3 cancel button 1 with title \"$TITLE\" with icon (POSIX file \"$ICON\")" \
      -e 'button returned of result' 2>/dev/null)
    case "$b" in
      "Download…")
        r=$(/usr/bin/osascript -e 'tell current application to activate' -e 'choose from list {"Asia", "North America", "Europe"} with title "World of Warplanes" with prompt "Which region do you play on?" OK button name "Open Website"' 2>/dev/null)
        case "$r" in Asia) open "https://worldofwarplanes.asia";; "North America") open "https://worldofwarplanes.com";; Europe) open "https://worldofwarplanes.eu";; esac ;;
      "Choose Installer…")
        f=$(/usr/bin/osascript -e 'tell current application to activate' -e 'POSIX path of (choose file with prompt "Choose the Wargaming Game Center installer (.exe):" default location (path to downloads folder))' 2>/dev/null)
        [ -n "$f" ] || continue
        case "$f" in *.exe|*.EXE) ;; *) say "That isn't a Windows installer (.exe). Pick the file you downloaded from the World of Warplanes website."; continue ;; esac
        use_mode gamecenter
        log "installing Game Center from $(basename "$f")"
        nohup "$APP/Contents/MacOS/Sikarugir" WSS-installer "$f" >/dev/null 2>&1 </dev/null &
        disown
        watch_and_restore
        exit 10 ;;
      *) exit 10 ;;
    esac
  done
}

play() {    # play [low]
  if ! game_path >/dev/null; then
    b=$(/usr/bin/osascript -e 'tell current application to activate' \
      -e "display dialog \"World of Warplanes isn't installed yet. Open Game Center to install it?\" buttons {\"Cancel\", \"Game Center\"} default button 2 cancel button 1 with title \"$TITLE\" with icon (POSIX file \"$ICON\")" \
      -e 'button returned of result' 2>/dev/null)
    [ "$b" = "Game Center" ] && game_center
    exit 10
  fi
  use_mode game
  ensure_vulkan
  prepare_prefs
  /bin/bash "$HERE/display-sync.sh" "$PREFS"
  local low="$1"
  if [ -z "$low" ]; then
    local batt pct; batt="$(pmset -g batt 2>/dev/null)"
    pct=$(printf '%s' "$batt" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
    if printf '%s' "$batt" | grep -q "Battery Power" && [ -n "$pct" ] && [ "$pct" -le 50 ]; then
      low=low
      /usr/bin/osascript -e "display notification \"Battery at ${pct}%: 30 FPS and lower graphics for this launch.\" with title \"World of Warplanes: Low Power mode\"" >/dev/null 2>&1
    fi
  fi
  [ "$low" = low ] && start_low_power
  log "play ${low:-normal}"
  exit 0
}

game_center() {
  wgc_path >/dev/null || install_game_center
  use_mode gamecenter
  log "game center"
  watch_and_restore
  exit 0
}

# --- what to do ------------------------------------------------------------------------
if [ -f "$FLAG" ]; then rm -f "$FLAG"; play low; fi

while true; do
  choice=$(/usr/bin/osascript -e 'tell current application to activate' \
    -e "choose from list {\"Play\", \"Game Center\", \"Settings…\"} with title \"$TITLE\" with prompt \"What would you like to do?\" default items {\"Play\"} OK button name \"Go\" cancel button name \"Cancel\"" 2>/dev/null)
  case "$choice" in
    Play) play ;;
    "Game Center") game_center ;;
    "Settings…")
      s=$(/usr/bin/osascript -e 'tell current application to activate' \
        -e 'choose from list {"Play in Low Power mode (30 FPS, lower graphics)", "Wrapper settings (Sikarugir Configure)", "Open the game folder"} with title "World of Warplanes" with prompt "Settings" OK button name "Open" cancel button name "Back"' 2>/dev/null)
      case "$s" in
        Play\ in\ Low*) play low ;;
        Wrapper*) open "$APP/Contents/Configure.app"; exit 10 ;;
        Open\ the*) if [ -d "$GAMEDIR" ]; then open "$GAMEDIR"; else open "$DRIVE"; fi; exit 10 ;;
        *) continue ;;
      esac ;;
    *) exit 10 ;;
  esac
done
