# End-to-end checks for Plania. Sourced by scripts/smoke.sh after the tab tour, with the app
# open on Home. Uses the helpers defined there (tap_text, type_text, expect, shot, ...).

# Scroll the current screen up by about half its height (works at any emulator resolution).
swipe_up() {
  local size w h
  size=$(adb shell wm size | tr -d '\r' | awk '{print $NF}' | tail -1)
  w=${size%x*}; h=${size#*x}
  adb shell input swipe $((w / 2)) $((h * 3 / 4)) $((w / 2)) $((h / 4)) 400; sleep 1
}
# smoke.sh's scroll_to swipes at fixed coordinates; this screen size needs swipe_up.
swipe_to() { for i in 1 2 3 4 5 6; do has_text "$1" && return 0; swipe_up; done; has_text "$1"; }

# --- Tasks: create, complete, then find it with search ---------------------------------------
tap_text "Tasks"; sleep 2
tap_text "New task"; sleep 2
tap_class EditText 0; type_text "Buy oat milk"; hide_keyboard
shot e2e-task-editor
tap_text "Save"; sleep 2
expect "Buy oat milk" 10 "task is created and listed"
tap_text "Complete Buy oat milk"; sleep 2
expect_not "Complete Buy oat milk" 2 "completed task leaves the open list"
tap_text "Done"; sleep 2
expect "Reopen Buy oat milk" 10 "completed task shows under Done"
tap_text "Search"; sleep 2
type_text "oat milk"; hide_keyboard
expect "Buy oat milk" 10 "search finds the completed task"
shot e2e-search
back

# --- Reminder: a task due next week with a reminder registers a system alarm -----------------
tap_text "Open"; sleep 1
tap_text "New task"; sleep 2
tap_class EditText 0; type_text "Renew passport"; hide_keyboard
has_text "Next week" || swipe_up
tap_text "Next week"; sleep 1
for i in 1 2 3; do has_text "1 day before" && break; swipe_up; done
tap_text "1 day before"; sleep 1
tap_text "Save"; sleep 3
expect "Renew passport" 10 "task with a reminder is saved"
expect "Reminder" 5 "task row shows its reminder"
if adb shell dumpsys alarm | grep -q "dev.basalt.lifeos"; then pass "reminder alarm is scheduled with the system"; else fail "no alarm scheduled for the reminder"; fi

# --- Notes: create one and find it with search -----------------------------------------------
tap_text "Notes"; sleep 2
tap_text "New note"; sleep 2
type_text "Packing list"
tap_class EditText 1; type_text "passport and charger"; hide_keyboard
shot e2e-note-editor
tap_text "Done"; sleep 2
expect "Packing list" 10 "note is saved"
tap_class EditText 0; type_text "charger"; hide_keyboard
expect "Packing list" 10 "notes search finds the note"
expect_not "No matching notes" 1 "notes search has a result"
shot e2e-notes

# --- Categories, swipe with Undo, note lines into tasks, insights (2.2) -----------------------
# Swipe a task row (found by its text) from left to right.
swipe_right_on() {
  local xy size w; dump; xy=$(_find contains "$1"); [ -n "$xy" ] || return 1
  size=$(adb shell wm size | tr -d '\r' | awk '{print $NF}' | tail -1); w=${size%x*}
  set -- $xy
  adb shell input swipe $((w / 10)) "$2" $((w * 9 / 10)) "$2" 300
}
tap_text "Tasks"; sleep 2
tap_text "New task"; sleep 2
tap_class EditText 0; type_text "Draft report"; hide_keyboard
tap_text "Work"; sleep 1
shot e2e-task-category
tap_text "Save"; sleep 2
expect "Work 1" 10 "a Work task makes the Work count 1"
shot e2e-categories
swipe_right_on "Draft report"; sleep 1
dump
UNDO_XY=$(_find exact "Undo")
# Tap Undo from this same screen dump: the snackbar only stays for a few seconds.
[ -n "$UNDO_XY" ] && adb shell input tap $UNDO_XY
if [ -n "$UNDO_XY" ] && [ -z "$(_find contains "Complete Draft report")" ]; then
  pass "swipe right completes the task and offers Undo"
else
  fail "swipe right completes the task and offers Undo"
fi
sleep 2
shot e2e-swipe-undo
tap_text "Insights"; sleep 2
expect "1 completed today · 1-day streak" 8 "insights show 1 completed today and a 1-day streak"
shot e2e-insights
back
swipe_to "Complete Draft report" && pass "Undo reopens the swiped task" || fail "Undo reopens the swiped task"

tap_text "Notes"; sleep 2
tap_text "New note"; sleep 2
type_text "Errands"
tap_class EditText 1
type_text "Buy stamps"; adb shell input keyevent 66
type_text "Post letter"; adb shell input keyevent 66
type_text "Call bank"
tap_text "Turn into tasks"; sleep 2
expect "Create 3 tasks?" 5 "a 3-line note offers 3 tasks"
shot e2e-note-to-tasks
tap_text "Create"; sleep 2
tap_text "Done"; sleep 2
tap_text "Tasks"; sleep 2
expect "General 4" 8 "the new tasks are counted under General (with Renew passport)"
for t in "Buy stamps" "Post letter" "Call bank"; do
  swipe_to "$t" && pass "note line '$t' is a task" || fail "note line '$t' is a task"
done
shot e2e-tasks-from-note

# --- Habits: add one and check it off for today ----------------------------------------------
tap_text "More"; sleep 2
shot e2e-more
tap_text "Habits"; sleep 2
tap_text "New habit"; sleep 2
type_text "Drink water"; hide_keyboard
tap_text "Save"; sleep 2
expect "Drink water" 10 "habit is created"
tap_text "Check off Drink water"; sleep 2
expect "Undo Drink water today" 10 "habit is checked off today"
expect "1-day streak" 5 "streak starts at one day"
shot e2e-habits
back

# --- Expenses: add one and see the monthly total ---------------------------------------------
tap_text "Expenses"; sleep 2
tap_text "Add expense"; sleep 2
tap_class EditText 0; type_text "12.50"
tap_class EditText 1; type_text "Lunch"; hide_keyboard
tap_text "Save"; sleep 2
expect "12.50" 10 "monthly total shows the expense"
expect "Lunch" 5 "expense is listed"
shot e2e-expenses

# --- Recurring: a monthly expense dated today is posted and counted this month ----------------
tap_text "Add expense"; sleep 2
tap_class EditText 0; type_text "1200"
tap_class EditText 1; type_text "Rent"; hide_keyboard
tap_text "Monthly"; sleep 1
expect "Each one is added on its day" 5 "editor explains the monthly schedule"
shot e2e-recurring-editor
tap_text "Save"; sleep 3
expect "1,212.50" 10 "this month's total includes the recurring expense"
expect "RECURRING" 5 "Recurring section lists the rule"
expect "Monthly on the" 5 "recurring rule shows its schedule"
shot e2e-recurring
back

# --- Assistant: answers come from the data above ---------------------------------------------
tap_text "Assistant"; sleep 2
tap_text "Plan my day"; sleep 2
expect "Next up: Renew passport" 5 "assistant plans the day from real data"
tap_text "What's overdue?"; sleep 2
expect "Nothing is overdue" 5 "assistant answers the overdue question"
shot e2e-assistant
back

# --- Settings renders --------------------------------------------------------------------------
tap_text "Home"; sleep 2
tap_text "Settings"; sleep 2
shot e2e-settings
# Reminders come with Mark done and Snooze buttons (the test notification uses the same layout).
tap_text "Send a test notification"; sleep 3
adb shell dumpsys notification --noredact > "$OUT/notifications.txt" 2>/dev/null
if grep -q "Mark done" "$OUT/notifications.txt" && grep -q "Snooze 10 min" "$OUT/notifications.txt"; then
  pass "reminder notification has Mark done and Snooze actions"
else
  fail "reminder notification has Mark done and Snooze actions"
fi
swipe_to "Launcher shortcuts" && pass "settings list the launcher shortcuts" || fail "settings list the launcher shortcuts"
has_text "Quick Settings tile" && pass "settings explain quick access" || fail "settings explain quick access"
shot e2e-settings-quick-access
swipe_to "Plania keeps everything on this phone" && pass "settings use the new name" || fail "settings use the new name"
has_text "Export backup" && pass "settings show backup options" || fail "settings show backup options"
shot e2e-settings-data

# --- Encrypted backup: the passphrase sheet, then the system save dialog ----------------------
# At the very bottom of Settings the backup rows are always on screen.
swipe_up; swipe_up; swipe_up; swipe_up
tap_text "Export backup"; sleep 2
expect "Protect this backup" 8 "export asks for a passphrase"
expect "Skip, save without a passphrase" 3 "passphrase can be skipped"
shot e2e-backup-passphrase
# The passphrase field has focus. Enter moves to the repeat field, then submits.
type_text "plania-pass-42"; adb shell input keyevent 66; sleep 1
type_text "plania-pass-42"; adb shell input keyevent 66
SAVE_UI=0
for i in $(seq 1 20); do
  if adb shell dumpsys window | grep -E "mCurrentFocus|mFocusedApp" | grep -q documentsui; then SAVE_UI=1; break; fi
  sleep 2
done
shot e2e-backup-save-dialog
if [ "$SAVE_UI" = 1 ]; then pass "encrypted backup reaches the system save dialog"; else fail "encrypted backup reaches the system save dialog"; fi
back; back
alive || fail "app survives cancelling the backup save"
adb shell am force-stop com.google.android.documentsui >/dev/null 2>&1
adb shell am force-stop com.android.documentsui >/dev/null 2>&1
adb shell am force-stop "$PKG"; sleep 2
launch
wait_for "Today" 20

# --- Calendar: add an event for today ----------------------------------------------------------
tap_text "Calendar"; sleep 2
tap_text "New event"; sleep 2
type_text "Team lunch"; hide_keyboard
tap_text "Save"; sleep 2
expect "Team lunch" 10 "event shows on the selected day"
shot e2e-calendar

# --- Relaunch: everything is still there -------------------------------------------------------
adb shell am force-stop "$PKG"; sleep 2
launch
expect "Today" 20 "app reopens on Home"
expect "Drink water" 10 "habit persisted"
expect "Team lunch" 5 "event persisted"
shot e2e-home-after-relaunch
tap_text "Tasks"; sleep 2
expect "Renew passport" 10 "open task persisted"
tap_text "Done"; sleep 2
expect "Reopen Buy oat milk" 10 "completed task persisted"
tap_text "Notes"; sleep 2
expect "Packing list" 10 "note persisted"
tap_text "More"; sleep 2
tap_text "Expenses"; sleep 2
expect "12.50" 10 "expense persisted"
expect "Rent" 5 "recurring expense persisted"
back

# --- Quick access: widget, launcher shortcuts and the New task tile ---------------------------
adb shell dumpsys appwidget > "$OUT/appwidget.txt" 2>/dev/null
grep -q "$PKG/$PKG.TodayWidget" "$OUT/appwidget.txt" && pass "Today widget is registered" || fail "Today widget is registered"
adb shell dumpsys shortcut > "$OUT/shortcuts.txt" 2>/dev/null
for id in new-task new-note focus; do
  grep -A150 "Package: $PKG" "$OUT/shortcuts.txt" | grep -q "id=$id" && pass "launcher shortcut $id" || fail "launcher shortcut $id"
done

adb shell am force-stop "$PKG"; sleep 2
launch
wait_for "Today" 20
TILE="$PKG/$PKG.NewTaskTileService"
adb shell cmd statusbar add-tile "$TILE" >/dev/null 2>&1; sleep 1
adb logcat -c
adb shell cmd statusbar click-tile "$TILE" >/dev/null 2>&1; sleep 4
adb shell cmd statusbar collapse >/dev/null 2>&1; sleep 2
shot e2e-tile
# The title field has focus and the keyboard is up, so check without scrolling.
if wait_contains "CATEGORY" 5 && has_text "New task"; then pass "New task tile opens the task editor"; else fail "New task tile opens the task editor"; fi
adb logcat -d | grep -q "FATAL EXCEPTION" && fail "tile opens the app without crashing" || pass "tile opens the app without crashing"

# Cold start from the New note shortcut's intent.
adb shell am force-stop "$PKG"; sleep 2
adb shell am start -n "$PKG/.MainActivity" --es plania.action new-note >/dev/null 2>&1; sleep 6
shot e2e-shortcut-note
if wait_contains "Add checklist item" 5; then pass "New note shortcut opens the note editor"; else fail "New note shortcut opens the note editor"; fi

# Start focus shortcut while the app is open.
adb shell am start -n "$PKG/.MainActivity" --es plania.action focus >/dev/null 2>&1; sleep 4
shot e2e-shortcut-focus
if wait_contains "Pause" 5; then pass "Start focus shortcut starts a session"; else fail "Start focus shortcut starts a session"; fi
tap_text "Stop"; sleep 1
alive || fail "app is not running at the end of the end-to-end checks"

# --- Appearance: draft preview, Apply, persistence after restart, reset -----------------------
read -r AW AH <<<"$(adb shell wm size | grep -o '[0-9]*x[0-9]*' | tail -1 | tr x ' ')"; AW=${AW:-1080}; AH=${AH:-1920}
# Scroll until an exact label sits in the upper part of the screen (clear of bars), then tap it.
scroll_tap() {
  for i in $(seq 1 10); do
    dump; xy=$(_find exact "$1")
    if [ -n "$xy" ] && [ "${xy#* }" -lt $((AH*65/100)) ]; then adb shell input tap $xy; echo "tapped '$1' at $xy"; return 0; fi
    swipe_up
  done
  return 1
}
is_selected() { dump; python3 - "$1" <<'PY'
import re, sys, html
xml = open('/tmp/ui.xml', encoding='utf-8', errors='ignore').read()
for m in re.finditer(r'<node [^>]*>', xml):
    n = m.group(0)
    vals = [html.unescape(v) for v in re.findall(r' (?:text|content-desc)="([^"]*)"', n)]
    if any(v == sys.argv[1] or sys.argv[1] in v.split('\n') for v in vals):
        sys.exit(0 if ('selected="true"' in n or 'checked="true"' in n) else 1)
sys.exit(1)
PY
}
adb shell am force-stop "$PKG"; sleep 2
launch; sleep 6
tap_text "Home"; sleep 2
tap_text "Settings"; sleep 2
scroll_tap "Appearance"; sleep 3
expect "Plania, your way" 10 "Appearance screen opens with a live preview"
shot e2e-appearance
scroll_tap "Teal accent"; sleep 1
scroll_tap "Manrope font"; sleep 1
scroll_tap "Cool background"; sleep 1
scroll_tap "Glass"; sleep 1
scroll_tap "Floating"; sleep 1
shot e2e-appearance-draft
expect "Apply" 5 "changes wait for Apply"
tap_text "Apply"; sleep 2
expect_not "Discard" 2 "Apply saves the draft"
back; back
shot e2e-appearance-applied
adb shell am force-stop "$PKG"; sleep 2
launch; sleep 6
shot e2e-appearance-after-restart
tap_text "Home"; sleep 2
tap_text "Settings"; sleep 2
scroll_tap "Appearance"; sleep 3
for i in 1 2 3; do has_text "Teal accent" && break; swipe_up; done
if is_selected "Teal accent"; then pass "accent choice survives a restart"; else fail "accent choice survives a restart"; fi
swipe_to "Manrope font" >/dev/null
if is_selected "Manrope font"; then pass "font choice survives a restart"; else fail "font choice survives a restart"; fi
scroll_to "Reset to default" >/dev/null; tap_text "Reset to default"; sleep 1
tap_text "Apply"; sleep 2
for i in 1 2 3 4 5 6 7 8; do adb shell input swipe $((AW/2)) $((AH*30/100)) $((AW/2)) $((AH*80/100)) 200; done; sleep 1
for i in 1 2 3; do has_text "Plania accent" && break; swipe_up; done
if is_selected "Plania accent"; then pass "Reset to default returns to the app colour"; else fail "Reset to default returns to the app colour"; fi
back
alive || fail "app died during the appearance checks"
