# Define some colors
BRED="%B%F{9}"
RED="%F{9}"
YELLOW="%F{11}"
BYELLOW="%B%F{11}"
TEAL="%F{6}"
AQUA="%F{14}"
OLIVE="%F{3}"
RESET="%f%b"
LPAREN="${OLIVE}(${RESET}"
RPAREN="${OLIVE})${RESET}"

# Git prompt (ala https://github.com/olivierverdier/zsh-git-prompt)
if [[ -f ${HOME}/Projects/zsh-git-prompt/zshrc.sh ]]; then
    source ${HOME}/Projects/zsh-git-prompt/zshrc.sh
    GIT_PROMPT='-$(git_super_status)'
    ZSH_THEME_GIT_PROMPT_CACHE=true
else
    GIT_PROMPT=""
fi

# Colorize the prompt
PROMPT="${LPAREN}${BRED}%n${RESET}@${BYELLOW}%m${RESET}${RPAREN}"
PROMPT="${PROMPT}-${LPAREN}${TEAL}%h${AQUA}/${TEAL}%y${RESET}${RPAREN}"
PROMPT="${PROMPT}-${LPAREN}${TEAL}%D %D{%H:%M:%S}${RESET}${RPAREN}"
PROMPT="${PROMPT}${GIT_PROMPT}"
PROMPT="${PROMPT}"$'\n'"${LPAREN}%~${RPAREN}${AQUA}>${RESET} "
