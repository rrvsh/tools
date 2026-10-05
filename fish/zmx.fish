function __zmx_attach
  set -l session $argv[1]

  env ZMX_SESSION_PREFIX= zmx attach "$session"
  set -l attach_status $status
  set -l sessions (env ZMX_SESSION_PREFIX= zmx list --short 2>/dev/null)

  if not contains -- "$session" $sessions
    exit 0
  end

  return $attach_status
end

function __zmx-cycle
  if not set -q ZMX_SESSION
    echo "zmx: not inside a zmx session" >&2
    return 1
  end

  set -l sessions (zmx list --short 2>/dev/null)
  set -l current_index (contains -i -- "$ZMX_SESSION" $sessions)
  if test -z "$current_index"
    echo "zmx: current session '$ZMX_SESSION' is not active" >&2
    return 1
  end

  if test (count $sessions) -eq 1
    return 0
  end

  set -l target_index
  switch $argv[1]
    case next
      set target_index (math "$current_index % "(count $sessions)" + 1")
    case prev
      set target_index (math "($current_index - 2 + "(count $sessions)") % "(count $sessions)" + 1")
    case '*'
      echo "zmx: expected next or prev" >&2
      return 2
  end

  env ZMX_SESSION_PREFIX= zmx attach "$sessions[$target_index]"
end

function __zmx-picker-host-rows
  set -l anchor $argv[1]
  set -l current_host $argv[2]
  set -l host $argv[3]

  set -l sessions
  if test "$host" = "$current_host"
    set sessions (env ZMX_SESSION_PREFIX= zmx list 2>/dev/null)
  else
    set sessions (
      ssh \
        -o BatchMode=yes \
        -o ConnectTimeout=3 \
        -o ControlMaster=auto \
        -o ControlPersist=60 \
        -o "ControlPath=$ZMX_SELECT_CONTROL_PATH" \
        "$host" \
        env ZMX_SESSION_PREFIX= zmx list 2>/dev/null
    )
  end
  set -l list_status $status
  if test $list_status -ne 0
    return $list_status
  end

  for metadata in $sessions
    set -l session (string match -r -g 'name=([^\t]+)' -- "$metadata")
    if test -z "$session"
      continue
    end

    set -l title (string match -r -g '(?:^|\t)title=([^\t]*)' -- "$metadata")
    if test -z "$title"
      set title $session
    end

    set -l key "$host/$session"
    set -l selection_marker '  '
    if test "$key" = "$anchor"
      set selection_marker '→ '
    end

    set -l clients (string match -r -g '(?:^|\t)clients=([0-9]+)' -- "$metadata")
    set -l attachment_marker '  '
    if test -n "$clients"; and test "$clients" -gt 0
      set attachment_marker '● '
    end

    set -l label $session
    if test "$title" != "$session"
      set label "$title  [$session]"
    end
    if test "$host" != "$current_host"
      set label "[$host] $label"
    end

    set -l encoded_session (printf '%s' "$session" | base64 | string join '')
    printf '%s\t%s\t%s\t%s%s%s\n' "$host" "$session" "$encoded_session" "$selection_marker" "$attachment_marker" "$label"
  end
end

function __zmx-picker-status-row
  set -l host $argv[1]
  set -l state $argv[2]
  set -l session_count $argv[3]

  switch "$state"
    case local
      printf '\t\t\t● %s: local · %s sessions\n' "$host" "$session_count"
    case reachable
      printf '\t\t\t● %s: reachable · %s sessions\n' "$host" "$session_count"
    case unreachable
      printf '\t\t\t× %s: unreachable\n' "$host"
    case connecting
      printf '\t\t\t… %s: connecting\n' "$host"
  end
end

function __zmx-picker-refresh-host
  set -l anchor $argv[1]
  set -l current_host $argv[2]
  set -l host $argv[3]
  set -l row_file $argv[4]
  set -l status_file $argv[5]
  set -l reload_command $argv[6]
  set -l socket $argv[7]
  set -l temporary_rows "$row_file.$fish_pid"
  set -l temporary_status "$status_file.$fish_pid"

  __zmx-picker-host-rows "$anchor" "$current_host" "$host" >"$temporary_rows"
  set -l list_status $status
  set -l session_count (string split \n <"$temporary_rows" | string match -r '.+' | count)
  if test $list_status -eq 0
    __zmx-picker-status-row "$host" reachable "$session_count" >"$temporary_status"
  else
    __zmx-picker-status-row "$host" unreachable >"$temporary_status"
  end
  command mv "$temporary_rows" "$row_file"
  command mv "$temporary_status" "$status_file"

  for attempt in (seq 20)
    if printf 'reload(%s)\n' "$reload_command" | sk --remote "$socket" >/dev/null 2>&1
      return
    end
    sleep 0.05
  end
end

function zmx-new
  set -l session $argv[1]
  if test -z "$session"
    set session "shell-"(date +%Y%m%d-%H%M%S)"-$fish_pid"
  end
  set -l effective_session "$ZMX_SESSION_PREFIX$session"
  set -g __zmx_selected_session (hostname -s)"/$effective_session"
  __zmx_attach "$effective_session"
end

function zmx-murder
  if not set -q ZMX_SESSION
    echo 'zmx: not inside a zmx session' >&2
    return 1
  end

  env ZMX_SESSION_PREFIX= zmx kill "$ZMX_SESSION"
end

function zmx-next
  __zmx-cycle next
end

function zmx-prev
  __zmx-cycle prev
end

function zmx-select
  if set -q ZMX_SESSION
    env ZMX_SESSION_PREFIX= zmx detach
    return $status
  end

  set -l current_host (hostname -s)
  set -l hosts alpha kikir nemesis
  if not contains -- "$current_host" $hosts
    set -p hosts "$current_host"
  end
  set -lx ZMX_SELECT_CONTROL_PATH "/tmp/zmx-select-"(id -u)'-%C'
  set -l anchor $argv[1]
  set -l marker
  if test -n "$anchor"
    set marker Previous
  end

  while true
    set -l local_rows (__zmx-picker-host-rows "$anchor" "$current_host" "$current_host")
    set -l anchor_label "$anchor"
    for row in $local_rows
      set -l fields (string split \t -- "$row")
      set -l session_key "$fields[1]/$fields[2]"
      if test "$session_key" = "$anchor"
        set anchor_label (string replace -r '^(?:→ |  )(?:● |  )' '' -- "$fields[4]")
      end
    end

    set -l header 'Enter: attach | Ctrl-N: create here | Ctrl-R: rename | Ctrl-J/K: next/previous | Ctrl-C: cancel'
    if test -n "$anchor"
      set header "$marker: $anchor_label | $header"
    end

    set -l row_directory (mktemp -d)
    if test $status -ne 0
      echo 'zmx: could not create picker row directory' >&2
      return 1
    end

    set -l row_files
    set -l status_files
    set -l display_hosts $current_host
    for host in $hosts
      if test "$host" != "$current_host"
        set -a display_hosts $host
      end
    end
    for host in $display_hosts
      set -l row_file "$row_directory/$host.rows"
      set -l status_file "$row_directory/$host.status"
      set -a row_files "$row_file"
      set -a status_files "$status_file"
      printf '' >"$row_file"
      if test "$host" = "$current_host"
        __zmx-picker-status-row "$host" local (count $local_rows) >"$status_file"
      else
        __zmx-picker-status-row "$host" connecting >"$status_file"
      end
    end
    if test (count $local_rows) -gt 0
      printf '%s\n' $local_rows >"$row_directory/$current_host.rows"
    end

    set -l worker_file "$row_directory/worker.fish"
    functions --no-details \
      __zmx-picker-host-rows \
      __zmx-picker-status-row \
      __zmx-picker-refresh-host \
      >"$worker_file"
    printf '\n__zmx-picker-refresh-host $argv\n' >>"$worker_file"

    set -l socket "zmx-select-$fish_pid-"(random)
    set -l reload_command (string join ' ' cat $status_files $row_files)
    set -l refresh_pids
    for host in $hosts
      if test "$host" != "$current_host"
        fish "$worker_file" \
          "$anchor" \
          "$current_host" \
          "$host" \
          "$row_directory/$host.rows" \
          "$row_directory/$host.status" \
          "$reload_command" \
          "$socket" &
        set -a refresh_pids $last_pid
      end
    end

    set -l output (
      command cat $status_files $row_files |
        sk \
          --listen "$socket" \
          --header-lines=(count $status_files) \
          --print0 \
          --print-query \
          --bind='ctrl-n:accept(ctrl-n),ctrl-r:accept(ctrl-r),ctrl-j:accept(ctrl-j),ctrl-k:accept(ctrl-k)' \
          --cycle \
          --delimiter='\t' \
          --with-nth=4 \
          --height=80% \
          --reverse \
          --prompt='zmx> ' \
          --header="$header" \
          --preview='session="$(printf "%s" {3} | base64 --decode)"; if [ {1} = "$(hostname -s)" ]; then env ZMX_SESSION_PREFIX= zmx history "$session"; else ssh -o BatchMode=yes -o ConnectTimeout=3 -o ControlMaster=auto -o ControlPersist=60 -o ControlPath="$ZMX_SELECT_CONTROL_PATH" {1} "set session (printf \"%s\" {3} | base64 --decode); env ZMX_SESSION_PREFIX= zmx history \"\$session\""; fi | tail -n "$(tput lines)"' \
          --preview-window=right:60% |
        string split0
    )

    set -l rows
    for row_file in $row_files
      set -a rows (string split \n <"$row_file")
    end

    for refresh_pid in $refresh_pids
      kill "$refresh_pid" 2>/dev/null
    end
    command rm -rf "$row_directory"

    if test (count $output) -eq 0
      return 130
    end

    set -l query $output[1]
    set -l key
    set -l row
    if test (count $output) -ge 2; and contains -- "$output[2]" ctrl-n ctrl-r ctrl-j ctrl-k
      set key $output[2]
      if test (count $output) -ge 3
        set row $output[-1]
      end
    else if test (count $output) -ge 2
      set row $output[-1]
    end

    if test "$key" = ctrl-n
      zmx-new "$query"
      return $status
    end

    set -l active_sessions
    for active_row in $rows
      set -l active_fields (string split \t -- "$active_row")
      set -a active_sessions "$active_fields[1]/$active_fields[2]"
    end

    set -l fields (string split \t -- "$row")
    set -l host $fields[1]
    set -l session $fields[2]
    set -l session_key "$host/$session"
    if contains -- "$key" ctrl-j ctrl-k
      if test -z "$session"
        continue
      end

      set -l current_index (contains -i -- "$session_key" $active_sessions)
      if test "$key" = ctrl-j
        set session_key $active_sessions[(math "$current_index % "(count $active_sessions)" + 1")]
      else
        set session_key $active_sessions[(math "($current_index - 2 + "(count $active_sessions)") % "(count $active_sessions)" + 1")]
      end
      set fields (string split -m 1 / -- "$session_key")
      set host $fields[1]
      set session $fields[2]
    end

    if test "$key" = ctrl-r
      if test -z "$session"
        echo 'zmx: select a session to rename' >&2
        continue
      end

      if not read --prompt-str='zmx title (empty clears): ' --local title
        continue
      end

      set -l rename_output
      if test "$host" = "$current_host"
        set rename_output (env ZMX_SESSION_PREFIX= zmx set "$session" "title=$title" 2>&1)
      else
        set -l encoded_session (printf '%s' "$session" | base64 | string join '')
        set -l encoded_title (printf '%s' "$title" | base64 | string join '')
        set -l remote_command "set session (printf '%s' '$encoded_session' | base64 --decode); set title (printf '%s' '$encoded_title' | base64 --decode); env ZMX_SESSION_PREFIX= zmx set \"\$session\" \"title=\$title\""
        set rename_output (
          ssh \
            -o BatchMode=yes \
            -o ConnectTimeout=3 \
            -o ControlMaster=auto \
            -o ControlPersist=60 \
            -o "ControlPath=$ZMX_SELECT_CONTROL_PATH" \
            "$host" \
            "$remote_command" 2>&1
        )
      end
      if test $status -ne 0
        printf '%s\n' "$rename_output" >&2
        read --prompt-str='Press Enter to continue' --local ignored
      end
      continue
    end

    if test -z "$session"
      return 130
    end

    set -g __zmx_selected_session "$host/$session"
    if test "$host" = "$current_host"
      __zmx_attach "$session"
    else
      set -l encoded_session (printf '%s' "$session" | base64 | string join '')
      set -l session_ended_status 200
      set -l remote_command "
        set session (printf '%s' '$encoded_session' | base64 --decode)
        env ZMX_SESSION_PREFIX= zmx attach \"\$session\"
        set attach_status \$status
        set sessions (env ZMX_SESSION_PREFIX= zmx list --short 2>/dev/null)

        if not contains -- \"\$session\" \$sessions
          exit $session_ended_status
        end

        exit \$attach_status
      "
      ssh \
        -t \
        -o BatchMode=yes \
        -o ConnectTimeout=3 \
        -o ControlMaster=auto \
        -o ControlPersist=60 \
        -o "ControlPath=$ZMX_SELECT_CONTROL_PATH" \
        "$host" \
        "$remote_command"
      set -l attach_status $status

      if test $attach_status -eq $session_ended_status
        exit 0
      end

      return $attach_status
    end
    return $status
  end
end

function __zmx_auto_attach --on-event fish_prompt
  functions --erase __zmx_auto_attach
  if set -q ZMX_SESSION; or set -q ZMX_NO_AUTO_ATTACH
    return
  end

  set -g __zmx_selected_session
  while true
    zmx-select "$__zmx_selected_session"
    if test $status -eq 130
      break
    end
  end
end
