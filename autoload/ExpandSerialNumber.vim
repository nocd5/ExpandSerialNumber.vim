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
" settings
function! s:settings()
	if exists("g:expand_serial_number_delimiter")
		let s:delim = g:expand_serial_number_delimiter
	else
		let s:delim = ['\[', '\]']
	endif

	if exists("g:expand_serial_number_separator")
		let s:sep = g:expand_serial_number_separator
	else
		let s:sep = '-'
	endif

	if !exists("g:expand_serial_number_verbose")
		let g:expand_serial_number_verbose = 0
	endif

	" pos,neg,decimal,hex
	let s:NumberPat      = '\s*\(-\?\%\(\%\(0[xX][0-9a-fA-F]\+\)\|\d\+\)\)\s*'

	" expand format
	let s:FormatPat      = '\(.\{-}\)'
                         \ . s:delim[0]
                         \ . s:NumberPat . s:sep . s:NumberPat
                         \ . s:delim[1]
                         \ . '\(.*\)'

	" see also :help /\]
	let l:delim_tmp_0    = substitute(s:delim[0], '\\\ze[^\]\^\-]', '', '')
	let l:delim_tmp_1    = substitute(s:delim[1], '\\\ze[^\]\^\-]', '', '')
	" char other than delimiter
	let l:nondelim       = '[^' . l:delim_tmp_0 . l:delim_tmp_1 . ']'

	let s:NumCharPat     = '\%\(' . l:nondelim . '\|\%\(' . s:delim[0] . l:nondelim . '\{-}' . s:delim[1] . '\)\)\{-}'

	" except octal
	let s:ExceptOctalPat =  '^0\+\ze[^xX]\|^-\zs0\+\ze[^xX]'

endfunction
"--------------------------------------

"-----------------------------------
" eval() wrapper
" except invalid expression
function! s:eval_wrp(expr)
	let l:result = a:expr
	try
		let l:result = eval(a:expr)
	catch
		if (g:expand_serial_number_verbose == 1)
			echomsg v:exception . " -> eval(" . a:expr .")"
		endif
	endtry
	return l:result
endfunction
"-----------------------------------

"-----------------------------------
" replace & eval backref
function! s:backref(string, num, ref)
	let l:strExprPat = s:delim[0] . '\(' . s:NumCharPat
                     \ . '\\' . a:ref . '\>'
                     \ . s:NumCharPat . '\)' . s:delim[1]
	let l:src = a:string
	if (match(l:src, l:strExprPat) != -1)
		let l:expr = substitute(l:src, '.\{-}' . l:strExprPat . '.*', '\1', '')
		let l:imexp = substitute(l:expr, '\\' . a:ref . '\>', a:num, 'g')
		if (match(l:imexp, '\(\\\d\+\)\|\('. s:FormatPat . '\)' ) != -1)
			let l:result = s:delim[0]
                         \ . escape(l:imexp, "\\")
                         \ . s:delim[1]
		else
			let l:result = s:eval_wrp(l:imexp)
		endif
		let l:src = s:backref(substitute(l:src, l:strExprPat, l:result, ''), a:num, a:ref)
	endif
	return l:src
endfunction
"-----------------------------------

"-----------------------------------
" expand serial number
function! s:expandnum(line, ref)
	let l:strPre   = substitute(a:line, s:FormatPat, '\1', '')
	let l:strStart = substitute(a:line, s:FormatPat, '\2', '')
	let l:strEnd   = substitute(a:line, s:FormatPat, '\3', '')
	let l:strSuf   = substitute(a:line, s:FormatPat, '\4', '')

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


			let l:extd_pre =  l:strPre != "" ? l:line[0:strlen(l:strPre)-1] : ""
			let l:extd     =  l:line[strlen(l:strPre):strlen(l:line)-strlen(l:strSuf)-1]
			let l:extd_suf =  l:strSuf != "" ? l:line[strlen(l:line)-strlen(l:strSuf):strlen(l:line)-1] : ""

			let l:extd_pre = s:backref(l:extd_pre, i, a:ref)
			let l:extd     = s:backref(l:extd    , i, a:ref)
			let l:extd_suf = s:backref(l:extd_suf, i, a:ref)

			let l:line = l:extd_pre . l:extd . l:extd_suf

			if (match(l:extd_pre, '\(.*\%\(.*' . s:delim[1] . '.*\)\@!' .  s:delim[0] . '.*\)') != -1)
				let l:extd_pre_pre = substitute(l:extd_pre, '\(.\{-}\)\%\(.*' . s:delim[1] . '.*\)\@!\(' .  s:delim[0] . '.*\)', '\1', '')
				let l:extd_pre_suf = substitute(l:extd_pre, '\(.\{-}\)\%\(.*' . s:delim[1] . '.*\)\@!\(' .  s:delim[0] . '.*\)', '\2', '')
			else
				let l:extd_pre_pre = ""
				let l:extd_pre_suf = ""
			endif

			if (match(l:extd_suf, '\(.*\%\(.*' . s:delim[0] . '.*\)\@<!' . s:delim[1] . '\)\(.*\)') != -1)
				let l:extd_suf_pre = substitute(l:extd_suf, '\(.*\%\(.*' . s:delim[0] . '.*\)\@<!' . s:delim[1] . '\)\(.*\)', '\1', '')
				let l:extd_suf_suf = substitute(l:extd_suf, '\(.*\%\(.*' . s:delim[0] . '.*\)\@<!' . s:delim[1] . '\)\(.*\)', '\2', '')
			else
				let l:extd_suf_pre = ""
				let l:extd_suf_suf = ""
			endif

			let l:extd_pre = l:extd_pre_pre
			let l:extd     = l:extd_pre_suf . l:extd . l:extd_suf_pre
			let l:extd_suf = l:extd_suf_suf

			if (match(l:extd, s:FormatPat) == -1)
				let l:pat = s:delim[0] . '\zs.\{-}\ze' . s:delim[1]
				if (match(l:extd, l:pat) != -1)
					let l:temp     = matchstr(l:extd, l:pat)
					if (l:temp != "")
						let l:posteval = s:eval_wrp(l:temp)
						" l:posteval type nr, l:temp type string.
						" 1 and 1*1 is matched,
						" because string is converted to nr automatically.
						if (printf("%d",l:posteval) isnot l:temp)
							let l:line = l:extd_pre . l:posteval . l:extd_suf
						else
							let l:line = l:extd_pre . l:extd . l:extd_suf
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
		if (match(line, s:FormatPat) != -1)
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
function! ExpandSerialNumber#ExpandSerialNumber() range
	call s:settings()
	let l:dest = s:scanlines(getline(a:firstline, a:lastline), 1)
	call append(a:lastline, l:dest)
	execute "silent " . a:lastline . "," . a:firstline . " d"
endfunction
"-----------------------------------

