![alt tag](https://raw.github.com/Xlogicx/tronsolitare/pictures/tronsolitare01.png)

# About:
TronSolitare is a 512-byte boot sector OS that is actually a game. This was heavily inspired by this project: https://github.com/Shikhin/tetranglix. I blatantly borrowed some programming techniques that they used. I originally found out about this project from issue 0x03 of PoC||GTFO. Even though this game is only 512 bytes, I took more time play-testing this game to make sure it was actually fun and challanging than I did programming it. Most of this play-testing went into tweeking the scoring system for maxfun. This game can be addicting when you start to understand the scoring system and know how close you got to winning (but didn't win).

# Gameplay:
Move the gamepeice around as long as you can while collecting bonuses and avoidng the wall, your own streak, and trap items. You win when the score is high enough. This game looks a little bit like nibbles/snake and a little bit like Tron. Unlike nibbles, the tail of the 'snake' does not follow you; every move perpetually stays on the screen. This is more of a game of strategy than action; the streak will actually pause on each item (bonus or trap) waiting for your next move. Deciding when to get or wait for bonuses and even whether to head right into a trap can be a fluid decision due to the complex and progressive scoring system.

# Scoring:
To win this game, you need to score 62,720 points. There are several ways to gain (and lose) points. In the begginning, every move your streak makes gains you only 1 point. With only 1794 game squares, just filling the screen with your streak would fall very short of winning the game. For each bonus item (the light-green numbered squares) you land on, the 1 base point per move is increased by 3 points. In other words, if you are playing and have gotten 3 bonus items, you are now getting 10 points per move (1 + 3 + 3 + 3). The number in the light-green bonus item also gives you its own bonus points; take the number in the box, add 1 to it, multiply it by 256, and that's the amount of extra points given to you (as a one time bonus). In other words, landing on a light-green '7' square would net you 2,048 bonus points. The light-red squares (from 0-6) work the same, only they subtract this many points. The 'unlucky' light-red '7' square kills you to death.

# Score Display:
The score is represented in just one character in the lower left corner. Even though there is only one character to represent the score, using all 255 code page 437 characters, and 16 different background and foreground colors, we actually have up to 65,536 unique(ish) values to display.

# The Characters:
The score initially starts with a black background and blue foreground. All of the code page 437 characters are incremented until the last character is reached. In order, these characters are:
 ☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼
 !"#$%&'()*+,-./0123456789:;<=>?
@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_
`abcdefghijklmnopqrstuvwxyz{|}~⌂
ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒ
áíóúñÑªº¿⌐¬½¼¡«»░▒▓│┤╡╢╖╕╣║╗╝╜╛┐
└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀
αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■

# The Colors:
Once the last character is reached, the character resets to the first character and the foreground color is incremented to the next color in a list of 16 colors. Once the last foreground color is reached (white), the character and foreground color resets and the background color increments. The game is won when the player reaches a score of the first character of a white background and brown foreground. In order, the colors are:
Black, Blue, Green. Cyan, Red, Magenta, Brown, Light Gray, Dark Gray, Light Blue, Light Green, Light Cyan, Light Red, Light Magenta, Yellow, White.

# Speed:
There are 4 speeds in this game. The speed progressively speeds up after the score reaches the Red, Dark Gray, and Light Red background colors. Initially, the speed will be about 0.439 seconds per move (439.4 miliseconds). After each speedup, it will be 109.85 miliseconds less per move.

# Stragegy:
DO NOT READ IF YOU WANT TO FIGURE OUT YOUR OWN STRATEGY
In nibbles, the easiest strategy to fill the entire screen is to start from the top and zig-zag all the way down, leaving some clearance to the right or left to be able to go back up and repeat. You are bound to collect the items along the way eventually. Repeat this enough times and you fill the screen.
This is not a winning strategy with TronSolitare. To win this game, you need to score a certain amount; and the score provided by merely filling the screen is much to low. The one-time bonuses help boost the score, but more importantly, they also progressively increase the points you get for each movement of the green streak.
Because of this progressive scoring, I like to think of this like an investment, and the earlier you get in on it, the better. This means that it is best to collect a lot of bonus items in the beggining, even at the cost of making the screen a little messy. Once you have collected enough bonus items and the game is still moving slow enough, try to fill in some of the areas that wont be as easy to do once it speeds up.
Hopefully by the time your score is high and your streak is moving lighting fast, you still saved yourself a fairly open area somewhere that you can zig-zag around in with no regard.
A note on penalty/trap items. You generally want to avoid these becuase they decrease your score by quite a bit, although they don't hurt the progressive scoring. My only excpetion to this is in the end when the game is moving at lightning speed. It is not worth it to avoid them; the cost of making the small space on the board that is left messy is too high. If you 'invested' well in the begginning, the progressive score per move should be so high that these penalties are virtually negligable.
A miscelanious general movement strategy that I use is to hug one of the walls as soon as possible and circle around the outer area and move my way inwards, collecting bonuses that are close enough. I deviate from this a little, but it's a helpful strategy in collecting many bonuses without making large parts of the board less accecible.

# Cheats:
This is open source, so there are many quick hacks to make this a less challanging (or more) game to play. Comments in the source code with a 'hashtag' of #CHEAT are particularly vulnerable lines of code for cheating. Notable areas of pre-commented cheating are to play a slower (but still progressive speed) game, or even just a consistently slow game, change the initial socre, change the score that the game is won at, magnify the progressive score (or turn it off for a SUPER challange), or even have complete invincibility.

# Technical Notes:
Assemble source - nasm tronsolitare.asm -f bin -o tronsolitare.bin
Run with qemu - qemu tronsolitare.bin
Create floppy image - Uncomment last line of code: ;times (1440 * 1024) - ($ - $$)  db 0
Run floppy image with qemu: qemu-system-i386 -fda tronsolitare.bin
Run floppy image in VirtualBox: Create a low spec VM and set it to boot to tronsolitare as the floppy image. Either rename image file to tronsolitare.img or use: nasm tronsolitare.asm -f bin -o tronsolitare.img
Disassemble tronsolitare.bin with objdump: objdump -D -b binary -mi386 -Maddr16,data16 tronsolitare.bin
