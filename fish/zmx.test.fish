#!/usr/bin/env fish

source (path dirname (status filename))/zmx.fish

function assert_equal
  set -l expected $argv[1]
  set -l actual $argv[2]
  set -l message $argv[3]
  if test "$actual" != "$expected"
    printf 'FAIL: %s\nexpected: <%s>\nactual:   <%s>\n' "$message" "$expected" "$actual" >&2
    exit 1
  end
end

set -l clear_sequence (__zmx-picker-clear-viewport)
assert_equal (printf '\033[2J\033[H') "$clear_sequence" 'visible viewport clear sequence'
if string match -q "*"(printf '\033[3J')"*" -- "$clear_sequence"
  printf 'FAIL: viewport clear sequence erases scrollback\n' >&2
  exit 1
end

set -l now (date +%s)
assert_equal '… ' (__zmx-picker-pi-marker working 123 "$now" "$now") 'working marker'
assert_equal '! ' (__zmx-picker-pi-marker waiting 123 "$now" "$now") 'waiting marker'
assert_equal '  ' (__zmx-picker-pi-marker unknown 123 "$now" "$now") 'unknown state'
assert_equal '  ' (__zmx-picker-pi-marker working invalid "$now" "$now") 'invalid pid'
assert_equal '  ' (__zmx-picker-pi-marker waiting 123 (math "$now - 31") "$now") 'stale heartbeat'
assert_equal '  ' (__zmx-picker-pi-marker waiting 123 (math "$now + 6") "$now") 'future heartbeat'

set -l stub_directory (mktemp -d)
function cleanup --on-event fish_exit
  command rm -rf "$stub_directory"
end

printf '#!/bin/sh\nif [ "${ZMX_TEST_EMPTY:-}" = 1 ]; then exit 0; fi\ncat <<\x27EOF\x27\n  name=30 oct 26 09:38\tpid=1\tclients=1\tpi_heartbeat=%s\tpi_pid=123\tpi_state=working\ttitle=admin-sorting\n  name=29 oct 26 08:00\tpid=2\tclients=2\ttitle=old-review\n  name=28 oct 26 16:25\tpid=3\tclients=0\tpi_heartbeat=%s\tpi_pid=456\tpi_state=waiting\n  name=28 oct 26 09:00\tpid=4\tclients=0\tpi_heartbeat=%s\tpi_pid=789\tpi_state=working\ttitle=active-research\n  name=27 oct 26 16:32\tpid=5\tclients=1\tpi_heartbeat=%s\tpi_pid=987\tpi_state=waiting\ttitle=stale-thread\n  name=27 oct 26 10:00\tpid=6\tclients=0\tpi_heartbeat=%s\tpi_pid=654\tpi_state=waiting\ttitle=invoice-review\nEOF\n' "$now" "$now" "$now" (math "$now - 31") "$now" >"$stub_directory/zmx"
command chmod +x "$stub_directory/zmx"
set -lx PATH "$stub_directory:$PATH"
set -l preview_directory "$stub_directory/previews"
set -l rows (__zmx-picker-host-rows '' test test "$preview_directory")
assert_equal 6 (count $rows) 'row count'

set -l absent_one (string split \t -- "$rows[1]")
set -l absent_two (string split \t -- "$rows[2]")
set -l waiting_one (string split \t -- "$rows[3]")
set -l waiting_two (string split \t -- "$rows[4]")
set -l working_one (string split \t -- "$rows[5]")
set -l working_two (string split \t -- "$rows[6]")
assert_equal old-review "$absent_one[6]" 'blank sessions sort first'
assert_equal stale-thread "$absent_two[6]" 'stale sessions preserve blank-group order'
assert_equal '  ! 28 oct 26 16:25' "$waiting_one[4]" 'waiting sessions sort second'
assert_equal invoice-review "$waiting_two[6]" 'waiting sessions preserve source order'
assert_equal '  … admin-sorting' "$working_one[4]" 'working sessions sort last'
assert_equal active-research "$working_two[6]" 'working sessions preserve source order'
assert_equal admin-sorting "$working_one[6]" 'title hides timestamp'
assert_equal '28 oct 26 16:25' "$waiting_one[6]" 'timestamp fallback'
assert_equal "$preview_directory/MzAgb2N0IDI2IDA5OjM4" "$working_one[5]" 'stable preview path'

set -l anchored_rows (__zmx-picker-host-rows 'test/30 oct 26 09:38' test test "$preview_directory")
set -l anchored_working (string split \t -- "$anchored_rows[5]")
assert_equal '→ … admin-sorting' "$anchored_working[4]" 'selection follows a sorted session'

set -lx ZMX_TEST_EMPTY 1
set -l empty_rows (__zmx-picker-host-rows '' test test "$preview_directory")
set -e ZMX_TEST_EMPTY
assert_equal 0 (count $empty_rows) 'empty host has no phantom row'

set -l local_status (__zmx-picker-status-row test local 3)
set -l remote_status (__zmx-picker-status-row test reachable 3)
set -l connecting_status (__zmx-picker-status-row test connecting)
set -l unreachable_status (__zmx-picker-status-row test unreachable)
assert_equal (printf 'test\t\t\ttest: local · 3 sessions') "$local_status" 'local host row has no icon'
assert_equal (printf 'test\t\t\ttest: reachable · 3 sessions') "$remote_status" 'remote host row has no icon'
assert_equal (printf 'test\t\t\ttest: connecting') "$connecting_status" 'connecting host row has no icon'
assert_equal (printf 'test\t\t\ttest: unreachable') "$unreachable_status" 'unreachable host row has no icon'

set -l zmx_log "$stub_directory/zmx.log"
printf '#!/bin/sh\nprintf "marker=%%s args=%%s\\n" "${ZMX_STARTUP_EPHEMERAL:-}" "$*" >>"$ZMX_TEST_LOG"\ncase "$1" in\n  attach) exit 0 ;;\n  list) printf "sample\\nnormal\\n" ;;\n  set) [ "${ZMX_TEST_SET_FAIL:-}" != 1 ] ;;\nesac\n' >"$stub_directory/zmx"
command chmod +x "$stub_directory/zmx"
set -lx ZMX_TEST_LOG "$zmx_log"
set -lx XDG_RUNTIME_DIR "$stub_directory/runtime"

zmx-new --ephemeral sample
assert_equal 0 $status 'ephemeral session attaches successfully'
set -l ephemeral_attach (string match '*args=attach*' (string split \n -- (string collect <"$zmx_log")))
assert_equal 'marker=1 args=attach --labels startup_ephemeral=1 sample' "$ephemeral_attach" 'ephemeral session is labelled atomically'

printf '' >"$zmx_log"
zmx-new normal
assert_equal 0 $status 'normal session attaches successfully'
set -l normal_attach (string match '*args=attach*' (string split \n -- (string collect <"$zmx_log")))
assert_equal 'marker= args=attach normal' "$normal_attach" 'explicit session is not ephemeral'

set -l current_host (hostname -s)
printf '#!/bin/sh\nprintf "args=%%s\\n" "$*" >>"$ZMX_TEST_LOG"\ncase "$1" in\n  attach|kill) exit 0 ;;\n  set) [ "${ZMX_TEST_SET_FAIL:-}" != 1 ] ;;\n  list)\n    if [ "$2" = --short ]; then\n      printf "source\\ntarget\\n"\n    elif [ "${ZMX_TEST_EPHEMERAL:-}" = 1 ]; then\n      printf "  name=source\\tpid=1\\tclients=0\\tstartup_ephemeral=1\\n  name=target\\tpid=2\\tclients=0\\n"\n    else\n      printf "  name=source\\tpid=1\\tclients=0\\n  name=target\\tpid=2\\tclients=0\\n"\n    fi\n    ;;\nesac\n' >"$stub_directory/zmx"
printf '#!/bin/sh\nprintf "%%s\\t%s\\tdGFyZ2V0\\t  target\\t\\ttarget\\n" "$ZMX_TEST_HOST"\n' target >"$stub_directory/fzf"
printf '#!/bin/sh\nexit 1\n' >"$stub_directory/ssh"
command chmod +x "$stub_directory/zmx" "$stub_directory/fzf" "$stub_directory/ssh"
set -lx ZMX_TEST_HOST "$current_host"
set -e ZMX_SESSION

printf '' >"$zmx_log"
set -lx ZMX_TEST_EPHEMERAL 1
zmx-select "$current_host/source"
assert_equal 0 $status 'picker attaches to a selected local session'
set -l unused_kill (string match 'args=kill source' (string split \n -- (string collect <"$zmx_log")))
assert_equal 'args=kill source' "$unused_kill" 'switching removes an unused startup session'

printf '' >"$zmx_log"
set -e ZMX_TEST_EPHEMERAL
zmx-select "$current_host/source"
assert_equal 0 $status 'picker attaches after a startup session is promoted'
set -l promoted_kill (string match 'args=kill source' (string split \n -- (string collect <"$zmx_log")))
assert_equal 0 (count $promoted_kill) 'switching preserves a promoted startup session'

printf '' >"$zmx_log"
set -gx ZMX_SESSION sample
set -gx ZMX_STARTUP_EPHEMERAL 1
set -lx ZMX_TEST_SET_FAIL 1
__zmx_promote_startup_session_on_command true 2>/dev/null
assert_equal 1 "$ZMX_STARTUP_EPHEMERAL" 'failed promotion retains the shell marker'
assert_equal 1 (functions --query __zmx_promote_startup_session_on_command; and echo 1; or echo 0) 'failed promotion retains the event handler'

set -e ZMX_TEST_SET_FAIL
__zmx_promote_startup_session_on_command true
assert_equal 0 (set -q ZMX_STARTUP_EPHEMERAL; and echo 1; or echo 0) 'successful promotion clears the shell marker'
assert_equal 0 (functions --query __zmx_promote_startup_session_on_command; and echo 1; or echo 0) 'successful promotion removes the event handler'
set -l promotion_calls (string match '*args=set . startup_ephemeral=' (string split \n -- (string collect <"$zmx_log")))
assert_equal 2 (count $promotion_calls) 'promotion retries after a failure'
set -e ZMX_SESSION

printf 'zmx fish tests passed\n'
