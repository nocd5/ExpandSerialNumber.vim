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

if exists("g:expand_serial_num_experimental")
	let s:experimental = 1
else
	let s:experimental = 0
endif

let s:NumberPat      = '\s*\(-\?\%\(\%\(0[xX][0-9a-fA-F]\+\)\|\d\+\)\)\s*'
let s:strPat         = '\(.\{-}\)' . s:delim[0] . s:NumberPat . s:separator . s:NumberPat . s:delim[1] . '\(.*\)'
let s:NumCharPat     = '\%\([\ 0-9A-Za-z''"%+-/()]\|\*\|0[xX][0-9a-fA-F]\+\)\{-}'
" let s:NumCharPat     = '\%\([\ 0-9+-/()]\|\*\|0[xX][0-9a-fA-F]\+\)\{-}'
let s:ExceptOctalPat =  '^0\+\ze[^xX]\|^-\zs0\+\ze[^xX]'
"--------------------------------------

"-----------------------------------
" replace & eval backref
function! s:backref(string, num, ref)
	let l:strExprPat = s:delim[0] . '\(' . s:NumCharPat . '\\' . a:ref . '\>' . s:NumCharPat . '\)' . s:delim[1]
	let l:src = a:string
	if (match(l:src, l:strExprPat) != -1)
		let l:expr = substitute(l:src, '.\{-}' . l:strExprPat . '.*', '\1', '')
		let l:imexp = substitute(l:expr, '\\' . a:ref . '\>', a:num, 'g')
		if (match(l:imexp, '\\\d\+') != -1)
			let l:result = s:delim[0] . escape(l:imexp, "\\") . s:delim[1]
		else
			let l:result = eval(l:imexp)
		endif
		let l:src = s:backref(substitute(l:src, l:strExprPat, l:result, ''), a:num, a:ref)
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

		let l:digit = min([strlen(l:strStart), strlen(l:strEnd)])

		" lazy way to str2number
		let l:nStart = substitute(l:strStart, s:ExceptOctalPat, '', '') + 0
		let l:nEnd   = substitute(l:strEnd, s:ExceptOctalPat, '', '') + 0

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
					let l:line = l:strPre . printf('%0'. (l:digit-2) . 'X', i) . l:strSuf
				else
					let l:line = l:strPre . printf('%0'. (l:digit-2) . 'x', i) . l:strSuf
				endif
			else
				let l:line = l:strPre . printf('%0'. l:digit . 'd', i) . l:strSuf
			endif
			let l:line = s:backref(l:line, i, a:ref)
			if (match(l:line, s:strPat) == -1)
				if (match(l:line, s:delim[0] . '\(.\{-}\)' . s:delim[1]) != -1)
					let l:temp_pre = substitute(l:line, '\(.*\)' . s:delim[0] . '\(.\{-}\)' . s:delim[1] . '\(.*\)', '\1', '')
					let l:temp     = substitute(l:line, '\(.*\)' . s:delim[0] . '\(.\{-}\)' . s:delim[1] . '\(.*\)', '\2', '')
					let l:temp_suf = substitute(l:line, '\(.*\)' . s:delim[0] . '\(.\{-}\)' . s:delim[1] . '\(.*\)', '\3', '')
					if (l:temp != "")
						let l:posteval = eval(l:temp)
						if (l:posteval != l:temp)
							let l:line = l:temp_pre . l:posteval . l:temp_suf
						endif
					endif
				endif
			endif
			call add(l:lines, l:line)
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

