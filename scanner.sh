#!/usr/bin/env bash
#
# ============================================================================
#  BOILERPLATE : Linux Security Assessment Tool  (IS2083 Lab 1)
# ============================================================================
#  This is a boilerplate you can use to create your own script. Copy it,
#  rename it, and fill in each TODO section by section, following the handout.
#  Do not skip ahead: build and test one section at a time.
#
#  Target: a Debian based Linux VM (Ubuntu or Kali). Run from a terminal.
#  On a Red Hat based system, replace the Debian commands with equivalents
#  (apt -> dnf, ufw -> firewalld, /var/log/auth.log -> /var/log/secure).
# ============================================================================

set -u   # catch unset variables. We avoid 'set -e' so one failed check
         # does not stop the whole assessment.

# --- Section 2: Name the tool ------------------------------------------------
TOOL_NAME="Linux Scanner 0.1"

# --- Section 3: Startup dialog -----------------------------------------------
# TODO: show a zenity info box that says "<TOOL_NAME> has started".
#       Fall back to echo if zenity is missing.
# TODO: cache sudo once with:  sudo -v

zenity --info --title "$TOOL_NAME" --text "$TOOL_NAME has started" 2>/dev/null \
	|| echo "[$TOOL_NAME] started"
sudo -v

# --- Section 4: Report creation (file manipulation) --------------------------
# TODO: make WORKDIR under $HOME, build a timestamped REPORT path, touch it,
#       and write log() and section() helpers that echo AND append with tee -a.

WORKDIR="$HOME/${TOOL_NAME}_reports"
mkdir -p "$WORKDIR"
REPORT="$WORKDIR/report_$(date +%F_%H%M%S).txt"
touch "$REPORT"

log() {
	echo "$*" | tee -a "$REPORT"
}

section() {
	log ""
	log "==== $* ===="
}

log "$TOOL_NAME security report"
log "Generated: $(date)"
log "Host:      $(hostname)"
log "Run by:    $(whoami)"

# --- Section 5: System administration ----------------------------------------
# TODO: report OS, uptime, disk usage, UID 0 accounts, sudo group members,
#       and the count of upgradable packages. Save the count in UPGRADES.

section "System administration"
log "Operating system : $(uname -srm)"
log "Uptime : $(uptime -p)"
log "Disk usage on / :"
df -h / | tee -a "$REPORT"
log "Accounts with root privileges (UID 0):"
awk -F: '$3==0 {print " " $1}' /etc/passwd | tee -a "$REPORT"
log "Members of the sudo group:"
getent group sudo | cut -d: -f4 | tr ',' '\n' | sed 's/^/ /' | tee -a "$REPORT"
UPGRADES=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)
log "Packages that can be upgraded: $UPGRADES"

# --- Section 6: Process control ----------------------------------------------
# TODO: report process count, top 5 by CPU and by memory, listening services,
#       then start a background 'sleep' job, capture its PID with $!, and kill it.

section "Process control"
log "Total running processes: $(ps -e --no-headers | wc -l)"
log "Top 5 processes by CPU:"
ps -eo pid,comm,%cpu --sort=-%cpu | head -n 6 | tee -a "$REPORT"
log "Top 5 processes by memory:"
ps -eo pid,comm,%mem --sort=-%mem | head -n 6 | tee -a "$REPORT"
log "Network services that are listening:"
ss -tuln | tee -a "$REPORT"
log "Starting a temporary background watcher..."
sleep 120 &
WATCHER_PID=$!
log " watcher started as PID $WATCHER_PID"
kill "$WATCHER_PID" 2>/dev/null && log " watcher (PID $WATCHER_PID) stopped"

# --- Section 7: File security audit ------------------------------------------
# TODO: count and list world writable files under /home (save in WORLD_WRITABLE),
#       list SUID programs, and show permissions of /etc/passwd and /etc/shadow.

section "File and permission audit"
WORLD_WRITABLE=$(find /home -xdev -type f -perm -0002 2>/dev/null | wc -l)
log "World writable files under /home: $WORLD_WRITABLE"
find /home -xdev -type f -perm -0002 2>/dev/null | sed 's/^/ /' | tee -a "$REPORT"
log "SUID programs under /usr/bin and /usr/sbin:"
find /usr/bin /usr/sbin -xdev -type f -perm -4000 2>/dev/null | sed 's/^/ /' | tee
-a "$REPORT"
log "Permissions on sensitive files:"
ls -l /etc/passwd /etc/shadow | tee -a "$REPORT"

# --- Section 8: Security hardening --------------------------------------------
# TODO: enable ufw (default deny incoming) and set FW_ENABLED to 1 or 0;
#       count failed SSH logins into FAILED; count empty password accounts into EMPTY.

section "Hardening actions"
if command -v ufw >/dev/null; then
  sudo ufw --force enable >/dev/null
  sudo ufw default deny incoming >/dev/null
  sudo ufw default allow outgoing >/dev/null
  FW_ENABLED=1
  log "Firewall (ufw) enabled with default deny incoming."
  sudo ufw status verbose | tee -a "$REPORT"
else
  FW_ENABLED=0
  log "ufw is not installed. Install: sudo apt install ufw"
fi
FAILED=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
log "Failed SSH login attempts on record: $FAILED"
EMPTY=$(sudo awk -F: '($2==""){print $1}' /etc/shadow 2>/dev/null | wc -l)
log "Accounts with an EMPTY password: $EMPTY (should be 0)"

# --- Section 9: Security score -----------------------------------------------
# TODO: start SCORE at 100 and subtract points for each finding
#       (UPGRADES, WORLD_WRITABLE, FAILED, EMPTY, FW_ENABLED). Clamp at 0.
#       Set RATING to STRONG / MODERATE / NEEDS WORK, and log the score.

section "Security score"
SCORE=100
[ "$UPGRADES" -gt 0 ] && SCORE=$((SCORE - 10))
[ "$WORLD_WRITABLE" -gt 0 ] && SCORE=$((SCORE - 15))
[ "$FAILED" -gt 20 ] && SCORE=$((SCORE - 10))
[ "$EMPTY" -gt 0 ] && SCORE=$((SCORE - 30))
[ "$FW_ENABLED" -eq 0 ] && SCORE=$((SCORE - 20))
[ "$SCORE" -lt 0 ] && SCORE=0
if [ "$SCORE" -ge 90 ]; then RATING="STRONG"
elif [ "$SCORE" -ge 70 ]; then RATING="MODERATE"
else RATING="NEEDS WORK"
fi
log "Security score: $SCORE / 100 ($RATING)"

# --- Section 10: Completion dialog -------------------------------------------
# TODO: chmod 600 the report, then show a zenity box that says
#       "<TOOL_NAME> has completed", the security score, and the report path.

section "Finishing up"
chmod 600 "$REPORT"
log "Report locked to owner only (chmod 600)."
log "Report saved to: $REPORT"
zenity --info --width=420 --title="$TOOL_NAME" \
       --text="$TOOL_NAME has completed."$'\n'"Security score: $SCORE / 100 ($RATING)" \
       2>/dev/null || echo "[$TOOL_NAME] completed. Score: $SCORE/100"

# --- Section 11: GitHub (do this in the terminal, not in the script) ---------
#   git init
#   git add .
#   git commit -m "Version 1.0 of my Linux Security Assessment Tool"
#   git branch -M main
#   git remote add origin <your repo URL>
#   git push -u origin main

# vim: ts=2 sw=2 et:
