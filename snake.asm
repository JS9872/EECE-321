    # ------------------------------------------------------------
    # RARS Snake Game (wrap‑around) with WASD, hard‑coded MMIO
    # ------------------------------------------------------------

    .globl main
main:
    # ----------------------------------------
    # 0) Setup constants & registers
    # ----------------------------------------
    mv    s2, gp          # FB_BASE = 0x10008000
    li    s0, 256         # FULL_WIDTH (pixels)
    li    s1, 16          # CELL_PX
    li    s5, 2           # SEGMENTS (head + 1 body)
    li    s6, 1           # WIDTH_IN_CELLS
    li    s7, 1           # HEIGHT_IN_CELLS
    mul   s8, s6, s1      # SEG_W_PX
    mul   s9, s7, s1      # SEG_H_PX

    li    s10, 4          # START_X (cell)
    li    s11, 6          # START_Y (cell)

    # Colors
    li    s3, 255         # BG = bright green (0x00_00_FF_00)
    slli  s3, s3, 8
    li    a0, 255         # HEAD = bright purple (0x00_FF_00_FF)
    slli  a0, a0, 16
    ori   a0, a0, 255
    li    a1, 127         # BODY = dark purple (0x00_7F_00_7F)
    slli  a1, a1, 16
    ori   a1, a1, 127

    li    a2, 0           # dir = 0 (▶)

    # ----------------------------------------
    # 1) Draw solid background
    # ----------------------------------------
    li    t1, 0
Y_LOOP:
    bge   t1, s0, DRAW_SNAKE
    li    t2, 0
X_LOOP:
    bge   t2, s0, NEXT_ROW
    mv    t3, s3
STORE_BG:
    mul   t5, t1, s0
    add   t5, t5, t2
    slli  t5, t5, 2
    add   t5, t5, s2
    sw    t3, 0(t5)
    addi  t2, t2, 1
    j     X_LOOP
NEXT_ROW:
    addi  t1, t1, 1
    j     Y_LOOP

# ----------------------------------------
# 2) Draw Initial Snake (head + body)
# ----------------------------------------
DRAW_SNAKE:
    li    t6, 0
SEG_LOOP:
    bge   t6, s5, START_GAME
    beqz  t6, HEAD_COLOR
    mv    t3, a1
    j     DO_DRAW
HEAD_COLOR:
    mv    t3, a0
DO_DRAW:
    jal   ra, DRAW_SEGMENTS
    addi  t6, t6, 1
    j     SEG_LOOP

# ----------------------------------------
# 3) Main Game Loop
# ----------------------------------------
START_GAME:
MOVEMENT_LOOP:
    # -- a) Poll keyboard (non‑blocking) --
    li    t0, 0xFFFF0000   # KBD_STATUS MMIO base
    lb    t1, 0(t0)
    beqz  t1, SKIP_INPUT
    li    t0, 0xFFFF0004    # KBD_DATA MMIO base
    lb    t1, 0(t0)
    # decode WASD
    li    t2, 'W'
    beq   t1, t2, SET_UP
    li    t2, 'S'
    beq   t1, t2, SET_DOWN
    li    t2, 'A'
    beq   t1, t2, SET_LEFT
    li    t2, 'D'
    beq   t1, t2, SET_RIGHT
    j     SKIP_INPUT
SET_UP:
    li    a2, 1
    j     SKIP_INPUT
SET_DOWN:
    li    a2, 2
    j     SKIP_INPUT
SET_LEFT:
    li    a2, 3
    j     SKIP_INPUT
SET_RIGHT:
    li    a2, 0
SKIP_INPUT:

    # -- b) Clear previous snake segments --
    li    t6, 0
CLEAR_SEGMENTS:
    bge   t6, s5, UPDATE_POS
    mv    t3, s3
    jal   ra, DRAW_SEGMENTS
    addi  t6, t6, 1
    j     CLEAR_SEGMENTS

    # -- c) Update head position based on direction in a2 --
UPDATE_POS:
    li    t0, 0
    beq   a2, t0, DIR_RIGHT
    li    t0, 1
    beq   a2, t0, DIR_UP
    li    t0, 2
    beq   a2, t0, DIR_DOWN
    # else → left
    j     DIR_LEFT

DIR_RIGHT:
    addi  s10, s10, 1
    j     WRAP_POS
DIR_UP:
    addi  s11, s11, -1
    j     WRAP_POS
DIR_DOWN:
    addi  s11, s11, 1
    j     WRAP_POS
DIR_LEFT:
    addi  s10, s10, -1

WRAP_POS:
    # wrap X into [0..15]
    li    t0, 16
    blt   s10, t0, WRAP_Y
    li    s10, 0
WRAP_Y:
    li    t0, 0
    bge   s10, t0, CHECK_Y_NEG
    li    s10, 15
CHECK_Y_NEG:
    # wrap Y into [0..15]
    li    t0, 16
    blt   s11, t0, REDRAW
    li    s11, 0
REDRAW:

    # -- d) Draw snake at new position --
    li    t6, 0
REDRAW_SEGMENTS:
    bge   t6, s5, DELAY
    beqz  t6, RED_HEAD
    mv    t3, a1
    j     RED_DRAW
RED_HEAD:
    mv    t3, a0
RED_DRAW:
    jal   ra, DRAW_SEGMENTS
    addi  t6, t6, 1
    j     REDRAW_SEGMENTS

    # -- e) Simple delay (~1s) --
DELAY:
    li    t5, 80000
WAIT:
    addi  t5, t5, -1
    bnez  t5, WAIT
    j     MOVEMENT_LOOP

# ----------------------------------------
# 4) DRAW_SEGMENTS subroutine
#    Draw a single 16×16 block at (s10,s11) offset by t6
# ----------------------------------------
DRAW_SEGMENTS:
    mul   t0, t6, s6
    add   t0, t0, s10
    mul   t0, t0, s1

    mul   t1, s11, s1
    mul   t1, t1, s0

    li    t2, 0
DRAW_DY_LOOP:
    bge   t2, s9, END_SEG
    li    t4, 0
DRAW_DX_LOOP:
    bge   t4, s8, NEXT_Y
    mul   t5, t2, s0
    add   t5, t5, t1
    add   t5, t5, t0
    add   t5, t5, t4
    slli  t5, t5, 2
    add   t5, t5, s2
    sw    t3, 0(t5)
    addi  t4, t4, 1
    j     DRAW_DX_LOOP
NEXT_Y:
    addi  t2, t2, 1
    j     DRAW_DY_LOOP
END_SEG:
    jr    ra

# ----------------------------------------
# 5) Exit (never reached)
# ----------------------------------------
EXIT:
    li    a7, 10
    ecall
