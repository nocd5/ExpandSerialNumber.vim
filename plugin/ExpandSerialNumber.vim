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

let s:strPat = '\(.\{-}\)' . s:delim[0] . '\s*\(\%\(0[xX][0-9a-fA-F]\+\)\|\d\+\)\s*' . s:separator . '\s*\(\%\(0[xX][0-9a-fA-F]\+\)\|\d\+\)\s*' . s:delim[1] . '\(.*\)'
"--------------------------------------

"-----------------------------------
" replace & eval backref
function! s:backref(string, num, ref, hex, upper)
	let l:strExprPat = s:delim[0] . '\([\ ()0-9+-\*/]\{-}\\' . a:ref . '[\ ()0-9+-\*/]\{-}\)' . s:delim[1]
	let l:src = a:string
	if (match(l:src, l:strExprPat) != -1)
		let l:expr = substitute(l:src, '.\{-}' . l:strExprPat . '.*', '\1', "")
		let l:num = a:num
		if (a:hex)
			if (a:upper)
				let l:num = printf('0x%X', '0x' . a:num)
			else
				let l:num = printf('0x%x', '0x' . a:num)
			endif
		endif
		let l:imexp = substitute(l:expr, '\\'.a:ref, l:num, "g")
		let l:result = ""
		if (match(l:imexp, '\\\d\+') != -1)
			let l:result = s:delim[0] . escape(l:imexp, "\\") . s:delim[1]
		else
			let l:result = eval(substitute(l:expr, '\\' . a:ref, l:num, "g"))
			if (a:hex)
				if (a:upper)
					let l:result = printf('%X', l:result)
				else
					let l:result = printf('%x', l:result)
				endif
			endif
		endif
		let l:src = s:backref(substitute(l:src, l:strExprPat, l:result, ""), a:num, a:ref, a:hex, a:upper)
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
		let l:nStart = l:strStart+0
		let l:nEnd   = l:strEnd+0

		let l:isHex = 0
		let l:isUpper = 0
		if (match(l:strStart, '0[xX]') != -1 && match(l:strEnd, '0[xX]') != -1)
			let l:isHex = 1
		endif
		if (match(l:strStart, '\C0X') != -1 && match(l:strEnd, '\C0X') != -1)
			let l:isUpper = 1
		endif

		" if start-value > end-value, reverse flow direction
		let l:stride = l:nStart < l:nEnd ? 1 : -1
		for i in range(l:nStart, l:nEnd, l:stride)
			if (l:isHex)
				if (l:isUpper)
					let i = printf('%X', i)
				else
					let i = printf('%x', i)
				endif
			endif
			let l:line = l:strPre . i . l:strSuf
			call add(l:lines, s:backref(l:line, i, a:ref, l:isHex, l:isUpper))
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

