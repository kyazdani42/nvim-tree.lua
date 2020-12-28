if has('win32') || exists('g:loaded_tree') | finish | endif

let s:save_cpo = &cpo
set cpo&vim

let g:loaded_netrw = 1
let g:loaded_netrwPlugin = 1

hi def link NvimTreePopup Normal

augroup NvimTree
  au BufWritePost * lua require'nvim-tree'.refresh()
  au BufEnter * lua require'nvim-tree'.buf_enter()
  if get(g:, 'nvim_tree_auto_close') == 1
    au WinClosed * lua require'nvim-tree'.on_leave()
  endif
  au ColorScheme * lua require'nvim-tree'.reset_highlight()
  au User FugitiveChanged lua require'nvim-tree'.refresh()
  if get(g:, 'nvim_tree_tab_open') == 1
    au TabEnter * lua require'nvim-tree'.tab_change()
  endif
augroup end

command! NvimTreeOpen lua require'nvim-tree'.open()
command! NvimTreeClose lua require'nvim-tree'.close()
command! NvimTreeToggle lua require'nvim-tree'.toggle()
command! NvimTreeRefresh lua require'nvim-tree'.refresh()
command! NvimTreeClipboard lua require'nvim-tree'.print_clipboard()
command! NvimTreeFindFile lua require'nvim-tree'.find_file(true)

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_tree = 1
