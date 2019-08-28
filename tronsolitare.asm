;Tron Solitare
;  *This is a PoC boot sector ( <512 bytes) game
;  *Controls to move are just up/down/left/right
;  *Avoid touching yourself, blue border, and the
;     unlucky red 7

[ORG 0x7c00]      ;add to offsets
LEFT  EQU 75
RIGHT EQU 77
UP    EQU 72
DOWN  EQU 80

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
 
   mov ah, 0xb8   ;text video memory
   mov es, ax     ;ES=0xB800

   mov al, 0x03
   int 0x10

   ;Seems that this isn't needed, but leaving in commented out in case it needs to be added back
   ;mov al, 0x03   ;Some BIOS crash without this.                 
   ;mov ch, 0x26
   ;inc ah
   ;int 0x10 

   ;Use this instead:
   mov ah, 1
   mov ch, 0x26
   int 0x10       

;Draw Border
   ;Fill in all blue
   mov cx, 0x07d0    ;whole screens worth
   mov ax, 0x1f20    ;empty blue background
   xor di, di
   rep stosw         ;push it to video memory

   ;fill in all black except for remaining blue edges
   mov di, 158       ;Almost 2nd row 2nd column (need to add 4)
   cbw               ;space char on black on black
   fillin:
   scasw
   scasw             ;Adjust for next line and column
   mov cl, 78        ;inner 78 columns (exclude side borders)
   rep stosw         ;push to video memory
   cmp di, 0x0efe    ;Is it the last col of last line we want?
   jne fillin        ;If not, loop to next line

   ;init the score
   mov bp, 0x0100    ;#CHEAT (You can set the initial score higher than this)

   ;Place the game peice in starting position
   mov di, 0x07d1 ;starting position
   mov al, 0x2f   ;char to display
   stosb     
   push ax           ;initial key (nothing)  

mainloop:
   call random        ;Maybe place an item on screen

   ;Wait Loop
   ;Get speed (based on game/score progress)
      mov ax, bp        ;read data at coordinate
      shr ax, 14        ;now value 0-3
      neg ax
      add ax, 4         ;#CHEAT, default is 4; make amount higher for overall slower (but still progressive) game

   mov bx, [0x046C]   ;Get timer state
   add bx, ax        ;Wait 1-4 ticks (progressive difficulty)
   ;add bx, 8          ;unprogressively slow cheat #CHEAT (comment above line out and uncomment this line)
   delay:
      cmp [0x046C], bx
      jb delay

   ;Get keyboard state
   mov ah, 1
   int 0x16
   pop ax
   jz persisted   ;if no keypress, jump to persisting move state

   ;Clear Keyboard buffer
   xor ah, ah
   int 0x16

   ;Otherwise, move in direction last chosen
   persisted:
   push ax
   ;Check for directional pushes and take action
   cmp ah, LEFT
   je left
   cmp ah, RIGHT
   je right
   cmp ah, UP
   je up
   cmp ah, DOWN
   jne mainloop

   down:
      add di, 158
      jmp movement_overhead

   left:
      sub di, 4      ;coordinate offset correction
      jmp movement_overhead
   up:
      sub di, 162
   right:

   movement_overhead:
      call collision_check
      mov ax, 0x2f20
      stosw  
      push di
      call score
      pop di
      jmp mainloop

   collision_check:
      mov ax, [es:di]   ;grab video buffer + current location

      ;Did we Lose?
         ;#CHEAT: comment out all 4 of these checks (8 instructions) to be invincible
         cmp ax, 0x2f20    ;did we land on green (self)?
         je gameover           
         cmp ax, 0x1f20    ;did we land on blue (border)?
         je gameover
         cmp di, 0x0f00    ;did we land in score coordinate?
         jnb gameover
         cmp ax, 0xcf37    ;magic red 7
         je gameover

      ;Score Changes
         xchg ah, al
         and ax, 0x0ff0    ;mask background
         cmp al, 0xa0      ;add to score
         je bonus
         cmp al, 0xc0      ;subtract from score
         mov al, 0x29      ;make itemstuff: routine use sub opcode 
         je penalty
      ret

gameover: 
   int 0x19 ; Reboot the system and restart the game.

   ;Legacy gameover, doesn't reboot, just ends with red screen
   ;xor di, di
   ;mov cx, 80*25
   ;mov ax, 0x4f20
   ;rep stosw  
   ;jmp gameover

   bonus:
      add byte [selfmodify + 2], 3
      mov al, 0x01 ;make itemstuff: routine use add opcode

   penalty:

   do_item:
      mov byte [math], al

   itemstuff:
      inc ah            ;1-8 instead of 0-7      
      xor al, al
      math:
      add bp, ax        ;read data at coordinate and subtract from score

      jnb comm_ret      ;sanity check for integer underflow

      underflow:
         mov bp, 0x0100

   comm_ret:
         ret

score:
   ;for each mov of character, add 'n' to score
      ;this source shows add ax, 1, however, each bonus
      ;item that is picked up increments this value by
      ;3 each time an item is picked up. Yes, this is 
      ;self modifying code, which is why the lable
      ;'selfmodify:' is seen above, to be conveniently
      ;used as an address to pivot off of in an
      ;add byte [selfmodify + offset to '1'], 3 instruction
   selfmodify: add bp, 1         ;increment character in coordinate
   ;Why 0xf600 as score ceiling:
      ;if it was something like 0xffff, a score from 0xfffe would
      ;likley integer overflow to a low range (due to the progressive)
      ;scoring. 0xf600 gives a good amount of slack for this. However,
      ;it's still "technically" possible to overflow; for example,
      ;hitting a '7' bonus item after already getting more than 171
      ;bonus items (2048 points for bonus, 514 points per move) would
      ;make the score go from 0xf5ff to 0x0001.
   cmp bp, 0xf600    ;is the score high enough to 'win' ;#CHEAT
   ja win
mov ax, bp
mov di, 0f02h
push ax
xchg ah,al
call hex2asc
pop ax
hex2asc:
aam 16
call hex2nib
hex2nib:
xchg ah,al
cmp al,0ah
sbb al,69h
das
stosb
mov al,7
stosb
   ret

random:
   ;Decide whether to place bonus/trap
      in al,(0x40)
      and al, 0x0f
      cmp al, 0x07
      jne undo

   push di           ;store coord

   ;Getting random pixel
      redo:
      in al,(0x40)            ;random
      xor ax, dx        ;xor it up a little
      xor dx, dx        ;clear dx
      add ax, [0x046C]  ;moar randomness
      mov cx, 0x07d0    ;Amount of pixels on screen
      div cx            ;dx now has random val
      shl dx, 1         ;adjust for 'even' pixel values
      ;Are we clobbering other data?
         cmp dh, 0x0f      ;Is the pixel the score?
         jnb redo          ;Get a different value

         mov di, dx
         mov ax, [es:di]   ;read data at coordinate
         cmp ax, 0x2f20    ;Are we on the snake?
         je redo
         cmp ax, 0x1f20    ;Are we on the border?
         je redo

   ;Display random pixel

      ;Decide on item-type and value
      powerup:
      in al,(0x40)      ;random
      and al, 0x07      ;get random 8 values
      add al, 0x31      ;baseline
      xchg cx, ax       ;cx has rand value
      in al,(0x40)      ;random
      ;background either 'A' or 'C' (light green or red)
         and ah, 0x20      ;keep bit 13
         add ah, 0xaf      ;turn bit 14 and 12 on
      mov al, cl        ;item-type + value

      stosw             ;display it
      pop di            ;restore coordinate

   undo:
   ret

win:
   mov dx, 100h
win1:
   inc dx                           ;incrememnt fill char/fg/bg (whichever is next)

   ;clear screen

   mov bx, [0x046C]   ;Get timer state
   add bx, 2
   delay2:
      cmp [0x046C], bx
      jne delay2

   mov ax, dx
   xor di, di
   mov cx, 0x07d0    ;enough for full screen
   rep stosw         ;commit to video memory

   mov di, 0x07c4                   ;coord to start 'YOU WIN!' message
   mov al, 0x0f                     ;white text on black background
   mov si, winmessage               ;get win message pointer
   mov cl, winmessage_e - winmessage
   winloop: movsb
   stosb                            ;commit char to video memory
   loop winloop                     ;is it the last character?
   jmp win1
   
   winmessage: 
   db 0x02, 0x20
   dq 0x214e495720554f59   ;YOU WIN!
   db 0x21, 0x21, 0x20, 0x02
   winmessage_e: 

   ;BIOS sig and padding
   times 510-($-$$) db 0
   dw 0xAA55

   ; Pad to floppy disk.
   ;times (1440 * 1024) - ($ - $$)  db 0
