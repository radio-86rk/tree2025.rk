;  #############################################################################
;  ##  Новогодняя ёлка                                                        ##
;  #############################################################################
;
;  Author:   Vitaliy Poedinok aka Vital72
;  License:  MIT
;  www:      http://www.86rk.ru/
;  e-mail:   vital72@86rk.ru
;  Version:  1.0
;  Original: https://github.com/sergiolepore/ChristBASHTree
; ==============================================================================

ADDR_CRT_RK		EQU	0C000h
ADDR_DMA_RK		EQU	0E000h
ADDR_CRT_RK60		EQU	0F600h
ADDR_DMA_RK60		EQU	0F700h
ADDR_CRT_APOGEY		EQU	0EF00h
ADDR_DMA_APOGEY		EQU	0F000h

COLD_START		EQU	0F800h
IN_CHAR			EQU	0F803h
IN_KEY			EQU	0F81Bh
OUT_STR			EQU	0F818h

;  эффективкная частота CPU в килогерцах при стандартных настройках
CPU_CLOCK		EQU	1251

;  размер видимой части экрана в символах
SCR_VIDEO_SIZE_X	EQU	64	;  по X
SCR_VIDEO_SIZE_Y	EQU	25	;  по Y
;  полный размер экрана, включающий бланкирующие зоны, в символах
SCR_SIZE_X		EQU	78	;  по X
SCR_SIZE_Y		EQU	30	;  по Y
SCR_ARRAY		EQU	SCR_SIZE_X * SCR_SIZE_Y
; отступ левого верхнего угла видимой части экрана, в символах
SCR_PAD_X		EQU	8	;  по горизонтали
SCR_PAD_Y		EQU	3	;  по вертикали

;  параметры настройки контроллера CRT
CRT_PIXEL_CLOCK		EQU	8000	;  kHz
CRT_CHAR_WIDTH		EQU	6	;  ширина символа, пикселы
CRT_HORIZ_TIME		EQU	64	;  длительность строки, мкс
CRT_SPACED_ROWS		EQU	0	;  spaced row [0, 1]
CRT_VERT_ROW_COUNT	EQU	1	;  vertical retrace row count [1, 2, 3, 4]
CRT_UNDERLINE		EQU	10	;  underline placement [1..16]
CRT_LINES_PER_ROW	EQU	10	;  number of lines per character row [1..16]
CRT_LINE_OFFSET		EQU	1	;  line counter mode [0, 1]
CRT_NON_TRANSP_ATTR	EQU	0	;  field attribute mode [0, 1]
CRT_HORIZONTAL_COUNT	EQU	8	;  horizontal retrace count [2, 4, 6, .. 32]
CRT_BURST_SPACE_CODE	EQU	1	;  [0..7]
CRT_BURST_COUNT_CODE	EQU	3	;  [0..3]
CRT_ZZZZ		EQU	((CRT_HORIZ_TIME * CRT_PIXEL_CLOCK / 1000 / CRT_CHAR_WIDTH - SCR_SIZE_X + 1) >> 1) - 1

;  коды атрибутов 8275 для вывода цветного изображения
ATTR_COLOR_BLACK	EQU	8Dh
ATTR_COLOR_RED		EQU	8Ch
ATTR_COLOR_GREEN	EQU	85h
ATTR_COLOR_YELLOW	EQU	84h
ATTR_COLOR_BLUE		EQU	89h
ATTR_COLOR_MAGENTA	EQU	88h
ATTR_COLOR_CYAN		EQU	81h
ATTR_COLOR_WHITE	EQU	80h

; ==============================================================================

	.org	0
	jmp	start

tree_char:
	db	'*'			;  символ, которым рисуется ёлка
lamp_char:
	db	1Eh			;  символ, которым рисуется лампочка
tree_pos_y:
	db	3			;  позция ёлки по вертикали
tree_size:
	db	24			;  максимальный размер веток ёлки
garland_delay:
	db	50			;  задержка при переключении ламп гирлянды, мс
garland_size:
	db	35			;  размер гирлянды

start:
	;  определение конфигурации компьютера
	lxi	h, 0
	dad	sp
	shld	save_sp

	mvi	c, (cfg_data_end - cfg_data) / 2 / 4
	lxi	h, cfg_data
	sphl
	jmp	cfg_loop_cont + 2
cfg_loop1:
	dcr	c
	jnz	cfg_loop_cont
	lhld	save_sp
	sphl
	lxi	h, stop_str
	call	OUT_STR
	call	IN_CHAR
	jmp	COLD_START

stop_str:
	db	"ne udalosx opredelitx konfiguraci`\r\n", 0

cfg_loop_cont:
	pop	d
	pop	d
	pop	d
	pop	h
	shld	$+4
	lhld	0
	dad	d
	mov	a, h
	ora	l
	jnz	cfg_loop1

	pop	h
	shld	cfg_addr_crt
	pop	h
	shld	cfg_addr_dma
	lhld	save_sp
	sphl

	;  очистка экрана
	lxi	h, screen
	lxi	b, SCR_ARRAY
	mvi	m, 0
	inx	h
	dcx	b
	mov	a, c
	ora	b
	jnz	$-6
	;  код прекращения ПДП в последнем символе каждого знакоряда
	lxi	d, SCR_SIZE_X
	lxi	h, screen + SCR_SIZE_X - 1
	mvi	a, SCR_SIZE_Y
	mvi	m, 0F1h
	dad	d
	dcr	a
	jnz	$-4
	;  настройка контроллера дисплея на прозрачные атрибуты
	call	init_video

	;  выключение курсора
	lxi	b, 0FFFFh
	call	cursor_pos

	;  рисование ёлки
	lda	tree_char
	mov	c, a		;  символ, которым рисуется ёлка
	mvi	b, 1		;  длина веток
	mvi	e, SCR_VIDEO_SIZE_X / 2
	lda	tree_pos_y	
	mov	d, a
tree_loop:
	call	scr_addr
	mov	a, b
	mvi	m, ATTR_COLOR_GREEN
	inx	h
	mov	m, c
	inx	h
	dcr	a
	jnz	$-6
	dcr	e		;  dec x
	inr	d		;  inc y
	inr	b		;  inc size
	inr	b		;  inc size
	lda	tree_size
	cmp	b
	jnc	tree_loop
	;  ствол
	mvi	e, SCR_VIDEO_SIZE_X / 2 - 1
	mvi	c, ATTR_COLOR_YELLOW
	lxi	h, tree_trunk
	call	out_color_str_xy
	inr	d
	lxi	h, tree_trunk
	call	out_color_str_xy
	;  текст
	mvi	e, (SCR_VIDEO_SIZE_X - (happy_new_year_str_end - happy_new_year_str - 1)) / 2 + 1
	inr	d
	mvi	c, ATTR_COLOR_MAGENTA
	lxi	h, happy_new_year_str
	call	out_color_str_xy

	;  гирлянда
	lxi	h, garland
	lda	garland_size
	add	a
	mvi	m, 0
	dcr	a
	jnz	$-3
	sta	garland_flag

	xra	a
garland_loop:
	sta	garland_iter
	lda	garland_flag
	ana	a
	jz	garland_loop_lbl1
	lxi	h, garland
	lda	garland_iter
	mov	c, a
	mvi	b, 0
	dad	b
	dad	b
	mov	e, m
	inx	h
	mov	d, m
	mov	a, e
	ora	d
	jz	garland_loop_lbl1
	;  гасится лампочка
	xchg
	mvi	m, ATTR_COLOR_GREEN
	inx	h
	lda	tree_char
	mov	m, a
	xra	a
	stax	d
	dcx	d
	stax	d

garland_loop_lbl1:
	lda	tree_size
	rrc
	dcr	a
	mov	e, a
	call	rand
	call	div_a_e
	push	h
	mov	e, h
	inr	e
	call	rand
	call	div_a_e
	mvi	a, SCR_VIDEO_SIZE_X / 2
	add	h
	add	h
	add	h
	add	h
	pop	h
	sub	h
	inr	a
	mov	e, a		; x
	lda	tree_pos_y
	add	h
	inr	a
	mov	d, a		; y
	;  зажигается лампочка
	lxi	h, colors_set
	lda	color
	add	l
	mov	l, a
	adc	h
	sub	l
	mov	h, a
	mov	c, m
	call	scr_addr
	mov	m, c
	inx	h
	lda	lamp_char
	mov	m, a
	dcx	h
	;
	lda	garland_delay
	mov	c, a
garland_delay_loop:
	;  1 такт(мкс) = 1000 / CPU_CLOCK(кГц)
	;  количество тактов для 1мкс = CPU_CLOCK(кГц) / 1000
	;  для задержки в 1мс количество итераций = 1000 * (к.т.1мкс) / 20
	mvi	a, (1000 * CPU_CLOCK / 1000) / 20
	mov	a, a			;  (5)
	dcr	a			;  (5)
	jnz	$-2			;  (10)
	dcr	c
	jnz	garland_delay_loop
	;
	lda	color
	inr	a
	cpi	colors_set_end - colors_set
	jc	$+4
	xra	a
	sta	color

	xchg
	lxi	h, garland
	lda	garland_iter
	mov	c, a
	mvi	b, 0
	dad	b
	dad	b
	mov	m, e
	inx	h
	mov	m, d
	lda	garland_size
	mov	b, a
	mov	a, c
	inr	a
	cmp	b
	jc	garland_loop

	lda	garland_flag
	xri	1
	sta	garland_flag

	jmp	garland_loop - 1

;  =============================================================================

;  ВЫВОД ЦВЕТНОЙ СТРОКИ ПО КООРДИНАТАМ  ________________________________________
;  Вход:  D  - координата Y
;         E  - координата X
;         C  - цвет
;         HL - адрес сроки
out_color_str_xy:
	push	d
	push	h
	call	scr_addr
	pop	d
	mov	m, c
out_color_str_xy_loop:
	inx	h
	ldax	d
	inx	d
	mov	m, a
	ana	a
	jnz	out_color_str_xy_loop
	pop	d
	ret

;  ВЫЧИСЛЕНИЕ ЭКРАННОГО АДРЕСА ПО КООРДИНАТАМ  _________________________________
;  Вход:  D  - координата Y
;         E  - координата X
;  Выход: HL - адрес экранной памяти
scr_addr:
	push	b
	mvi	h, 0
	mov	l, d
	mov	b, h
	mov	c, d
	dad	h		;  y * 2
	dad	h		;  y * 4
	dad	h		;  y * 8
	dad	b		;  y * 9
	dad	h		;  y * 18
	dad	b		;  y * 19
	dad	h		;  y * 38
	dad	b		;  y * 39
	dad	h		;  y * 78
	mov	c, e		;  BC = POS_X
	dad	b
	lxi	b, screen + SCR_SIZE_X * SCR_PAD_Y + SCR_PAD_X
	dad	b
	pop	b
	ret

;  ГПСЧ  _______________________________________________________________________
;  Выход: A - случайное число в диапазоне [0..255]
;  примечание: все регистры сохраняются
rand:
	push	b
	push	h
	lxi	h, rand_data
	inr	m		;  x
	mov	c, m		;  x
	inx	h		;  a
	mov	a, m		;  a
	inx	h		;  b
	mov	b, m		;  b
	inx	h		;  c
	xra	m		;  c
	xra	c		;  x
	mov	c, a		;  a
	add	b		;  b
	mov	b, a		;  b
	rrc
	add	m		;  c
	xra	c		;  a
	mov	m, a		;  c
	dcx	h		;  b
	mov	m, b		;  b
	dcx	h		;  a
	mov	m, c		;  a
	pop	h
	pop	b
	ret

;  ДЕЛЕНИЕ БЕЗ ЗНАКА 8:8=(8,8)  ________________________________________________
;  Вход:  A  - делимое
;         E  - делитель
;  Выход: L  - частное
;         H  - остаток
div_a_e:
	mov	l, a
	mvi	h, 0
	mvi	d, 8
div_a_e_loop:
	dad	h
	mov	a, h
	sub	e
	jc	$+5
	mov	h, a
	inr	l
	dcr	d
	jnz	div_a_e_loop
	ret

;  ИНИЦИАЛИЗАЦИЯ КОНТРОЛЛЕРОВ  _________________________________________________
init_video:
	push	h
	lhld	cfg_addr_crt
	inx	h
	mvi	m, 0			;  команда "сброс"
	dcx	h

	;  компоновка кадра: загружаются 4 байта в регистр параметров
	;  1. SHHHHHHH
	;     S        - знакоряды:
	;                0 - нормальные знакоряды
	;                1 - чередующиеся знакоряды
	;      HHHHHHH - число знаков в знакоряду минус один (от 1 до 80)
	mvi	m, (SCR_SIZE_X - 1) | (CRT_SPACED_ROWS << 7)

	;  2. VVRRRRRR
	;     VV       - длительность обратного хода кадровой развертки
	;                00 - 1 знакоряд
	;                01 - 2 знакоряда
	;                10 - 3 знакоряда
	;                11 - 4 знакоряда
	;       RRRRRR - число знакорядов в кадре минус один (от 1 до 64):
	mvi	m, (SCR_SIZE_Y - 1) | ((CRT_VERT_ROW_COUNT - 1) << 6)

	;  3. UUUULLLL
	;     UUUU     - номер строки подчеркивания в знакоряду, старший бит
	;                определяет гашение верхней и нижней строк растра в
	;                знакоряду, если UUUU = 1xxx, то строки гасятся
	;         LLLL - число строк растра в знакоряду (от 1 до 16)
	mvi	m, ((CRT_UNDERLINE - 1) << 4) | (CRT_LINES_PER_ROW - 1)

	;  4. MFCCZZZZ
	;     M        - режим счетчика строк:
	;                0 - не сдвинуто
	;                1 - смещено на 1 счет
	;                подробно на стр. 125
	;      F       - режим атрибутов поля:
	;                0 - прозрачный
	;                1 - непрозрачный
	;       CC     - тип курсора:
	;                00 - мерцающий негативный видеоблок
	;                01 - мерцающие подчеркивание
	;                10 - немерцающий негативный видеоблок
	;                11 - немерцающее подчеркивание
	;         ZZZZ - число знаков при обратном ходе строчной
	;                развертки (2, 4, 6, ..., 32): (3 + 1) * 2 = 8
	mvi	m, (CRT_LINE_OFFSET << 7) | (CRT_NON_TRANSP_ATTR << 6) | (01b << 4) | CRT_ZZZZ
	inx	h			;  HL = адрес регистра команд CRT

	;  001SSSBB - команда "начало воспроизведения"
	;     SSS   - интервал между пакетами, число синхроимпульсов
	;             знака между пакетными запросами ПДП:
	;             000 = 0
	;             001 = 7
	;             010 = 15
	;             011 = 23
	;             100 = 31
	;             101 = 39
	;             110 = 47
	;             111 = 55
	;        BB - число запросов ПДП в пакете:
	;             00 = 1
	;             01 = 2
	;             10 = 4
	;             11 = 8
	mvi	m, 00100000b | (CRT_BURST_SPACE_CODE << 2) | CRT_BURST_COUNT_CODE
	mov	a, m			;  сброс регистра флагов
	mov	a, m			;  чтение слова состояния
	ani	20h			;  нужен флаг IR - запрос прерывания
	jz	$-3			;  ждём установленного IR

	lhld	cfg_addr_dma
	mvi	l, 08h			;  адрес регистра режимов ПДП
	mvi	m, 10000000b		;  запрет ПДП
	mvi	l, 04h			;  адрес регистра адреса канала 2 ПДП
	mvi	m, low (screen)		;  младший адрес памяти
	mvi	m, high (screen)	;  старший адрес памяти
	inr	l			;  адрес регистра количества циклов ПДП канала 2

	;  16 бит = RWCCCCCC CCCCCCCC
	;  CCCCCC CCCCCCCC - количество циклов
	;  RW = 00 - цикл проверки ПД
	;  RW = 01 - цикл записи ПД
	;  RW = 10 - цикл чтения ПД
	;  RW = 11 - запрещенная комбинация
	;  младший байт счётчика циклов (биты C7-C0)
	mvi	m, low (SCR_ARRAY - 1)
	;  старший байт счётчика циклов (биты C13-C8)
	mvi	m, high (SCR_ARRAY - 1) | (01b << 6)
	mvi	l, 08h			;  адрес регистра режимов ПДП

	;  D7 [AL]  = 1 - автозагрузка
	;  D6 [TCS] = 0 - КС-стоп
	;  D5 [EW]  = 1 - удлиненная запись
	;  D4 [RP]  = 0 - циклический сдвиг
	;  D3 [EN3] = 0 - разрешение канала 3
	;  D2 [EN2] = 1 - разрешение канала 2
	;  D1 [EN1] = 0 - разрешение канала 1
	;  D0 [EN0] = 0 - разрешение канала 0
	mvi	m, 10100100b		;  установка режима

	;  здесь начинаются циклы ПДП
	pop	h
	ret

;  _____________________________________________________________________________
;  BC - координаты курсора
cursor_pos:
	lhld	cfg_addr_crt
	inx	h
	mvi	m, 80h			;  команда "загрузка курсора"
	dcx	h
	mov	m, c
	mov	m, b
	ret

;  =============================================================================

cfg_data:
cfg_rk:
	dw	-076CFh
	dw	0F83Ch
	dw	ADDR_CRT_RK
	dw	ADDR_DMA_RK
cfg_rk_nova:
	dw	-076CFh
	dw	0F84Ah
	dw	ADDR_CRT_RK
	dw	ADDR_DMA_RK
cfg_rk60:
	dw	-0E6D0h
	dw	0F852h
	dw	ADDR_CRT_RK60
	dw	ADDR_DMA_RK60
cfg_apogey:
	dw	-0E1CFh
	dw	0F83Ch
	dw	ADDR_CRT_APOGEY
	dw	ADDR_DMA_APOGEY
cfg_data_end:

cfg_addr_crt:
	dw	0
cfg_addr_dma:
	dw	0
save_sp:
	dw	0
rand_data:
	db	1, 2, 3, 4

tree_trunk:
	db	"MWM", 0
happy_new_year_str:
	db	"s nowym 2025 godom!", 0
happy_new_year_str_end:

garland_iter:
	db	0
garland_flag:
	db	0
color:
	db	0
colors_set:
	db	ATTR_COLOR_RED, ATTR_COLOR_GREEN, ATTR_COLOR_YELLOW, ATTR_COLOR_BLUE
	db	ATTR_COLOR_MAGENTA, ATTR_COLOR_CYAN, ATTR_COLOR_WHITE
colors_set_end:

screen:
	ds	SCR_ARRAY

garland:
	ds	0

;  =============================================================================
;  end of file  ================================================================
