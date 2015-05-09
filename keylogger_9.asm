		model 	tiny
		.code
		org 	100h
_:		jmp	start


hex_buf		db	'xx ',0
escape_flg  db  0
vector09    dd  0

int09h:
        ; save registers
        push    ax
        push    bx
        push    cx
        push    dx
        push    ds
        push    es

        ; cs = ds = es
        push    cs
        push    cs
        pop     ds
        pop     es

        ; get escape code from keyboard
        xor     ax, ax
        in      al, 60h
        
        cmp     al, 1
        jne     print_scancode

        ; handle Escape key
        mov     escape_flg, 1

print_scancode:
        mov     ah, al

        ; send acknowledgment to keyboard
        in      al, 61h
        or      al, 10000000b
        out     61h, al
        and     al, 01111111b
        out     61h, al

        ; enable interrupts
        mov     al, 20h
        out     20h, al

        mov     al, ah

        call    keylogger

int9h_exit:
        ; restore registers
        pop     es
        pop     ds                      
        pop     dx
        pop     cx
        pop     bx
        pop     ax

        iret

start:		

        push    0
        pop     es

        ; save int9 handler
        mov     bx, 24h ; 24h = 36 = 9 * 4
        mov     ax, [es:bx]
        mov     cx, [es:bx + 2]
        mov     word ptr vector09, ax
        mov     word ptr vector09 + 2, cx

        cli
        ; set int9 handler
        push    cs
        pop     ax
        mov     [es:bx], offset int09h
        mov     [es:bx + 2], ax 
        sti

key_loop:
        cmp     escape_flg, 1
        jne     key_loop

exit_h:
        push    0
        pop     es

        cli
        ; restore int9 handler
        mov     bx, 24h ; 24h = 36 = 9 * 4
        mov     ax, word ptr [vector09]
        mov     cx, word ptr [vector09 + 2]
        mov     [es:bx], ax
        mov     [es:bx + 2], cx
        sti

exit:
		ret


keylogger:
        ; ax - scan code to print

        push    bx
        push    cx
        push    dx
        push    bp

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
        
        ; back to the line start
        dec     dx
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
