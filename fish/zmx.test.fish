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

printf '#!/bin/sh\ncat <<\x27EOF\x27\n  name=30 oct 26 09:38\tpid=1\tclients=1\tpi_heartbeat=%s\tpi_pid=123\tpi_state=working\ttitle=admin-sorting\n  name=28 oct 26 16:25\tpid=2\tclients=0\tpi_heartbeat=%s\tpi_pid=456\tpi_state=waiting\n  name=27 oct 26 16:32\tpid=3\tclients=2\nEOF\n' "$now" "$now" >"$stub_directory/zmx"
command chmod +x "$stub_directory/zmx"
set -lx PATH "$stub_directory:$PATH"
set -l preview_directory "$stub_directory/previews"
set -l rows (__zmx-picker-host-rows '' test test "$preview_directory")
assert_equal 3 (count $rows) 'row count'

set -l working (string split \t -- "$rows[1]")
assert_equal '  … admin-sorting' "$working[4]" 'working row display'
assert_equal admin-sorting "$working[6]" 'title hides timestamp'
assert_equal "$preview_directory/MzAgb2N0IDI2IDA5OjM4" "$working[5]" 'stable preview path'

set -l waiting (string split \t -- "$rows[2]")
assert_equal '  ! 28 oct 26 16:25' "$waiting[4]" 'waiting row display'
assert_equal '28 oct 26 16:25' "$waiting[6]" 'timestamp fallback'

set -l absent (string split \t -- "$rows[3]")
assert_equal '    27 oct 26 16:32' "$absent[4]" 'client count does not mark absent Pi'

set -l local_status (__zmx-picker-status-row test local 3)
set -l remote_status (__zmx-picker-status-row test reachable 3)
set -l connecting_status (__zmx-picker-status-row test connecting)
set -l unreachable_status (__zmx-picker-status-row test unreachable)
assert_equal (printf 'test\t\t\ttest: local · 3 sessions') "$local_status" 'local host row has no icon'
assert_equal (printf 'test\t\t\ttest: reachable · 3 sessions') "$remote_status" 'remote host row has no icon'
assert_equal (printf 'test\t\t\ttest: connecting') "$connecting_status" 'connecting host row has no icon'
assert_equal (printf 'test\t\t\ttest: unreachable') "$unreachable_status" 'unreachable host row has no icon'

printf 'zmx fish tests passed\n'
