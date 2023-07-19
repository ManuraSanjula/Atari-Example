    processor 6502

; Added the line below to be compatible with vcs.h version 1.05 -- Steve Engelhardt
TIA_BASE_READ_ADDRESS = $30

    include vcs.h



;===============================================================================
; A S S E M B L E R - S W I T C H E S
;===============================================================================

FILL_OPT        = 1             ; fill optimized bytes with NOPs
SCREENSAVER     = 1             ; compile with screensaver code
TRAINER         = 0             ; enable training mode
NTSC            = 1             ; compile for NTSC


;===============================================================================
; C O N S T A N T S
;===============================================================================

; initial values for the random number generator:
SEED_LO         = $14           ; change "to go, where no one has gone before" :)
SEED_HI         = $A8

; color constants:
BLACK           = $00
GREY            = $06
ORANGE          = $2A
  IF NTSC
YELLOW          = $1C
RED             = $48
BLUE            = $84
CYAN            = $B0
GREEN           = $D2
  ELSE
YELLOW          = $2C
RED             = $68
BLUE            = $B4
CYAN            = $70
GREEN           = $52
  ENDIF
DARK_RED        = RED    - $6
LIGHT_GREEN     = GREEN  + $8
BROWN           = YELLOW - $C
LIGHT_GREY      = GREY   + $6
DARK_BLUE       = BLUE   - $4

; main game constants:
NUM_BLOCKS      = 6             ; max. number of block on screen
SECTION_BLOCKS  = 16            ; number of blocks/stage
BLOCK_PARTS     = 2             ; each block has two parts
BLOCK_SIZE      = 32            ; number of lines/block
NUM_LINES       = 160           ; number of lines in main kernel
MAX_LEVEL       = 48            ; number of difficulty levels

DIGIT_H         = 8             ; height of the score digits
JET_Y           = 19            ; fixed y-position for jet
MIN_MISSILE     = JET_Y-6       ; starting position of player missile
MAX_MISSILE     = NUM_LINES+1
MISSILE_SPEED   = 6             ; y-speed of the jet missile
ROAD_HEIGHT     = 13            ; number of lines for road
INTRO_SCROLL    = 48            ; counter for scrolling into new game

SWITCH_PAGE_ID  = 9             ; first pattern id with data on different page

; constants for shape-ids:
ID_EXPLOSION0   = 0             ; used for explosion end
ID_EXPLOSION1   = 1
ID_EXPLOSION2   = 2
ID_EXPLOSION3   = 3
ID_PLANE        = 4
ID_HELI0        = 5
ID_HELI1        = 6
ID_SHIP         = 7
ID_BRIDGE       = 8
ID_HOUSE        = 9
ID_FUEL         = 10

; flags for blockLst:
PF1_PAGE_FLAG   = %00000001     ; pattern for PF1 in page $FC or $FD
PF2_PAGE_FLAG   = %00000010     ; pattern for PF1 in page $FC or $FD
PF_COLOR_FLAG   = %00000100     ; bright or dark green PF
PATROL_FLAG     = %00010000     ; enemy is patroling (change directions)
PF_COLLIDE_FLAG = %00100000     ; enemy collided with playfield
ENEMY_MOVE_FLAG = %01000000     ; enemy is moving
PF_ROAD_FLAG    = %10000000     ; display road and bridge

; flags for State1Lst:
DIRECTION_FLAG  = %00001000     ; move direction of object
FINE_MASK       = %11110000     ; mask bits for HMxy
NUSIZ_MASK      = %00000111     ; mask bits for NUSIx

; flags for PF_State:
ISLAND_FLAG     = %10000000     ; island displayed in block
CHANGE_FLAG     = %01000000     ; begin or end of island (JTZ: this interpretation might be wrong)

; joystick bits:
MOVE_RIGHT      = %00001000
MOVE_LEFT       = %00000100
MOVE_DOWN       = %00000010
MOVE_UP         = %00000001

; values for ENAxy:
DISABLE         = %00
ENABLE          = %10           ; value for enabling a missile

; values for NUSIZx:
TWO_COPIES      = %001
THREE_COPIES    = %011
DOUBLE_SIZE     = %101
QUAD_SIZE       = %111

; mask for SWCHB:
BW_MASK         = %1000         ; black and white bit


;===============================================================================
; Z P - V A R I A B L E S
;===============================================================================

gameVariation   = $80           ;               one or two player game
gameDelay       = $81           ;               delay before gameVariation changes
frameCnt        = $82           ;               simple frame counter
random          = $83           ;               8 bit random number (used for: start of ship and helicopter, sound)
joystick        = $84           ;               saved joystick value (?000rldu)
  IF SCREENSAVER
SS_XOR          = $85           ;               change colors in screensaver mode (0/$01..$ff)
SS_Mask         = $86           ;               darker colors in screensaver mode ($ff/$f7)
  ENDIF
dXSpeed         = $87           ;               x-acceleration
prevPF1PatId    = $88           ;               playfield pattern Id of the previous block
PF_State        = $89           ;               io000000
sectionEnd      = $8A           ;               0 = end of section
blockOffset     = $8B           ;               offset into first displayed block
posYLo          = $8C           ;               low value of blockOffset
bridgeExplode   = $8D           ;               counter for bridge explosion

; the next 36 bytes are used to save all variables for six blocks:
;---------------------------------------
blockLst        = $8E           ; ..$93         flags for block definition
blockLstEnd     = blockLst+NUM_BLOCKS-1
;---------------------------------------
XPos1Lst        = $94           ; ..$99         coarse value for x-positioning of object
XPos1LstEnd     = XPos1Lst+NUM_BLOCKS-1
;---------------------------------------
State1Lst       = $9A           ; ..$9F         bit 0..2 = NUSIZ1, bit 3 = REFP1, 4..7 = fine move
State1LstEnd    = State1Lst+NUM_BLOCKS-1
;---------------------------------------
Shape1IdLst     = $A0           ;.. $A5         ids for object
Shape1IdLstEnd  = Shape1IdLst+NUM_BLOCKS-1
;---------------------------------------
PF1Lst          = $A6           ; ..$AB         low pointer for PF1 data
PF1LstEnd       = PF1Lst+NUM_BLOCKS-1
;---------------------------------------
PF2Lst          = $AC           ; ..$B1         low pointer for PF2 data
PF2LstEnd       = PF2Lst+NUM_BLOCKS-1
;---------------------------------------
; end of block variables
missileY        = $B2           ;               y-position of player missile
playerX         = $B3           ;               x-position of player jet
speedX          = $B4           ;               x-speed of player jet
speedY          = $B5           ;               y-speed of play jet
blockPart       = $B6           ;               1/2 (used for bridge)
fuelHi          = $B7           ;               high value of fuel (displayed)
fuelLo          = $B8           ;               low value of fuel
sectionBlock    = $B9           ;               number of block in current section (16..1)
shapePtr0       = $BA           ; ..$BB         pointer to the shape for the player jet
PF1PatId        = $BC           ;               playfield pattern Id for the new generated block
;---------------------------------------
player1State    = $BD           ; ..$C1
level           = player1State  ;               difficulty level for current player (1..48)
randomLoSave    = player1State+1;               saved random generator values for begin of level
randomHiSave    = player1State+2;
livesPtr        = player1State+3; ..$C1
;---------------------------------------
player2State    = $C2           ; ..$C5
livesPtr2       = player2State+3;               the high pointer is not saved here, because it's const
;---------------------------------------
gameMode        = $C6           ;               0 = running; -1 = game over; 1..48 = scroll into game
shapePtr1a      = $C7           ; ..$C8
shapePtr1b      = $C9           ; ..$CA
colorPtr        = $CB           ; ..$CC
scorePtr1       = $CD           ; ..$D8         12 bytes for the score display of current player
PF1Ptr          = $D9           ; ..$DA
PF2Ptr          = $DB           ; ..$DC
;---------------------------------------
scorePtr2       = $DD           ; ..$E7         12 bytes for the score display of other player
; the constant hi-pointers are temporary used:
blockNum        = scorePtr2+1   ;               current block in kernel
reflect0        = scorePtr2+3   ;               flag for GRP0 (player jet) reflection
hitEnemyIdx     = scorePtr2+5   ;               index of enemy that was hit by missile
PFCrashFlag     = scorePtr2+7   ;               jet crashed into playfield
missileFlag     = scorePtr2+9   ;               $ff means: missile enabled
;---------------------------------------
collidedEnemy   = $E8           ;               jet collided with enemy (id)
randomLo        = $E9           ;               current number generator values
randomHi        = $EA
randomLoSave2   = $EB           ;               saved number generator values for current player
randomHiSave2   = $EC
temp2           = $ED           ;
roadBlock       = temp2         ;               bit 7 = 1: road in block
PFcolor         = $EE           ;               color of river banks
valleyWidth     = PFcolor       ;               define minimum width of valley in first levels (6/0)
playerColor     = $EF           ;               YELLOW/BLACK
stateBKColor    = $F0           ;               GREY (const!)
statePFColor    = $F1           ;               YELLOW+2 (const!)
temp            = $F2           ;               main temporary variable
diffPF          = temp          ;               difference between to PF pattern ids
zero1           = $f3           ;               always zero!
player          = $F4           ;               0/1
missileX        = $F5           ;               x-position of player missile
zero2           = $F6           ;               always zero!
  IF SCREENSAVER
SS_Delay        = $F7           ;               screensaver delay
  ENDIF
sound0Id        = $F8           ;
sound0Cnt       = $F9
bridgeSound     = $FA           ;               bridge is exploding
missileSound    = $FB           ;               missile fired
temp3           = $FC
blockLine       = temp3         ;               current displayed line of block in kernel
maxId           = temp3
lineNum         = $FD           ;               counter for kernel lines


;===============================================================================
; M A C R O S
;===============================================================================

  MAC FILL_NOP
    IF FILL_OPT
      REPEAT {1}
         NOP
      REPEND
    ENDIF
  ENDM


;===============================================================================
; R O M - C O D E (Part 1)
;===============================================================================

       ORG $F000

START:
       SEI                      ; 2
       CLD                      ; 2
       LDX    #0                ; 2
Reset:
       LDA    #0                ; 2
.loopClear:
       STA    $00,X             ; 4
       TXS                      ; 2
       INX                      ; 2
       BNE    .loopClear        ; 2
       JSR    SetScorePtrs      ; 6
       LDA    #>Zero            ; 2
       LDX    #12-1             ; 2
       JSR    SetScorePtr1      ; 6             set high-pointers to $FB
       LDX    #colorPtr+1-PF1Lst; 2             #38
       JSR    GameInit          ; 6
       LDA    random            ; 3
       BNE    MainLoop          ; 2
       INC    random            ; 5
       STA    livesPtr          ; 3             = 0!
       LDA    #<One             ; 2
       STA    scorePtr1+10      ; 3

MainLoop:
       LDX    #4                ; 2             offset ball
       LDA    fuelHi            ; 3
       LSR                      ; 2
       LSR                      ; 2
       LSR                      ; 2
       CLC                      ; 2
       ADC    #69               ; 2
       JSR    SetPosX           ; 6             position ball for fuel display

; *** prepare everything for the main kernel: ***
; set all color registers (and NUSIZ1 = 0)
       INX                      ; 2             x = 5!
.loopSetColors:
       LDA    ColorTab,X        ; 4
  IF SCREENSAVER
       EOR    SS_XOR            ; 3
       AND    SS_Mask           ; 3
  ELSE
       FILL_NOP 4
  ENDIF
       STA    PFcolor,X         ; 4
       STA    NUSIZ1,X          ; 4
       DEX                      ; 2
       BPL    .loopSetColors    ; 2
       TAY                      ; 2             y = 0!
       LDA    scorePtr1+10      ; 3
       CMP    #<Two             ; 2
       BEQ    .skipTwo          ; 2
       LDA    SWCHB             ; 4
       LSR                      ; 2             reset pressed?
       BCC    .skipTwo          ; 2              yes, skip player 2
       LDA    player            ; 3             current player = 2?
       BEQ    .skipTwo          ; 2              no, skip
       STY    playerColor       ; 3              yes, set..
       STY    COLUP0            ; 3              ..and player 2 color = 0
.skipTwo:

; flicker background when bridge explodes:
       LDA    bridgeExplode     ; 3
       BEQ    .skipExplosion    ; 2
       DEC    bridgeExplode     ; 5
       LSR                      ; 2
       BCC    .skipExplosion    ; 2
       LDA    #DARK_RED         ; 2             flicker background red
  IF SCREENSAVER
       AND    SS_Mask           ; 3
  ELSE
       FILL_NOP 2
  ENDIF
       STA    COLUBK            ; 3
.skipExplosion:

       INX                      ; 2             x = 0!
       STX    temp              ; 3
       STX    NUSIZ0            ; 3
       LDY    playerX           ; 3
       LDA    reflect0          ; 3
       STA    REFP0             ; 3
       BEQ    .noReflect        ; 2
       INY                      ; 2             adjust x-pos
.noReflect:
       TYA                      ; 2
       JSR    SetPosX           ; 6             x-position player jet
       INX                      ; 2
       STX    CTRLPF            ; 3             reflect playfield

       STX    VDELP1            ; 3             enable vertical delay for player 1

; set size, reflect and postion for top enemy object;
       LDY    XPos1Lst +NUM_BLOCKS-1; 3
       LDA    State1Lst+NUM_BLOCKS-1; 3
       STA    NUSIZ1            ; 3
       STA    REFP1             ; 3
       JSR    SetPosX2          ; 6             position top enemy object

; x-position missile:
       INX                      ; 2
       LDA    missileX          ; 3
       JSR    SetPosX           ; 6             position missile

       JSR    DoHMove           ; 6
       STY    PF0               ; 3             enable complete PF0 (y=$ff)

; clear collsion variables:
       STY    hitEnemyIdx       ; 3
       STY    PFCrashFlag       ; 3
       STY    missileFlag       ; 3
       STY    collidedEnemy     ; 3

; set variables for top block:
       LDX    #NUM_BLOCKS-1     ; 2
       JSR    SetPFxPtr         ; 6
       LDA    blockOffset       ; 3
       CMP    #3                ; 2             top block just started?
       BCS    .skipDex          ; 2              no, skip
       DEX                      ; 2              yes, start at block 4
.skipDex:
       STX    blockNum          ; 3
       LDY    Shape1IdLst,X     ; 4
       LDX    shapePtr1aTab,Y   ; 4
       STX    shapePtr1a        ; 3
       LDX    shapePtr1bTab,Y   ; 4
       STX    shapePtr1b        ; 3
       LDX    ColorPtrTab,Y     ; 4
       STX    colorPtr          ; 3
       STA    CXCLR             ; 3             clear all collison registers
       STA    HMCLR             ; 3
; calculate offset into first block:
       TAX                      ; 2
       SEC                      ; 2
       SBC    #1                ; 2
       AND    #$1F              ; 2
       STA    blockLine         ; 3
       LSR    blockLine         ; 5             0..15
       CMP    #26               ; 2
       BCC    lowOffset         ; 2
       SBC    #22               ; 2
       BNE    endOffset         ; 2

lowOffset:
       CMP    #4                ; 2
       BCC    endOffset         ; 2
       AND    #%01              ; 2
       ORA    #%10              ; 2
endOffset:

; set entrypoint into kernel:
       TAY                      ; 2
       LDA    JmpHiTab,Y        ; 4
       PHA                      ; 3
       LDA    JmpLoTab,Y        ; 4
       PHA                      ; 3

; prepare graphics for first line of kernel:
       TXA                      ; 2
       LSR                      ; 2
       TAY                      ; 2
       LDA    (shapePtr1a),Y    ; 5
       BCC    .evenLine         ; 2             even blockOffset!
       LDA    (shapePtr1b),Y    ; 5
.evenLine:
       CPX    #26               ; 2             blockoffset >= 26?
       BCS    .noShape          ; 2              yes, skip enemy shape
       CPX    #3                ; 2             blockoffset < 3?
       BCC    .noShape          ; 2              yes, skip enemy shape
       STA    GRP1              ; 3              no, display enemy shape in first row
       LDA    #0                ; 2
       STA    GRP0              ; 3             VDELP1!
.noShape:
       LDA    (PF1Ptr),Y        ; 5
       STA    PF1               ; 3
       LDA    (PF2Ptr),Y        ; 5
       STA    PF2               ; 3
       LDA    (colorPtr),Y      ; 5
  IF SCREENSAVER
       EOR    SS_XOR            ; 3
       AND    SS_Mask           ; 3
  ELSE
       FILL_NOP 4
  ENDIF
       STA    COLUP1            ; 3
       LDX    blockNum          ; 3
       LDA    blockLst,X        ; 4
       STA    roadBlock         ; 3             save road-state
       AND    #PF_COLOR_FLAG    ; 2
       ORA    #GREEN            ; 2
  IF SCREENSAVER
       EOR    SS_XOR            ; 3
       AND    SS_Mask           ; 3
  ELSE
       FILL_NOP 4
  ENDIF
       STA    PFcolor           ; 3
       BIT    blockLstEnd       ; 3             road in first block?
       BPL    .noRoad           ; 2              no, use green color
       CPY    #ROAD_HEIGHT      ; 2             offset inside road?
       BCS    .noRoad           ; 2              no, use green color
       LDA    RoadColorTab,Y    ; 4              yes, use road colors
  IF SCREENSAVER
       EOR    SS_XOR            ; 3
       AND    SS_Mask           ; 3
  ELSE
       FILL_NOP 4
  ENDIF
.noRoad:
       STA    COLUPF            ; 3
       LDY    #NUM_LINES        ; 2
       STY    lineNum           ; 3
.waitTim:
       LDA    INTIM             ; 4
       BNE    .waitTim          ; 2
       STA    WSYNC             ; 3
       STA    HMOVE             ; 3
       STA    VBLANK            ; 3
       RTS                      ; 6             jump into kernel!

; *** main display kernel: ***
DisplayKernel SUBROUTINE

; first some external code to save cycles in the kernel:
JmpPoint2:                      ;12
       INC    lineNum           ; 5
       LDY    blockLine         ; 3
       BPL    enterKernel2      ; 3

.skipJet0:
       LDX    zero2             ; 3             load 0 with exactly 3 cylces
       BEQ    .contJet0         ; 3

.noRoad:
       LDA    PFcolor           ; 3
       JMP    .contPFColor      ; 3

.doJet0a:
       LDA    (shapePtr0),Y     ; 5
       TAX                      ; 2
       LDA    #$00              ; 2
.loopKernel1:                   ;   @19
       BEQ    .contJet0a        ; 2             this jump is taken when comming from .doJet0a
       BNE    .contKernel1      ; 3             this jump is taken when comming from .loopkernel1

  IF SCREENSAVER = 0
       FILL_NOP 1
  ENDIF

JmpPoint3:                      ;12
       JSR    Wait12            ;12
.contKernel1:
       NOP                      ; 2 @26
;--------------------------------------
; even line:
; - ...
; - draw player jet
; - load new P1 shape

; *** here starts the main kernel loop: ***
.loopKernel:                    ;
       CPY    #JET_Y            ; 2             draw player jet?
       BCS    .skipJet0         ; 2              no, skip
       LDA    (shapePtr0),Y     ; 5              yes, load data..
       TAX                      ; 2              ..into x
.contJet0:
       LDY    blockLine         ; 3
       BIT    roadBlock         ; 3             road displayed?
       BPL    .noRoad           ; 2              no, normal PF color
       LDA    RoadColorTab,Y    ; 4              yes, load road colors
  IF SCREENSAVER
       EOR    SS_XOR            ; 3
.contPFColor:
       AND    SS_Mask           ; 3
  ELSE
       FILL_NOP 2
.contPFColor:
       FILL_NOP 1
  ENDIF
       STA.w  temp              ; 4
       LDA    (shapePtr1b),Y    ; 5
       STA    GRP1              ; 3             time doesn't matter (VDELP1!)
       LDA    (PF1Ptr),Y        ; 5
       STA    PF1               ; 3 @75
;--------------------------------------
; new line starts here!
; odd line:
; - set PF color
; - set P1 color
; - change PF
       STA    HMOVE             ; 3
       STX    GRP0              ; 3 @2          this also updates GRP1
       LDA    temp              ; 3
       STA    COLUPF            ; 3 @8
       LDA    (colorPtr),Y      ; 5
  IF SCREENSAVER
       EOR    SS_XOR            ; 3
       AND    SS_Mask           ; 3
  ELSE
       FILL_NOP 4
  ENDIF
       STA    COLUP1            ; 3 @22
       LDA    (PF2Ptr),Y        ; 5
       STA    PF2               ; 3 @30
enterKernel2:
       LDA    (shapePtr1a),Y    ; 5
       STA    GRP1              ; 3             time doesn't matter (VDELP1!)
       LDY    lineNum           ; 3
       DEY                      ; 2
       BEQ    .exitKernel2      ; 2
       CPY    #JET_Y            ; 2
       BCC    .doJet0a          ; 2
       TYA                      ; 2
       SBC    missileY          ; 3
       AND    #$F8              ; 2
       BNE    .skipEnable0      ; 2
       LDA    #ENABLE           ; 2
.skipEnable0:
       LDX    #$00              ; 2
.contJet0a:
       DEY                      ; 2
       STY    lineNum           ; 3
       STA    WSYNC             ; 3
;--------------------------------------
; even line:
; - en-/disable missile
; - update P0 and P1 graphics
; - decrease block-line
; - ...
       STA    HMOVE             ; 3
       STA    ENAM0             ; 3
       STX    GRP0              ; 3 @6          this also updates GRP1
       BEQ    .exitKernel2      ; 2
       DEC    blockLine         ; 5
       BNE    .loopKernel1      ; 2

;*** start of next block (requires eight extra kernel lines): ***
; new block, line 1
; - dec block-number
; - set new  road-state
; - get new PF color
;  - set new shape-pointer 1a
       DEC    blockNum          ; 5
JmpPoint1:
       LDX    blockNum          ; 3
       BMI    LF202             ; 2
       LDA    blockLst,X        ; 4             save road-state
       STA    roadBlock         ; 3
       AND    #PF_COLOR_FLAG    ; 2             bright or dark..
       ORA    #GREEN            ; 2             ..green
  IF SCREENSAVER
       EOR    SS_XOR            ; 3
       AND    SS_Mask           ; 3
  ELSE
       FILL_NOP 4
  ENDIF
       STA    PFcolor           ; 3
       LDA    Shape1IdLst,X     ; 4             set
       TAX                      ; 2              shape-pointer
       LDA    shapePtr1aTab,X   ; 4              for the
       STA    shapePtr1a        ; 3              next enemy
LF1CE:
       LDA    #$00              ; 2
       STA    GRP1              ; 3
       CPY    #JET_Y            ; 2
       STA    WSYNC             ; 3
;--------------------------------------
; new block, line 2
; x = shape-id
;  - set jet
;  - set PF
;  - set new shape-pointer 1b
;  - set new color-pointer
       STA    HMOVE             ; 3
       BCS    .skipJet1         ; 2
       LDA    (shapePtr0),Y     ; 5
.skipJet1:
       STA    GRP0              ; 3
       LDY    #0                ; 2             display last line of playfield pattern
       LDA    (PF1Ptr),Y        ; 5
       STA    PF1               ; 3
       LDA    (PF2Ptr),Y        ; 5
       STA    PF2               ; 3
       LDY    lineNum           ; 3
       DEY                      ; 2
.exitKernel2:
       BEQ    .exitKernel1      ; 2
       LDA    shapePtr1bTab,X   ; 4
       STA    shapePtr1b        ; 3
       LDA    ColorPtrTab,X     ; 4
       STA    colorPtr          ; 3
JmpPoint0:
       CPY    #JET_Y            ; 2
       BCS    .skipJet2         ; 2
       LDA    (shapePtr0),Y     ; 5
       TAX                      ; 2
       LDA    #DISABLE          ; 2
       BEQ    .contJet2         ; 3

LF202: INX                      ; 2
       BEQ    LF1CE             ; 2
JmpPoint9:
       NOP                      ; 2
       SEC                      ; 2
       BCS    .enterKernel9     ; 3

.skipJet2:
       TYA                      ; 2
       SBC    missileY          ; 3
       AND    #$F8              ; 2
       BNE    .skipEnable1      ; 2
       LDA    #ENABLE           ; 2
.skipEnable1:
       LDX    #$00              ; 2
.contJet2:
       STA    WSYNC             ; 3
;--------------------------------------
; new block, line 3
; - en-/disabvle missile
; - set jet
; - set new PF pointers
       STA    HMOVE             ; 3
       STA    ENAM0             ; 3
       STX    GRP0              ; 3
       DEY                      ; 2
       STY    lineNum           ; 3
.exitKernel1:
       BEQ    .exitKernel       ; 2
       LDX    blockNum          ; 3
.enterKernel9:
       JSR    SetPFxPtr         ;50
       LDA    PFcolor           ; 3
       CPY    #JET_Y            ; 2
       NOP                      ; 2 @76
;--------------------------------------
; new block, line 4
; - set new PF color
; - set PF
; - load fine movement
       STA    HMOVE             ; 3
       STA    COLUPF            ; 3
       BCS    .skipJet3         ; 2
       LDA    (shapePtr0),Y     ; 5
       STA    GRP0              ; 3
.skipJet3:
       LDY    #SECTION_BLOCKS-1 ; 2
       LDA    (PF1Ptr),Y        ; 5
       STA    PF1               ; 3
       LDA    (PF2Ptr),Y        ; 5
       STA    PF2               ; 3
       DEC    lineNum           ; 5
       BEQ    .exitKernel       ; 2
JmpPoint8:
       LDA    State1Lst,X       ; 4             put fine move-value
       STA    temp              ; 3              into temp
       LDY    lineNum           ; 3
       CPY    #JET_Y            ; 2
       BCC    .skipJet4         ; 2
       TYA                      ; 2
       SBC    missileY          ; 3
       AND    #$F8              ; 2
       BNE    .skipEnable2      ; 2
       LDA    #ENABLE           ; 2
.skipEnable2:
       LDY    #0                ; 2
.contJet4:
       STA    WSYNC             ; 3
;--------------------------------------
; new block, line 5
; - en-/disable missile
; - set jet
; - position new shape
       STA    HMOVE             ; 3
       STA    ENAM0             ; 3
       STY    GRP0              ; 3
; position player 1:
       LDA    XPos1Lst,X        ; 4             load coarse move-value
       BEQ    .posVeryLeft      ; 2
       TAX                      ; 2
       CPX    #7                ; 2
       BCS    .posRight         ; 2
.waitLeft:
       DEX                      ; 2
       BNE    .waitLeft         ; 2
       STA    RESP1             ; 3
.contLeft:
       DEC    lineNum           ; 5
       LDY    lineNum           ; 3
       BNE    .contPos          ; 2
.exitKernel:
       JMP    DisplayState      ; 3             exit the kernel

.posVeryLeft:
       NOP                      ; 2
       NOP                      ; 2
       LDA    #$60              ; 2
       STA    RESP1             ; 3
       STA    HMP1              ; 3
       BNE    .contLeft         ; 2

.skipJet4:
       LDA    (shapePtr0),Y     ; 5
       TAY                      ; 2
       LDA    #$00              ; 2
       BEQ    .contJet4         ; 2

.posRight:
       SBC    #4                ; 2
       TAX                      ; 2
       DEC    lineNum           ; 5
       LDY    lineNum           ; 3
       BEQ    .exitKernel       ; 2
.waitRight:
       DEX                      ; 2
       BPL    .waitRight        ; 2
       STA    RESP1             ; 3
JmpPoint7:
.contPos:
       STA    WSYNC             ; 3
;--------------------------------------
; new block, line 6
       STA    HMOVE             ; 3
       CPY    #JET_Y            ; 2
       BCS    .skipJet5         ; 2
       LDA    (shapePtr0),Y     ; 5
       STA    GRP0              ; 3
.skipJet5:
       LDY    #SECTION_BLOCKS-2 ; 2
       LDA    (PF1Ptr),Y        ; 5
       STA    PF1               ; 3
       LDA    (PF2Ptr),Y        ; 5
       STA    PF2               ; 3
       LDY    lineNum           ; 3
       DEY                      ; 2
       BEQ    .exitKernel       ; 2
       LDX    blockNum          ; 3
       LDA    temp              ; 3
       STA    HMP1              ; 3
JmpPoint6:
       LDA    #[BLOCK_SIZE-8]/2 ; 2
       STA    blockLine         ; 3
       TYA                      ; 2
       SEC                      ; 2
       SBC    missileY          ; 3
       AND    #$F8              ; 2
       BNE    .skipEnable3      ; 2
       LDA    #ENABLE           ; 2
.skipEnable3:
       CPY    #JET_Y            ; 2
       STA    WSYNC             ; 3
;--------------------------------------
; new block, line 7
       STA    HMOVE             ; 3
       STA    ENAM0             ; 3
       BCS    .skipJet6         ; 2
       LDA    (shapePtr0),Y     ; 5
       STA    GRP0              ; 3
.skipJet6:
       LDA    State1Lst,X       ; 4
       STA    NUSIZ1            ; 3
       STA    REFP1             ; 3
       DEY                      ; 2
       STY    lineNum           ; 3
       BEQ    DisplayState      ; 2
       STA    HMCLR             ; 3

; check collisions:
; (the collsion check between jet or missile and playfield aren't
;  really neccessary for each block, but the collison registers
;  are cleared after each block)
       INX                      ; 2
       BIT    CXM0P-$30         ; 3             player missile hit enemy?
       BPL    .notHit           ; 2
       STX    hitEnemyIdx       ; 3             save block number
.notHit:
  IF TRAINER
       BIT    zero1
  ELSE
       BIT    CXP0FB-$30        ; 3             jet hit PF?
  ENDIF
       BPL    .noPFCrash        ; 2
       STX    PFCrashFlag       ; 3
.noPFCrash:
  IF TRAINER
       BIT    zero1
  ELSE
       BIT    CXM0FB-$30        ; 3             player missile hit PF?
  ENDIF
       BPL    .notHitPF         ; 2
       STX    missileFlag       ; 3
.notHitPF:
  IF TRAINER
       BIT    zero1
  ELSE
       BIT    CXPPMM-$30        ; 3             jet crashed into enemy?
  ENDIF
       BPL    .noCrash          ; 2
       STX    collidedEnemy     ; 3             save block number
.noCrash:

.enterKernel5:
;--------------------------------------
; new block, line 8
       STA    WSYNC             ; 3
       STA    HMOVE             ; 3
       CPY    #JET_Y            ; 2
       BCS    .skipJet7         ; 2
       LDA    (shapePtr0),Y     ; 5
       STA    GRP0              ; 3
.skipJet7:
       LDY    #SECTION_BLOCKS-3 ; 2
       LDA    (PF1Ptr),Y        ; 5
       STA    PF1               ; 3
       LDA    (PF2Ptr),Y        ; 5
       STA    PF2               ; 3
       LDY    lineNum           ; 3
       DEY                      ; 2
       BEQ    DisplayState      ; 2
       BIT    CXP1FB-$30        ; 3             enemy hit PF?
       BPL    .notEnemyPF       ; 2              no, skip
       LDA    blockLst,X        ; 4
       ORA    #PF_COLLIDE_FLAG  ; 2              yes, set collision flag
       STA    blockLst,X        ; 4
.notEnemyPF:
       STA    CXCLR             ; 3             clear all collison registers

.enterKernel4:
       TYA                      ; 2
       SEC                      ; 2
       SBC    missileY          ; 3
       AND    #$F8              ; 2
       BNE    .skipEnable4      ; 2
       LDA    #ENABLE           ; 2
.skipEnable4:
       CPY    #JET_Y            ; 2
       STA    WSYNC             ; 3
;--------------------------------------
; new block, line 9 (= begin of even line)
       STA    HMOVE             ; 3
       STA    ENAM0             ; 3
       BCS    .skipJet8         ; 2
       LDA    (shapePtr0),Y     ; 5
       STA    GRP0              ; 3
.contJet8:
       DEY                      ; 2
       STY    lineNum           ; 3
       BEQ    DisplayState      ; 2             exit the kernel
       JMP    .loopKernel       ; 3 @26

JmpPoint5:
       LDA    #[BLOCK_SIZE-8]/2 ; 2
       STA    blockLine         ; 3
       BNE    .enterKernel5     ; 3

JmpPoint4:
       LDA    #[BLOCK_SIZE-8]/2 ; 2             12
       STA    blockLine         ; 3
       BNE    .enterKernel4     ; 3

.skipJet8:                      ;               waste some time
       NOP                      ; 2
       NOP                      ; 2
       BCS    .contJet8         ; 3

DisplayState SUBROUTINE
; finish display kernel:
       STA    WSYNC             ; 3
       STA    HMOVE             ; 3
       LDY    #$00              ; 2
       STY    GRP1              ; 3
       STY    GRP0              ; 3
       LDA    zero1             ; 3             waste one extra cylce (but also wastes a variable!)
       STA    COLUBK            ; 3
       STY    PF0               ; 3
       STY    PF1               ; 3
       STY    PF2               ; 3
       STY    REFP0             ; 3
       STY    REFP1             ; 3
       STY    reflect0          ; 3
; prepare state display:
       LDA    #$11              ; 2             reflect PF, 2 pixel ball width, also for HMP0!
       STA    RESP0             ; 3
       STA    RESP1             ; 3
       STA    CTRLPF            ; 3
       STA    HMP0              ; 3
       LDA    #$20              ; 2
       STA    HMP1              ; 3
       LDA    playerColor       ; 3
       JSR    SetColPx          ; 6
       LDA    stateBKColor      ; 3
       STA    COLUBK            ; 3
       LDA    #THREE_COPIES     ; 2
       STA    NUSIZ0            ; 3
       STA    NUSIZ1            ; 3
       LDA    statePFColor      ; 3
       STA    COLUPF            ; 3
       LDY    #$07              ; 2
       STY    VDELP0            ; 3
       STY    lineNum           ; 3
       STA    HMCLR             ; 3
; display score:
.loopScore:
       LDA    (scorePtr1+8),Y   ; 5
       TAX                      ; 2
       LDA    (scorePtr1+10),Y  ; 5
       STA    WSYNC             ; 3
       STA    HMOVE             ; 3
       STY    temp2             ; 3
       STA    temp              ; 3
       LDA    (scorePtr1),Y     ; 5
       STA    GRP0              ; 3
       LDA    (scorePtr1+2),Y   ; 5
       STA    GRP1              ; 3
       LDA    (scorePtr1+4),Y   ; 5
       STA    GRP0              ; 3
       LDA    (scorePtr1+6),Y   ; 5
       LDY    temp              ; 3
       STA    GRP1              ; 3
       STX    GRP0              ; 3
       STY    GRP1              ; 3
       STA    GRP0              ; 3
       LDY    temp2             ; 3
       DEY                      ; 2
       BPL    .loopScore        ; 2

       LDA    zero1             ; 3             a = 0 (BLACK)
       JSR    FinishDigits      ; 6             y = 14
; display fuel:
.loopFuel:
       STY    temp2             ; 3             line counter
       LDA    FuelTab4,Y        ; 4
       LDX    FuelTab3,Y        ; 4
       STA    WSYNC             ; 3
       STA    HMOVE             ; 3
       STA    temp              ; 3
       NOP                      ; 2
       LDA    #$00              ; 2
       STA    GRP0              ; 3
       LDA    ENABLTab,Y        ; 4
       STA    ENABL             ; 3
       LDA    FuelTab0,Y        ; 4
       STA    GRP1              ; 3
       LDA    FuelTab1,Y        ; 4
       STA    GRP0              ; 3
       LDA    FuelTab2,Y        ; 4
       LDY    temp              ; 3
       STA    GRP1              ; 3
       STX    GRP0              ; 3
       STY    GRP1              ; 3
       STA    GRP0              ; 3
       LDY    temp2             ; 3
       DEY                      ; 2
       BPL    .loopFuel         ; 2

       LDA    playerColor       ; 3
       JSR    FinishDigits      ; 6
       INY                      ; 2             y=15
       CLC                      ; 2
       LDX    gameMode          ; 3
       INX                      ; 2
       BNE    .noGame           ; 2
       LDA    #<Space           ; 2
       STA    livesPtr          ; 3

; animate copyright message:
       LDA    frameCnt          ; 3
       LSR                      ; 2
       LSR                      ; 2
       LSR                      ; 2
       CMP    #20               ; 2
       BCS    .ok               ; 2
       CMP    #12               ; 2
.noGame:
       LDY    #7                ; 2
       BCC    .ok               ; 2
       SBC    #4                ; 2
       TAY                      ; 2
.ok:
       STY    temp3             ; 3             copyright scroll offset
; display lives and copyright:
.loopCopyright:
       LDY    temp3             ; 3
       LDA    Copyright5,Y      ; 4
       STA    temp              ; 3
       STA    WSYNC             ; 3
       STA    HMOVE             ; 3
       LDX    Copyright4,Y      ; 4
       LDA    (livesPtr),Y      ; 5
       STA    GRP0              ; 3
       DEC    temp3             ; 5
       LDA    Copyright1,Y      ; 4
       STA    GRP1              ; 3
       LDA    Copyright2,Y      ; 4
       STA    GRP0              ; 3
       LDA    Copyright3,Y      ; 4
       LDY    temp              ; 3
       STA    GRP1              ; 3
       STX    GRP0              ; 3
       STY    GRP1              ; 3
       STA    GRP0              ; 3
       DEC    lineNum           ; 5
       BPL    .loopCopyright    ; 2

       STA    WSYNC             ; 3
       STA    HMOVE             ; 3
       LDX    #$00              ; 2
       STX    VDELP0            ; 3
       STX    GRP1              ; 3
       STX    GRP0              ; 3
       LDA    blockOffset       ; 3
       CMP    #BLOCK_SIZE-6     ; 2
       BCC    .skipInx          ; 2
       INX                      ; 2
.skipInx:

; check collisions for the last displayed block:
       BIT    CXM0P-$30         ; 3             player missile hit enemy?
       BPL    .notHit2          ; 2
       STX    hitEnemyIdx       ; 3             save block number
.notHit2:
  IF TRAINER
       BIT    zero1
  ELSE
       BIT    CXP0FB-$30        ; 3             jet hit PF?
  ENDIF
       BPL    .noPFCrash2       ; 2
       STX    PFCrashFlag       ; 3
.noPFCrash2:
       BIT    CXM0FB-$30        ; 3             player missile hit PF?
       BPL    .notHitPF2        ; 2
       STX    missileFlag       ; 3
.notHitPF2:

  IF NTSC
       LDA    #29               ; 2
  ELSE
       LDA    #58               ; 2
  ENDIF
       LDY    #%10000010        ; 2
       STA    WSYNC             ; 3
       STA    TIM64T            ; 4
       STY    VBLANK            ; 3

       BIT    CXP1FB-$30        ; 3             enemy hit PF?
       BPL    .notEnemyPF2      ; 2
       LDA    blockLst,X        ; 4
       ORA    #PF_COLLIDE_FLAG  ; 2
       STA    blockLst,X        ; 4
.notEnemyPF2:
  IF TRAINER
       LDA    zero1
  ELSE
       BIT    CXPPMM-$30        ; 3             jet crashed into enemy?
  ENDIF
       BPL    .noCrash2         ; 2
       STX    collidedEnemy     ; 3             save block number
.noCrash2:

; *** update framecounter, check for screensaver: ***
       DEC    frameCnt          ; 5
       BNE    .skipSS_Delay     ; 2
       LDX    gameMode          ; 3
       INX                      ; 2
       BNE    .skipInit         ; 2
       JSR    SwapPlayers       ; 6
.skipInit:
  IF SCREENSAVER
       INC    SS_Delay          ; 5
       BNE    .skipSS_Delay     ; 2
       SEC                      ; 2
       ROR    SS_Delay          ; 5
  ELSE
       FILL_NOP 4
  ENDIF
.skipSS_Delay:
  IF SCREENSAVER
       LDY    #$FF              ; 2
       LDA    SWCHB             ; 4
       AND    #BW_MASK          ; 2             black and white?
       BNE    .colorMode        ; 2              no, color mode
       LDY    #$0F              ; 2              yes, mask out high nibble
.colorMode:
       TYA                      ; 2
       LDY    #$00              ; 2
       BIT    SS_Delay          ; 3
       BPL    .noScreenSaver    ; 2
       AND    #$F7              ; 2
       LDY    SS_Delay          ; 3
.noScreenSaver:
       STY    SS_XOR            ; 3
       ASL    SS_XOR            ; 5
       STA    SS_Mask           ; 3
  ELSE
       FILL_NOP 28
  ENDIF

; *** randomly start movement of enemies: ***
       LDA    random            ; 3
       ASL                      ; 2
       ASL                      ; 2
       ASL                      ; 2
       EOR    random            ; 3
       ASL                      ; 2
       ROL    random            ; 5
       LDA    frameCnt          ; 3
       AND    #$0F              ; 2             every 16th frame
       BNE    .skipStartMove    ; 2
       LDA    random            ; 3
       AND    #$07              ; 2
       CMP    #5                ; 2             start one of the first five enemies
       BCC    .inBound          ; 2
       SBC    #5                ; 2             doubled chances for the first three enemies
.inBound:
       TAX                      ; 2
       LDA    blockLst,X        ; 4             start
       ORA    #ENEMY_MOVE_FLAG  ; 2              movement
       STA    blockLst,X        ; 4              of enemy
.skipStartMove:

;*** animate and move the enemy objects: ***
       LDX    #NUM_BLOCKS-1     ; 2
.loopEnemies:
; animate some enemies:
       LDY    Shape1IdLst,X     ; 4
       CPY    #ID_SHIP          ; 2             don't animate ship, bridge, house and fuel
       BCS    .skipAnimate      ; 2
       LDA    #$01              ; 2             every 2nd frame
       CPY    #ID_PLANE         ; 2             fast animate plane (not done) and helicopter
       BCS    .fastAnimation    ; 2
       LDA    #$0F              ; 2             slow animate explosions (every 16th frame)
.fastAnimation:
       AND    frameCnt          ; 3
       BNE    .skipAnimate      ; 2
       LDA    AnimateIdTab,Y    ; 4
       STA    Shape1IdLst,X     ; 4
       TAY                      ; 2
.skipAnimate:

; check for move and direction change:
       LDA    gameMode          ; 3
       BNE    .skipMoveEnemy    ; 2
       LDA    level             ; 3
       LSR                      ; 2             first level?
       BEQ    .skipMoveEnemy    ; 2              yes, don't move
       CPY    #ID_PLANE         ; 2             move plane in same direction every frame
       BEQ    .xMoveEnemy       ; 2
       BCC    .skipMoveEnemy    ; 2
       CPY    #ID_BRIDGE        ; 2             don't move bridge, house and fuel
       BCS    .skipMoveEnemy    ; 2
       LDA    frameCnt          ; 3
       ROR                      ; 2
       BCS    .skipMoveEnemy    ; 2             move helicopter and ship every 2nd frame
       LDA    blockLst,X        ; 4
       ASL                      ; 2             enemy moving?
       BPL    .skipMoveEnemy    ; 2              no, skip move
       ASL                      ; 2             enemy collided with PF?
       BPL    .noPFCollision    ; 2              no, skip
       ASL                      ; 2             patroling enemy?
       BMI    .xMoveEnemy       ; 2              no, skip swap direction
       LDA    State1Lst,X       ; 4             switch
       EOR    #DIRECTION_FLAG   ; 2              enemy move
       STA    State1Lst,X       ; 4              direction
       LDA    blockLst,X        ; 4
       ORA    #PATROL_FLAG      ; 2             (re)enable patrol mode
       BNE    .endChangeDir     ; 2

.noPFCollision:
       LDA    blockLst,X        ; 4
       AND    #~PATROL_FLAG     ; 2             disable patrol mode (only temporary)
.endChangeDir:
       STA    blockLst,X        ; 4

; move enemy one pixel left or right:
; (no real position variables, the code is working
;  directly  with the positioning values)
.xMoveEnemy:
       LDY    XPos1Lst,X        ; 4
       LDA    State1Lst,X       ; 4
       LSR                      ; 2
       LSR                      ; 2
       LSR                      ; 2
       LSR                      ; 2
       EOR    #$07              ; 2
       BCS    .xMoveLeft        ; 2             moving left!
       ADC    #1                ; 2
       CMP    #15               ; 2
       BCC    .skipRightIny     ; 2
       SBC    #15               ; 2
       INY                      ; 2
.skipRightIny:
       CPY    #10               ; 2
       BCC    .contMoveX        ; 2
       CMP    #10               ; 2             >= 160?
       BCC    .contMoveX        ; 2              no, continue
       LDY    #0                ; 2              yes,..
       TYA                      ; 2              ..move shape (plane)..
       BEQ    .contMoveX        ; 2              ..to the very left (0)

.xMoveLeft:
       SBC    #1                ; 2
       BCS    .contMoveX2       ; 2
       ADC    #15               ; 2
       DEY                      ; 2             < 0?
       BPL    .contMoveX        ; 2              no, continue
       LDY    #10               ; 2              yes, move shape (plane)..
       LDA    #9                ; 2              ..to the very right (159)
.contMoveX:
       STY    XPos1Lst,X        ; 4             store coarse value here
.contMoveX2:
       EOR    #$07              ; 2
       JSR    Mult16            ; 6
       EOR    State1Lst,X       ; 4
       AND    #FINE_MASK        ; 2             #$F0
       EOR    State1Lst,X       ; 4
       STA    State1Lst,X       ; 4             OR fine value into here
.skipMoveEnemy:

; clear PF-collision:
       LDA    blockLst,X        ; 4
       AND    #~PF_COLLIDE_FLAG ; 2
       STA    blockLst,X        ; 4
       DEX                      ; 2
       BMI    .exitLoopEnemies  ; 2
       JMP    .loopEnemies      ; 3
.exitLoopEnemies:

; *** read joystick: ***
       LDA    SWCHA             ; 4
       LDX    player            ; 3
       BEQ    .player1          ; 2
       JSR    Mult16            ; 6
.player1:
       AND    #$F0              ; 2             mask out other player joystick
       TAX                      ; 2
       LDY    #4                ; 2
.loopBits:
       ROL                      ; 2             roll new 4 bits into joystick
       ROL    joystick          ; 5              (old 4 bits got into upper nibble!)
       DEY                      ; 2
       BNE    .loopBits         ; 2

       CPX    #$F0              ; 2
       BNE    .joystickMoved    ; 2
       LDX    player            ; 3
       LDA    INPT4-$30,X       ; 4
       BMI    .noFire           ; 2
.joystickMoved:

       LDA    gameMode          ; 3
       CMP    #INTRO_SCROLL     ; 2
       BNE    .skipRestart      ; 2
       LDA    #64               ; 2             restart new game
       STA    speedY            ; 3
       STY    gameMode          ; 3             y=0!
.skipRestart:
  IF SCREENSAVER
       STY    SS_Delay          ; 3             y=0!
  ELSE
       FILL_NOP 2
  ENDIF
.noFire:
       LDX    gameMode          ; 3
       BEQ    .checkCollisions  ; 2             game running
       BMI    .gameOver         ; 2             game is over
       CPX    #INTRO_SCROLL+1   ; 2             scrolling into new game/life?
       BCC    .doSoundJmp       ; 2              yes, skip decrease
       BNE    .startGame        ; 2              no, finished scrolling, start new game
; decrease lives:
       LDA    livesPtr          ; 3
       BEQ    .finishGame       ; 2             zero!
       SBC    #DIGIT_H          ; 2
       BNE    LF5B5             ; 2
       LDA    #<Space+1         ; 2
LF5B5: CMP    #<MaxOut          ; 2             score overflow?
       BNE    LF5BB             ; 2
       LDA    #<Three           ; 2             reset lives to 3
LF5BB: STA    livesPtr          ; 3
.startGame:
       DEC    gameMode          ; 5             start game
       BNE    .doSoundJmp       ; 2

.gameOver:
       INX                      ; 2
       BEQ    .doSoundJmp       ; 2
       DEC    gameMode          ; 5
       BMI    .doSoundJmp       ; 2
       STY    shapePtr0         ; 3
       LDA    livesPtr2         ; 3
       CMP    #<Copyright0      ; 2             other player still alive?
       BEQ    .skipSwap         ; 2              no, skip swap
       JSR    SwapPlayers       ; 6
.skipSwap:
       LDA    livesPtr          ; 3
       CMP    #<Copyright0      ; 2             current player still alive?
       BNE    .initPlayer       ; 2              yes, continue
.finishGame:
       JSR    FinishGame        ; 6
       BNE    .doSoundJmp       ; 2

.initPlayer:
       LDX    #shapePtr0+2-PF1Lst;2             #22
       JSR    GameInit          ; 6
       TYA                      ; 2
       ORA    #PF_ROAD_FLAG     ; 2
       STA    blockLstEnd       ; 3
       LDA    randomLoSave      ; 3             load..
       STA    randomLo          ; 3             ..random variables..
       LDA    randomHiSave      ; 3             ..with saved..
       STA    randomHi          ; 3             ..player variables
.doSoundJmp:
       JMP    DoSound           ; 3

.checkCollisions:
       LDX    collidedEnemy     ; 3             collided with enemy?
       BMI    .endCollisions    ; 2              no, skip
       LDA    Shape1IdLst,X     ; 4
       CMP    #ID_PLANE         ; 2             collided with explosion?
       BCC    .endCollisions    ; 2              no, skip
       CMP    #ID_BRIDGE        ; 2             collided with ship, plane or helicopter?
       BCC    .noBridge         ; 2              yes, do collision
       BNE    .refuel           ; 2              no, collided with fuel!
       INC    sectionEnd        ; 5              no, collided with bridge!
.noBridge:
       LDY    #$1F              ; 2             load some sound values
       LDA    #1                ; 2             sound id = 1
       JSR    LooseJet          ; 6
       LDX    collidedEnemy     ; 3
       LDA    #ID_EXPLOSION2    ; 2             start explosion
       JMP    .contJetExplosion ; 3

.refuel:
       LDA    fuelHi            ; 3
       ADC    #$01              ; 2
       LDX    #4                ; 2             sound id = 4
       BCC    .notFull          ; 2
       LDA    #$FF              ; 2
       STA    fuelLo            ; 3
       LDX    #3                ; 2             sound id = 3
.notFull:
       STA    fuelHi            ; 3
       CPX    sound0Id          ; 3
       BEQ    .endCollisions    ; 2
       STX    sound0Id          ; 3
       LDA    #$08              ; 2
       STA    sound0Cnt         ; 3

.endCollisions:
       LDX    PFCrashFlag       ; 3             jet crashed?
       BMI    .skipCrash        ; 2              no, skip
.maxedOut:
       LDY    #$1F              ; 2
       LDA    #1                ; 2             sound id = 1
.looseJet:
       JSR    LooseJet          ; 6
       BNE    .doSoundJmp       ; 2

.skipCrash:

; decrease fuel:
       LDA    fuelLo            ; 3
       SEC                      ; 2
  IF TRAINER
       SBC    #0
  ELSE
       SBC    #$20              ; 2
  ENDIF
       BCS    .skipDecHi        ; 2
       LDY    fuelHi            ; 3
       BNE    .fuelOk           ; 2
       LDA    #2                ; 2             sound id = 2
       LDY    #$23              ; 2
       JMP    .looseJet         ; 3             out of fuel!

.fuelOk:
       DEC    fuelHi            ; 5
.skipDecHi:
       STA    fuelLo            ; 3

; *** move jet left or right: ***
       LDA    joystick          ; 3
       TAY                      ; 2
       AND    #MOVE_LEFT|MOVE_RIGHT; 2
       EOR    #MOVE_LEFT|MOVE_RIGHT; 2
       BNE    .leftRight        ; 2
       STA    dXSpeed           ; 3             jet is flying straight
       STA    speedX            ; 3
       LDX    #<JetStraight-1   ; 2
       BNE    .setPtr0          ; 2

.leftRight:
       LDA    dXSpeed           ; 3             increase the x speed change
       CLC                      ; 2
       ADC    #8                ; 2
       BCS    .maxChange        ; 2
       STA    dXSpeed           ; 3
.maxChange:
       LDX    #<JetMove-1       ; 2
       TYA                      ; 2
       AND    #MOVE_RIGHT       ; 2
       STA    reflect0          ; 3
       BEQ    .moveRight        ; 2
       BCS    .maxChange2       ; 2
       LDA    speedX            ; 3
       SEC                      ; 2
       SBC    dXSpeed           ; 3
       BCS    .setXSpeed        ; 2
.maxChange2:
       DEC    playerX           ; 5
       BNE    .setXSpeed        ; 2

.moveRight:
       BCS    .maxChange3       ; 2
       LDA    speedX            ; 3
       BIT    joystick          ; 3             moved right before?
       BPL    .wasRight         ; 2              yes, skip
       LDA    #-1               ; 2              bo, move the jet very slowly to the left (JTZ: what's that good for?)
.wasRight:
       ADC    dXSpeed           ; 3
       BCC    .setXSpeed        ; 2
.maxChange3:
       INC    playerX           ; 5
.setXSpeed:
       STA    speedX            ; 3
.setPtr0:
       STX    shapePtr0         ; 3

; change jet speed:
       LDX    speedY            ; 3
       TYA                      ; 2
       LSR                      ; 2
       BCS    .noMoveUp         ; 2
.incSpeed:
       TXA                      ; 2
       ADC    #2                ; 2
       BCC    .changeSpeed      ; 2
       BCS    .skipChange       ; 2

.noMoveUp:
       LSR                      ; 2
       BCC    .noMoveDown       ; 2
       TXA                      ; 2
       ASL                      ; 2
       BCC    .incSpeed         ; 2
       BEQ    .skipChange       ; 2

.noMoveDown:
       TXA                      ; 2
       CMP    #$41              ; 2             minimal speed?
       BCC    .skipChange       ; 2              yes, skip slow down
       SBC    #2                ; 2
.changeSpeed:
       STA    speedY            ; 3
.skipChange:

       LDX    hitEnemyIdx       ; 3             object hit?
       BMI    .skipCollisions   ; 2              no, skip
       LDY    Shape1IdLst,X     ; 4
       CPY    #ID_PLANE         ; 2             enemy objects?
       BCC    .skipCollisions   ; 2              no, explosions
       LDA    #ID_EXPLOSION1    ; 2             start explosion animation
.contJetExplosion:
       LDY    Shape1IdLst,X     ; 4
       STA    Shape1IdLst,X     ; 4
       LDA    #23               ; 2
       STA    bridgeSound       ; 3
       CPY    #ID_BRIDGE        ; 2
       BNE    .skipBridge       ; 2
       STA    bridgeExplode     ; 3             start bridge explosion
       LDA    #$E0|TWO_COPIES   ; 2             set fixed position and size (two copies close)
       STA    State1Lst,X       ; 4
       LDA    #4                ; 2             coarse positiong value
       STA    XPos1Lst,X        ; 4
       INC    sectionEnd        ; 5             new section has been started
.skipBridge:

; increase score:
       LDX    #8                ; 2             add 10s
       LDA    ScoreTab,Y        ; 4
       BPL    .loopSetPtr1      ; 2
       AND    #$7F              ; 2             add n*100 points
       LDX    scorePtr1+8       ; 3
       CPX    #<Space           ; 2
       BNE    .noSpace          ; 2
       LDX    #<Zero            ; 2             replace Space..
       STX    scorePtr1+8       ; 3             ..with Zero
.noSpace:
       LDX    #6                ; 2             add 100s
.loopSetPtr1:
       PHA                      ; 3
       CPX    #2                ; 2             life pointer
       BNE    .notLivePtr       ; 2
; check for bonus life:
       LDA    livesPtr          ; 3
       CMP    #<Nine            ; 2
       BEQ    .maxLives         ; 2
       BCC    .notMax           ; 2
       LDA    #$FF              ; 2             CF=1!
.notMax:
       ADC    #DIGIT_H          ; 2
       STA    livesPtr          ; 3
.maxLives:
.notLivePtr:
       LDA    scorePtr1,X       ; 4
       SEC                      ; 2
       SBC    #<Space           ; 2
       BNE    .noSpace2         ; 2
       STA    scorePtr1,X       ; 4             point to '0'
.noSpace2:
       PLA                      ; 4
       CLC                      ; 2
       ADC    scorePtr1,X       ; 4
       CMP    #<MaxOut          ; 2
       BCC    .noMaxOut         ; 2             exit loop
       SBC    #<MaxOut          ; 2
       STA    scorePtr1,X       ; 4
       LDA    #DIGIT_H          ; 2
       DEX                      ; 2
       DEX                      ; 2
       BPL    .loopSetPtr1      ; 2

; more than 999990 points, set score to !!!!!!, game over:
       LDA    #<MaxOut          ; 2
       LDX    #12-2             ; 2
       JSR    SetScorePtr1      ; 6
       LDA    #<Copyright0      ; 2
       STA    livesPtr          ; 3
       JMP    .maxedOut         ; 3

.noMaxOut:
       STA    scorePtr1,X       ; 4
.noMissile:
       LDX    #$B4              ; 2             disable missile
       BNE    .directMissile    ; 2
.skipCollisions:

; *** move or fire missiles: ***
       LDA    missileFlag       ; 3
       BPL    .noMissile        ; 2
       LDA    missileY          ; 3
       CMP    #MAX_MISSILE+1    ; 2
       BCS    .checkFire        ; 2
       ADC    #MISSILE_SPEED    ; 2             y-move missile
       TAX                      ; 2
       LDA    SWCHB             ; 4             read difficulty
       LDY    player            ; 3
       BNE    .player1a         ; 2
       ASL                      ; 2
.player1a:
       TAY                      ; 2
       BPL    .guidedMissile    ; 2
       BMI    .directMissile    ; 2

.checkFire:
       LDX    player            ; 3
       LDA    INPT4-$30,X       ; 4
       BMI    .noMissile        ; 2
       LDX    #$0F              ; 2
       STX    missileSound      ; 3
       LDX    #MIN_MISSILE      ; 2
.guidedMissile:
       LDA    playerX           ; 3
       CLC                      ; 2
       ADC    #$05              ; 2
       STA    missileX          ; 3
.directMissile:
       STX    missileY          ; 3

; *** sound routines: ***
; TODO: analyze, labels, comments
DoSound:
; start with channel 0:
       LDY    #$1C              ; 2
       LDA    sound0Cnt         ; 3
       LDX    sound0Id          ; 3
       BEQ    LF789             ; 2
       DEX                      ; 2
       BEQ    LF770             ; 2
       LDY    #$0F              ; 2
       CPX    #$02              ; 2
       BCS    LF776             ; 2
       LDY    #$08              ; 2
LF770: LSR                      ; 2
       TAX                      ; 2
       LDA    #$08              ; 2             white noise
       BNE    LF77D             ; 2

LF776: BEQ    LF77A             ; 2
       LDY    #$1F              ; 2
LF77A: TAX                      ; 2
       LDA    #$04              ; 2             high pure tone
LF77D: DEC    sound0Cnt         ; 5
       BNE    .setAud0          ; 2
       PHA                      ; 3
       LDA    #0                ; 2
       STA    sound0Id          ; 3             stop sound0
       PLA                      ; 4
       BPL    .setAud0          ; 2

; low fuel sound:
LF789: LDA    gameMode          ; 3             game running?
       BNE    .mute0            ; 2              no, quiet (x=0)
       LDA    fuelHi            ; 3
       CMP    #$40              ; 2
       BCS    .jetSound         ; 2
       LDY    sound0Cnt         ; 3
       BNE    .contSound0       ; 2
       LDY    #$3F              ; 2
.contSound0:
       DEY                      ; 2
       STY    sound0Cnt         ; 3
       LDX    fuelLo            ; 3
       STX    temp              ; 3
       CMP    #$04              ; 2
       BCS    LF7B0             ; 2
       ROL    temp              ; 5
       ROL                      ; 2
       ROL    temp              ; 5
       ROL                      ; 2
       EOR    #$FF              ; 2
       ADC    #$20              ; 2
       BNE    .loadAud0         ; 2

LF7B0: CPY    #$1C              ; 2
       BCC    .jetSound         ; 2
       TYA                      ; 2
       LSR                      ; 2
.loadAud0:
       TAY                      ; 2
       LDA    #$0C              ; 2
       LDX    #$0F              ; 2
       BNE    .setAud0          ; 2

; make some noise, depending on jet speed:
.jetSound:
       LDA    speedY            ; 3             frequency depends on y-speed
       LSR                      ; 2
       LSR                      ; 2
       LSR                      ; 2
       LSR                      ; 2
       EOR    #$FF              ; 2
       SEC                      ; 2
       ADC    #$1F              ; 2
       TAY                      ; 2
       LDA    joystick          ; 3             volume depends on joystick position
       AND    #MOVE_UP|MOVE_DOWN; 2
       TAX                      ; 2
       LDA    VolumeTab,X       ; 4
       TAX                      ; 2
       LDA    #$08              ; 2             white noise
.setAud0:
       STA    AUDC0             ; 3
       STY    AUDF0             ; 3
.mute0:
       STX    AUDV0             ; 3

; continue with channel 1:
; (missile fire or bridge explosion)
       LDA    missileSound      ; 3
       BEQ    .noMissileSound   ; 2
       DEC    missileSound      ; 5
       LDX    bridgeSound       ; 3             bridge exposion has higher priority
       BNE    .doBridge         ; 2
       EOR    #$FF              ; 2
       SEC                      ; 2
       ADC    #$1C              ; 2
       LDY    #$0C              ; 2             medium pure tone
       LDX    #$08              ; 2
       BNE    .setAud1          ; 2

.noMissileSound:
       LDX    bridgeSound       ; 3
       BEQ    .skipSound1       ; 2
; let the bridge explode:
.doBridge:
       DEC    bridgeSound       ; 5             countdown volume
       TXA                      ; 2
       LSR                      ; 2
       CLC                      ; 2
       ADC    #$04              ; 2
       TAX                      ; 2
       LDA    random            ; 3             random frequency
       ORA    #$18              ; 2
       LDY    #$08              ; 2
.setAud1:
       STA    AUDF1             ; 3
       STY    AUDC1             ; 3
.skipSound1:
       STX    AUDV1             ; 3

; start next frame:
.waitTim:
       LDA    INTIM             ; 4
       BNE    .waitTim          ; 2
       LDY    #$82              ; 2
       STY    WSYNC             ; 3
       STY    VSYNC             ; 3
       STY    WSYNC             ; 3
       STY    WSYNC             ; 3
       STY    WSYNC             ; 3
       STA    VSYNC             ; 3
  IF NTSC
       LDA    #43               ; 2
  ELSE
       LDA    #73               ; 2
  ENDIF
       STA    TIM64T            ; 4

; *** check switches: ***
       LDA    SWCHB             ; 4
       LSR                      ; 2
       BCS    .noReset          ; 2
       LDA    gameVariation     ; 3             RESET was pressed
       STA    player            ; 3
       LDX    #$F7              ; 2
       JMP    Reset             ; 3

.noReset:
       LSR                      ; 2
       BCS    .noSelect         ; 2
       DEC    gameDelay         ; 5             SELECT was pressed
       BPL    .skipSelect       ; 2
       LDA    gameVariation     ; 3             toggle game (one or two player)
       EOR    #$01              ; 2
       STA    gameVariation     ; 3
  IF SCREENSAVER
       STA    SS_Delay          ; 3
  ELSE
       FILL_NOP 2
  ENDIF
       STA    player            ; 3
       ASL                      ; 2
       ASL                      ; 2
       ASL                      ; 2
       ADC    #DIGIT_H          ; 2
       JSR    SetScorePtrs      ; 6
       JSR    FinishGame        ; 6
       LDY    #$1E              ; 2
.noSelect:
       STY    gameDelay         ; 3

.skipSelect:
       LDA    gameMode          ; 3
       BMI    .mainLoopJmp      ; 2
       CMP    #INTRO_SCROLL     ; 2             scrolling into game
       BNE    .setBlockVars     ; 2              no, generate new blocks
       LDA    #<JetStraight-1   ; 2              yes, set..
       STA    shapePtr0         ; 3              ..jet data pointer..
.mainLoopJmp:
       JMP    MainLoop          ; 3              .. and continue with main loop

; check, if a new block is neccessary:
.setBlockVars:
       LDA    #3-1              ; 2             add speedY*3 to blockOffset -> max. speed = 3 lines/frame
       STA    blockNum          ; 3
.loopNext:
       DEC    blockNum          ; 5
       BMI    .mainLoopJmp      ; 2
       LDA    speedY            ; 3
       CMP    #$FE              ; 2             maximum speed?
       BCS    .incOffset        ; 2              yes, increase offset
       ADC    posYLo            ; 3
       STA    posYLo            ; 3
       BCC    .loopNext         ; 2
.incOffset:
       INC    blockOffset       ; 5
       LDA    blockOffset       ; 3
       CMP    #BLOCK_SIZE       ; 2
       BCC    .loopNext         ; 2

; *** it#s time to create a new block: ***
       LDX    #0                ; 2
       STX    blockOffset       ; 3
       LDY    #NUM_BLOCKS       ; 2
       STY    temp              ; 3             move 6 blocks
       LDA    level             ; 3
       CMP    #5                ; 2             first four levels?
       BCC    .firstLevels      ; 2              yes, prevent small valley
       LDY    #0                ; 2              no, allow all widths of valley
.firstLevels:
       STY    valleyWidth       ; 3             0 = all widths allowed, 6 = limited widths

; first move the other blocks, to make space for the new one:
.loopBlocks:                    ;
       LDY    #5                ; 2             move 5 bytes
.loopMoveBlock:
       LDA    blockLst+1,X      ; 4
       STA    blockLst,X        ; 4
       INX                      ; 2
       DEY                      ; 2
       BNE    .loopMoveBlock    ; 2
       INX                      ; 2             skip one entry
       DEC    temp              ; 5
       BNE    .loopBlocks       ; 2

       STY    State1LstEnd      ; 3             y=0!
       LDA    blockLstEnd       ; 3             clear variable (except PF_COLOR_FLAG)
       AND    #PF_COLOR_FLAG    ; 2
       STA    blockLstEnd       ; 3
       LDX    PF1PatId          ; 3             copy previous PF pattern id
       STX    prevPF1PatId      ; 3

       DEC    blockPart         ; 5             second part of block?
       BEQ    .nextBlock        ; 2              yes, next block
       LDX    sectionBlock      ; 3
       DEX                      ; 2             first part of last block of section?
       BNE    .notLast          ; 2              no, continue part

; the last block of a section has to be a road with bridge:
       STX    sectionEnd        ; 3              yes, end of current section
       LDA    level             ; 3
       LSR                      ; 2             straight current level?
       LDA    #PF_ROAD_FLAG     ; 2
       BCS    .isStraight       ; 2              yes, dark green in NEXT level
       LDA    #PF_ROAD_FLAG|PF_COLOR_FLAG; 2     no, lighter green in NEXT level
.isStraight:
       STA    blockLstEnd       ; 3
.notLast:
       JSR    NextRandom16      ; 6             new random number for next part of block
       JMP    .nextBlockPart    ; 3

; continue with a 'normal' block:
.nextBlock:
       DEC    sectionBlock      ; 5             last block of section?
       BNE    .contSection      ; 2              no, continue
       JSR    SaveSection       ; 6              yes, save variables..
       LDX    #SECTION_BLOCKS   ; 2              ..and got next level
       STX    sectionBlock      ; 3
.contSection:
       JSR    NextRandom16      ; 6             new random number for next block
       LDX    sectionBlock      ; 3
       DEX                      ; 2             last block of section?
       BNE    .notLastBlock     ; 2              no, skip
       STX    PF_State          ; 3              yes, PF-State = static
       LDA    #12               ; 2              pattern-id for last block (with bridge)
       BNE    .setPF1Id         ; 3

.notLastBlock:
       LDA    level             ; 3
       LSR                      ; 2             straight level?
       LDA    #7                ; 2             pattern-id for straight block
       BCS    .setPF1Id         ; 2              yes, set
       LDA    PF_State          ; 3
       DEX                      ; 2             last but one block of section?
       BNE    .notLastButOne    ; 2              no, skip

; finish island before end of section:
       CMP    #ISLAND_FLAG|CHANGE_FLAG; 2       both flags set?
       BEQ    .isSetBoth        ; 2              yes, 11 -> 10 (1. step to finish island)
       BNE    .clearBoth        ; 3              no, static PF and no island (2. step to finish island)

; change PF_State bits 7 & 6:
; 00 -> 01/00     static -> changing or static
; 01 -> 11        changing ->  island & changing
; 10 -> 00        island & static -> static (JTZ: ???)
; 11 -> 10/11     island & changing -> island & changing or static
.notLastButOne:
       ASL                      ; 2
       EOR    PF_State          ; 3             CHANGE_FLAG != ISLAND_FLAG?
       BMI    .updateFlags      ; 2              yes, change flags
       LDA    randomLo          ; 3             randomly change state?
       AND    #%00110000        ; 2
       BNE    .skipFlags        ; 2              no, don't change state (75%)
.isSetBoth:
       LDA    PF_State          ; 3
       AND    #ISLAND_FLAG      ; 2             ISLAND_FLAG set?
       BNE    .isIsland         ; 2              yes, clear CHANGE_FLAG
       ORA    #CHANGE_FLAG      ; 2              no, set CHANGE_FLAG
.isIsland:
       STA    PF_State          ; 3
       LDA    #0                ; 2
       BEQ    .setPF1Id         ; 3

.updateFlags:
; change flags: 01 -> 11, 10 -> 00
       LDA    #ISLAND_FLAG|CHANGE_FLAG; 2
       BIT    PF_State          ; 3             CHANGE_FLAG set?
       BVS    .setBoth          ; 2              yes, set ISLAND_FLAG
.clearBoth:
       LDA    #0                ; 2              no, clear both flags
.setBoth:
       STA    PF_State          ; 3
.skipFlags:

; create new random PF id:
; (JTZ: I'm not 100% sure, that I understand everything completely)
       LDY    #14               ; 2             y = 14
       LDA    randomLo          ; 3
       AND    #$0F              ; 2
       CMP    #2                ; 2
       BCS    .minOk            ; 2
       ADC    #2                ; 2             minimum = 2
.minOk:                         ;               a = 2..15
       BIT    PF_State          ; 3             ISLAND_FLAG set?
       BPL    .skipDey          ; 2              no, skip
       DEY                      ; 2             y = 13
.skipDey:
       LDX    valleyWidth       ; 3             all widths allowed?
       BEQ    .allWidths        ; 2              yes, skip limit
       LDY    #8                ; 2             y = 8
.allWidths:
       STY    temp              ; 3             save max. allowed id
       CMP    temp              ; 3             random id < max. id?
       BCC    .setPF1Id         ; 2              yes, skip
       LDA    temp              ; 3              no, use max. id
.setPF1Id:
       STA    PF1PatId          ; 3             a = 2..8 or 2..13/14
       LDY    #BLOCK_PARTS      ; 2             reset blockPart
       STY    blockPart         ; 3

.nextBlockPart:
       LDA    prevPF1PatId      ; 3
       TAX                      ; 2
       SEC                      ; 2
       SBC    PF1PatId          ; 3
       STA    diffPF            ; 3             store the difference between the two blocks
       BCS    .biggerPrev       ; 2
; new id is bigger:
       INC    diffPF            ; 5
       CPX    #SWITCH_PAGE_ID-1 ; 2
       LDX    PF1PatId          ; 3
       BCS    .prevBigId        ; 2
       CPX    #SWITCH_PAGE_ID   ; 2
       BCC    .page1Id          ; 2
       LDA    #-1               ; 2
       ADC    prevPF1PatId      ; 3             CF=1! (JTZ: what's that good for?)
       BPL    .prevId           ; 3

; old id is bigger or equal:
.biggerPrev:
       BEQ    .equalId          ; 2
       DEC    diffPF            ; 5             -1
.equalId:
       CPX    #SWITCH_PAGE_ID   ; 2
       BCS    .page0Id          ; 2
; not enough space for an island:
.page1Id:
       JSR    GetPageFlag       ; 6
       JSR    LoadPFPattern     ; 6             a = 0/1
       STA    PF1LstEnd         ; 3
       LDA    #0                ; 2
       STA    PF2LstEnd         ; 3
       BEQ    .contPage1        ; 3

; enough space for an island in previous block:
.page0Id:
       LDA    PF1PatId          ; 3
       CMP    #SWITCH_PAGE_ID-1 ; 2
       BCS    .prevBigId        ; 2
; enough space for an island in both blocks:
       LDA    #14+1             ; 2
       SBC    PF1PatId          ; 3             CF=0!
       BCS    .prevId           ; 3             negate id (inverts pattern)

.prevBigId:
       LDA    #PF1_PAGE_FLAG|PF2_PAGE_FLAG|PF_COLOR_FLAG; 2
.prevId:
       STA    PF1LstEnd         ; 3
       JSR    GetPageFlag       ; 6
       SEC                      ; 2
       ROL                      ; 2
       JSR    LoadPFPattern     ; 6             a = 1/3
.contPage1:
       BIT    PF_State          ; 3             ISLAND_FLAG set?
       BPL    .skipSwapPF       ; 2              no, don't swap
       LDA    PF1LstEnd         ; 3
       LDX    PF2LstEnd         ; 3
       STA    PF2LstEnd         ; 3
       STX    PF1LstEnd         ; 3
.skipSwapPF:
       BIT    blockLstEnd       ; 3             PF_ROAD_FLAG set?
       BPL    .skipRoad         ; 2              no, skip
       LDA    #QUAD_SIZE        ; 2              yes, create road block
       STA    State1LstEnd      ; 3             quad size bridge
       LDY    #ID_BRIDGE        ; 2
       LDA    #63               ; 2             x-position
       JMP    .endNewShape      ; 3

.skipRoad:
; *** create new objects: ***
       LDY    #ID_FUEL          ; 2
       LDA    sectionBlock      ; 3
       CLC                      ; 2
       ADC    blockPart         ; 3
       CMP    #SECTION_BLOCKS+BLOCK_PARTS; 2    no enemies at first part of first block of section
       BCS    .newHouse         ; 2
; create more enemies and less fuel in higher difficulty levels:
       LDA    #64               ; 2
       SBC    level             ; 3             1..48 (CF=0!)
       ASL                      ; 2             a = 124..30
       CMP    randomHi          ; 3
       BCC    .newEnemy         ; 2             ~48%..88% -> more enemies, less fuel and houses
       BIT    randomLo          ; 3
       BVC    .newFuel          ; 2             ~24%.. 6% -> less fuel
; no enemy or fuel, create new house instead:
.newHouse:
       DEY                      ; 2             y=ID_HOUSE
       LDX    PF1PatId          ; 3
       CPX    prevPF1PatId      ; 3
       BCC    .currentSmaller   ; 2
       LDX    prevPF1PatId      ; 3
.currentSmaller:                ;               x = smaller id
       LDA    #DOUBLE_SIZE      ; 2             house is double sized
       STA    State1LstEnd      ; 3
       LDA    level             ; 3
       LSR                      ; 2
       BCC    .notStraight      ; 2
; create random x-position for house in straight section:
       LDA    randomLo          ; 3
       AND    #$1F              ; 2
       ADC    #8                ; 2
       CMP    #25               ; 2             random position fits in left bank?
       BCC    .setShapeDir      ; 2              yes, ok
       ADC    #92               ; 2              no, position house on right bank
       BNE    .setShapeDir      ; 3

; position house in non-straight section:
.notStraight:
       LDA    ShapePosTab,X     ; 4             x-pos based on PF1 id
       BIT    PF_State          ; 3             ISLAND_FLAG set?
       BPL    .setShapeDir      ; 2              no, skip
       CPX    #0                ; 2             PF id = 0?
       BEQ    .setShapeDir      ; 2              no, skip
       LDA    #71               ; 2             fixed position for a house on island
       BNE    .setShapeDir      ; 3

; create new ship, helicopter or plane:
.newEnemy:
       LDA    #%111             ; 2
       LDX    level             ; 3
       CPX    #3                ; 2             enemy planes start at level three
       BCS    .withPlanes       ; 2
       LDA    #%001             ; 2             limit first levels to ship and helicopter
.withPlanes:
       AND    randomHi          ; 3             create random enemy object
       TAX                      ; 2
       LDY    EnemyIdTab,X      ; 4
.newFuel:
       CPY    #ID_SHIP          ; 2
       BNE    .noShip           ; 2
       LDA    #DOUBLE_SIZE      ; 2             doublesize
       STA    State1LstEnd      ; 3
.noShip:
       LDA    PF1PatId          ; 3
       CMP    prevPF1PatId      ; 3             new pat-id = previous pat-id?
       BNE    .newId            ; 2              no,
; position object in straight blocks:
       STA    maxId             ; 3
       LDA    level             ; 3
       LSR                      ; 2
       BCC    .notStraight2     ; 2
; position object in straight section:
       LDA    #106              ; 2
       LDX    State1LstEnd      ; 3             ship? (doublesize)
       BEQ    .isShip           ; 2              yes, position more right
       LDA    #97               ; 2              no, position more left
.isShip:
       SBC    valleyWidth       ; 3             decrease maximum position (-6) in first four levels,
                                ;                this avoids positioning near the river bank
       STA    temp              ; 3             store maximum position
       LDA    randomLo          ; 3
       AND    #$3F              ; 2
       ADC    #45               ; 2
       ADC    valleyWidth       ; 3             increase random position in first four levels (s.a.)
       CMP    temp              ; 3             random position < maximum?
       BCC    .setShapeDir      ; 2              yes, ok
       LDA    temp              ; 3              no, position = maximum
.setShapeDir:
; make random direction for new shape:
       BIT    randomLo          ; 3
       BMI    .invertDirection  ; 2
       BPL    .endNewShape      ; 3

.newId:
       BCS    .currentBigger    ; 2
       LDA    prevPF1PatId      ; 3
.currentBigger:
       STA    maxId             ; 3             maxId cointains max(prevId, newId)

; position object in non-straight section:
.notStraight2:
; check, if there is enough space for new object:
       LDX    #13               ; 2             PF id
       BIT    PF_State          ; 3             ISLAND_FLAG set?
       BPL    .contPage12       ; 2              no, skip
       LDX    #10               ; 2              yes, lower PF id
.contPage12:
       CPX    maxId             ; 3
       BCS    .spaceOk          ; 2
       TYA                      ; 2
       SBC    #ID_SHIP-1        ; 2             new enemy is a ship?
       BNE    .spaceOk          ; 2              no, skip
       STA    State1LstEnd      ; 3              yes, change..
       DEY                      ; 2              ..ship into helicopter
.spaceOk:
       LDA    maxId             ; 3
       ASL                      ; 2
       ASL                      ; 2
       BEQ    .posSomewhere     ; 2
       BIT    PF_State          ; 3             ISLAND_FLAG set?
       BPL    .posSomewhere     ; 2              no, position somewhere
; position object outside:
       EOR    #$FF              ; 2
       ADC    #81               ; 2
       BIT    randomLo          ; 3
       BPL    .skipNeg          ; 2
       EOR    #$FF              ; 2
       ADC    #160              ; 2
       BNE    .contPos          ; 3

; position object somewhere:
.posSomewhere:
       ADC    #16               ; 2
       BIT    randomLo          ; 3
       BMI    .doNeg            ; 2
.contPos:
       CLC                      ; 2
       ADC    #2                ; 2
       ADC    valleyWidth       ; 3             keep space to river bank in first levels
       BNE    .endNewShape      ; 3

.doNeg:
       EOR    #$FF              ; 2
       ADC    #160+1            ; 2
.skipNeg:
       CPY    #ID_FUEL          ; 2             position fuel 1 pixel more right
       SBC    #9                ; 2
       SBC    valleyWidth       ; 3             keep space to river bank in first levels
       LDX    State1LstEnd      ; 3             double sized object? (ship, house)
       BEQ    .invertDirection  ; 2              no, skip
       SBC    #10               ; 2              yes, move 10 pixels left
.invertDirection:
       CPY    #ID_FUEL          ; 2             fuel?
       BEQ    .endNewShape      ; 2              yes, has constant direction
       PHA                      ; 3
       LDA    State1LstEnd      ; 3
       ORA    #DIRECTION_FLAG   ; 2             set direction flag
       STA    State1LstEnd      ; 3
       PLA                      ; 4
.endNewShape:
       STY    Shape1IdLstEnd    ; 3             save id of new object
       JSR    CalcPosX          ; 6
       STY    XPos1LstEnd       ; 3             save coarse x-positioning value
       ORA    State1LstEnd      ; 3
       STA    State1LstEnd      ; 3             save fine x-positioning value
       JMP    .loopNext         ; 3

; ****************************** end of main loop ******************************


GameInit SUBROUTINE
; Input: x (= 22/38, number of initialized variables)
; initializes some variables for new game:
.initLoop:
       LDA    InitTab,X         ; 4
       STA    PF1Lst,X          ; 4
       DEX                      ; 2
       BPL    .initLoop         ; 2

; clear some variables for new game:
       LDA    #0                ; 2
       LDX    #30               ; 2
.loopClear:
       STA    dXSpeed,X         ; 4
       DEX                      ; 2
       BPL    .loopClear        ; 2

       LDX    #NUM_BLOCKS-1     ; 2
       LDY    #PF1_PAGE_FLAG    ; 2
       LDA    level             ; 3
       LSR                      ; 2             straight level?
       BCC    .loopSet          ; 2              no, skip
       LDY    #PF1_PAGE_FLAG|PF_COLOR_FLAG; 2    yes, set brighter green in current level
.loopSet:
       STY    blockLst,X        ; 4
       DEX                      ; 2
       BPL    .loopSet          ; 2
       RTS                      ; 6

  IF NTSC
LoadPFPattern SUBROUTINE
       BIT    PF_State          ; 3             ISLAND_FLAG set?
       BPL    .contPage1        ; 2              no, set current page-flag
       TAY                      ; 2              yes, read new page-flag from table
       LDA    PageFlagTab,Y     ; 4
.contPage1:
       ORA    blockLstEnd       ; 3
       STA    blockLstEnd       ; 3
       LDA    BankPtrTab,X      ; 4             load a pattern for the river bank
       CLC                      ; 2
       ADC    diffPF            ; 3             adjust with difference between new and prev PF id
       STA    PF2LstEnd         ; 3
       RTS                      ; 6
  ELSE
FinishDigits SUBROUTINE
       INY                      ; 2
       STA    WSYNC             ; 3
       STA    HMOVE             ; 3
       STY    GRP1              ; 3
       STY    GRP0              ; 3
       STY    GRP1              ; 3
       LDY    #14               ; 2             load line counter
SetColPx:
       STA    COLUP0            ; 3
       STA    COLUP1            ; 3
DoHMove:
       STA    WSYNC             ; 3
       STA    HMOVE             ; 3
       RTS                      ; 6
  ENDIF

NextRandom16 SUBROUTINE
; implements a 16 bit LFSR which generates a new random number:
       LDA    randomHi          ; 3
       ASL                      ; 2
       ASL                      ; 2
       ASL                      ; 2
       EOR    randomHi          ; 3
       ASL                      ; 2
       ROL    randomLo          ; 5
       ROL    randomHi          ; 5
; (JTZ: randomHi is very random, randomLo is NOT when more than one bit is used,
; because: randomLo[x+1] = randomLo[x]*2 + 0/1, but randomLo is used more often,
; randomHi only for new enemy and which. This could make the game a bit predictable.)
       RTS                      ; 6

SaveSection SUBROUTINE
; called at the start of a new section, increases difficulty level
;  and saves random variables to be able to restart this section
       LDX    level             ; 3             limit level to 48
       CPX    #MAX_LEVEL        ; 2
       BCC    .notMax           ; 2
       LDX    #MAX_LEVEL-2      ; 2              go back to 47
.notMax:
       LDA    randomLoSave      ; 3
       STA    randomLoSave2     ; 3
       LDA    randomHiSave      ; 3
       STA    randomHiSave2     ; 3
       LDA    randomLo          ; 3
       STA    randomLoSave      ; 3
       LDA    randomHi          ; 3
       STA    randomHiSave      ; 3
       INX                      ; 2
       STX    level             ; 3             1..48
       RTS                      ; 6

SetPosX SUBROUTINE
; calculates the values and positions objects:
       JSR    CalcPosX          ; 6
SetPosX2:
       STA    HMP0,X            ; 4
       INY                      ; 2
       INY                      ; 2
       INY                      ; 2
       STA    WSYNC             ; 3
.waitPos:
       DEY                      ; 2
       BPL    .waitPos          ; 2
       STA    RESP0,X           ; 4
       RTS                      ; 6


;===============================================================================
; R O M - T A B L E S (Part 1)
;===============================================================================

       align 256

Zero:
       .byte $3C ; |  XXXX  | $FB00
       .byte $66 ; | XX  XX |
       .byte $66 ; | XX  XX |
       .byte $66 ; | XX  XX |
       .byte $66 ; | XX  XX |
       .byte $66 ; | XX  XX |
       .byte $66 ; | XX  XX |
       .byte $3C ; |  XXXX  |
One:
       .byte $3C ; |  XXXX  |
       .byte $18 ; |   XX   |
       .byte $18 ; |   XX   |
       .byte $18 ; |   XX   |
       .byte $18 ; |   XX   |
       .byte $18 ; |   XX   |
       .byte $38 ; |  XXX   |
       .byte $18 ; |   XX   |
Two:
       .byte $7E ; | XXXXXX |
       .byte $60 ; | XX     |
       .byte $60 ; | XX     |
       .byte $3C ; |  XXXX  |
       .byte $06 ; |     XX |
       .byte $06 ; |     XX |
       .byte $46 ; | X   XX |
       .byte $3C ; |  XXXX  |
Three:
       .byte $3C ; |  XXXX  |
       .byte $46 ; | X   XX |
       .byte $06 ; |     XX |
       .byte $0C ; |    XX  |
       .byte $0C ; |    XX  |
       .byte $06 ; |     XX |
       .byte $46 ; | X   XX |
       .byte $3C ; |  XXXX  |
Four:
       .byte $0C ; |    XX  |
       .byte $0C ; |    XX  |
       .byte $0C ; |    XX  |
       .byte $7E ; | XXXXXX |
       .byte $4C ; | X  XX  |
       .byte $2C ; |  X XX  |
       .byte $1C ; |   XXX  |
       .byte $0C ; |    XX  |
Five:
       .byte $7C ; | XXXXX  |
       .byte $46 ; | X   XX |
       .byte $06 ; |     XX |
       .byte $06 ; |     XX |
       .byte $7C ; | XXXXX  |
       .byte $60 ; | XX     |
       .byte $60 ; | XX     |
       .byte $7E ; | XXXXXX |
Six:
       .byte $3C ; |  XXXX  |
       .byte $66 ; | XX  XX |
       .byte $66 ; | XX  XX |
       .byte $66 ; | XX  XX |
       .byte $7C ; | XXXXX  |
       .byte $60 ; | XX     |
       .byte $62 ; | XX   X |
       .byte $3C ; |  XXXX  |
Seven:
       .byte $18 ; |   XX   |
       .byte $18 ; |   XX   |
       .byte $18 ; |   XX   |
       .byte $18 ; |   XX   |
       .byte $0C ; |    XX  |
       .byte $06 ; |     XX |
       .byte $42 ; | X    X |
       .byte $7E ; | XXXXXX |
Eight:
       .byte $3C ; |  XXXX  |
       .byte $66 ; | XX  XX |
       .byte $66 ; | XX  XX |
       .byte $3C ; |  XXXX  |
       .byte $3C ; |  XXXX  |
       .byte $66 ; | XX  XX |
       .byte $66 ; | XX  XX |
       .byte $3C ; |  XXXX  |
Nine:
       .byte $3C ; |  XXXX  |
       .byte $46 ; | X   XX |
       .byte $06 ; |     XX |
       .byte $3E ; |  XXXXX |
       .byte $66 ; | XX  XX |
       .byte $66 ; | XX  XX |
       .byte $66 ; | XX  XX |
       .byte $3C ; |  XXXX  |
MaxOut:
       .byte $18 ; |   XX   |
       .byte $18 ; |   XX   |
       .byte $00 ; |        |
       .byte $18 ; |   XX   |
       .byte $18 ; |   XX   |
       .byte $18 ; |   XX   |
       .byte $18 ; |   XX   |
       .byte $18 ; |   XX   |
Space:
       .byte $00 ; |        |
Copyright0:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $F7 ; |XXXX XXX|
       .byte $95 ; |X  X X X|
       .byte $87 ; |X    XXX|
       .byte $80 ; |X       |
       .byte $90 ; |X  X    |
       .byte $F0 ; |XXXX    |
Copyright1:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $47 ; | X   XXX|
       .byte $41 ; | X     X|
       .byte $77 ; | XXX XXX|
       .byte $55 ; | X X X X|
       .byte $75 ; | XXX X X|
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
Copyright2:
       .byte $AD ; |X X XX X|
       .byte $A9 ; |X X X  X|
       .byte $E9 ; |XXX X  X|
       .byte $A9 ; |X X X  X|
       .byte $ED ; |XXX XX X|
       .byte $41 ; | X     X|
       .byte $0F ; |    XXXX|
       .byte $00 ; |        |
       .byte $03 ; |      XX|
       .byte $00 ; |        |
       .byte $4B ; | X  X XX|
       .byte $4A ; | X  X X |
       .byte $6B ; | XX X XX|
       .byte $00 ; |        |
       .byte $08 ; |    X   |
       .byte $00 ; |        |
Copyright3:
       .byte $50 ; | X X    |
       .byte $58 ; | X XX   |
       .byte $5C ; | X XXX  |
       .byte $56 ; | X X XX |
       .byte $53 ; | X X  XX|
       .byte $11 ; |   X   X|
       .byte $F0 ; |XXXX    |
       .byte $00 ; |        |
       .byte $80 ; |X       |
       .byte $80 ; |X       |
       .byte $AA ; |X X X X |
       .byte $AA ; |X X X X |
       .byte $BA ; |X XXX X |
       .byte $22 ; |  X   X |
       .byte $27 ; |  X  XXX|
       .byte $02 ; |      X |
Copyright4:
       .byte $BA ; |X XXX X |
       .byte $8A ; |X   X X |
       .byte $BA ; |X XXX X |
       .byte $A2 ; |X X   X |
       .byte $3A ; |  XXX X |
       .byte $80 ; |X       |
       .byte $FE ; |XXXXXXX |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $11 ; |   X   X|
       .byte $11 ; |   X   X|
       .byte $17 ; |   X XXX|
       .byte $15 ; |   X X X|
       .byte $17 ; |   X XXX|
       .byte $00 ; |        |
Copyright5:
       .byte $E9 ; |XXX X  X|
       .byte $AB ; |X X X XX|
       .byte $AF ; |X X XXXX|
       .byte $AD ; |X X XX X|
       .byte $E9 ; |XXX X  X|
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $77 ; | XXX XXX|
       .byte $54 ; | X X X  |
       .byte $77 ; | XXX XXX|
       .byte $51 ; | X X   X|
       .byte $77 ; | XXX XXX|

PageFlagTab:
       .byte 0, PF2_PAGE_FLAG, PF1_PAGE_FLAG, PF1_PAGE_FLAG|PF2_PAGE_FLAG       ; PF1_PAGE_FLAG unused!
shapePtr1bTab:
       .byte <Explosion0-1, <Explosion1B-1, <Explosion2B-1, <Explosion1B-1
       .byte <PlaneB-1, <Heli0B-1, <Heli1B-1, <ShipB-1, <BridgeB-1, <HouseB-1, <FuelB-1

; x-positions of new object:
ShapePosTab:
       .byte 143, 141, 7, 10, 132, 13, 128, 18, 124, 22, 120, 26, 116, 30, 112


;===============================================================================
; R O M - C O D E (Part 2)
;===============================================================================

SetPFxPtr SUBROUTINE
; called from kernel, sets pointers for new playfield data:
       LDA    PF1Lst,X          ; 4
       STA    PF1Ptr            ; 3
       LDA    blockLst,X        ; 4
       AND    #PF1_PAGE_FLAG    ; 2
       ORA    #>PFPat0          ; 2
       STA    PF1Ptr+1          ; 3

       LDA    PF2Lst,X          ; 4
       STA    PF2Ptr            ; 3
       LDA    blockLst,X        ; 4
       LSR                      ; 2
       AND    #PF2_PAGE_FLAG>>1 ; 2
       ORA    #>PFPat0          ; 2
       STA    PF2Ptr+1          ; 3
       RTS                      ; 6 = 44


;===============================================================================
; R O M - T A B L E S (Part 2)
;===============================================================================

; high addresses of entry points into kernel:
JmpHiTab:
       .byte >[JmpPoint0-1], >[JmpPoint1-1], >[JmpPoint2-1], >[JmpPoint3-1], >[JmpPoint4-1]
       .byte >[JmpPoint5-1], >[JmpPoint6-1], >[JmpPoint7-1], >[JmpPoint8-1], >[JmpPoint9-1]

; used to animate explosions and helicopter:
AnimateIdTab:
       .byte 0                  ;
       .byte ID_EXPLOSION2      ; start of explosion sequence
       .byte ID_EXPLOSION3      ;
       .byte ID_EXPLOSION0      ; end explosion with 0
       .byte ID_PLANE           ; no animation for plane
       .byte ID_HELI1           ; switch between..
       .byte ID_HELI0           ; ..ID_HELI0 and ID_HELI1

; these are the patterns, that are used to define the playfield:
PFPat0:
       .byte $00 ; |        | $FC00
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $01 ; |       X|
       .byte $03 ; |      XX|
       .byte $07 ; |     XXX|
       .byte $0F ; |    XXXX|
       .byte $1F ; |   XXXXX|
PFPat14:
       .byte $3F ; |  XXXXXX|
       .byte $3F ; |  XXXXXX|
       .byte $3F ; |  XXXXXX|
       .byte $3F ; |  XXXXXX|
       .byte $3F ; |  XXXXXX|
       .byte $3F ; |  XXXXXX|
       .byte $3F ; |  XXXXXX|
       .byte $3F ; |  XXXXXX|
       .byte $3F ; |  XXXXXX|
       .byte $3F ; |  XXXXXX|
       .byte $3F ; |  XXXXXX|
       .byte $3F ; |  XXXXXX|
       .byte $3F ; |  XXXXXX|
       .byte $3F ; |  XXXXXX|
       .byte $3F ; |  XXXXXX|
       .byte $3F ; |  XXXXXX|
       .byte $1F ; |   XXXXX|
       .byte $0F ; |    XXXX|
       .byte $07 ; |     XXX|
       .byte $03 ; |      XX|
       .byte $01 ; |       X|
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $01 ; |       X|
       .byte $03 ; |      XX|
       .byte $07 ; |     XXX|
       .byte $0F ; |    XXXX|
PFPat13:
       .byte $1F ; |   XXXXX|
       .byte $1F ; |   XXXXX|
       .byte $1F ; |   XXXXX|
       .byte $1F ; |   XXXXX|
       .byte $1F ; |   XXXXX|
       .byte $1F ; |   XXXXX|
       .byte $1F ; |   XXXXX|
       .byte $1F ; |   XXXXX|
       .byte $1f ; |   XXXXX|
       .byte $1F ; |   XXXXX|
       .byte $1F ; |   XXXXX|
       .byte $1F ; |   XXXXX|
       .byte $1F ; |   XXXXX|
       .byte $1F ; |   XXXXX|
       .byte $1F ; |   XXXXX|
       .byte $1F ; |   XXXXX|
       .byte $0F ; |    XXXX|
       .byte $07 ; |     XXX|
       .byte $03 ; |      XX|
       .byte $01 ; |       X|
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $01 ; |       X|
       .byte $03 ; |      XX|
       .byte $07 ; |     XXX|
PFPat12:
       .byte $0F ; |    XXXX|
       .byte $0F ; |    XXXX|
       .byte $0F ; |    XXXX|
       .byte $0F ; |    XXXX|
       .byte $0F ; |    XXXX|
       .byte $0F ; |    XXXX|
       .byte $0F ; |    XXXX|
       .byte $0F ; |    XXXX|
       .byte $0F ; |    XXXX|
       .byte $0F ; |    XXXX|
       .byte $0F ; |    XXXX|
       .byte $0F ; |    XXXX|
       .byte $0F ; |    XXXX|
       .byte $0F ; |    XXXX|
       .byte $0F ; |    XXXX|
       .byte $0F ; |    XXXX|
       .byte $07 ; |     XXX|
       .byte $03 ; |      XX|
       .byte $01 ; |       X|
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $01 ; |       X|
       .byte $03 ; |      XX|
PFPat11:
       .byte $07 ; |     XXX|
       .byte $07 ; |     XXX|
       .byte $07 ; |     XXX|
       .byte $07 ; |     XXX|
       .byte $07 ; |     XXX|
       .byte $07 ; |     XXX|
       .byte $07 ; |     XXX|
       .byte $07 ; |     XXX|
       .byte $07 ; |     XXX|
       .byte $07 ; |     XXX|
       .byte $07 ; |     XXX|
       .byte $07 ; |     XXX|
       .byte $07 ; |     XXX|
       .byte $07 ; |     XXX|
       .byte $07 ; |     XXX|
       .byte $07 ; |     XXX|
       .byte $03 ; |      XX|
       .byte $01 ; |       X|
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $01 ; |       X|
PFPat10:
       .byte $03 ; |      XX|
       .byte $03 ; |      XX|
       .byte $03 ; |      XX|
       .byte $03 ; |      XX|
       .byte $03 ; |      XX|
       .byte $03 ; |      XX|
       .byte $03 ; |      XX|
       .byte $03 ; |      XX|
       .byte $03 ; |      XX|
       .byte $03 ; |      XX|
       .byte $03 ; |      XX|
       .byte $03 ; |      XX|
       .byte $03 ; |      XX|
       .byte $03 ; |      XX|
       .byte $03 ; |      XX|
       .byte $03 ; |      XX|
       .byte $01 ; |       X|
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
PFPat9:
       .byte $01 ; |       X|
       .byte $01 ; |       X|
       .byte $01 ; |       X|
       .byte $01 ; |       X|
       .byte $01 ; |       X|
       .byte $01 ; |       X|
       .byte $01 ; |       X|
       .byte $01 ; |       X|
       .byte $01 ; |       X|
       .byte $01 ; |       X|
       .byte $01 ; |       X|
       .byte $01 ; |       X|
       .byte $01 ; |       X|
       .byte $01 ; |       X|
       .byte $01 ; |       X|
       .byte $01 ; |       X|
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
JetStraight:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $2A ; |  X X X |
       .byte $3E ; |  XXXXX |
       .byte $1C ; |   XXX  |
       .byte $08 ; |    X   |
       .byte $49 ; | X  X  X|
       .byte $6B ; | XX X XX|
       .byte $7F ; | XXXXXXX|
       .byte $7F ; | XXXXXXX|
       .byte $3E ; |  XXXXX |
       .byte $1C ; |   XXX  |
       .byte $08 ; |    X   |
       .byte $08 ; |    X   |
       .byte $08 ; |    X   |
JetMove:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $02 ; |      X |
       .byte $2E ; |  X XXX |
       .byte $3C ; |  XXXX  |
       .byte $18 ; |   XX   |
       .byte $08 ; |    X   |
       .byte $0A ; |    X X |
       .byte $2E ; |  X XXX |
       .byte $3E ; |  XXXXX |
       .byte $3E ; |  XXXXX |
       .byte $3C ; |  XXXX  |
       .byte $18 ; |   XX   |
       .byte $08 ; |    X   |
       .byte $08 ; |    X   |
       .byte $08 ; |    X   |
JetExplode:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $02 ; |      X |
       .byte $08 ; |    X   |
       .byte $10 ; |   X    |
       .byte $00 ; |        |
       .byte $40 ; | X      |
       .byte $08 ; |    X   |
       .byte $21 ; |  X    X|
       .byte $44 ; | X   X  |
       .byte $10 ; |   X    |
       .byte $04 ; |     X  |
       .byte $08 ; |    X   |
       .byte $00 ; |        |

; low pointers to the patterns for the river bank:
BankPtrTab:                     ; $FCF1
       .byte <PFPat0, <PFPat1, <PFPat2, <PFPat3, <PFPat4, <PFPat5, <PFPat6, <PFPat7, <PFPat8
; last patterns are only used for islands:
       .byte <PFPat9, <PFPat10, <PFPat11, <PFPat12, <PFPat13, <PFPat14

       align 256

       .byte $80 ; |X       | $FD00
       .byte $C0 ; |XX      |
       .byte $E0 ; |XXX     |
       .byte $F0 ; |XXXX    |
       .byte $F8 ; |XXXXX   |
       .byte $FC ; |XXXXXX  |
       .byte $FE ; |XXXXXXX |
PFPat8:
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FE ; |XXXXXXX |
       .byte $FC ; |XXXXXX  |
       .byte $F8 ; |XXXXX   |
       .byte $F0 ; |XXXX    |
       .byte $E0 ; |XXX     |
       .byte $C0 ; |XX      |
       .byte $80 ; |X       |
       .byte $C0 ; |XX      |
       .byte $E0 ; |XXX     |
       .byte $F0 ; |XXXX    |
       .byte $F8 ; |XXXXX   |
       .byte $FC ; |XXXXXX  |
PFPat7:
       .byte $FE ; |XXXXXXX |
       .byte $FE ; |XXXXXXX |
       .byte $FE ; |XXXXXXX |
       .byte $FE ; |XXXXXXX |
       .byte $FE ; |XXXXXXX |
       .byte $FE ; |XXXXXXX |
       .byte $FE ; |XXXXXXX |
       .byte $FE ; |XXXXXXX |
       .byte $FE ; |XXXXXXX |
       .byte $FE ; |XXXXXXX |
       .byte $FE ; |XXXXXXX |
       .byte $FE ; |XXXXXXX |
       .byte $FE ; |XXXXXXX |
       .byte $FE ; |XXXXXXX |
       .byte $FE ; |XXXXXXX |
       .byte $FE ; |XXXXXXX |
       .byte $FC ; |XXXXXX  |
       .byte $F8 ; |XXXXX   |
       .byte $F0 ; |XXXX    |
       .byte $E0 ; |XXX     |
       .byte $C0 ; |XX      |
       .byte $80 ; |X       |
       .byte $C0 ; |XX      |
       .byte $E0 ; |XXX     |
       .byte $F0 ; |XXXX    |
       .byte $F8 ; |XXXXX   |
PFPat6:
       .byte $FC ; |XXXXXX  |
       .byte $FC ; |XXXXXX  |
       .byte $FC ; |XXXXXX  |
       .byte $FC ; |XXXXXX  |
       .byte $FC ; |XXXXXX  |
       .byte $FC ; |XXXXXX  |
       .byte $FC ; |XXXXXX  |
       .byte $FC ; |XXXXXX  |
       .byte $FC ; |XXXXXX  |
       .byte $FC ; |XXXXXX  |
       .byte $FC ; |XXXXXX  |
       .byte $FC ; |XXXXXX  |
       .byte $FC ; |XXXXXX  |
       .byte $FC ; |XXXXXX  |
       .byte $FC ; |XXXXXX  |
       .byte $FC ; |XXXXXX  |
       .byte $F8 ; |XXXXX   |
       .byte $F0 ; |XXXX    |
       .byte $E0 ; |XXX     |
       .byte $C0 ; |XX      |
       .byte $80 ; |X       |
       .byte $C0 ; |XX      |
       .byte $E0 ; |XXX     |
       .byte $F0 ; |XXXX    |
PFPat5:
       .byte $F8 ; |XXXXX   |
       .byte $F8 ; |XXXXX   |
       .byte $F8 ; |XXXXX   |
       .byte $F8 ; |XXXXX   |
       .byte $F8 ; |XXXXX   |
       .byte $F8 ; |XXXXX   |
       .byte $F8 ; |XXXXX   |
       .byte $F8 ; |XXXXX   |
       .byte $F8 ; |XXXXX   |
       .byte $F8 ; |XXXXX   |
       .byte $F8 ; |XXXXX   |
       .byte $F8 ; |XXXXX   |
       .byte $F8 ; |XXXXX   |
       .byte $F8 ; |XXXXX   |
       .byte $F8 ; |XXXXX   |
       .byte $F8 ; |XXXXX   |
       .byte $F0 ; |XXXX    |
       .byte $E0 ; |XXX     |
       .byte $C0 ; |XX      |
       .byte $80 ; |X       |
       .byte $C0 ; |XX      |
       .byte $E0 ; |XXX     |
PFPat4:
       .byte $F0 ; |XXXX    |
       .byte $F0 ; |XXXX    |
       .byte $F0 ; |XXXX    |
       .byte $F0 ; |XXXX    |
       .byte $F0 ; |XXXX    |
       .byte $F0 ; |XXXX    |
       .byte $F0 ; |XXXX    |
       .byte $F0 ; |XXXX    |
       .byte $F0 ; |XXXX    |
       .byte $F0 ; |XXXX    |
       .byte $F0 ; |XXXX    |
       .byte $F0 ; |XXXX    |
       .byte $F0 ; |XXXX    |
       .byte $F0 ; |XXXX    |
       .byte $F0 ; |XXXX    |
       .byte $F0 ; |XXXX    |
       .byte $E0 ; |XXX     |
       .byte $C0 ; |XX      |
       .byte $80 ; |X       |
       .byte $C0 ; |XX      |
PFPat3:
       .byte $E0 ; |XXX     |
       .byte $E0 ; |XXX     |
       .byte $E0 ; |XXX     |
       .byte $E0 ; |XXX     |
       .byte $E0 ; |XXX     |
       .byte $E0 ; |XXX     |
       .byte $E0 ; |XXX     |
       .byte $E0 ; |XXX     |
       .byte $E0 ; |XXX     |
       .byte $E0 ; |XXX     |
       .byte $E0 ; |XXX     |
       .byte $E0 ; |XXX     |
       .byte $E0 ; |XXX     |
       .byte $E0 ; |XXX     |
       .byte $E0 ; |XXX     |
       .byte $E0 ; |XXX     |
       .byte $C0 ; |XX      |
       .byte $80 ; |X       |
PFPat2:
       .byte $C0 ; |XX      |
       .byte $C0 ; |XX      |
       .byte $C0 ; |XX      |
       .byte $C0 ; |XX      |
       .byte $C0 ; |XX      |
       .byte $C0 ; |XX      |
       .byte $C0 ; |XX      |
       .byte $C0 ; |XX      |
       .byte $C0 ; |XX      |
       .byte $C0 ; |XX      |
       .byte $C0 ; |XX      |
       .byte $C0 ; |XX      |
       .byte $C0 ; |XX      |
       .byte $C0 ; |XX      |
       .byte $C0 ; |XX      |
       .byte $C0 ; |XX      |
PFPat1:
       .byte $80 ; |X       |
       .byte $80 ; |X       |
       .byte $80 ; |X       |
       .byte $80 ; |X       |
       .byte $80 ; |X       |
       .byte $80 ; |X       |
       .byte $80 ; |X       |
       .byte $80 ; |X       |
       .byte $80 ; |X       |
       .byte $80 ; |X       |
       .byte $80 ; |X       |
       .byte $80 ; |X       |
       .byte $80 ; |X       |
       .byte $80 ; |X       |
       .byte $80 ; |X       |
       .byte $80 ; |X       |

InitTab:        ; $FDB1
       .ds   6, <PFPat8                         ; PF1Lst
       .ds   6, <PFPat12                        ; PF2Lst
       .byte NUM_LINES+20                       ; missileY
       .byte 76                                 ; playerX
       .byte 0                                  ; speedX
       .byte 254                                ; speedY
       .byte 1                                  ;
       .byte $FF, $FF                           ; fuelHi, fuelLo
       .byte 17                                 ; sectionBlock
       .byte <PFPat0, >PFPat0                   ; shapePtr0             ;22
       .byte 12                                 ; PF1PatId
       .byte 1                                  ; level
       .byte SEED_LO, SEED_HI                   ; randomLoSave, randomHiSave
       .byte <Space, >Space                     ; livesPtr
       .byte 1, SEED_LO, SEED_HI, <Space        ; player2State (level, randomLoSave, randomHiSave, livesPtr)
       .byte $80                                ; gameMode
       .byte <FuelA, >FuelA                     ; shapePtr1a
       .byte <FuelB, >FuelB                     ; shapePtr1b
       .byte <ShipCol-3, >ShipCol               ; colorPtr


;===============================================================================
; R O M - C O D E (Part 3)
;===============================================================================

CalcPosX SUBROUTINE
; calculates values for x-positioning:
; Input:
; - a = x-position
; Return:
; - y = coarse value for delay loop
; - a = fine value for HMxy
       TAY                      ; 2
       INY                      ; 2
       TYA                      ; 2
       AND    #$0F              ; 2
       STA    temp2             ; 3
       TYA                      ; 2
       LSR                      ; 2
       LSR                      ; 2
       LSR                      ; 2
       LSR                      ; 2
       TAY                      ; 2
       CLC                      ; 2
       ADC    temp2             ; 3
       CMP    #$0F              ; 2
       BCC    .skipIny          ; 2
       SBC    #$0F              ; 2
       INY                      ; 2
.skipIny:
       EOR    #$07              ; 2
Mult16:
       ASL                      ; 2
       ASL                      ; 2
       ASL                      ; 2
       ASL                      ; 2
Wait12:
       RTS                      ; 6


;===============================================================================
; R O M - T A B L E S (Part 3)
;===============================================================================

; low addresses of entry points into kernel:
JmpLoTab:
       .byte <[JmpPoint0-1]
       .byte <[JmpPoint1-1]
       .byte <[JmpPoint2-1]
       .byte <[JmpPoint3-1]
       .byte <[JmpPoint4-1]
       .byte <[JmpPoint5-1]
       .byte <[JmpPoint6-1]
       .byte <[JmpPoint7-1]
       .byte <[JmpPoint8-1]
       .byte <[JmpPoint9-1]

       align 256

FuelTab0:
       .byte $7F ; | XXXXXXX| $FE00
       .byte $40 ; | X      |
       .byte $4F ; | X  XXXX|
       .byte $48 ; | X  X   |
       .byte $48 ; | X  X   |
       .byte $4E ; | X  XXX |
       .byte $48 ; | X  X   |
       .byte $48 ; | X  X   |
       .byte $4F ; | X  XXXX|
       .byte $40 ; | X      |
       .byte $40 ; | X      |
       .byte $4C ; | X  XX  |
       .byte $4C ; | X  XX  |
       .byte $4C ; | X  XX  |
       .byte $7F ; | XXXXXXX|

FuelTab1:
       .byte $FF ; |XXXXXXXX|
Explosion0:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
FuelTab2:
       .byte $FF ; |XXXXXXXX|
       .byte $00 ; |        |
       .byte $03 ; |      XX|
       .byte $C2 ; |XX    X |
       .byte $63 ; | XX   XX|
       .byte $30 ; |  XX    |
       .byte $1B ; |   XX XX|
       .byte $EC ; |XXX XX  |
       .byte $46 ; | X   XX |
       .byte $43 ; | X    XX|
       .byte $C1 ; |XX     X|
       .byte $48 ; | X  X   |
       .byte $08 ; |    X   |
       .byte $08 ; |    X   |
FuelTab3:
       .byte $FF ; |XXXXXXXX|
       .byte $00 ; |        |
       .byte $80 ; |X       |
       .byte $00 ; |        |
       .byte $80 ; |X       |
       .byte $80 ; |X       |
       .byte $80 ; |X       |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $80 ; |X       |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
FuelTab4:
       .byte $FF ; |XXXXXXXX|
       .byte $01 ; |       X|
       .byte $81 ; |X      X|
       .byte $81 ; |X      X|
       .byte $81 ; |X      X|
       .byte $E1 ; |XXX    X|
       .byte $81 ; |X      X|
       .byte $81 ; |X      X|
       .byte $F1 ; |XXXX   X|
       .byte $01 ; |       X|
       .byte $01 ; |       X|
       .byte $19 ; |   XX  X|
       .byte $19 ; |   XX  X|
       .byte $19 ; |   XX  X|
       .byte $FF ; |XXXXXXXX|

; used to en- or disable ball in fuel display:
ENABLTab:
       .byte DISABLE
       .byte ENABLE, ENABLE, ENABLE, ENABLE, ENABLE, ENABLE, ENABLE, ENABLE, ENABLE, ENABLE

; the scores to the enemy objects (bit 7 = 0: *10, = 1: *100):
ScoreTab:
       .byte 0, 0, 0, 0         ; EXPLOSIONS
       .byte DIGIT_H * 1 | $80  ; PLANE      100
       .byte DIGIT_H * 6        ; HELI        60
       .byte DIGIT_H * 6        ; HELI        60
       .byte DIGIT_H * 3        ; SHIP        30
       .byte DIGIT_H * 5 |$80   ; BRIDGE     500
       .byte 0                  ; HOUSE
       .byte DIGIT_H * 8        ; FUEL        80

; the data is stored for interlaced display:
FuelA:
       .byte $FE ; |XXXXXXX |
       .byte $DE ; |XX XXXX |
       .byte $DE ; |XX XXXX |
       .byte $FE ; |XXXXXXX |
       .byte $DE ; |XX XXXX |
       .byte $DE ; |XX XXXX |
       .byte $FE ; |XXXXXXX |
       .byte $D6 ; |XX X XX |
       .byte $D6 ; |XX X XX |
       .byte $DE ; |XX XXXX |
       .byte $CE ; |XX  XXX |
FuelB:
       .byte $C6 ; |XX   XX |
       .byte $DE ; |XX XXXX |
       .byte $DE ; |XX XXXX |
       .byte $C6 ; |XX   XX |
       .byte $CE ; |XX  XXX |
       .byte $C6 ; |XX   XX |
       .byte $C6 ; |XX   XX |
       .byte $D6 ; |XX X XX |

       .byte $FE ; |XXXXXXX |
       .byte $DE ; |XX XXXX |
       .byte $DE ; |XX XXXX |
       .byte $7C ; | XXXXX  |
BridgeA:
       .byte $42 ; | X    X |
BridgeB:
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $FF ; |XXXXXXXX|
       .byte $42 ; | X    X |
ShipB:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $FC ; |XXXXXX  |
       .byte $FF ; |XXXXXXXX|
       .byte $30 ; |  XX    |
       .byte $10 ; |   X    |
PlaneA:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $30 ; |  XX    |
       .byte $4F ; | X  XXXX|
       .byte $C6 ; |XX   XX |
       .byte $00 ; |        |
Heli1B:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $0E ; |    XXX |
       .byte $8E ; |X   XXX |
       .byte $FF ; |XXXXXXXX|
       .byte $0E ; |    XXX |
       .byte $07 ; |     XXX|
Heli0A:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $04 ; |     X  |
       .byte $FF ; |XXXXXXXX|
       .byte $9F ; |X  XXXXX|
       .byte $04 ; |     X  |
       .byte $07 ; |     XXX|
ShipA:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $7C ; | XXXXX  |
       .byte $FE ; |XXXXXXX |
       .byte $78 ; | XXXX   |
       .byte $10 ; |   X    |
PlaneB:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $38 ; |  XXX   |
       .byte $FF ; |XXXXXXXX|
       .byte $80 ; |X       |
Heli1A:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $04 ; |     X  |
       .byte $FF ; |XXXXXXXX|
       .byte $9F ; |X  XXXXX|
       .byte $04 ; |     X  |
       .byte $1C ; |   XXX  |
Heli0B:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $0E ; |    XXX |
       .byte $8E ; |X   XXX |
       .byte $FF ; |XXXXXXXX|
       .byte $0E ; |    XXX |
       .byte $1C ; |   XXX  |
Explosion1B:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $10 ; |   X    |
       .byte $20 ; |  X     |
       .byte $40 ; | X      |
       .byte $10 ; |   X    |
Explosion1A:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $04 ; |     X  |
       .byte $02 ; |      X |
       .byte $08 ; |    X   |
       .byte $04 ; |     X  |
       .byte $00 ; |        |
Explosion2B:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $20 ; |  X     |
       .byte $02 ; |      X |
       .byte $41 ; | X     X|
       .byte $20 ; |  X     |
       .byte $02 ; |      X |
       .byte $04 ; |     X  |
Explosion2A:
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $04 ; |     X  |
       .byte $88 ; |X   X   |
       .byte $10 ; |   X    |
       .byte $04 ; |     X  |
       .byte $80 ; |X       |
       .byte $10 ; |   X    |
       .byte $00 ; |        |
       .byte $00 ; |        |
HouseB:
       .byte $00 ; |        |
       .byte $04 ; |     X  |
       .byte $1F ; |   XXXXX|
       .byte $0E ; |    XXX |
       .byte $04 ; |     X  |
       .byte $04 ; |     X  |
       .byte $00 ; |        |
       .byte $AA ; |X X X X |
       .byte $FE ; |XXXXXXX |
       .byte $7C ; | XXXXX  |
       .byte $00 ; |        |
HouseA:
       .byte $00 ; |        |
       .byte $04 ; |     X  |
       .byte $0E ; |    XXX |
       .byte $1F ; |   XXXXX|
       .byte $0E ; |    XXX |
       .byte $04 ; |     X  |
       .byte $00 ; |        |
       .byte $FE ; |XXXXXXX |
       .byte $AA ; |X X X X |
       .byte $FE ; |XXXXXXX |
       .byte $38 ; |  XXX   |
       .byte $00 ; |        |
       .byte $00 ; |        |
       .byte $00 ; |        |


;===============================================================================
; R O M - C O D E (Part 4)
;===============================================================================

GetPageFlag SUBROUTINE
; get bit 0 of the page for the playfield data:
       TXA                      ;2
       BEQ    .exit             ;2
       LDA    #%0               ;2
       CPX    #SWITCH_PAGE_ID   ;2              PF id < 9
       BCS    .exit             ;2               no, read data from page $FC
       LDA    #%1               ;2               yes, read data from page $FD
.exit:
       RTS                      ;6

SetScorePtrs SUBROUTINE
       STA    scorePtr1+10      ;3
       STA    scorePtr2+10      ;3

; let score-pointers point to 'Space' to avoid leading zeros:
       LDA    #<Space           ;2
       LDX    #8                ;2
.loopScorePtr2:
       STA    scorePtr2,X       ;4
       DEX                      ;2
       DEX                      ;2
       BPL    .loopScorePtr2    ;2

       LDX    #8                ;2
SetScorePtr1:
       STA    scorePtr1,X       ;4
       DEX                      ;2
       DEX                      ;2
       BPL    SetScorePtr1      ;2
       RTS                      ;6


;===============================================================================
; R O M - T A B L E S (Part 4)
;===============================================================================

ColorPtrTab:
       .byte $49                ; explosion 0   (no extra data for explosion colors)
       .byte $2A                ; explosion 1
       .byte $66                ; explosion 2
       .byte $2A                ; explosion 3
       .byte <PlaneCol-6        ; plane
       .byte <HelicopterCol-4   ; helicopter
       .byte <HelicopterCol-4   ; helicopter
       .byte <ShipCol-4         ; ship
       .byte <BridgeCol-1       ; bridge
       .byte <HouseCol-2        ; house         (one byte shared!)
       .byte <FuelCol-1         ; fuel          (=$37)

HouseCol:
       .byte BROWN, LIGHT_GREEN, LIGHT_GREEN, LIGHT_GREEN, LIGHT_GREEN
       .byte BLACK, LIGHT_GREY, LIGHT_GREY, BLACK, BLACK
FuelCol:
       .byte LIGHT_GREY, LIGHT_GREY, LIGHT_GREY, RED, RED, RED
       .byte LIGHT_GREY, LIGHT_GREY, LIGHT_GREY, RED, RED, RED
HelicopterCol:
       .byte CYAN, CYAN, DARK_BLUE, CYAN, ORANGE, ORANGE
  IF NTSC
PlaneCol:
       .byte $AC, $9C, $8C
ShipCol:
       .byte $A8, $32, BLACK, BLACK
BridgeCol:
       .byte $20, $14, $12, $14, $12, $18, $12, $14, $12, $14, $20
  ELSE
PlaneCol:
       .byte $BC, $BC, $9C
ShipCol:
       .byte $98, $42, BLACK, BLACK
BridgeCol:
       .byte $20, $24, $22, $24, $22, $28, $22, $24, $22, $24, $20
       .byte $B4        ; unused
  ENDIF


;===============================================================================
; R O M - C O D E (Part 5)
;===============================================================================

LooseJet SUBROUTINE
; called when player looses a life:
       STY    sound0Cnt         ; 3
       STA    sound0Id          ; 3
       LDA    blockLst          ; 3
       EOR    blockLstEnd       ; 3
       AND    #PF_COLOR_FLAG    ; 2             dark section?
       BEQ    .skipRestartLevel ; 2              yes, skip
       LDA    sectionEnd        ; 3             end of section?
       BEQ    .isEnd            ; 2              yes, check restart of level
       BIT    blockLstEnd       ; 3             road in new block?
       BPL    .skipRestartLevel ; 2              no, skip
       JSR    SaveSection       ; 6              yes, goto next section
       BNE    .skipRestartLevel ; 3

.isEnd:
       BIT    blockLstEnd       ; 3             PF_ROAD_FLAG set?
       BMI    .skipRestartLevel ; 2              yes, skip restart level
; restart level:
       LDX    level             ; 3             limit level to 48
       DEX                      ; 2
       CPX    #MAX_LEVEL-2      ; 2
       BNE    .skipLimit        ; 2
       LDX    #MAX_LEVEL        ; 2
.skipLimit:
       STX    level             ; 3
       LDA    randomLoSave2     ; 3             retrieve saved random values
       STA    randomLoSave      ; 3
       LDA    randomHiSave2     ; 3
       STA    randomHiSave      ; 3
.skipRestartLevel:
       LDA    #<JetExplode-1    ; 2
       STA    shapePtr0         ; 3
.contFinish:
       STA    gameMode          ; 3
       LDA    #NUM_LINES+20     ; 2             disable missile
       STA    missileY          ; 3
       RTS                      ; 6

FinishGame:
; called when the the game is not running:
       LDA    #$FF              ; 2             disable al animations
       STA    frameCnt          ; 3
       BNE    .contFinish       ; 3

  IF NTSC
FinishDigits SUBROUTINE
       INY                      ; 2
       STA    WSYNC             ; 3
       STA    HMOVE             ; 3
       STY    GRP1              ; 3
       STY    GRP0              ; 3
       STY    GRP1              ; 3
       LDY    #14               ; 2             load line counter
SetColPx:
       STA    COLUP0            ; 3
       STA    COLUP1            ; 3
DoHMove:
       STA    WSYNC             ; 3
       STA    HMOVE             ; 3
       RTS                      ; 6
  ELSE
LoadPFPattern SUBROUTINE
       BIT    PF_State          ; 3             ISLAND_FLAG set?
       BPL    .contPage1        ; 2              no, set current page-flag
       TAY                      ; 2              yes, read new page-flag from table
       LDA    PageFlagTab,Y     ; 4
.contPage1:
       ORA    blockLstEnd       ; 3
       STA    blockLstEnd       ; 3
       LDA    BankPtrTab,X    ; 4
       CLC                      ; 2
       ADC    diffPF            ; 3             adjust with difference between new and prev PF id
       STA    PF2LstEnd         ; 3
       RTS                      ; 6
  ENDIF


;===============================================================================
; R O M - T A B L E S (Part 5)
;===============================================================================

RoadColorTab:
       .byte $04, $04, $08, $08, $08, $08, YELLOW, $08, $08, $08, $08   ; next two bytes are shared
VolumeTab:
       .byte $04, $04                                                   ; next byte ($07) is shared
EnemyIdTab:
       .byte ID_SHIP, ID_HELI0, ID_SHIP, ID_HELI0, ID_PLANE, ID_SHIP, ID_HELI0, ID_HELI0

shapePtr1aTab:
       .byte <Explosion0-1, <Explosion1A-1, <Explosion2A-1, <Explosion1A-1
       .byte <PlaneA-1, <Heli0A-1, <Heli1A-1, <ShipA-1, <BridgeA-1, <HouseA-1, <FuelA-1


;===============================================================================
; R O M - C O D E (Part 6)
;===============================================================================

SwapPlayers SUBROUTINE
; swaps player variable blocks in two player game:
       LDA    gameVariation     ;3              don't swap in one player game
       BEQ    .skipSwap         ;2
       EOR    player            ;3              change player
       STA    player            ;3

       LDX    #3                ;2
.loopSwap0:
       LDA    player1State,X    ;4
       LDY    player2State,X    ;4
       STA    player2State,X    ;4
       STY    player1State,X    ;4
       DEX                      ;2
       BPL    .loopSwap0        ;2

       LDX    #12-2             ;2
.loopSwap1:
       LDA    scorePtr1,X       ;4
       LDY    scorePtr2,X       ;4
       STA    scorePtr2,X       ;4
       STY    scorePtr1,X       ;4
       DEX                      ;2
       DEX                      ;2
       BPL    .loopSwap1        ;2
.skipSwap:
       RTS                      ;6


;===============================================================================
; R O M - T A B L E S (Part 6)
;===============================================================================

ColorTab:
       .byte 0, YELLOW, GREY, YELLOW+2, BLUE

       .word START
       .word 0
