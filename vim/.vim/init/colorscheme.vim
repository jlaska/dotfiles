set t_Co=256
set background=dark

" Highlight whitespace at end of line ----------
let c_space_errors=1
highlight BadWhitespace ctermbg=red guibg=red
" The following alternative may be less obtrusive.
" highlight BadWhitespace ctermbg=darkgreen guibg=lightgreen
" Try the following if your GUI uses a dark background.
" highlight BadWhitespace ctermbg=darkgreen guibg=darkgreen
match BadWhitespace /\s\+\%#\@<!$/
" ----------------------------------------------
