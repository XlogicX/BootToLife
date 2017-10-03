[ORG 0x7c00]      ;add to offsets

;Init the environment
;  init data segment
;  init stack segment allocate area of mem
;  init E/video segment and allocate area of mem
;  Set to 0x03/80x25 text mode
;  Hide the cursor
   xor ax, ax     ;make it zero
   mov ds, ax     ;DS=0

   mov ss, ax     ;stack starts at 0
   mov sp, 0x9c00 ;200h past code start
 
   mov ax, 0xb800 ;text video memory
   mov es, ax     ;ES=0xB800

   mov al, 0x03
   xor ah, ah
   int 0x10

   mov al, 0x03   ;Some BIOS crash without this.                 
   mov ch, 0x26
   inc ah
   int 0x10    

;Clear the entire video area
mov cx, 0xffff	;maximum amount
xor di, di		;make sure we start at 1st pixel
mov ah, 0x0000	;black on black	
rep stosw		;repeat until done

mov cx, 2000		;actual screens worth
call screen_seed	;get random pixels onto screen

;================Main Loop===============
next_tick:
xor di, di					;start at pixel origin
life_check:
call count_n				;for current pixel, count 8 alive pixels surrounding it

;Life Check
cmp word [es:di], 0xff01	;is current pixel alive
jne dead					;if not go to the code for being 'dead'

;Process Life/Death into 2nd screen buffer
cmp cl, 2					;is it below 2?
jb die							;if so die
cmp cl, 3					;is it above 3?
ja die							;if so die
jmp life_check_end			;otherwise it's 2 or 3 and we stay alive

dead:
cmp cl, 3					;is it exactly 3?
je live							;give birth to this pixel
jmp life_check_end

die:
mov word [temp_screen_buffer + di], 0x0000	;load pixel data for death
jmp life_check_end

live:
mov word [temp_screen_buffer + di], 0xff01	;load pixel data for life

life_check_end:
add di, 2			;go to next pixel
cmp di, 4000		;see if we are done with pixels
jb life_check		;if not, go to the next pixel

;-----------Display Next Screen----------
; Time Dealy loop, so it doesn't blast too quick
mov bx, [0x046c]		;get clock
add bx, 2				;use 2 cycles
delay:
	cmp [0x046c], bx	;check cycle
	jb delay			;keep delaying if not hit

; Print the Results from 2nd buffer
xor di, di								;resit pixel origin
new_pixel:
mov ax, word [temp_screen_buffer + di]	;get the buffered pixel into register
stosw									;display it on screen
cmp di, 4000							;are we done with all the pixels?
jne new_pixel								;go to next pixel if not

inc word [iterations]				;increment total ticks
cmp word [iterations], 0x0500		;have we done 0x500 ticks?
jne next_tick							;if not, then do another
mov word [iterations], 0x0000		;if we have, reset ticks
mov cx, 2000						;set loop for 2000 pixels worth
xor di, di							;reset pixel origin
call screen_seed					;and get a new random screen
jmp next_tick						;now we can do another tick

;-------Put Random Pixels On Screen------
screen_seed:
	cmp cx, 0			;Are we done yet
	je end_seed				;return if done
	dec cx				;Otherwise note another pixel off
	mov ax, 0x0000		;a black pixel
	stosw				;print it
	rdtsc				;get random value into ax
	and al, 0x01		;just look at LSB
	cmp al, 0x01		;is bit a 1 (not 0)
	jne screen_seed		;if not, go back to top for another black pixle
	mov ax, 0xff01		;otherwise setup a white pixel (with 1 in al)
	stosw				;display it
	jmp screen_seed		;do another
	end_seed:
	ret

;Counting Neighbors, Result in CL
;Needs Bounds checking
;------------Counts Neighbors------------
;It stores the results in CL
;It uses a side effect of 'live' registers
;also having 0x01 in last (non-color) byte
count_n:
	xor cx, cx								;clear count
	mov bx, [es:di + 2]		;East			;get east pixel
	add cl, bl								;add 0x01 or 0x00 value it will already have
	mov bx, [es:di + 158]	;South West		;and so on...
	add cl, bl
	mov bx, [es:di + 160]	;South
	add cl, bl
	mov bx, [es:di + 162]	;South East
	add cl, bl
	mov bx, [es:di - 2]		;West
	add cl, bl
	mov bx, [es:di - 162]	;North West
	add cl, bl
	mov bx, [es:di - 160]	;North
	add cl, bl
	mov bx, [es:di - 158]	;North East
	add cl, bl
	ret

iterations:
dw 0

;BIOS sig and padding
times 510-($-$$) db 0
dw 0xAA55

temp_screen_buffer:
