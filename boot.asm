		model 	tiny
		locals
		.code
		org 	07c00h
		;org 	0100h
_:		jmp	start

memadr		dw	0

bytes_per_line	dw	16
hex_buffer	db	'xx ',0
addr_buffer	db	'[xxxx]: ',0
endl		db	13,10,0

key_up		EQU	48h
key_down	EQU	50h
key_esc		EQU	01h

lines_count	dw	20
pos_min		dw	0
pos_max		dw	80 ; 0500h = 1280 / (bytes_per_line) 

start:		cli
		mov	ax, cs
		mov	ds, ax
		mov	es, ax
		mov	ss, ax
		mov	bp, 7c00h
		mov	sp, 7c00h
		sti

		mov	ax, 0
		mov	bx, 0
		call	print
		call 	keyboard		

		ret

print:		; arguments: ax - num of start line 

		; save registers
		push 	bx
		push	cx
		push	dx
		push	si

		; get position of start byte
		mul	byte ptr[bytes_per_line]
		mov	si, ax

		; set cursor to (0,0)
		mov	ax, 02h
		mov	dx, 0
		int	10h

		; print lines_count lines
		mov 	cx, lines_count

print_loop:	mov	dx, cx
		mov 	cx, bytes_per_line

		; print address
		mov	bx, offset addr_buffer
		inc	bx
		mov	ax, si
		call	word_to_hex
		mov	bx, offset addr_buffer
		call	tty_print

line_loop:	xor	ax, ax
		mov	bx, memadr
		mov	al, byte ptr[bx + si]
		mov	bx, offset hex_buffer
		call	byte_to_hex
		mov 	bx, offset hex_buffer
		call 	tty_print
		inc	si
		loop	line_loop
		
		; print end line
		mov	bx, offset endl
		call 	tty_print
		
		; restore cx, loop over outer loop
		mov	cx, dx
		loop	print_loop
		
print_exit:	; restore registers
		pop si
		pop dx
		pop cx
		pop bx

		ret

keyboard:	; bx - current line number
		mov	ax, 0
		int	16h
		cmp	ah, key_up
		je	print_up
		cmp	ah, key_down
		je	print_down
		cmp	ah, key_esc
		je	exit
		jmp	keyboard

print_up:	mov	dx, lines_count
		neg	dx
		add	bx, dx
		cmp	bx, pos_min
		jge	call_print

print_down:	add	bx, lines_count
		cmp	bx, pos_max
		jge	print_up
		
call_print:	mov	ax, bx
		call	print
		jmp	keyboard	


tty_print:	push	si
		mov 	si, 0
tty_loop:	mov	al, [bx + si]
		cmp	al, 0
		jz	tty_exit
		; print character to tty
		mov	ah, 0eh
		int	010h
		inc	si
		jmp	tty_loop
tty_exit:	pop 	si
		ret

word_to_hex:	xchg 	ah, al
		call	byte_to_hex
		xchg	ah, al
		add	bx, 2
		call 	byte_to_hex
		ret

byte_to_hex:	push 	ax
		; convert firts 4 bits
		mov	ah, al
		shr	al, 4
		call	to_hex
		mov	byte ptr[bx], al
		; convert second 4 bits
		mov	al, ah
		and	al, 0fh
		call	to_hex
		mov	byte ptr[bx + 1], al
		pop 	ax
		ret	

to_hex:		add 	al, '0'
		cmp	al, '9'
		jle	exit
		add	al, 7

exit:		ret		


EOF:		end	_
