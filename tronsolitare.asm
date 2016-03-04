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
   mov di, 0x0f02
   mov ax, 0x0100    ;#CHEAT (You can set the initial score higher than this)
   stosw 

   ;Place the game peice in starting position
   mov di, 0x07d1 ;starting position
   mov al, 0x2f   ;char to display
   stosb     
   push ax           ;initial key (nothing)  

mainloop:
   call random        ;Maybe place an item on screen

   ;Wait Loop
   ;Get speed (based on game/score progress)
      mov ax, [es:0x0f02]   ;read data at coordinate
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
      call score
      jmp mainloop

   collision_check:
      mov ax, [es:di]   ;grab video buffer + current location

      ;Did we Lose?
         ;#CHEAT: comment out all 4 of these checks (8 instructions) to be invincible
         cmp ax, 0x2f20    ;did we land on green (self)?
         je gameover           
         cmp ax, 0x1f20    ;did we land on blue (border)?
         je gameover
         cmp bx, 0x0f02    ;did we land in score coordinate?
         je gameover
         cmp ax, 0xcf37    ;magic red 7
         je gameover

      ;Score Changes
         push ax           ;save copy of ax/item
         and ax, 0xf000    ;mask background
         cmp ax, 0xa000    ;add to score
         je bonus
         cmp ax, 0xc000    ;subtract from score
         je penalty
         pop ax            ;restore ax
      ret

   bonus:
      mov byte [math], 0x01   ;make itemstuff: routine use add opcode
      call itemstuff
      stosw             ;put data back in
      mov di, bx        ;restore coordinate
      add byte [selfmodify + 2], 3
      
      ret
   penalty:
      mov byte [math], 0x29   ;make itemstuff: routine use sub opcode 
      call itemstuff
      cmp ax, 0xe000    ;sanity check for integer underflow
      ja underflow
      stosw             ;put data back in
      mov di, bx        ;restore coordinate
      ret      

      underflow:
         mov ax, 0x0100
         stosw
         mov di, bx
         ret

   itemstuff:
      pop dx   ;store return
      pop ax
      and ax, 0x000f
      inc ax            ;1-8 instead of 0-7      
      shl ax, 8         ;multiply value by 256
      push ax           ;store the value

      mov bx, di        ;save coordinate
      mov di, 0x0f02    ;set coordinate
      mov ax, [es:di]   ;read data at coordinate and subtract from score
      pop cx
      math:
      add ax, cx        ;'add' is just a suggestion...
      push dx  ;restore return
      ret

score:
   push di
   mov di, 0x0f02    ;set coordinate
   mov ax, [es:di]   ;read data at coordinate
   ;for each mov of character, add 'n' to score
      ;this source shows add ax, 1, however, each bonus
      ;item that is picked up increments this value by
      ;3 each time an item is picked up. Yes, this is 
      ;self modifying code, which is why the lable
      ;'selfmodify:' is seen above, to be conveniently
      ;used as an address to pivot off of in an
      ;add byte [selfmodify + offset to '1'], 3 instruction
   selfmodify: add ax, 1         ;increment character in coordinate
   stosw             ;put data back in
   pop di
   ;Why 0xf600 as score ceiling:
      ;if it was something like 0xffff, a score from 0xfffe would
      ;likley integer overflow to a low range (due to the progressive)
      ;scoring. 0xf600 gives a good amount of slack for this. However,
      ;it's still "technically" possible to overflow; for example,
      ;hitting a '7' bonus item after already getting more than 171
      ;bonus items (2048 points for bonus, 514 points per move) would
      ;make the score go from 0xf5ff to 0x0001.
   cmp ax, 0xf600    ;is the score high enough to 'win' ;#CHEAT
   ja win
   ret

random:
   ;Decide whether to place bonus/trap
      rdtsc
      and al, 0x0f
      cmp al, 0x07
      jne undo

   push cx           ;save cx

   ;Getting random pixel
      redo:
      rdtsc             ;random
      xor ax, dx        ;xor it up a little
      xor dx, dx        ;clear dx
      add ax, [0x046C]  ;moar randomness
      mov cx, 0x07d0    ;Amount of pixels on screen
      div cx            ;dx now has random val
      shl dx, 1         ;adjust for 'even' pixel values
      ;Are we clobbering other data?
         cmp dx, 0x0f02    ;Is the pixel the score?
         je redo           ;Get a different value

         push di           ;store coord
         mov di, dx
         mov ax, [es:di]   ;read data at coordinate
         pop di            ;restore coord
         cmp ax, 0x2f20    ;Are we on the snake?
         je redo
         cmp ax, 0x1f20    ;Are we on the border?
         je redo

   ;Display random pixel
      push di           ;save current coordinate
      mov di, dx        ;put rand coord in current

      ;Decide on item-type and value
      powerup:
      rdtsc             ;random
      and ax, 0x0007    ;get random 8 values
      mov cx, ax        ;cx has rand value
      add cx, 0x5f30    ;baseline
      rdtsc             ;random
      ;background either 'A' or 'C' (light green or red)
         and ax, 0x2000    ;keep bit 13
         add ah, 0x50    ;turn bit 14 and 12 on
      add ax, cx        ;item-type + value

      stosw             ;display it
      pop di            ;restore coordinate

   pop cx            ;restore cx

   undo:
   ret

gameover: 
   int 0x19 ; Reboot the system and restart the game.

   ;Legacy gameover, doesn't reboot, just ends with red screen
   ;xor di, di
   ;mov cx, 80*25
   ;mov ax, 0x4f20
   ;rep stosw  
   ;jmp gameover

win:
   ;clear screen

   mov bx, [0x046C]   ;Get timer state
   add bx, 2
   delay2:
      cmp [0x046C], bx
      jne delay2

   mov di, 0
   mov cx, 0x07d0    ;enough for full screen
   winbg: mov ax, 0x0100  ;xor ax, ax wont work, needs to be this machine-code format
   rep stosw         ;commit to video memory

   mov di, 0x07c4                   ;coord to start 'YOU WIN!' message
   xor cl, cl                       ;clear counter register
   winloop: mov al, [winmessage]    ;get win message pointer
   mov ah, 0x0f                     ;white text on black background
   stosw                            ;commit char to video memory
   inc byte [winloop + 0x01]        ;next character
   cmp di, 0x07e0                   ;is it the last character?
   jne winloop
   inc word [winbg + 0x01]          ;incrememnt fill char/fg/bg (whichever is next)
   sub byte [winloop + 0x01], 14     ;back to first character upon next full loop
   jmp win
   
   winmessage: 
   db 0x02, 0x20
   dq 0x214e495720554f59   ;YOU WIN!
   db 0x21, 0x21, 0x20, 0x02

   ;BIOS sig and padding
   times 510-($-$$) db 0
   dw 0xAA55

   ; Pad to floppy disk.
   ;times (1440 * 1024) - ($ - $$)  db 0
