command! -range ExpandSerialNumber <line1>,<line2>call s:ExpandSerialNumber()
"-----------------------------------------
" expand serial number
" syntax  : foo[nStart-nEnd][...]
" example : before
"                  0: foo[0-1][3-2]
"           after
"                  0: foo03
"                  1: foo02
"                  2: foo13
"                  3: foo12
"-----------------------------------------

"--------------------------------------
" setting
if exists("g:expand_serial_num_delimiter")
	let s:delim = g:expand_serial_num_delimiter
else
	let s:delim = ['\[', '\]']
endif

if exists("g:expand_serial_num_separator")
	let s:separator = g:expand_serial_num_separator
else
	let s:separator = '-'
endif

let s:strPat = '\(.\{-}\)' . s:delim[0] . '\s*\(\d\+\)\s*' . s:separator . '\s*\(\d\+\)\s*' . s:delim[1] . '\(.*\)'
"--------------------------------------

"-----------------------------------
" replace & eval backref
function! s:backref(string, num, ref)
	let l:strExprPat = s:delim[0] . '\([\ ()0-9+-\*/]\{-}\\' . a:ref . '[\ ()0-9+-\*/]\{-}\)' . s:delim[1]
	let l:src = a:string
	if (match(l:src, l:strExprPat) != -1)
		let l:expr = substitute(l:src, '.\{-}' . l:strExprPat . '.*', '\1', "")
		let l:imexp = substitute(l:expr, '\\'.a:ref, a:num, "g")
		let l:result = ""
		if (match(l:imexp, '\\\d\+') != -1)
			let l:result = s:delim[0] . escape(l:imexp, "\\") . s:delim[1]
		else
			let l:result = eval(substitute(l:expr, '\\' . a:ref, a:num, "g"))
		endif
		let l:src = s:backref(substitute(l:src, l:strExprPat, l:result, ""), a:num, a:ref)
	endif
	return l:src
endfunction
"-----------------------------------

"-----------------------------------
" expand serial number
function! s:expandnum(line, ref)
	let l:strPre   = substitute(a:line, s:strPat, '\1', '')
	let l:strStart = substitute(a:line, s:strPat, '\2', '')
	let l:strEnd   = substitute(a:line, s:strPat, '\3', '')
	let l:strSuf   = substitute(a:line, s:strPat, '\4', '')

	let l:lines = []
	if (l:strStart != "") && (l:strEnd != "")
		let l:nStart = str2nr(l:strStart)
		let l:nEnd   = str2nr(l:strEnd)

		" if start-value > end-value, reverse flow direction
		let l:stride = l:nStart < l:nEnd ? 1 : -1
		for i in range(l:nStart, l:nEnd, l:stride)
			let l:line = l:strPre . i . l:strSuf
			call add(l:lines, s:backref(l:line, i, a:ref))
		endfor
	endif
	return l:lines
endfunction
"-----------------------------------

"-----------------------------------
" scan each lines
function! s:scanlines(lines, ref)
	for line in a:lines
		if (match(line, s:strPat) != -1)
			let l:idx = index(a:lines, line)
			call extend(a:lines, s:scanlines(s:expandnum(line, a:ref), a:ref+1), l:idx+1)
			call remove(a:lines, l:idx)
		endif
	endfor
	return a:lines
endfunction
"-----------------------------------

"-----------------------------------
" main
function! s:ExpandSerialNumber() range
	let l:dest = s:scanlines(getline(a:firstline, a:lastline), 1)
	:execute ":" . a:firstline . "," . a:lastline . ' s/.*\n//'
	call append(a:firstline-1, l:dest)
endfunction
"-----------------------------------

