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
  for session in (zmx list --short 2>/dev/null)
    set -l title (env ZMX_SESSION_PREFIX= zmx get "$session" title 2>/dev/null)
    if test $status -ne 0; or test -z "$title"
      set title $session
    end

    set -l prefix '  '
    if test "$session" = "$anchor"
      set prefix '→ '
    end

    if test "$title" = "$session"
      printf '%s/%s%s\n' "$session" "$prefix" "$session"
    else
      printf '%s/%s%s  [%s]\n' "$session" "$prefix" "$title" "$session"
    end
  end
end

function zmx-new
  set -l session $argv[1]
  if test -z "$session"
    set session "shell-"(date +%Y%m%d-%H%M%S)"-$fish_pid"
  end
  set -g __zmx_selected_session "$ZMX_SESSION_PREFIX$session"
  zmx attach "$session"
end

function zmx-next
  __zmx-cycle next
end

function zmx-prev
  __zmx-cycle prev
end

function zmx-select
  set -l anchor
  set -l marker
  if set -q ZMX_SESSION
    set anchor "$ZMX_SESSION"
    set marker Current
  else if test -n "$argv[1]"
    set anchor "$argv[1]"
    set marker Previous
  end

  set -l active_sessions (zmx list --short 2>/dev/null)
  if test -n "$anchor"; and not contains -- "$anchor" $active_sessions
    set anchor
    set marker
  end

  while true
    set -l header 'Enter: attach | Ctrl-N: create | Ctrl-R: rename | Ctrl-J/K: next/previous | Ctrl-C: cancel'
    if test -n "$anchor"
      set -l anchor_title (env ZMX_SESSION_PREFIX= zmx get "$anchor" title 2>/dev/null)
      if test $status -eq 0; and test -n "$anchor_title"; and test "$anchor_title" != "$anchor"
        set header "$marker: $anchor_title [$anchor] | $header"
      else
        set header "$marker: $anchor | $header"
      end
    end

    set -l output (
      __zmx-picker-rows "$anchor" |
        sk \
          --print0 \
          --print-query \
          --expect=ctrl-n,ctrl-r \
          --bind='ctrl-j:down+accept,ctrl-k:up+accept' \
          --cycle \
          --delimiter='/' \
          --with-nth=2 \
          --height=80% \
          --reverse \
          --prompt='zmx> ' \
          --header="$header" \
          --preview='env ZMX_SESSION_PREFIX= zmx history {1} | tail -n "$(tput lines)"' \
          --preview-window=right:60% |
        string split0
    )

    if test (count $output) -eq 0
      return 130
    end

    set -l query $output[1]
    set -l key
    set -l row
    if test (count $output) -ge 2; and contains -- "$output[2]" ctrl-n ctrl-r
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

    set -l session (string split -m 1 / -- "$row")[1]
    if test "$key" = ctrl-r
      if test -z "$session"
        echo 'zmx: select a session to rename' >&2
        continue
      end

      if not read --prompt-str='zmx title (empty clears): ' --local title
        continue
      end
      set -l rename_output (env ZMX_SESSION_PREFIX= zmx set "$session" "title=$title" 2>&1)
      if test $status -ne 0
        printf '%s\n' "$rename_output" >&2
        read --prompt-str='Press Enter to continue' --local ignored
      end
      continue
    end

    if test -z "$session"
      return 130
    end

    set -g __zmx_selected_session "$session"
    env ZMX_SESSION_PREFIX= zmx attach "$session"
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
