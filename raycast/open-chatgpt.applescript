#!/usr/bin/osascript

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Open ChatGPT
# @raycast.mode compact

tell application "Google Chrome"
    activate
    delay 0.2
    set targetHost to "chatgpt.com"
    set windowCount to count of windows

    repeat with w from 1 to windowCount
        set tabCount to count of tabs of window w
        repeat with t from 1 to tabCount
            set tabUrl to URL of tab t of window w
            if tabUrl contains targetHost then
                set active tab index of window w to t
                if w is not 1 then
                    set index of window w to 1
                end if
                return
            end if
        end repeat
    end repeat

    open location "https://chatgpt.com"
end tell
