;goto -) 
		model 	tiny
		locals
		.code
		org 	100h
_:		jmp	start

boot_fn		db	'boot.bin',0
test_fn		db	'boot.dmp',0
fopen_emsg	db	'Cannot open file. Error code: $'
fcreate_emsg	db	'Cannot create file. Error code: $'
fread_emsg	db	'Cannot read from file. Error code: $'
fwrite_emsg	db	'Cannot write to file. Error code: $'
fclose_emsg	db	'Cannot close file. Error code: $'
bwrite_emsg	db	'Cannot write to boot sector.$'

start:		push 	cs
		pop	es
		
		call	fill_buffer
		call 	boot_sign
		call	read_boot
		;call 	write_file
		call	write_boot

		ret

read_boot:	; open file with boot
		mov 	ah, 03dh
		mov	al, 0
		mov	dx, offset boot_fn
		int	21h
		; error handling
		mov	dx, offset fopen_emsg
		jc	print_err

		; read from file
		mov	bx, ax
		mov	ah, 03fh
		mov	cx, 512
		mov	dx, offset EOF
		int	21h
		; error handling
		mov 	dx, offset fread_emsg
		jc 	print_err

		; close file
		mov 	ah, 03eh
		int	21h
		; error handling
		mov	dx, offset fclose_emsg
		jc	print_err

		ret

write_boot:	; write buffer to boot sector
		mov 	dx, 80h
		mov	cx, 1
		mov	ah, 03h
		mov	al, 1
		mov	bx, offset EOF
		int	13h
		; error handling
		mov	al, ah
		xor	ah, ah
		mov 	dx, offset bwrite_emsg
		jc	print_err
		
		ret		
		

		; write buffer to file
		; just for testing purpose

write_file:	; create file
		mov	ah, 03ch
		xor	cx, cx
		mov	dx, offset test_fn
		int	21h
		; error handling
		mov	dx, offset fcreate_emsg
		jc 	print_err

		; write to file
		mov	bx, ax
		mov	ah, 040h
		mov	cx, 512
		mov	dx, offset EOF
		int 	21h
		; error handling
		mov	dx, offset fwrite_emsg
		jc	print_err

		; close file
		mov	ah, 03eh
		int	21h
		; error handling
		mov 	dx, offset fclose_emsg
		jc	print_err

		ret

fill_buffer:	mov	cx, 511
		mov 	byte ptr[EOF], 0
fill_loop:	mov	si, cx
		mov	byte ptr[EOF + si], 0
		loop	fill_loop
		ret

boot_sign:	; write boot signature to the end of buffer
		mov	byte ptr[EOF + 510], 055h
		mov	byte ptr[EOF + 511], 0aah
		ret

print_err:	; arguments: ax - error code, dx - ptr to error string
		; save error code
		push	ax
		; write error string
		mov	ah, 09h
		int	21h
		; write error code
		pop	dx
		add	dx, 030h
 		mov	ax, 02h
		int 	21h
		jmp	exit



exit:		ret

EOF:		end	_

:-)
@echo off
tasm /m write.bat
tlink /x/t write
del write.obj
