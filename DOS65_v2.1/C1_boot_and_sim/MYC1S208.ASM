;my dos/65 sim
;osi - c1p/sbii version
;version 2.07
;released:	6 August 1983 (2.00)
;last revision:
;		13 August 1983 (2.01)
;			allow different step rates per drive
;			included data for 12x48
;		1 September 1983 (2.02)
;			added cdb entries
;		28 August 1984 (2.03)
;			changed printer to /1
;		14 May 1986 (2.04)
;			changed printer to /16
;		15 June 1986 (2.05)
;			reworked mstwrt flag handling in conot
;			dropped to two drives
;			changed to 16 pages
;		21 July 1986 (2.06)
;			linked to c1mon
;			changed to 11 pages
;		12 August 2015 (2.07)
;			added semicolons for comments
;			corrected record and sector use
;			added notes on SPEED generation & use
;			expanded start up banner
;			expanded .byt & .wor to .byte & .word
;		16 August 2915 (2.08)
;			incremented system version
;base addresses
msize	=	40		;memory size in 1K blocks
pages	=	11		;sim length in pages
wbtjmp	=	$100		;warm boot entry
pemjmp	=	$103		;pem entry
iostat	=	$106		;io status byte
dflbuf	=	$128		;default buffer
;osi addresses and parameters
prnter	=	$f001		;printer port
;definitions
numtrk	=	40		;number of tracks
recrds	=	16		;dos/65 records per track
nsystr	=	4		;number system tracks
maxblk	=	numtrk-nsystr*recrds/8-1	;max block number
tries	=	20		;retry limit
;pia
flpsts	=	$c000		;status port
;bit definitions
; 0
; 1	track 0 if 0
; 2
; 3
; 4
; 5	write protect if 0
; 6	drive select 1 (0=b or d, 1=a or c)
; 7	index if 0
flpcnt	=	flpsts+2
;bit definitions
; 0	write enable if 0
; 1
; 2	step
;	  0 if in
;	  1 if out (to track zero)
; 3	step on falling edge
; 4
; 5	drive select 2 (0=c or d, 1=a or b)
; 6
; 7	head load if 0
;acia
flpdta	=	$c011		;data port
;parameters
cr	=	$d		;return
lf	=	$a		;line feed
tens	=	msize/10*10	;tens part of msize
bs	=	8		;backspace
fs	=	$1c		;forward space
clreol	=	5		;clear to end of line
;module addresses
simlng	=	pages*256	;sim length in bytes
memlng	=	msize*1024	;memory length in bytes
pemlng	=	3072		;pem length in bytes
ccmlng	=	2048		;ccm length in bytes
sim	=	memlng-simlng	;start of sim
pem	=	sim-pemlng	;start of pem
ccm	=	pem-ccmlng	;start of ccm
length	=	pemlng+ccmlng	;length of ccm and pem
nrcrds	=	length/128	;number records
;c1mon rom entry points
c1mon	=	$f800
const	=	c1mon		;console status
conin	=	c1mon+3		;console input
conot	=	c1mon+6		;console output
list	=	c1mon+9		;list output
seldrv	=	c1mon+12	;select drive
home	=	c1mon+15	;home drive
;return with c=0 if ok else c=1
doseek	=	c1mon+18	;seek track
extrde	=	c1mon+21	;read track at ay
extwrt	=	c1mon+24	;write track at ay
msgout	=	c1mon+27	;message output
;page zero variable definitions
;these definitions match c1mon.asm, version 2.01 & 2.02
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
timer1	*=	*+1		;debounce and
timer2	*=	*+1		repeat timers
oldcrd	*=	*+1		;old corrd
;disk related
secpnt	*=	*+2		;dos/65 buffer address
mstwrt	*=	*+1		;must write flag
errcde	*=	*+1		;disk i/o error code
;error code bit definitions
; 0	wrong track if 1
; 1	read parity error if 1
; 2	write protect if 1
nxttrk	*=	*+1		;next track for seek
curtrk	*=	*+1		;current track
;general timing constant
;When SPEED is calculated
;every 256 inner loops bump the speed counter by 1
;so SPEED is the number of 16x256=4096 clock cycles
;that equal 200ms - the floppy rotation time. Other
;delays are created by dividing the 200ms and the 4096
;cycle count by the appropriate value and then
;implementing the required loop. Examples:
;	delay = 1 ms --> divider = 200 --> loop
;			cycle count = 4096/200 = 20.48
;			Since that is close to 20.5
;			a loop that alternates between
;			20 and 21 would be best but using
;			20 is only 2.3% off. SPEED could
;			be calculated differently so that
;			the total cycle count was
;			a convenient number like 4000. Or
;			the desired delay could just be
;			adjusted up by 2.3%. So 40--> 41,
;			100 --> 102, 200 --> 205.
;	delay = 100 us --> divider = 2000 --> loop
;			cycle count of 2.048 that is
;			too small to implement so
;			scale SPEED down by /5 by
;			subtracting 5 each loop rather
;			than doing a decrement. Also scale
;			the loop cycle count up from 2
;			by 5x to 10.
speed	*=	*+1		;timing constant
;interrupt vectors
nmivec	*=	*+2		;nmi vector
irqvec	*=	*+2		;irq vector
;main program
*	=	sim
;jump vector used by pem
	jmp	boot		;from cold start
wboote	jmp	wboot		;from warm boot
	jmp	const		;console status
	jmp	conin		;console input
	jmp	conot		;console output
	jmp	list		;printer output
	nop			;punch output
	nop
	rts
	nop			;reader input
	nop
	rts
	jmp	xhome		;home drive
	jmp	seldsk		;select disk
	jmp	settrk		;set track
	jmp	setrec		;set record
	jmp	setdma		;set buffer address
	jmp	xread		;read record
	jmp	xwrite		;write record
	lda	#1
	rts			;printer always ready
	ldx	#128
	rts			;no clock
	jmp	xlate		;translate record
;console definition block
	.byte	0		;scratch
	.byte	bs		;backspace
	.byte	clreol		;clear to end of line
	.byte	fs		;forward space
	.byte	0		;normal video
	.byte	'^'		;invert video
	.byte	12		;lines
	.byte	48		;char per line
	.byte	$c		;form feed
	.byte	1		;home
	.byte	$b		;clear to end of screen
;cold entry from loader
boot	ldx	#$ff		;set stack
	txs			;pointer
	cld			;set binary mode
	lda	#0		;clear
	sta	iostat		;io status
	lda	#<smsg		;print opening
	ldy	#>smsg
	jsr	msgout		;message
;set up jumps into dos/65 in page one
setup	ldx	#5		;do 6 bytes
setupl	lda	p1tbl,x		;get byte
	sta	wbtjmp,x	;and set
	dex			;drop counter
	bpl	setupl		;loop till done
;set buffer to default
	lda	#<dflbuf	;get low buffer
	ldy	#>dflbuf	;and high
	jsr	setdma		;then set
	lda	nxtdrv		;get disk
	jmp	ccm		;and go to ccm
;initialization table
p1tbl	.byte	$4c,<wboote,>wboote,$4c,<pem,>pem
;warm boot-read dos/65 back except sim and then
; jump to ccm.
wboot	ldx	#$ff		;set stack
	txs			;pointer
	cld			;set binary mode
	jsr	xhome		;reset current drive
	lda	nxtdrv		;get drive number
	sta	temp		;and save
	lda	#0		;set zero
	jsr	seldsk		;and select drive zero
	jsr	xhome		;home that drive
	lda	#<ccm		;get ccm low
	ldy	#>ccm		;and high
	jsr	setdma		;then set start
	lda	#nrcrds		;get number records
	sta	count		;and set count
	lda	#2		;starting record
rdblk	jsr	setrec		;set it
	jsr	xread		;then do read
	and	#$ff		;test for error
	bne	wboot		;if error try again
	clc			;clear carry
	lda	secpnt		;get buffer address
	adc	#128		;and raise it
	sta	secpnt		;then save
	bcc	nocary		;skip if no carry
	inc	secpnt+1	;else increment high
nocary	dec	count		;count down
	beq	aldon		;if zero done
	lda	nxtrec		;else get old record
	cmp	#recrds		;if last in track
	beq	newtrk		;go to track 1
	adc	#1		;else add 1
	BNE	rdblk		;and read next portion
newtrk	inc	nxttrk		;bump track
	lda	#1		;else set record to 1
	bne	rdblk		;and loop
aldon	lda	temp		;get old drive back
	jsr	seldsk		;select it
	jmp	setup		;and go to ccm
;select disk
seldsk	and	#7		;look at three lsbs
	cmp	#3+1		;see if too big for osi
	bcs	invdrv		;error if is
	sta	nxtdrv		;save for later use
	asl	a		;else make an index
	tax
	lda	dcbtbl,x	;and get address of dcb
	ldy	dcbtbl+1,x
	rts
invdrv	lda	#0		;set illegal value
	tay
	rts
;dcb location table
dcbtbl	.word	dcba
	.word	dcbb
	.word	0
	.word	0
	.word	0
	.word	0
	.word	0
	.word	0
;dcbs for up to two drives
;drive a
dcba	.word	maxblk		;max block number
	.word	recrds		;records per track
	.word	nsystr		;systems tracks
	.byte	0		;block = 1024
	.word	63		;max dir number
	.word	almpa		;allocation map address
	.byte	0		;do checksums
	.word	ckmpa		;checksum map address
;drive b
dcbb	.word	maxblk		;max block number
	.word	recrds		;records per track
	.word	nsystr		;systems tracks
	.byte	0		;block = 1024
	.word	63		;max dir number
	.word	almpb		;allocation map address
	.byte	0		;do checksums
	.word	ckmpb		;checksum map address
;do actual select
dosel	lda	curdrv		;get current drive
	cmp	nxtdrv		;compare to next
	beq	selext		;done if same
	jsr	chkmwr		;see if must write
	lda	#0		;clear buffer
	sta	bufact		;active flag
	ldx	curdrv		;get old drive number
	lda	curtrk		;get current track
	sta	trtab,X		;and put in table
	ldx	nxtdrv		;get new number
	stx	curdrv		;and update current
	lda	trtab,X		;get table value
	sta	curtrk		;update current track
	txa			;get drive in a
	jmp	seldrv		;go select
selext	rts			;return
;set record number
setrec	sta	nxtrec		;save for later use
	rts
;translate logical to physical record
xlate	tax			;move to x
	inx			;bump by one
	txa			;return in a
	rts
;set buffer address
setdma	sta	secpnt		;store low
	sty	secpnt+1	;and high
	rts			;then return
;read a dos/65 record
; if ok then a=0 else a=1
xread	jsr	dosel		;select drive
	jsr	chkmwr		;see if must write track
	bcs	rwerr		;error
	jsr	chkmrd		;see if must read track
	bcs	rwerr		;error
	jsr	strkpt		;set pointer
	ldy	#0		;clear index
rdloop	lda	(trkpnt),y	;get from track
	sta	(secpnt),y	;move to dos/65
	iny			;bump index
	bpl	rdloop		;loop if more
rwok	lda	#0		;say ok
	rts			;and exit
rwerr	lda	#1		;error
	rts
;write a dos/65 record
; if ok then a=0 else a=1
xwrite	jsr	dosel		;select drive
	jsr	chkmwr		;see if must write track
	bcs	rwerr		;error
	jsr	chkmrd		;see if must read track
	bcs	rwerr		;error
	jsr	strkpt		;set pointer
	ldy	#0		;clear index
wrloop	lda	(secpnt),y	;get from dos/65
	sta	(trkpnt),y	;move to buffer
	iny			;bump index
	bpl	wrloop		;loop if more
	lda	#128		;set
	sta	mstwrt		;must write flag
	bmi	rwok		;then do ok exit
;home drive to track zero
xhome	lda	#0		;set next track
	sta	nxttrk		;to zero
	jsr	dosel		;select drive
	bit	mstwrt		;see if write pending
	bpl	b0		;it isn't
	jsr	dowrt		;else force write
b0	lda	#0		;clear active
	sta	bufact		;flag
	sta	curtrk		;set current track to zero
	jmp	home		;go force to zero
;set track
settrk	sta	nxttrk		;save number
	rts
;messages
smsg	.byte	cr,lf,'40K DOS/65 V2.18 SIM V2.08',0
;check for must write and write track if necessary
; if ok then c=0 else c=1
chkmwr	bit	bufact		;see if active
	bpl	nowrt		;it isn't
	bit	mstwrt		;see if written to
	bpl	nowrt		;it wasn't
	lda	curdrv		;see if same
	cmp	nxtdrv		;drive
	bne	dowrt		;isn't so write
	lda	curtrk		;see if same
	cmp	nxttrk		;track
	beq	nowrt		;is so don't write
dowrt	jsr	wrttrk		;write track
	lda	#0		;clear must
	sta	mstwrt		;write flag
	sta	bufact		;and buffer full flag
	rts			;without changing carry
nowrt	clc			;say ok
	rts
;check for must read and read track if necessary
; if ok then c=0 else c=1
chkmrd	bit	bufact		;see if active
	bpl	dorde		;isn't so read
	lda	curtrk		;see if
	cmp	nxttrk		;track change
	beq	norde		;wasn't so ok
dorde	lda	#tries		;set retry
	sta	retrys		;counter
mrseek	jsr	doseek		;seek track
	bcs	rdeend		;if illegal exit
tryrde	jsr	rdetrk		;read track
	lda	#128		;set buffer
	sta	bufact		;active flag
	bcc	rdeend		;if no error then exit
	dec	retrys		;drop count
	beq	rdeend		;exit if tried enough
	jsr	home		;home drive
	jsr	dly12m		;delay
	jmp	mrseek		;then do seek
norde	clc			;no error
rdeend	rts
;delay=20*y+14 cycles (including calling JSR)
dlyy20	jsr	dly15		;delay 15 cycles C15
	dey			;drop count C2
	bne	dlyy20		;loop if more C3 (last is C2)
	nop			;waste time C2
	rts			;C6
;delay=15 cycles (including calling JSR)
dly15	jmp	dly12		;C3
;delay=12 cycles (when called using jsr)
dly12	rts			;C6
;delay=12ms
dly12m	ldx	#12
;delay=xms
dlyxm	ldy	speed		:C4
	jsr	dlyy20		;do 20*y cycles
	dex			;C2
	bne	dlyxm		;loop if more
	rts
;set trkpnt to first byte of desired record in track buffer
strkpt	lda	nxtrec		;get next record
	sec			;drop by one
	sbc	#1
	ldy	#0		;clear high part of pointer
	sty	trkpnt+1
	ldy	#7		;log2 128
mul128	asl	a		;multiply
	rol	trkpnt+1
	dey
	bne	mul128		;loop until done
	clc			;now add buffer start
	adc	#<trkbuf
	sta	trkpnt
	lda	trkpnt+1
	adc	#>trkbuf
	sta	trkpnt+1
	rts
;read track into buffer
; if ok then c=0
; if error then c=1 and errcde is set
rdetrk	lda	#<trkbuf	;point to start of buffer
	ldy	#>trkbuf
	jmp	extrde		;go read
;write track from buffer
; if ok then c=0
; if error then c=1 and errcde is set
wrttrk	lda	#<trkbuf	;set pointer to start
	ldy	#>trkbuf
	jmp	extwrt		;go write it
;data area
;storage definitions
curdrv	.byte	0		;current drive
nxtdrv	.byte	0		;next drive
nxtrec	.byte	0		;next record
bufact	.byte	0		;buffer active if >=128
retrys	.byte	0		;number of read retries
temp	.byte	0		;scratch
count	.byte	0		;record count in warm boot
numdsk	.byte	1		;number drives minus one
trtab	.byte	0,0		;head positions
;the location just before here is the
;last location actually loaded by boot.
;allocation maps for two drives
almpa	*=	maxblk/8+1+*
almpb	*=	maxblk/8+1+*
;checksum maps for two drives
ckmpa	*=	63/4+1+*
ckmpb	*=	63/4+1+*
;full track buffer
trkbuf	*=	recrds/2*256+*	;track buffer
	.end
