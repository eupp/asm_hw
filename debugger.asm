		model 	tiny
		locals
		.code
		org 	100h

psp = ((EOF - _ + 100h) + 15)/16 * 16
prog = psp + 100h

_:		jmp	start

; breakpoint interrupt handler start adress 
int03h:
        jmp     int03hf

bp_pos      db  0
saved_byte  db  0
vector03    dd  0

bp_msg      db  'Breakpoint reached!',13,10,'$'
exit_msg    db  'Debugging finished!',13,10,'$'
cs_msg      db  'CS: $'
ip_msg      db  'IP: $'
ax_msg      db  'AX: $'
bx_msg      db  'BX: $'
cx_msg      db  'CX: $'
dx_msg      db  'DX: $'
word_buf    db  'xxxx',13,10,'$'

print_ip:

        ; save registers
        push    ax
        push    bx
        push    cx
        push    dx

        ; print cs
        mov     ax, 0900h
        mov     dx, offset cs_msg
        int     21h
        mov     ax, [bp + 2]
        mov     bx, offset word_buf
        call    word_to_hex
        mov     ax, 0900h        
        mov     dx, bx
        int     21h

        ; print ip
        mov     ax, 0900h
        mov     dx, offset ip_msg
        int     21h
        mov     ax, [bp]
        mov     bx, offset word_buf
        call    word_to_hex
        mov     ax, 0900h        
        mov     dx, bx
        int     21h

        ; restore registers
        pop     dx
        pop     cx
        pop     bx
        pop     ax

        ret
        

print_regs:
        
        ; save registers
        push    ax
        push    bx
        push    cx
        push    dx

        ; print ax
        mov     ax, 0900h
        mov     dx, offset ax_msg
        int     21h
        mov     ax, word ptr[bp + 6]
        mov     bx, offset word_buf
        call    word_to_hex
        mov     ax, 0900h        
        mov     dx, bx
        int     21h

        ; print bx
        mov     ax, 0900h
        mov     dx, offset bx_msg
        int     21h
        mov     ax, word ptr[bp + 4]
        mov     bx, offset word_buf
        call    word_to_hex   
        mov     ax, 0900h        
        mov     dx, bx
        int     21h
    
        ; print cx
        mov     ax, 0900h
        mov     dx, offset cx_msg
        int     21h
        mov     ax, word ptr[bp + 2]
        mov     bx, offset word_buf
        call    word_to_hex   
        mov     ax, 0900h        
        mov     dx, bx
        int     21h

        ; print dx
        mov     ax, 0900h
        mov     dx, offset dx_msg
        int     21h
        mov     ax, word ptr[bp]
        mov     bx, offset word_buf
        call    word_to_hex   
        mov     ax, 0900h        
        mov     dx, bx
        int     21h

        ; restore registers
        pop     dx
        pop     cx
        pop     bx
        pop     ax

        ret
     
; breakpoint interrupt handler code
int03hf:

        ; save head of stack
        push    bp
        mov     bp, sp  
        add     bp, 2

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

        ; restore instruction
        mov     bx, [bp]
        sub     bx, 1h
        mov     cl, saved_byte
        mov     [bx + psp], cl
        mov     [bp], bx

        ; handler code
        
        ; print message

        mov     ax, 0900h
        mov     dx, offset bp_msg
        int     21h

        ; print cs, ip
        call    print_ip

        ; print ax - dx
        mov     bp, sp
        add     bp, 4
        call    print_regs

        ; restore registers
        pop     es
        pop     ds                      
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        pop     bp

        iret

exit_h:
        
        push    cs
        pop     ds

        ; save registers
        push    ax
        push    dx

        mov     dx, offset exit_msg
        mov     ax, 0900h
        int     21h

        ; recover breakpoint interrupt
        lds     dx, vector03
        mov     ax, 2503h
        int     21h

        ; restore registers
        pop     dx
        pop     ax

        ret

prog_fn     db  'hello.com',0
hex_buf     db  'xx $'

load_err    db  'Cannot load and run program. Error code: $'
fopen_err	db	'Cannot open file. Error code: $'
fcreate_err	db	'Cannot create file. Error code: $'
fread_err	db	'Cannot read from file. Error code: $'
fclose_err	db	'Cannot close file. Error code: $'
load_succ   db  'Program was sucessfully loaded',13,10,'$'

start:		
        push 	cs
		pop	    es
		
        call    load_prog
        call    set_bp
        call    set_interrupts

        ; set retf instruction to start of loaded program
        ; to return to out exit handler
        mov     bx, psp
        mov     byte ptr[bx], 0cbh; retf = 0cbh

        ; push address of exit handler to clean up after debugging
        push    cs
        push    offset exit_h
        
        ; calculate cs for loaded program
        mov     ax, psp / 16
        push    cs 
        pop     bx 
        add     ax, bx

        ; push address of loaded program on stack
        push    0h
        push    ax
        push    100h
        mov     ds, ax

        ; jump to loaded program 
        retf    
        
        ret

load_prog:

        ; save registers
        push    ax        
        push    bx
        push    cx
        push    dx        

        ; open file with program
		mov 	ax, 3d00h
		mov	    dx, offset prog_fn
		int	    21h
        ; error handling
		mov	    dx, offset fopen_err
		jc	    err_h

        ; read from file
		mov	    bx, ax
		mov	    ax, 3f00h
        ; read from file 400 bytes, file should be equal or smaller 
		mov	    cx, 400
		mov	    dx, prog
		int	    21h
		; error handling
		mov 	dx, offset fread_err
		jc 	    err_h

        ; save actual file size to cx
        mov     cx, ax

        ; close file
		mov 	ax, 3e00h
		int	    21h
		; error handling
		mov	    dx, offset fclose_err
		jc	    err_h

        ; success message
        mov	    ah, 09h
        mov     dx, offset load_succ
		int	    21h

        ; restore registers        
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        
        ret
        
set_interrupts:
        
        ; save registers
        push    ax
        push    bx
        push    dx
        push    es
        
        ; save old int03 handler        
        mov     ax, 3503h
        int     21h ; pointers on vecotr in bx, es
        mov     word ptr vector03, bx
        mov     bx, offset vector03
        add     bx, 02h
        mov     word ptr [bx], es

        mov     ax, 2503h
        mov     dx, offset int03h
        int     21h

        ; restore registers
        pop     es 
        pop     dx
        pop     bx
        pop     ax

        ret

set_bp:
        ; save registers
        push    ax
        push    bx
        push    cx
        push    dx

        ; calculate position of breakpoint
        mov     bx, prog
        mov     cl, bp_pos
        mov     ch, 0
        add     bx, cx

        ; save current command
        mov     al, byte ptr[bx]        
        mov     saved_byte, al

        ; write breakpoint
        mov     byte ptr[bx], 0cch ;  INT03 = 0cch

        ; restore registers
        pop     dx
        pop     cx
        pop     bx
        pop     ax        

        ret

err_h:
        call    print_err
        ; terminate process
        mov     ah, 4ch
        mov     al, 0
        int     21h

print_err:	
        ; arguments: ax - error code, dx - ptr to error string
        ; save registers
        push    bx
        push    dx		
        
        ; save error code
		push	ax
		; write error string
		mov	    ah, 09h
		int	    21h
		; write error code
        mov     bx, offset hex_buf
        pop     ax
        call    byte_to_hex
        mov     ah, 09h
        mov     dx, bx
        int     21h
        
        ; restore registers
        pop     dx
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
		jle	    exit
		add	    al, 7

exit:		
        ret       

EOF:		
        end	_
