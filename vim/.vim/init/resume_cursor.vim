" https://askubuntu.com/questions/223018/vim-is-not-remembering-last-position
if has("autocmd")
  au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif
