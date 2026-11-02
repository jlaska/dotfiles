# User specific aliases
alias ls='/bin/ls -GFb'
alias ll='ls -l'
alias l.='ls .[a-zA-Z]* -d'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias vimr="vim -R"
alias cvsup="cvs -qz3 up -Pd"
alias grep="grep --color=always"
alias less="less -R"
alias fg-="fg -"
alias fg+="fg +"
alias irc='screen -DR irc'
alias gvim='mvim'
alias lvim='vim -c "normal '\''0"'
MACOS_TAILSCALE_PATH="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
if [ -f ${MACOS_TAILSCALE_PATH} ]; then
    alias tailscale="${MACOS_TAILSCALE_PATH}"
fi
# macOS-style clipboard commands on Linux (dnf install wl-clipboard)
if [[ $OSTYPE == linux* ]] && (( $+commands[wl-copy] )); then
    alias pbcopy='wl-copy'
    alias pbpaste='wl-paste --no-newline'
fi
