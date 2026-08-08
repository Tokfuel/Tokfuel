#!/usr/bin/env bash
# Screen Recording / Accessibility の「許可 / Allow」ダイアログを押し続ける。
# screencapture -v 起動時に出るモーダルを自動で通すための補助。
set -euo pipefail

DURATION="${1:-60}"
DEADLINE=$((SECONDS + DURATION))

click_allow() {
  /usr/bin/osascript <<'APPLESCRIPT' 2>/dev/null || true
tell application "System Events"
  set buttonNames to {"Allow", "許可", "OK", "続けて許可", "Once", "今回のみ許可"}
  repeat with procName in {"UserNotificationCenter", "SecurityAgent", "coreautha", "screencaptureui", "WindowManager"}
    try
      tell process (procName as text)
        repeat with w in windows
          repeat with bName in buttonNames
            try
              click button (bName as text) of w
              return
            end try
            try
              click button (bName as text) of group 1 of w
              return
            end try
            try
              click button (bName as text) of sheet 1 of w
              return
            end try
          end repeat
          -- ダイアログ内の任意ボタンで「許可」を含むものを押す
          try
            repeat with b in (buttons of w)
              set t to name of b as text
              if t contains "Allow" or t contains "許可" then
                click b
                return
              end if
            end repeat
          end try
        end repeat
      end tell
    end try
  end repeat
end tell
APPLESCRIPT
}

echo "dismiss-tcc-prompt: watching for Allow/許可 up to ${DURATION}s"
while (( SECONDS < DEADLINE )); do
  click_allow
  sleep 0.4
done
echo "dismiss-tcc-prompt: done"
