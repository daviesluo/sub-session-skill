# VHS tape for docs/demo.gif
# https://github.com/charmbracelet/vhs
#
# Reproduces the README demo by running scripts/record-demo.sh, which
# drives this package's own watch-inbox.sh, watch-outbox.sh and notify.sh
# against a throwaway toy repo named hello-notes. The second clone is a
# seat stand-in, labelled as such. No project repos, tokens or hostnames.
#
#   vhs docs/demo.tape
#
# Prefer `sh scripts/record-demo.sh` (asciinema + agg) when VHS/ttyd is
# not installed. That is how the committed GIF was recorded.

Output docs/demo.gif
Set FontSize 14
Set Width 1400
Set Height 900
Set FontFamily "JetBrains Mono"
Set Theme "Catppuccin Mocha"
Set PlaybackSpeed 1.0
Set TypingSpeed 0ms
Set Framerate 12

Sleep 500ms
Type "sh scripts/record-demo.sh --play"
Enter
Sleep 45s
