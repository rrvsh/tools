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

function __zmx-picker-rows
  set -l anchor $argv[1]
  set -l current_host $argv[2]

  for host in $argv[3..-1]
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
end

function zmx-new
  set -l session $argv[1]
  if test -z "$session"
    set session "shell-"(date +%Y%m%d-%H%M%S)"-$fish_pid"
  end
  set -g __zmx_selected_session (hostname -s)"/$ZMX_SESSION_PREFIX$session"
  zmx attach "$session"
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
    set -l rows (__zmx-picker-rows "$anchor" "$current_host" $hosts)
    set -l active_sessions
    set -l anchor_label
    for row in $rows
      set -l fields (string split \t -- "$row")
      set -l session_key "$fields[1]/$fields[2]"
      set -a active_sessions "$session_key"
      if test "$session_key" = "$anchor"
        set anchor_label (string replace -r '^(?:→ |  )(?:● |  )' '' -- "$fields[4]")
      end
    end

    if test -n "$anchor"; and not contains -- "$anchor" $active_sessions
      set anchor
      set marker
    end

    set -l header 'Enter: attach | Ctrl-N: create here | Ctrl-R: rename | Ctrl-J/K: next/previous | Ctrl-C: cancel'
    if test -n "$anchor"
      set header "$marker: $anchor_label | $header"
    end

    set -l output (
      printf '%s\n' $rows |
        sk \
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
      env ZMX_SESSION_PREFIX= zmx attach "$session"
    else
      set -l encoded_session (printf '%s' "$session" | base64 | string join '')
      set -l remote_command "set session (printf '%s' '$encoded_session' | base64 --decode); env ZMX_SESSION_PREFIX= zmx attach \"\$session\""
      ssh \
        -t \
        -o BatchMode=yes \
        -o ConnectTimeout=3 \
        -o ControlMaster=auto \
        -o ControlPersist=60 \
        -o "ControlPath=$ZMX_SELECT_CONTROL_PATH" \
        "$host" \
        "$remote_command"
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
