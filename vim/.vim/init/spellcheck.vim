" Spell checking configuration
" Enable spell checking for text-based file types
autocmd FileType markdown,text,gitcommit,mail setlocal spell

" Set default spell language to US English
set spelllang=en_us

" Spell check highlighting - subtle for dark backgrounds
highlight clear SpellBad
highlight SpellBad cterm=underline ctermfg=red
highlight clear SpellCap
highlight SpellCap cterm=underline ctermfg=yellow
highlight clear SpellLocal
highlight SpellLocal cterm=underline ctermfg=cyan
highlight clear SpellRare
highlight SpellRare cterm=underline ctermfg=magenta

" Manual toggle for spell checking (useful for code files)
nnoremap <silent> <leader>s :setlocal spell!<CR>

" Spell checking navigation keybindings
" ]s - next misspelled word
" [s - previous misspelled word
" z= - show spelling suggestions
" zg - add word to personal dictionary
" zw - mark word as wrong (remove from dictionary)
