" set list
set nobackup
set noswapfile
set history=1000         " remember more commands and search history
set undolevels=1000      " use many muchos levels of undo
set wildignore+=*.swp,*.bak,*.pyc,*.class
set title                " change the terminal's title
set visualbell           " don't beep
set noerrorbells         " don't beep
set hidden
set tabstop=4
set shiftwidth=4
set sw=4
set autoindent
set softtabstop=4
set expandtab
set cursorline
set scrolloff=3
set showmatch
set splitright
set splitbelow
set wildmode=list:longest
set backspace=indent,eol,start
set nonumber
set nowrap

set nosmarttab
set formatoptions=qrn1

set hls
nnoremap <silent> <Space> :nohlsearch<Bar>:echo<CR>""

" More detailed status line
set statusline=[%n]\ %f\ %m\ %y
set statusline+=%{fugitive#statusline()} " Show git details"
set statusline+=%{exists('g:loaded_rvm')?rvm#statusline():''} " Show RVM details"
set statusline+=%w              " [Preview]
set statusline+=%=              " Left/right separator
set statusline+=%c,             " Cursor column
set statusline+=%l/%L           " Cursor line/total lines
set statusline+=\ %P            " Percent through file

set laststatus=2                " Always show statusline

set incsearch                   " Incremental search
set history=1024                " History size
set smartcase                   " Smart case-sensitivity when searching (overrides ignorecase)

syntax on
filetype on
filetype plugin on
filetype plugin indent on
