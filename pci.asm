; goto -)
		model 	tiny
        .386
		locals
		.code
		org 	100h

_:		jmp	start

CFG_ADDR    equ     0cf8h
CFG_DATA    equ     0cfch      

bus_msg     db  ' Bus number #$'
dev_msg 	db	' Device number #$'
func_msg	db	' Function number #$'
vendor_msg  db  ' VendorID: '
dev_msg     db  ' DeviceID: '
byte_buf    db  'xx $'
word_buf    db  'xxxx $'
endl        db  13,10,'$'

p1 	        db "C:/WORK/PCI2",0
p2	        db "C:/WORK",0
dir1 	    db "C:/WORK/PCI2/x",0
file 	    db "xxxx",0 

sym_tab     db "0123456789ABCDEF"

mbuff 	    db 150 dup(0),"$"

start:		
        push 	cs
		pop	    es

        call print_devices
        
        ret

mer 	db	"error!",13,10,"$"

_e:     
        mov     dx, offset mer
	    mov     ax, 0900h
	    int     21h
	    ret

print_devices:

        mov ax, 3b00h	        ; change dir
	    mov dx, offset p1
	    int 21h
        jc _e

        mov     ecx, 80000000h 	; null bus null dev null func

dev_loop:
        mov     dx, CFG_ADDR	; 0cf8 - Config Address port	  
	    mov     eax, ecx		; save address device to eax
	    add     eax, 0Ch		; we want to read specified row (0C) from configuration space header 
                                ; which contains header type 
                                ; see https://en.wikipedia.org/wiki/PCI_configuration_space#/media/File:Pci-config-space.svg
	    out     dx, eax		    ; send to config address query for device (device address in eax)
	    
        mov     dx, CFG_DATA    ; 0cfc - Config Data port
	    in      eax, dx		    ; read 0Ch from configuration space

        cmp     ax, 0ffffh		; compare to -1 (check device exist)
	    je      dev_exit	    ; if device not exist - exit
	
        xor     si, si
        xor     ebx, ebx

	    shr     eax, 23		    ; check for multifunction (7 bit of Header type, 16 + 7 = 23)
	    and     ax, 0001h
        cmp     ax, 1		
	    jne     func_loop

        mov     si, 1           ; use si as multifunction bit flag

func_loop:
        mov     eax, ecx		; device address to eax
        or      eax, ebx        ; ebx - function mask (3 bits, 8-10 in struct)   
        mov     esi, eax        ; save device address with function	

        mov     dx, CFG_ADDR
        out     dx, eax
        mov     dx, CFG_DATA
        in      eax, dx

        cmp     ax, -1          ; (check device exist)
        je      inc_func
        call    print_device    ; if exist - print it

        cmp     si, 1           ; check multifunction flag
        jne     inc_dev

inc_func:
        shr     ebx, 8          ; increment function number
        inc     ebx
        cmp     ebx, 8          ; 8 = 1000 - above maximum count of multifunction
        je      inc_dev
        shl     ebx, 8          ; ebx - function mask (3 bits, 8-10 in struct)
        jmp     func_loop

inc_dev:
        add     ecx, 0800h		; go to next device
	    test    ecx, 01000000h 	; check device exist (01000000 hex -> 25th bit = 1, other bits = 0)
	    jz      dev_loop		
        
dev_exit:

        mov     ax, 3b00h       ; move to exec dir	
	    mov     dx, offset p2 
	    int     21h

        ret

print_device:
        ; eax - DeviceID | VendorID (each has size of 16 bits)
        ; esi - device address

        ; save registers
        push    edx
        push    ebx
        push    eax

        mov     bx, offset byte_buf

        ; print bus number

        mov 	dx, offset bus_msg
		mov 	ax, 0900h	
		int	    21h
        
        mov     eax, esi
        shr     eax, 16     ; get bus number, 16-23 bits in struct
        and     eax, 0ffh
        call    byte_to_hex

        mov     dx, offset byte_buf
        mov     ax, 0900h
        int     21h   
        
        ; print device number

        mov 	dx, offset dev_msg
		mov 	ax, 0900h	
		int	    21h
        
        mov     eax, esi
        shr     eax, 11     ; get device number, 11-15 bits in struct
        and     eax, 1fh
        call    byte_to_hex

        mov     dx, offset byte_buf
        mov     ax, 0900h
        int     21h

        ; print function number

        mov 	dx, offset func_msg
		mov 	ax, 0900h	
		int	    21h
        
        mov     eax, esi
        shr     eax, 8     ; get function number, 8-10 bits in struct
        and     eax, 7h
        call    byte_to_hex

        mov     dx, offset byte_buf
        mov     ax, 0900h
        int     21h

        mov     dx, offset endl
        mov     ax, 0900h
        int     21h

        ; print vendorID

        mov     dx, offset vendor_msg
        mov     ax, 0900h
        int     21h

        ; restore eax with devID, vendorID 
        pop     eax

        mov     bx, offset word_buf
        call    word_to_hex
        push    eax

        mov     dx, offset word_buf
        mov     ax, 0900h
        int     21h

        ; print deviceID

        mov     dx, offset device_msg
        mov     ax, 0900h
        int     21h

        ; restore eax with devID, vendorID 
        pop     eax
        shr     eax, 16

        mov     bx, offset word_buf
        call    word_to_hex

        mov     dx, offset word_buf
        mov     ax, 0900h
        int     21h

        mov     dx, offset endl
        mov     ax, 0900h
        int     21h

        ; resotre registers
        pop     ebx
        pop     edx

        ret

info:

	pusha

    ; convert first sym

	mov     si, offset file
	lea     bx, sym_tab
	mov     ax, cx
	shr     ax, 12
	xlat
	mov     byte ptr[si], al
	
	push    si
	mov     si, offset dir1
	mov     byte ptr[si+13], al	
	xor     al, al
	mov     ah, 3bh
	mov     dx, offset si ; cd pci2/nextdir
	pop     si
	int     21h
	jc      _e	

    ; convert other symbol

 	mov ax, cx
	shr ax, 8
	and al, 0fh
	xlat
	mov byte ptr[si+1], al
	
 	mov ax, cx
	shr ax, 4
	and al, 0fh
	xlat
	mov byte ptr[si+2], al
	
	mov ax, cx
	and al, 0fh
	xlat
	mov byte ptr[si+3], al

    ; open file

	xor     al,al
	mov     ax, 3d00h
	mov     dx, si
	int     21h
	jc      _e

	mov     dx, offset mbuff
	mov     bx, ax
	mov     cx, 100
	mov     ax, 3f00h
	int     21h

	mov     cx, 100
	sub     cx, ax
_loop:	
	mov     bx, dx
	add     bx, ax
	add     bx, cx
	mov     byte ptr [bx], ' '
	loop    _loop
		
	mov     ax, 0900h
	int     21h
 
    ; move to parent dir

	mov     ax, 3b00h	
	mov     dx, offset p1 ; cd pci2
	int     21h
	jc      _e

	popa

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

:-)
@echo off
tasm /m pci.bat
tlink /x/t pci.obj
del pci.obj
