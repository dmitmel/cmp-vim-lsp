" Based on:
" <https://github.com/hrsh7th/nvim-compe/blob/d186d739c54823e0b010feb205c6f97792322c08/autoload/compe_vim_lsp/source.vim>
" <https://github.com/hrsh7th/cmp-nvim-lsp/blob/accbe6d97548d8d3471c04d512d36fa61d0e4be8/lua/cmp_nvim_lsp/init.lua>
" <https://github.com/hrsh7th/cmp-nvim-lsp/blob/accbe6d97548d8d3471c04d512d36fa61d0e4be8/lua/cmp_nvim_lsp/source.lua>
" <https://github.com/prabirshrestha/asyncomplete-lsp.vim/blob/684c34453db9dcbed5dbf4769aaa6521530a23e0/plugin/asyncomplete-lsp.vim>
" <https://github.com/ncm2/ncm2-vim-lsp/blob/f5f50d3f976a700a927cf4e53bf45b58755982b0/plugin/ncm2_vim_lsp.vim>

function! cmp_vim_lsp#setup() abort
  augroup cmp_vim_lsp
    autocmd!
    autocmd User lsp_server_init unsilent call cmp_vim_lsp#check_servers()
    autocmd User lsp_server_exit unsilent call cmp_vim_lsp#check_servers()
  augroup END
  unsilent call cmp_vim_lsp#check_servers()
endfunction

let g:cmp_vim_lsp#servers = {}

function! cmp_vim_lsp#check_servers() abort
  let stopped_servers = {}
  for server_name in keys(g:cmp_vim_lsp#servers)
    let stopped_servers[server_name] = v:true
  endfor

  for server_name in lsp#get_server_names()
    " let server_status = lsp#get_server_status(server_name)
    " if server_status isnot# 'running'
    "   continue
    " endif
    if has_key(stopped_servers, server_name)
      unlet stopped_servers[server_name]
    endif
    if has_key(g:cmp_vim_lsp#servers, server_name)
      continue
    endif
    let capabilities = lsp#get_server_capabilities(server_name)
    if !has_key(capabilities, 'completionProvider')
      continue
    endif

    let source = deepcopy(g:cmp_vim_lsp#source)
    let source.server_name = server_name
    let source.server_stopped = v:false
    let source.capabilities = capabilities
    let source.requests_disposables = {}
    let source.cmp_id = cmp#register_source('vim_lsp', source)
    let g:cmp_vim_lsp#servers[server_name] = source
  endfor

  for server_name in keys(stopped_servers)
    if has_key(g:cmp_vim_lsp#servers, server_name)
      let source = g:cmp_vim_lsp#servers[server_name]
      let source.server_stopped = v:true
      call cmp#unregister_source(source.cmp_id)
      unlet g:cmp_vim_lsp#servers[server_name]
    endif
  endfor
endfunction

let g:cmp_vim_lsp#source = {}

function! g:cmp_vim_lsp#source.get_debug_name() abort
  return 'vim_lsp:' . self.server_name
endfunction

function! g:cmp_vim_lsp#source.get_trigger_characters(params) abort
  return s:get(self.capabilities, ['completionProvider', 'triggerCharacters'], [])
endfunction

function! g:cmp_vim_lsp#source.complete(request, callback) abort
  if self.server_stopped
    return a:callback()
  endif
  let params = { 'textDocument': lsp#get_text_document_identifier(), 'position': lsp#get_position() }
  if get(a:request, 'completion_context', v:null) isnot# v:null
    let params.context = a:request.completion_context
  endif
  call self._request('textDocument/completion', params, {
  \ res -> a:callback(s:get(res, ['response', 'result'], {}))
  \ })
endfunction

function! g:cmp_vim_lsp#source.resolve(completion_item, callback) abort
  if self.server_stopped
    return a:callback()
  endif
  if s:get(self.capabilities, ['completionProvider', 'resolveProvider'], v:false) is# v:false
    return a:callback()
  endif
  call self._request('completionItem/resolve', a:completion_item, {
  \ res -> a:callback(s:get(res, ['response', 'result'], a:completion_item))
  \ })
endfunction

function! g:cmp_vim_lsp#source.execute(completion_item, callback) abort
  if self.server_stopped
    return a:callback()
  endif
  if get(a:completion_item, 'command', v:null) is# v:null
    return a:callback()
  endif
  call self._request('workspace/executeCommand', a:completion_item.command, {
  \ _ -> a:callback()
  \ })
endfunction

function! g:cmp_vim_lsp#source._request(method, params, callback) abort
  if has_key(self.requests_disposables, a:method)
    call self.requests_disposables[a:method]()
    unlet self.requests_disposables[a:method]
  endif
  let Dispose = function('s:noop')
  let Dispose = lsp#callbag#pipe(
  \ lsp#request(self.server_name, { 'method': a:method, 'params': a:params }),
  \ lsp#callbag#subscribe({
  \   'next': { d -> a:callback(d) },
  \   'error': { e -> [a:callback(e), Dispose()] },
  \   'complete': { -> Dispose() },
  \   }),
  \ )
  let self.requests_disposables[a:method] = Dispose
endfunction

function! s:noop(...) abort
endfunction

function! s:get(dict, keys, default) abort
  let dict = a:dict
  for key in a:keys
    let value = get(dict, key, v:null)
    if value is# v:null | return a:default | endif
    let dict = value
  endfor
  return dict
endfunction
