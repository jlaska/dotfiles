"Pep8
let g:pep8_map='<leader>8'

"Tab Completion
au FileType python set omnifunc=pythoncomplete#Complete
let g:SuperTabDefaultCompletionType = "context"
set completeopt=menuone,longest,preview

"Strip trailing whitespace from Python source files
autocmd BufWritePre *.py :%s/\s\+$//e

"Color column
au FileType python set colorcolumn=121
au FileType python set textwidth=120

au BufNewFile,BufRead *.mako set syntax=mako

" let g:PyFlakeOnWrite = 1
let g:syntastic_python_checkers = ['pylama']
