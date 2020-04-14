;my dos/65 sim
;osi - c1p/sbii version
;version 2.06
;released:	6 august 1983
;last revision:
;		13 august 1983
;			allow different step rates per drive
;			included data for 12x48
;		1 september 1983
;			added cdb entries
;		28 august 1984
;			changed printer to /1
;		14 may 1986
;			changed printer to /16
;		15 jun 1986
;			reworked mstwrt flag handling in conot
;			dropped to two drives
;			changed to 16 pages
;		21 july 1986
;			linked to c1mon
;			changed to 11 pages
;base addresses
msize	=	40		memory size in 1K blocks
pages	=	11		sim length in pages
wbtjmp	=	$100		warm boot entry
pemjmp	=	$103		pem entry
iostat	=	$106		io status byte
dflbuf	=	$128		default buffer
;osi addresses and parameters
prnter	=	$f001		printer port
;definitions
numtrk	=	40		number of tracks
sectrs	=	16		dos/65 sectors per track
nsystr	=	4		number system tracks
maxblk	=	numtrk-nsystr*sectrs/8-1	max block number
tries	=	20		retry limit
;pia
flpsts	=	$c000		status port
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
flpdta	=	$c011		data port
;parameters
cr	=	$d		return
lf	=	$a		line feed
tens	=	msize/10*10	tens part of msize
bs	=	8		backspace
fs	=	$1c		forward space
clreol	=	5		clear to end of line
;module addresses
simlng	=	pages*256	sim length in bytes
memlng	=	msize*1024	memory length in bytes
pemlng	=	3072		pem length in bytes
ccmlng	=	2048		ccm length in bytes
sim	=	memlng-simlng	start of sim
pem	=	sim-pemlng	start of pem
ccm	=	pem-ccmlng	start of ccm
length	=	pemlng+ccmlng	length of ccm and pem
nsects	=	length/128	number sectors
;c1mon rom entry points
c1mon	=	$f800
const	=	c1mon		console status
conin	=	c1mon+3		console input
conot	=	c1mon+6		console output
list	=	c1mon+9		list output
seldrv	=	c1mon+12	select drive
home	=	c1mon+15	home drive
;return with c=0 if ok else c=1
doseek	=	c1mon+18	seek track
extrde	=	c1mon+21	read track at ay
extwrt	=	c1mon+24	write track at ay
msgout	=	c1mon+27	message output
;page zero variable definitions
;these definitions match c1mon.asm, version 2.01
*	=	$dc
;monitor only
point	*=	*+2		pointer
in	*=	*+2		input buffer
;this first region is shared by several routines
;but is mainly for transient storage for the keyboard handler
ctlrow	*=	*+8		keyboard closures
from	=	ctlrow		from scroll
to	=	ctlrow+2	scroll to
msgpnt	=	ctlrow+4	message pointer
col	*=	*+1		current column
row	*=	*+1		current row
bcdtrk	=	row		bcd = curtrk
coord	*=	*+1		current coordinates
pgecnt	=	coord		pages in track
group	*=	*+1		current char group
trkpnt	=	group		read/write address for disk
tblpnt	*=	*+1		pointer to table
;this region is for dedicated usage - do not reuse
;video
index	*=	*+1		video index
lstchr	*=	*+1		char under cursor
;keyboard
chrflg	*=	*+1		waiting char
char	*=	*+1		current char
oldchr	*=	*+1		last char
timer1	*=	*+1		debounce and
timer2	*=	*+1		repeat timers
oldcrd	*=	*+1		old corrd
;disk related
secpnt	*=	*+2		dos/65 buffer address
mstwrt	*=	*+1		must write flag
errcde	*=	*+1		disk i/o error code
;error code bit definitions
; 0	wrong track if 1
; 1	read parity error if 1
; 2	write protect if 1
nxttrk	*=	*+1		next track for seek
curtrk	*=	*+1		current track
;general timing constant
speed	*=	*+1		timing constant
;interrupt vectors
nmivec	*=	*+2		nmi vector
irqvec	*=	*+2		irq vector
;main program
*	=	sim
;jump vector used by pem
	jmp	boot		from cold start
wboote	jmp	wboot		from warm boot
	jmp	const		console status
	jmp	conin		console input
	jmp	conot		console output
	jmp	list		printer output
	nop			punch output
	nop
	rts
	nop			reader input
	nop
	rts
	jmp	xhome		home drive
	jmp	seldsk		select disk
	jmp	settrk		set track
	jmp	setsec		set sector
	jmp	setdma		set buffer address
	jmp	xread		read sector
	jmp	xwrite		write sector
	lda	#1
	rts			printer always ready
	ldx	#128
	rts			no clock
	jmp	xlate		translate sector
;console definition block
	.byt	0		scratch
	.byt	bs		backspace
	.byt	clreol		clear to end of line
	.byt	fs		forward space
	.byt	0		normal video
	.byt	'^'		invert video
	.byt	12		lines
	.byt	48		char per line
	.byt	$c		formfeed
	.byt	1		home
	.byt	$b		clear to end of screen
;cold entry from loader
boot	ldx	#$ff		set stack
	txs			pointer
	cld			set binary mode
	lda	#0		clear
	sta	iostat		io status
	lda	#<smsg		print opening
	ldy	#>smsg
	jsr	msgout		message
;set up jumps into dos/65 in page one
setup	ldx	#5		do 6 bytes
setupl	lda	p1tbl,x		get byte
	sta	wbtjmp,x	and set
	dex			drop counter
	bpl	setupl		loop till done
;set buffer to default
	lda	#<dflbuf	get low buffer
	ldy	#>dflbuf	and high
	jsr	setdma		then set
	lda	nxtdrv		get disk
	jmp	ccm		and go to ccm
;initialization table
p1tbl	.byt	$4c,<wboote,>wboote,$4c,<pem,>pem
;warm boot-read dos/65 back except sim and then
; jump to ccm.
wboot	ldx	#$ff		set stack
	txs			pointer
	cld			set binary mode
	jsr	xhome		reset current drive
	lda	nxtdrv		get drive number
	sta	temp		and save
	lda	#0		set zero
	jsr	seldsk		and select drive zero
	jsr	xhome		home that drive
	lda	#<ccm		get ccm low
	ldy	#>ccm		and high
	jsr	setdma		then set start
	lda	#nsects		get number sectors
	sta	count		and set count
	lda	#2		starting sector
rdblk	jsr	setsec		set it
	jsr	xread		then do read
	and	#$ff		test for error
	bne	wboot		if error try again
	clc			clear carry
	lda	secpnt		get buffer address
	adc	#128		and raise it
	sta	secpnt		then save
	bcc	nocary		skip if no carry
	inc	secpnt+1	else increment high
nocary	dec	count		count down
	beq	aldon		if zero done
	lda	nxtsec		else get old sector
	cmp	#sectrs		if last in track
	beq	newtrk		go to track 1
	adc	#1		else add 1
	BNE	rdblk		and read next portion
newtrk	inc	nxttrk		bump track
	lda	#1		else set sector to 1
	bne	rdblk		and loop
aldon	lda	temp		get old drive back
	jsr	seldsk		select it
	jmp	setup		and go to ccm
;select disk
seldsk	and	#7		look at three lsbs
	cmp	#3+1		see if too big for osi
	bcs	invdrv		error if is
	sta	nxtdrv		save for later use
	asl	a		else make an index
	tax
	lda	dcbtbl,x	and get address of dcb
	ldy	dcbtbl+1,x
	rts
invdrv	lda	#0		set illegal value
	tay
	rts
;dcb location table
dcbtbl	.wor	dcba
	.wor	dcbb
;dcbs for up to two drives
;drive a
dcba	.wor	maxblk		max block number
	.wor	sectrs		sectors per track
	.wor	nsystr		systems tracks
	.byt	0		block = 1024
	.wor	63		max dir number
	.wor	almpa		allocation map address
	.byt	0		do checksums
	.wor	ckmpa		checksum map address
;drive b
dcbb	.wor	maxblk		max block number
	.wor	sectrs		sectors per track
	.wor	nsystr		systems tracks
	.byt	0		block = 1024
	.wor	63		max dir number
	.wor	almpb		allocation map address
	.byt	0		do checksums
	.wor	ckmpb		checksum map address
;do actual select
dosel	lda	curdrv		get current drive
	cmp	nxtdrv		compare to next
	beq	selext		done if same
	jsr	chkmwr		see if must write
	lda	#0		clear buffer
	sta	bufact		active flag
	ldx	curdrv		get old drive number
	lda	curtrk		get current track
	sta	trtab,X		and put in table
	ldx	nxtdrv		get new number
	stx	curdrv		and update current
	lda	trtab,X		get table value
	sta	curtrk		update current track
	txa			get drive in a
	jmp	seldrv		go select
selext	rts			return
;set sector number
setsec	sta	nxtsec		save for later use
	rts
;translate logical to physical sector
xlate	tax			move to x
	inx			bump by one
	txa			return in a
	rts
;set buffer address
setdma	sta	secpnt		store low
	sty	secpnt+1	and high
	rts			then return
;read a dos/65 sector
; if ok then a=0 else a=1
xread	jsr	dosel		select drive
	jsr	chkmwr		see if must write track
	bcs	rwerr		error
	jsr	chkmrd		see if must read track
	bcs	rwerr		error
	jsr	strkpt		set pointer
	ldy	#0		clear index
rdloop	lda	(trkpnt),y	get from track
	sta	(secpnt),y	move to dos/65
	iny			bump index
	bpl	rdloop		loop if more
rwok	lda	#0		say ok
	rts			and exit
rwerr	lda	#1		error
	rts
;write a dos/65 sector
; if ok then a=0 else a=1
xwrite	jsr	dosel		select drive
	jsr	chkmwr		see if must write track
	bcs	rwerr		error
	jsr	chkmrd		see if must read track
	bcs	rwerr		error
	jsr	strkpt		set pointer
	ldy	#0		clear index
wrloop	lda	(secpnt),y	get from dos/65
	sta	(trkpnt),y	move to buffer
	iny			bump index
	bpl	wrloop		loop if more
	lda	#128		set
	sta	mstwrt		must write flag
	bmi	rwok		then do ok exit
;home drive to track zero
xhome	lda	#0		set next track
	sta	nxttrk		to zero
	jsr	dosel		select drive
	bit	mstwrt		see if write pending
	bpl	*+5		it isn't
	jsr	dowrt		else force write
	lda	#0		clear active
	sta	bufact		flag
	sta	curtrk		set current track to zero
	jmp	home		go force to zero
;set track
settrk	sta	nxttrk		save number
	rts
;messages
smsg	.byt	cr,lf,msize/10+'0',msize-tens+'0','K DOS/65 V2.06',0
;check for must write and write track if necessary
; if ok then c=0 else c=1
chkmwr	bit	bufact		see if active
	bpl	nowrt		it isn't
	bit	mstwrt		see if written to
	bpl	nowrt		it wasn't
	lda	curdrv		see if same
	cmp	nxtdrv		drive
	bne	dowrt		isn't so write
	lda	curtrk		see if same
	cmp	nxttrk		track
	beq	nowrt		is so don't write
dowrt	jsr	wrttrk		write track
	lda	#0		clear must
	sta	mstwrt		write flag
	sta	bufact		and buffer full flag
	rts			without changing carry
nowrt	clc			say ok
	rts
;check for must read and read track if necessary
; if ok then c=0 else c=1
chkmrd	bit	bufact		see if active
	bpl	dorde		isn't so read
	lda	curtrk		see if
	cmp	nxttrk		track change
	beq	norde		wasn't so ok
dorde	lda	#tries		set retry
	sta	retrys		counter
mrseek	jsr	doseek		seek track
	bcs	rdeend		if illegal exit
tryrde	jsr	rdetrk		read track
	lda	#128		set buffer
	sta	bufact		active flag
	bcc	rdeend		if no error then exit
	dec	retrys		drop count
	beq	rdeend		exit if tried enough
	jsr	home		home drive
	jsr	dly12m		delay
	jmp	mrseek		then do seek
norde	clc			no error
rdeend	rts
;delay=20*y+14 cycles
dlyy20	jsr	dly15		delay 15 cycles
	dey			drop count
	bne	dlyy20		loop if more
	nop			waste time
	rts
;delay=15 cycles (if z=0)
dly15	bne	*+2
;delay=12 cycles
dly12	rts
;delay=12ms
dly12m	ldx	#12
;delay=xms
dlyxm	ldy	speed
	jsr	dlyy20		do 20*y cycles
	dex
	bne	dlyxm		loop if more
	rts
;set trkpnt to first byte of desired sector in track buffer
strkpt	lda	nxtsec		get next sector
	sec			drop by one
	sbc	#1
	ldy	#0		clear high part of pointer
	sty	trkpnt+1
	ldy	#7		log2 128
mul128	asl	a		multiply
	rol	trkpnt+1
	dey
	bne	mul128		loop til done
	clc			now add buffer start
	adc	#<trkbuf
	sta	trkpnt
	lda	trkpnt+1
	adc	#>trkbuf
	sta	trkpnt+1
	rts
;read track into buffer
; if ok then c=0
; if error then c=1 and errcde is set
rdetrk	lda	#<trkbuf	point to start of buffer
	ldy	#>trkbuf
	jmp	extrde		go read
;write track from buffer
; if ok then c=0
; if error then c=1 and errcde is set
wrttrk	lda	#<trkbuf	set pointer to start
	ldy	#>trkbuf
	jmp	extwrt		go write it
;data area
;storage definitions
curdrv	.byt	0		current drive
nxtdrv	.byt	0		next drive
nxtsec	.byt	0		next sector
bufact	.byt	0		buffer active if >=128
retrys	.byt	0		number of read retries
temp	.byt	0		scratch
count	.byt	0		sector count in warm boot
numdsk	.byt	1		number drives minus one
trtab	.byt	0,0		head positions
;the location just before here is the
;last location actually loaded by boot.
;allocation maps for two drives
almpa	*=	maxblk/8+1+*
almpb	*=	maxblk/8+1+*
;checksum maps for two drives
ckmpa	*=	63/4+1+*
ckmpb	*=	63/4+1+*
;full track buffer
trkbuf	*=	sectrs/2*256+*	track buffer
	.end
