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

printf 'zmx fish tests passed\n'
