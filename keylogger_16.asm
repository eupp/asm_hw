		model 	tiny
		.code
		org 	100h
_:		jmp	start


hex_buf		db	'xx ',0

start:		

        push    cs
        pop     es

key_loop:
        mov     ax, 0
        int     16h

        cmp     ah, 1
        je      exit
        call    keylogger
        jmp     key_loop
exit:
		ret

keylogger:
        ; ah - scan code
        ; al - ascii char

        push    bx
        push    cx
        push    dx
        push    si
        push    bp

        ; save ascii code
        mov     si, ax
        ; move bits of scan code
        shr     ax, 8

        ; convert code to ascii num
        mov     bx, offset hex_buf
        call    byte_to_hex
        mov     bp, bx
        xor     bx, bx
        
        ; write first byte to display
        mov     ah, 0Ah
        mov     al, byte ptr [bp]
        mov     cx, 1
        int     10h

        ; get current cursor pos
        mov     ax, 0300h
        int     10h

        ; set cursor position to next column
        inc     dx
        mov     ax, 0200h
        int     10h
        
        ; write second byte to display
        mov     ah, 0Ah
        mov     al, byte ptr [bp + 1]
        mov     cx, 1
        int     10h

        ; get current cursor pos
        mov     ax, 0300h
        int     10h

        ; set cursor position to next column
        inc     dx
        mov     ax, 0200h
        int     10h

        ; write third byte
        mov     ah, 0Ah
        mov     al, byte ptr [bp + 2]
        mov     cx, 1
        int     10h

        ; get current cursor pos
        mov     ax, 0300h
        int     10h

        ; set cursor position to next column
        inc     dx
        mov     ax, 0200h
        int     10h

    
        ; write ascii code
        mov     ax, si
        mov     ah, 0Ah
        mov     cx, 1
        int     10h

        ; get current cursor pos
        mov     ax, 0300h
        int     10h
        
        ; back to the line start
        sub     dx, 3
        mov     ax, 0200h
        int     10h

        ; scroll up
        mov     ah, 06h
        mov     al, 1
        mov     bh, 07h
        xor     cx, cx        
        mov     dh, 25
		mov     dl, 85
        int     10h

        pop     bp
        pop     si
        pop     dx
        pop     cx
        pop     bx

        ret

word_to_hex:	
        ; ax - word to be printed
        ; bx - pointer to output buffer
        push    bx    
        xchg 	ah, al
		call	byte_to_hex
		xchg	ah, al
		add	    bx, 2
		call 	byte_to_hex
        pop     bx
		ret

byte_to_hex:	
        ; al - byte to be printed
        ; bx - pointer to output buffer          
        push 	ax
		; convert firts 4 bits
		mov	    ah, al
		shr	    al, 4
		call	to_hex
		mov	    byte ptr[bx], al
		; convert second 4 bits
		mov	    al, ah
		and	    al, 0fh
		call	to_hex
		mov	    byte ptr[bx + 1], al
		pop 	ax
		ret	

to_hex:		
        add 	al, '0'
		cmp	    al, '9'
		jle	    to_hex_exit
		add	    al, 7
to_hex_exit:
        ret

EOF:
        end _
