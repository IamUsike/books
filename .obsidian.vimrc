" ============================================================
" .obsidian.vimrc — LazyVim-flavored bindings for Obsidian
" Requires the "Vimrc Support" community plugin.
" Place this file in your vault root, then set its name in
" Vimrc Support settings (default expects ".obsidian.vimrc").
" ============================================================

" ---------- Leader ----------
let mapleader = " "

" ---------- Sane defaults ----------
set clipboard=unnamed
set ignorecase
set smartcase
set incsearch
set surround
set easymotion
set showmatch

" ---------- Escape / general sanity ----------
inoremap jk <Esc>
inoremap kj <Esc>
noremap <C-c> <Esc>

" ---------- Move by visual line, not logical line ----------
nmap j gj
nmap k gk

" ---------- Window navigation (Ctrl+hjkl, like LazyVim) ----------
nmap <C-h> <C-w>h
nmap <C-j> <C-w>j
nmap <C-k> <C-w>k
nmap <C-l> <C-w>l

" ---------- Split management ----------
exmap vsplit obcommand workspace:split-vertical
exmap hsplit obcommand workspace:split-horizontal
nmap <leader>wv :vsplit<CR>
nmap <leader>ws :hsplit<CR>
exmap closepane obcommand workspace:close
nmap <leader>wc :closepane<CR>

" ---------- Buffer / tab-ish navigation ----------
exmap nexttab obcommand workspace:next-tab
exmap prevtab obcommand workspace:previous-tab
nmap <leader>bn :nexttab<CR>
nmap <leader>bp :prevtab<CR>
exmap closetab obcommand workspace:close-tab-group
nmap <leader>bd :closetab<CR>

" ---------- File / quick navigation (LazyVim <leader>f family) ----------
exmap quickswitch obcommand switcher:open
nmap <leader>ff :quickswitch<CR>

exmap cmdpalette obcommand command-palette:open
nmap <leader><leader> :cmdpalette<CR>
nmap <leader>fc :cmdpalette<CR>

exmap globalsearch obcommand global-search:open
nmap <leader>fg :globalsearch<CR>
nmap <leader>/ :globalsearch<CR>

exmap newnote obcommand file-explorer:new-file
nmap <leader>fn :newnote<CR>

exmap graphview obcommand graph:open
nmap <leader>fr :graphview<CR>

" ---------- Explorer / sidebar toggles (<leader>e like LazyVim) ----------
exmap filetree obcommand file-explorer:open
nmap <leader>e :filetree<CR>

exmap togglesidebarleft obcommand app:toggle-left-sidebar
exmap togglesidebarright obcommand app:toggle-right-sidebar
nmap <leader>el :togglesidebarleft<CR>
nmap <leader>er :togglesidebarright<CR>

" ---------- Notes: back/forward navigation ----------
exmap goback obcommand app:go-back
exmap goforward obcommand app:go-forward
nmap H :goback<CR>
nmap L :goforward<CR>

" ---------- Outline / table of contents ----------
exmap outline obcommand outline:open
nmap <leader>o :outline<CR>

" ---------- Markdown editing helpers ----------
exmap togglecheck obcommand editor:toggle-checklist-status
nmap <leader>tc :togglecheck<CR>

exmap togglebold obcommand editor:toggle-bold
exmap toggleitalics obcommand editor:toggle-italics
vmap <leader>b :togglebold<CR>
vmap <leader>i :toggleitalics<CR>

exmap insertlink obcommand editor:insert-link
nmap <leader>k :insertlink<CR>
vmap <leader>k :insertlink<CR>

exmap togglepreview obcommand markdown:toggle-preview
nmap <leader>tp :togglepreview<CR>

" ---------- Save (write-like behavior; Obsidian autosaves, but map anyway) ----------
exmap saveall obcommand editor:save-file
nmap <leader>w :saveall<CR>
nnoremap <C-s> :saveall<CR>
inoremap <C-s> <Esc>:saveall<CR>

" ---------- Daily notes ----------
exmap dailynote obcommand daily-notes
nmap <leader>nd :dailynote<CR>

" ---------- Yank to end of line like D/C ----------
nnoremap Y y$

" ---------- Clear search highlight ----------
nmap <leader>nh :nohl<CR>

" ---------- Center screen on jumps ----------
nnoremap <C-d> <C-d>zz
nnoremap <C-u> <C-u>zz
nnoremap n nzzzv
nnoremap N Nzzzv
