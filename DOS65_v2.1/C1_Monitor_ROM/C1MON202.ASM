;osi c1p monitor rom for dos/65
;released:	17 september 1983
;last revision:	27 july 1986
;			reworked video
;			reduced step rate
;			added printer port init
;			added message output
;			moved disk pia init
;			altered page zero assignments
;		1 August 2015
;			added semicolons for all comments
;			changed sectors to records
;			changed associated record parms
;			made all jump and branch targets explicit
;			added notes about SPEED
;			changed keyboard address to $DF00
;base addresses
wbtjmp	=	$100		;warm boot entry
pemjmp	=	$103		;pem entry
iostat	=	$106		;io status byte
dflbuf	=	$128		;default buffer
trkbuf	=	$200		;whole track buffer
;OSI addresses and parameters
;video output related
frspge	=	$d000		;start of video ram
lstpge	=	$d300		;last page in video ram
scrpgs	=	8		;pages in screen
screen	=	$d385		;prompt location
scrcnt	=	$d800		;control port for video
;following values change as a function of display size
;variable	24x24	12x48
;vidlmt		$7d	$7b
;vidfrs		$65	$4b
;vidmsk		$1f	$3f
;vidmxi		$1d	$3b
;vidmni		4	10
;vidlns		24	12
;vidchr		24	48
;vidmde		0	1
;vidprm		$d3a5	$d38b
;vidmve		32	64
vidlmt	=	$7b		;max+1 video index
vidfrs	=	$4b		;first video index
vidmsk	=	$3f		;mask for index
vidmxi	=	$3b		;max+1 of index
vidmni	=	10		;min-1 of index
vidlns	=	12		;lines per screen
vidchr	=	48		;char per line
vidmde	=	1		;12x48 mode
vidprm	=	$d38b		;flag location
vidmve	=	64		;amount to move
;keyboard related
keybd	=	$df00		;keyboard array
;printer (or other use) acia
prnter	=	$f001		;printer port
;disk i/o related
numtrk	=	40		;number of tracks
recrds	=	16		;dos/65 records per track
tries	=	20		;retry limit
stprte	=	5		;disk step rate
;pia
;read only
flpsts	=	$c000		;status port
;bit definitions
; 0
; 1	track 0 if 0
; 2
; 3
; 4
; 5	write protect if 0
; 6	drive select 1 (0=B or D, 1=A or C)
; 7	index if 0
;write only
flpcnt	=	flpsts+2
;bit definitions
; 0	write enable if 0
; 1
; 2	step
;	  0 if in
;	  1 if out (to track zero)
; 3	step on falling edge
; 4
; 5	drive select 2 (0=C or D, 1=A or B)
; 6
; 7	head load if 0
;acia
flpdta	=	$c011		;data port
;parameters
cr	=	$d		;return
lf	=	$a		;line feed
bs	=	8		;backspace
fs	=	$1c		;forward space
clreol	=	5		;clear to end of line
;page zero variable definitions
;page zero data initialized by boot sector on disk
*	=	$00
ldeadr	*=	*+2		;load address
sclptr	=	ldeadr		;just used for screen clear
simadr	*=	*+2		;sim entry address
reclde	*=	*+1		;records to load
sectrk	*=	*+1		;records per track
nxtsec	*=	*+1		;next sector to read
;page zero areas used by monitor
*	=	$dc
;monitor only
point	*=	*+2		;pointer
in	*=	*+2		;input buffer
;this first region is shared by several routines
;but is mainly for transient storage for the keyboard handler
ctlrow	*=	*+8		;keyboard closures
from	=	ctlrow		;from scroll
to	=	ctlrow+2	;scroll to
msgpnt	=	ctlrow+4	;message pointer
col	*=	*+1		;current column
row	*=	*+1		;current row
bcdtrk	=	row		;bcd = curtrk
coord	*=	*+1		;current coordinates
pgecnt	=	coord		;pages in track
group	*=	*+1		;current char group
trkpnt	=	group		;read/write address for disk
tblpnt	*=	*+1		;pointer to table
;this region is for dedicated usage - do not reuse
;video
index	*=	*+1		;video index
lstchr	*=	*+1		;char under cursor
;keyboard
chrflg	*=	*+1		;waiting char
char	*=	*+1		;current char
oldchr	*=	*+1		;last char
timer1	*=	*+1		;de-bounce and
timer2	*=	*+1		;repeat timers
oldcrd	*=	*+1		;old coord
;disk related
recpnt	*=	*+2		;dos/65 buffer address
mstwrt	*=	*+1		;must write flag
errcde	*=	*+1		;disk i/o error code
;error code bit definitions
; 0	wrong track if 1
; 1	read parity error if 1
; 2	write protect if 1
nxttrk	*=	*+1		;next track for seek
curtrk	*=	*+1		;current track
;general timing constant
speed	*=	*+1		;timing constant
;interrupt vectors
nmivec	*=	*+2		;nmi vector
irqvec	*=	*+2		;irq vector
;main program
*	=	$f800		;2k eprom start
;jump vector
	jmp	const		;console status
	jmp	conin		;console input
	jmp	conot		;console output
	jmp	list		;printer output
	jmp	seldrv		;select drive in a
	jmp	home		;home selected drive
	jmp	doseek		;seek to track in a
	jmp	extrde		;read track to ay
	jmp	extwrt		;write track from ay
	jmp	msgout		;send message to console
;entry after reset
reset	ldx	#$ff		;set stack
	txs
	cld			;binary mode
;clear page zero
	inx			;set x to 0
	txa			;and clear a
clpzlp	sta	$00,x		;put zero in
	inx			;bump index
	bne	clpzlp		;loop if more
;clear screen
	ldx	#scrpgs		;pages to clear
	lda	#>frspge	;starting page
	sta	sclptr+1	;and set
	ldy	#0		;clear lower part
	sty	sclptr		;of pointer
	lda	#' '		;get space
clrslp	sta	(sclptr),y	;put space on screen
	iny			;bump index
	bne	clrslp		;loop if more
	inc	sclptr+1	;bump high pointer
	dex			;drop page count
	bne	clrslp		;loop if more
	inx			;set screen to 12x48
	stx	scrcnt
	sta	lstchr		;set char under cursor
	lda	#vidfrs		;set starting index
	sta	index
	lda	#49		;set speed
	sta	speed		;for 1 mhz
;initialize printer port to /16
	lda	#%00000011
	sta	prnter-1
	lda	#%00010001
	sta	prnter-1
;initialize disk controller pia
	lda	#%01000000
	ldy	#0
	ldx	#%00000100
	sty	flpsts+1	;ddr on a side
	sta	flpsts		;all but one are input
	stx	flpsts+1	;back to data
	sta	flpsts		;set output to high
	sty	flpcnt+1	;ddr on b side
	dey			;y to ff
	sty	flpcnt		;all are output
	stx	flpcnt+1	;back to data
	sty	flpcnt		;set all high
;send opening prompt
	lda	#<ident
	ldy	#>ident
	jsr	msgout		;send message
;monitor loop
main	jsr	crlf		;send cr and lf
	lda	#'#'		;send prompt
	jsr	prompt		;and address and data
	jsr	outsp		;then a space
	jsr	execut		;get and do command
	jmp	main		;loop for more
;fetch, decode, and execute command
execut	lda	#0		;clear buffer
	sta	in
	sta	in+1
exelpe	jsr	conin		;get key
	cmp	#'a'		;see if under a
	bcc	notlc		;it is
	cmp	#'z'+1		;see if over z
	bcs	notlc		;it is
	and	#$5f		;make uppercase
notlc	jsr	conot		;echo
	jsr	pack		;put in buffer if can
	cmp	#'G'		;see if g
	bne	notg		;it isn't
	jmp	(point)		;else execute
notg	cmp	#'O'		;see if o
	bne	noto		;it isn't
	lda	in		;set point to in
	sta	point
	lda	in+1
	sta	point+1
	rts
noto	cmp	#'S'		;see if s
	bne	nots		;it isn't
	lda	in		;get low
	ldy	#0
	sta	(point),y
noto1	beq	incpt		;then bump pointer
nots	cmp	#'N'		;see if n
	beq	noto1		;it is
	cmp	#'P'		;see if p
	beq	decpt		;if so drop
	cmp	#'Q'		;see if Q
	bne	exelpe		;loop if not
	beq	boot		;else boot
;decrement pointer by one
decpt	lda	point
	bne	nodchp
	dec	point+1
nodchp	dec	point		;always low
	rts
;increment pointer
incpt	inc	point
	bne	incpt1
	inc	point+1
incpt1	rts
;boot dos/65
;first set timer constant
boot	lda	#255		;say is quite fast
	sta	speed
;find true cpu speed
	jsr	loadhd		;load head
ind0	lda	flpsts		;get status
	bmi	ind0		;loop until index
ind1	lda	flpsts		;get again
	bpl	ind1		;loop until end of index
	ldx	#0		;clear counters
	ldy	#0
chkrev	lda	flpsts		;get again
	bpl	gotrev		;branch if index
	nop			;delay a bit
	jmp	j0		;and then some more
j0	inx
	bne	chkrev
	iny
	jmp	chkrev
gotrev	txa			;see if should round
	bpl	b1		;branch if should not
	iny			;else bump speed
b1	sty	speed		;set speed
	jsr	unldhd
	jsr	home		;home selected drive (usually 0)
	jsr	rdytrk		;get header
	bne	error		;branch if error
getv	jsr	rd1byt		;look for rest of header
	cmp	#'v'
	bne	getv		;loop until v
	jsr	rd1byt		;now get number
	cmp	#1		;if not 1
	bne	error		;is error
	jsr	rd1byt		;now get length
	cmp	#recrds/2	;see if correct
	bne	error		;error if not
;got good header
	ldx	#0		;clear index
btelpe	lda	#%00000001	;mask for ready
wteflp	bit	flpdta-1	;test acia
	beq	wteflp		;loop if not ready
	lda	flpdta		;else get byte
	bvs	error		;parity error
	sta	0,x		;else put in page zero
	inx			;bump index
	bpl	btelpe		;then loop
;got a good boot so all is initialized
;start read again
gettrk	jsr	rdetrk		;read entire track
	bcs	error		;exit if error
gottrk	jsr	strkpt		;set pointer
	ldy	#0		;now move a sector
mvesec	lda	(trkpnt),y
	sta	(ldeadr),y
	iny
	bpl	mvesec		;of 128 bytes
	clc			;add 128 to pointer
	tya
	adc	ldeadr
	sta	ldeadr
	bcc	b0
	inc	ldeadr+1
b0	dec	reclde		;drop count
	beq	alllde		;done if all loaded
	inc	nxtsec		;else bump sector
	lda	nxtsec		;get it
	cmp	sectrk		;compare to max
	beq	gottrk		;ok if equal
	bcc	gottrk		;or less
	lda	#1		;else reset
	sta	nxtsec		;sector
	jsr	stepin		;step in a track
	inc	curtrk		;bump track number
	jmp	gettrk		;and loop to read
;data all read and moved
alllde	jmp	(simadr)	;execute
;general error handler
error	jmp	unldhd		;unload head
;pack input into buffer
pack	cmp	#'0'		;see if under 0
	bcc	pack3		;is
	cmp	#'9'+1		;see if number
	bcc	pack0		;is
	cmp	#'A'		;see if not hex
	bcc	pack3		;isn't
	cmp	#'F'+1		;see if not hex
	bcs	pack3		;isn't
pack0	pha			;save char
	cmp	#'A'		;see if digit
	bcc	pack1		;it is
	adc	#8		;else convert
pack1	rol	a		;move to high
	rol	a
	rol	a
	rol	a
	ldx	#4		;shift four times
pack2	rol	a		;into c
	rol	in		;then low
	rol	in+1		;then high
	dex
	bne	pack2		;loop if more
	pla			;get char back
pack3	rts
;home drive to track zero
home	jsr	stepin		;step head in one
	jsr	dly12m		;delay 12ms
hlp	lda	#%00000010	;mask for track zero
	bit	flpsts		;test it
	bne	nthome		;continue if not there
	lda	#0		;clear current
	sta	curtrk		;track
	rts			;else done
nthome	jsr	stepot		;step out
	jmp	hlp		;and loop
;step towards track zero
stepot	lda	flpcnt		;get control
	ora	#%00000100	;set direction to out
	bne	step
;step away from track zero
stepin	lda	flpcnt		;get control
	and	#%11111011	;set direction to in
step	sta	flpcnt		;set it
	jsr	dly12		;wait 12 cycles
	and	#%11110111	;set step bit
	sta	flpcnt		;set it
	jsr	dly24		;delay 24 cycles
	ora	#%00001000	;clear bit
	sta	flpcnt		;set it
	ldx	#stprte		;get rate in ms
	jmp	dlyxm		;delay the right time
;check console status
const	jsr	getinp		;check input
	tay			;set or reset z
	sta	chrflg		;set flag
	rts
;read a char from keyboard
conin	lda	chrflg		;test flag
	ldx	#0		;now clear it
	stx	chrflg
	tay			;see if a char
	bne	conin2		;exit if is
conin1	jsr	getinp		;else get char
	tay			;test it
	beq	conin1		;loop if none
conin2	rts
;check for keyboard input
getinp	jsr	rdkey		;scan keyboard
	lda	char		;test result
	beq	noinp		;branch if no key
	cmp	oldchr		;see if same
	beq	same		;it is
noinp	ldx	#200		;init delays
	stx	timer1		;400 (200*2) msec
	ldx	#30		;and 30 msec for following
	stx	timer2		;auto repeat inputs
	rts
same	lda	timer1
	bne	dly2ms		;not timed out
	ldx	#1
	jsr	dlyxm		;delay 1 ms
	dec	timer2
	bne	same1		;not timed out
	ldx	#30		;reset
	stx	timer2
	lda	char		;get char
	rts
dly2ms	ldx	#2		;do 2 msec
	jsr	dlyxm
	dec	timer1		;then drop timer
same1	lda	#0		;no new char
	rts
;keyboard is decoded as close to a terminal keyboard
;as possible with rpt-p creating 'at sign',
;rpt-k creating 'left bracket', rpt-m
;creating 'right bracket', rpt-l creating
;'reverse slash', rpt-n creating 'up arrow',
;and shift-rpt- combinations adding four
;more characters.
;alters: a,x,y,p
rdkey	lda	char		;get last
	sta	oldchr		;and save
	lda	#%10000000
	ldy	#7
rdkey1	tax			;save pattern
	eor	#$ff		;complement
	sta	keybd		;then send to keyboard
	lda	keybd		;read rows
	eor	#$ff		;invert (makes same as C4P)
	sta	ctlrow,y	;and save
	txa
	lsr	a
	dey
	bpl	rdkey1		;loop if more
	lda	ctlrow		;get first
	and	#%00100000	;see if esc
	beq	rdkey2		;it wasn't
	lda	#$1b		;get esc code
exit1	sta	char
	lda	#0
	sta	oldcrd		;clear key coords
	rts
rdkey2	ldy	#7
nxtrow	ldx	ctlrow,y	;get row
	beq	next		;none
	cmp	#0		;check last row
	bne	nokey		;more than one
	stx	col
	sty	row
	txa
next	dey
	bne	nxtrow		;get next row
	cmp	#0
	beq	nokey		;no key found
	lda	col
	ldx	ctlrow
	bpl	rdkey3		;rpt not depressed
	and	#$7f		;mask row image
rdkey3	and	#$fe		;with $7e if rpt, $fe otherwise
	sta	col
	ldy	#7		;find column
	lda	#$80
rdkey4	cmp	col
	beq	found1		;found column
	lsr	a
	dey
	bne	rdkey4
	beq	nokey		;none found
found1	sty	col		;save column num
	lda	row		;get row number
	asl	a
	asl	a
	asl	a		;and combine
	ora	col
	sta	col		;and save
	cmp	oldcrd		;same as last
	bne	newkey		;no
	rts
newkey	sta	oldcrd		;save for next time
	lda	ctlrow
	and	#$80		;see if rpt
	ora	col
	sta	coord		;bit 7 set if rpt
	ldx	#$2e		;check if key in table1
rdkey5	lda	table1,x
	and	#$bf		;compare only coordinates
	cmp	coord		;and rpt bits
	beq	found2		;key found
	dex
	bpl	rdkey5
	lda	col		;not in table1
	ldx	#3		;check table2
rdkey6	cmp	table2,x	;for sp,cr,lf,0
	beq	found3		;got it
	dex
	bpl	rdkey6
nokey	lda	#0		;no key found
	sta	char
	sta	oldcrd
	rts
found3	lda	table3,x	;get ascii for sp,cr,lf,0
	jmp	exit1
found2	ldy	#$60
	txa			;check ascii base
	beq	rdkey8		;rpt-p
	cpx	#$1b
	bcs	rdkey7		;>Z
	lda	#0		;keys in group 0
	bpl	rdky10		;are A through Z
rdkey7	cpx	#$20
	bcs	rdkey9		;>rubout
rdkey8	lda	#1		;keys in group 1 are
	bpl	rdky10		;rpt-p,k,l,l,n, and rubout
rdkey9	lda	#2		;keys in group 2
	ldy	#$11		;are 1 through /
rdky10	sta	group
	stx	char
	stx	tblpnt
	clc
	tya
	adc	char
	sta	char		;set to no shift ascii
	lda	ctlrow
	and	#$40		;ctrl ?
	beq	rdky11		;no
	lda	group		;ctrl depressed
	cmp	#2
	beq	rdky11		;1 through / not changed
	lda	char
	sec
	sbc	#$60		;else adjust
	jmp	exit2
rdky11	ldx	tblpnt
	lda	table1,x	;get bit 6 from table
	and	#$40		;indicates reverse shift
	sta	coord		;set for rpt-p,k,l,,m,n
	lda	ctlrow		;and , - . and /
	and	#6		;shift ?
	beq	rdky12		;no
	lda	#$40
	eor	coord		;invert for above
	sta	coord
rdky12	lda	coord
	beq	rdky14		;no shift except for above
	lda	char
	ldx	group
	cpx	#2
	bne	rdky15
	sec
	sbc	#$10		;adjust for group 2
	jmp	exit2
rdky14	lda	ctlrow
	and	#1		;shift lock ?
	beq	exit3		;no got ascii so exit
	lda	group
	bne	exit3
	lda	char		;shift only a through z
rdky15	sec
	sbc	#$20
exit2	sta	char
exit3	rts
;key coordinates table is in ASCII base order
; bits 0-2 = column #
; bits 3-5 = row #
; bit 6    = reverse shift action when set
; bit 7    = set for rpt-p,k,l,m,n
table1	.byt	$c9,$0e,$14,$16,$1e,$26,$1d,$1c
	.byt	$1b,$21,$1a,$19,$2e,$12,$13,$2d
	.byt	$09,$0f,$25,$1f,$24,$22,$15,$27
	.byt	$17,$23,$0d,$d9,$ee,$d2,$d3,$32
	.byt	$3f,$3e,$3d,$3c,$3b,$3a,$39,$37
	.byt	$36,$34,$0a,$51,$73,$6f,$4b
;coordinates for sp,cr,lf,0
table2	.byt	$0c,$2b,$2c,$35
;ascii table for sp,cr,lf,0
table3	.byt	' ',$d,$a,'0'
;output pointer as two hex bytes
outpnt	lda	point+1		;high first
	jsr	outbyt
	lda	point		;then low
;output byte as two hex chars
outbyt	pha			;save input
	lsr	a
	lsr	a
	lsr	a
	lsr	a		;shift over
	jsr	outnib		;do nibble
	pla			;get all back
;output nibble a hex char
outnib	and	#$f		;clear high
	ora	#'0'		;make ascii
	cmp	#'9'+1		;see if over 9
	bcc	hex1		;isn't
	adc	#6		;make a-f
hex1	jmp	conot		;then send
;send prompt, address and data to console
prompt	jsr	conot		;send prompt
	jsr	outpnt		;then pointer
	jsr	outsp		;then a space
	ldy	#0		;clear index
	lda	(point),y	;get byte
	jmp	outbyt
;send a cr and lf to console
crlf	lda	#cr		;first do cr
	jsr	conot
	lda	#lf		;then linefeed
	bne	conot
;send a space to console
outsp	lda	#' '		;get char
;write a Character to Console
conot	pha			;save char
	pha			;save again
	jsr	clmwfl		;clear flag in case we scroll
	ldx	index		;get line index
	lda	lstchr		;and last char
	sta	lstpge,x	;and put on screen
	pla			;get new char
	beq	vidext		;done if null
	cmp	#$7f		;if not a delete continue
	bne	b4
	lda	#' '		;else make a space
b4	cmp	#cr		;if cr
	beq	docr		;go do it
	cmp	#lf		;if lf
	beq	dolf		;go do it
	cmp	#bs		;if bs
	beq	dobs		;go do it
	cmp	#fs		;if fs
	beq	dofs		;go do it
	cmp	#clreol		;if clear to eol
	beq	doceol		;go do it
	sta	lstpge,x	;move char to screen
	inx			;bump index
	cpx	#vidlmt		;compare to limit
	beq	scrool		;scrool if too big
vidext	lda	lstpge,x	;get char under cursor
	sta	lstchr		;and save
	lda	#$5f		;cursor char
	sta	lstpge,x	;send to screen
	stx	index		;save index
	jsr	stmwfl		;set flag if needed
	pla			;restore char
	rts
;carriage return
docr	ldx	#vidfrs		;index for left edge
	bne	vidext
;automatic cr and lf
scrool	ldx	#vidfrs		;do cr
	stx	index		;by saving start
;linefeed
dolf	lda	#0		;clear to low
	sta	to
	lda	#vidmve		;then from
	sta	from
	ldy	#4*32		;set y
	ldx	#>frspge-1	;starting page - one
setnxt	inx			;bump page
	stx	from+1		;set pages
	stx	to+1
get	lda	(from),y	;get from down
	sta	(to),y		;and move up
	iny			;bump index
	beq	setnxt		;loop for page end
	bpl	get		;loop for line
	cpx	#>lstpge	;see if at end
	bcc	get		;loop if not
	lda	#' '		;get space
	ldx	#vidlmt		;last position+1
clrend	sta	lstpge,x	;put on screen
	inx
	bne	clrend		;loop till done
	ldx	index		;else get index
	bne	vidext		;and exit
;backspace
dobs	dex			;drop index
	txa			;move to a
	and	#vidmsk		;look at position in line
	cmp	#vidmni		;see if at left edge
	bne	vidext		;done if not else fall through
;forward space
dofs	inx			;bump index
	txa			;move to a
	and	#vidmsk		;look at position in line
	cmp	#vidmxi		;see if past end
	bne	vidext		;ok if not
	dex			;else drop back one
	bpl	vidext		;and exit
;clear to end of line
doceol	lda	#' '		;get a space
	sta	lstpge,x	;send to screen
	inx			;bump index
	txa			;move to a
	and	#vidmsk		;look at position in line
	cmp	#vidmxi		;see if past end
	bne	doceol		;loop if ok
	ldx	index		;get correct back
	bne	vidext		;and quit
;the following five lines output a visual indication
;on the screen of the state of the mstwrt flag.  If
;the flag is set a special character (the $e5) is
;placed on the last visible line of the display.
;this indication serves as a warning to the user
;not to change diskettes.
stmwfl	lda	#$e5		;ready for special char
	bit	mstwrt		;test must write flag
	bmi	b3		;use if set
;always clear flag
clmwfl	lda	#' '		;clear position
b3	sta	vidprm		;to prompt location
	rts
;write a character to printer
list	pha			;save char
lstlpe	lda	prnter-1	;get status
	lsr	a		;test for empty
	lsr	a
	bcc	lstlpe		;loop if not
	pla			;get char
	sta	prnter		;send it
	rts
;convert hex track to bcd
hexbcd	lda	curtrk		;get hex track
	sec			;use x
	ldx	#$ff		;as counter
hexlpe	inx			;bump counter
	sbc	#10		;drop by ten
	bcs	hexlpe		;loop if no carry
	adc	#10		;add ten back in
	sta	bcdtrk		;save that result
	txa			;get ten's
	asl	a		;shift to high
	asl	a
	asl	a
	asl	a
	ora	bcdtrk		;or with low
	sta	bcdtrk		;and save
	rts
;delay 100us x times
dly100	lda	speed		;get constant C4
d100lp	jmp	j1		;waste time C3
j1	sec			;C2
	sbc	#5		;drop by five C2
	bcs	d100lp		;loop if more C3 (last C2)
	dex			;drop x C2
	bne	dly100		;loop to start C3 (last C2)
	rts			;C6
;delay=20*y+14 cycles
dlyy20	jsr	dly15		;delay 15 cycles
	dey			;drop count
	bne	dlyy20		;loop if more
	nop			;waste time
	rts
;delay=15 cycles
dly15	jmp	dly12		;C3
;delay=12 cycles
dly12	rts
;delay=24 cycles
dly24	jsr	dly12		;do 12
	rts
;delay=12ms
dly12m	ldx	#12
;delay=xms
dlyxm	ldy	speed
	jsr	dlyy20		;do 20*y cycles
	dex
	bne	dlyxm		;loop if more
	rts
;load head and wait 40 ms
loadhd	lda	#%01111111	;set load bit
	and	flpcnt		;to active
	sta	flpcnt
dly40m	ldx	#41		;delay 40 ms
	bne	dlyxm
;unload head and delay
unldhd	lda	#%10000000	;set load bit
	ora	flpcnt		;to inactive
	sta	flpcnt
	bne	dly40m		;and delay
;do reset of disk acia
rstdsk	lda	#%00000011	;master reset
	sta	flpdta-1
	lda	#%01011000	;no interrupt,rts* high,8+ep+s,/1
	sta	flpdta-1
	rts
;set up to read or write track into buffer
;if at correct track z=1 else z=0
rdytrk	jsr	hexbcd		;convert track to bcd
	jsr	loadhd		;load head with settling delay
fndind	lda	flpsts		;read status
	bmi	fndind		;not there yet
gotind	lda	flpsts		;read again
	bpl	gotind		;loop while index
	ldx	#8		;delay 800 us
	jsr	dly100
	jsr	rstdsk		;reset acia
trkstr	lda	flpsts		;get status
	bpl	inderr		;error if index
	jsr	rd1byt		;read a byte
tryc	cmp	#'C'		;see if start code
	bne	trkstr		;if not keep looking
	jsr	rd1byt		;read next byte
	cmp	#'W'		;see if second half
	bne	tryc		;if not try for C
	jsr	rd1byt		;get another byte
	cmp	bcdtrk		;see if correct
	bne	rdyext		;error if wrong track
	jsr	rd1byt		;get next byte
	cmp	#'X'		;see if X
rdyext	rts
inderr	lda	#1		;say error
	rts
;read a byte from disk into a (ignore parity)
rd1byt	lda	flpdta-1	;get acia status
	lsr	a		;check for ready
	bcc	rd1byt		;loop if not
	lda	flpdta		;get byte
	rts
;write byte in x to disk
wr1byt	lda	flpdta-1	;get status
	lsr	a		;test buffer empty
	lsr	a
	bcc	wr1byt		;loop if not
	stx	flpdta		;else send byte
	rts
;set trkpnt to first byte of desired sector in track buffer
strkpt	lda	nxtsec		;get next sector
	sec			;drop by one
	sbc	#1
	ldy	#0		;clear high part of pointer
	sty	trkpnt+1
	ldy	#7		;log2 128
mul128	asl	a		;multiply
	rol	trkpnt+1
	dey
	bne	mul128		;loop til done
	clc			;now add buffer start
	adc	#<trkbuf
	sta	trkpnt
	lda	trkpnt+1
	adc	#>trkbuf
	sta	trkpnt+1
	rts
;select drive in a
seldrv	asl	a		;multiply by two
	tax			;make index
	lda	seltbl,x	;initialize pia
	sta	flpsts
	lda	seltbl+1,x
	sta	flpcnt
	clc			;say no error
	rts
;drive select table
seltbl	.byt	$40,$ff		;drive a
	.byt	$00,$ff		;      b
;read track into buffer
; if ok then c=0
; if error then c=1 and errcde is set
;read to default track buffer
rdetrk	lda	#<trkbuf	;point to start of buffer
	ldy	#>trkbuf
;read to user specified buffer
extrde	sta	trkpnt		;set pointer
	sty	trkpnt+1
	lda	#0		;clear error code
	sta	errcde
	jsr	rdytrk		;get ready to read
	bne	rdeer1		;wrong track error
	ldx	#16		;delay 1600 us
	jsr	dly100
	jsr	rstdsk		;reset acia
tryv	jsr	rd1byt		;get next byte
	cmp	#'v'		;see if v
	bne	rdeer1		;error if not
	jsr	rd1byt		;and another
	cmp	#1		;if not 1
	bne	rdeer1		;is error
	jsr	rd1byt		;get track length
	cmp	#recrds/2	;compare to correct
	bne	rdeer1		;error if wrong
	tax			;make a counter
	ldy	#0		;clear index
rdelpe	lda	#%00000001	;get mask for ready
tstflp	bit	flpdta-1	;test acia
	beq	tstflp		;loop if not ready
	lda	flpdta		;get byte
	bvs	rdeer2		;parity error
	sta	(trkpnt),y	;put in memory
	iny			;bump index
	bne	rdelpe		;loop if more in page
	inc	trkpnt+1	;bump page pointer
	dex			;drop page count
	bne	rdelpe		;loop if more pages
	clc			;else done and ok
	bcc	rdeext		;then exit
;read header error
rdeer1	lda	#1
	bne	rdeerr
;parity error
rdeer2	lda	#%10
rdeerr	sta	errcde		;set error code
	sec			;and error flag
;common read exit
rdeext	jmp	unldhd		;un load head
;write track from buffer
; if ok then c=0
; if error then c=1 and errcde is set
;write from default track buffer
wrttrk	lda	#<trkbuf	;set pointer to start
	ldy	#>trkbuf
;write to user specified location
extwrt	sta	trkpnt		;set pointer
	sty	trkpnt+1
	lda	#0		;clear error code
	sta	errcde
	lda	#%00100000	;test for write protect
	bit	flpsts
	beq	wrter4		;write protect error
	jsr	rdytrk		;set up
	bne	wrter1		;bad header error
	lda	#recrds/2	;set page count
	sta	pgecnt
	ldx	#8		;delay 800us
	jsr	dly100
	lda	#%11111110	;turn on write enable
	and	flpcnt
	sta	flpcnt
	ldx	#12		;delay 1200 us
	jsr	dly100
	ldx	#'v'		;send sector start
	jsr	wr1byt		;code
	ldx	#1		;only one sector
	jsr	wr1byt
	ldx	#recrds/2	;fixed length
	jsr	wr1byt		;send it
	ldy	#0		;clear index
wrtlpe	lda	(trkpnt),y	;get byte
	tax			;move to x
	jsr	wr1byt		;write it
	iny			;bump index
	bne	wrtlpe		;loop if more in page
	inc	trkpnt+1	;bump pointer
	dec	pgecnt		;drop page count
	bne	wrtlpe		;loop if more
	ldx	#2		;wait 200 us
	jsr	dly100
	lda	#%10000001	;turn off write
	ora	flpcnt		;and unload head
	sta	flpcnt
	ldx	#10		;wait until erase stops
	jsr	dly100
	clc			;done and ok
	rts
;write bad header error
wrter1	lda	#1
	bne	wrterr
;write protect error
wrter4	lda	#%100
wrterr	sta	errcde		;set error code
	sec			;and flag
	rts
;seek track in nxttrk
; if ok then c=0 else c=1
doseek	lda	nxttrk		;get next
	cmp	#numtrk		;compare to number
	bcs	seeker		;error if too big
	lda	nxttrk		;see if at destination
	cmp	curtrk
	beq	noseek		;then do nothing if there
tkcmp	lda	nxttrk		;get next
	cmp	curtrk		;compare to current
	beq	seekok		;if same then done
	bcc	goout		;if smaller go out
	jsr	stepin		;else go in one
	inc	curtrk		;bump current
	bpl	tkcmp		;loop to check
goout	jsr	stepot		;step once
	dec	curtrk		;drop track
	bpl	tkcmp
seekok	jsr	dly40m		;wait for settle
noseek	clc			;and say ok
seeker	rts
;messages
ident	.byt	'C1MON 2.02',0
;output message at ay until 0
msgout	sta	msgpnt		;save pointer
	sty	msgpnt+1
outmsl	ldy	#0		;clear index
	lda	(msgpnt),y	;get char
	beq	seeker		;exit if null
	jsr	conot		;else send to console
	inc	msgpnt		;bump pointer
	bne	outmsl		;loop
	inc	msgpnt+1
	jmp	outmsl		;always
;reset, irq, and nmi vectors
;interrupt handlers
nmi	jmp	(nmivec)
irq	jmp	(irqvec)
*	=	$fffa
	.wor	nmi
	.wor	reset
	.wor	irq

	.end
