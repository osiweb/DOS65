;getbasic - for osi basic source files
;program to interactively read osi files and convert them to
;dos/65 format.
;this program assumes that the starting location saved on the
;diskette is for a OS65D V3.2 system and that the normal start
;of source files is at $317f.  this assumption is used to find
;out how many bytes to skip before conversion begins.
;version 2.00
;released:	17 july 1983
;last revision:	none
;fixed definitions
boot	=	$100		warm boot entry
pem	=	$103		pem entry
dflfcb	=	$107		default fcb
dflbuf	=	$128		default buffer
;constants
cr	=	$d		carriage return
lf	=	$a		linefeed
numtrk	=	77		number of tracks
stprte	=	8		step rate in ms
eof	=	$1a		eof character
buflng	=	8		sectors in dos/65 buffer
ldestr	=	$317f		load start for data
;space mode types
no	=	$00		no spaces
bo	=	$80		before only
ao	=	$40		after only
ba	=	$c0		before and after
;disk controller definitions
;pia
flpsts	=	$c000		status port
;bit definitions
; 0	drive 0 ready if 0
; 1	track 0 if 0
; 2	fault if 0
; 3
; 4	drive 1 ready if 0
; 5	write protect if 0
; 6	drive select (0=B or D, 1=A or C)
; 7	index if 0
flpcnt	=	flpsts+2
;bit definitions
; 0	write enable if 0
; 1	erase enable if 0
;	  enable 200us after write enable
;	  disable 530us after write disable
; 2	step
;	  0 if in
;	  1 if out (to track zero)
; 3	step on falling edge
; 4	fault reset if 0
; 5	side select (0=C or D, 1=A or B)
; 6	TG43 if 0
; 7	head load if 0
;acia
flpdta	=	$c011		data port
;page zero data area
*	=	$00
spcmde	*=	*+1		mode set by user
spcflg	*=	*+1		and of spcmde and spctbl,token
moduls	*=	*+2		modulus of digit
lineno	*=	*+2		binary line number
leadzf	*=	*+1		leading zero flag
skplng	*=	*+2		bytes at start to skip
savind	*=	*+1		token table index
zerchk	*=	*+1		check for zero link
eofflg	*=	*+1		eof flag for osi file
rptcnt	*=	*+1		repeat count for char comp
lstchr	*=	*+1		last character output
numcnv	*=	*+2		number bytes to convert
first	*=	*+2		start of file
last	*=	*+2		end of file + 1
tracks	*=	*+1		number of tracks in file
temp	*=	*+1		temporary
rectwr	*=	*+1		records to write
speed	*=	*+1		cpu speed constant (49=1 mhz)
track	*=	*+1		track to read
curtrk	*=	*+1		current track
sector	*=	*+1		sector to read
bcdtrk	*=	*+1		track in bcd
tmpbcd	*=	*+1		temp in hexbcd
drive	*=	*+1		drive selected
seclng	*=	*+1		sector length in pages
secnum	*=	*+1		sector number
number	*=	*+1		number result of decimal input
bufpnt	*=	*+2		pointer into dosbuf
osipnt	*=	*+2		pointer into osibuf
osimax	*=	*+2		max value of osipnt
reccnt	*=	*+1		record counter for write
;start of main program
*	=	$200
	lda	boot+2		get sim page
	sta	shome+2		set page for direct home
	sta	ssel+2		and select drive
	lda	#0		clear eof flag
	sta	eofflg
	sta	spcmde		and space mode
	lda	#buflng		get default buffer length
	sta	rectwr
	jsr	intbuf		set pointer to start
	jsr	fileof		fill buffer with eof
	lda	#<opnmsg	point to opening message
	ldy	#>opnmsg
	jsr	msgout		send it
	lda	dflfcb+1	get first char in name
	cmp	#' '		see if a space
	bne	nmeok		ok if not
	lda	dflfcb+9	get first char of type
	cmp	#' '		see if a space
	bne	nmeok		ok if not
	lda	#0		else illegal name error
	jmp	ftlerr		else fatal illegal name error
nmeok	jsr	tstamb		test for afn
	bcc	isufn		ok if not
	lda	#5		else is fatal error
	jmp	ftlerr
isufn	ldx	#13		reset system
	jsr	pem
	lda	#0		select drive A
	sta	dflfcb		force dos/65 to a
	jsr	seldrv
	jsr	dltfle		delete file if it exists
	jsr	crtfle		then go create it
	jsr	setspd		determine cpu speed
askfsp	lda	#<spcmsg	ask if spaces to be added
	ldy	#>spcmsg
	jsr	msgout
	jsr	coninp		get answer
	cmp	#'N'		see if no
	beq	askftr		if so leave as is
	cmp	#'Y'		see if yes
	bne	askfsp		if not ask again
	lda	#$ff		else set flag
	sta	spcmde
	bne	askftr		and go get track
;determine if to continue
askcon	lda	#<conmsg	ask for continue or not
	ldy	#>conmsg
	jsr	msgout
	jsr	coninp		get result
	cmp	#'N'		see if stop code
	beq	nrmext		exit if is
	cmp	#'Y'		see if continue
	bne	askcon		try again if not
;determine first track
askftr	lda	#<trkmsg	ask for first track
	ldy	#>trkmsg
	jsr	msgout
	jsr	rdedec		then get answer
	jsr	chklgt		check for legal track
	bcs	askcon		if error try again
	sta	track		save for seek and read
	lda	#1		set sector to 1
	sta	sector		save for read
	jsr	rdetrk		try to read
	jsr	suossf		set up file pointers
	jsr	convrt		convert to dos/65
	lda	#<eofmsg	say eof read
	ldy	#>eofmsg
	jsr	msgout
nrmext	lda	#0		select drive 0
	jsr	ssel
	jsr	shome		and home
	jsr	incbpt		make sure at least one eof
	sec			first determine
	lda	bufpnt		distance modulo 128
	sbc	#<dosbuf	that pointer is from start
	and	#$7f
	beq	nodmmy		if zero no delta needed
	eor	#$ff		complement
	tax			and add one
	inx
adddmy	jsr	incbpt		bump pointer by one
	dex			drop count
	bne	adddmy		loop if more
nodmmy	sec			calculate length of buffer
	lda	bufpnt
	sbc	#<dosbuf
	sta	bufpnt
	lda	bufpnt+1
	sbc	#>dosbuf
	sta	bufpnt+1
	ldx	#7		divide by 128
	lda	bufpnt
shftbp	lsr	bufpnt+1	to calculate number records
	ror	a
	dex
	bne	shftbp
	sta	rectwr		save as length
	jsr	dmpbuf		write records
	jsr	clsfle		close file
	jmp	boot		return with boot
;subroutines
;test fcb for ambiguous file name
;if afn return with c=1 else c=0
tstamb	ldx	#1		set index
tamlpe	lda	dflfcb,x	get char
	cmp	#'?'		see if ?
	beq	isafn		if so is afn
	inx			bump index
	cpx	#12		see if end
	bne	tamlpe		loop if not
	clc			else say ok
isafn	rts
;space mode table for each token
spctbl	.byt	ao		end
	.byt	ao		for
	.byt	ao		next
	.byt	ao		data
	.byt	ao		input
	.byt	ao		dim
	.byt	ao		read
	.byt	ao		let
	.byt	ba		goto
	.byt	ao		run
	.byt	ao		if
	.byt	ao		restore
	.byt	ba		gosub
	.byt	no		return
	.byt	ao		rem
	.byt	no		stop
	.byt	ao		on
	.byt	ao		null
	.byt	ao		wait
	.byt	no		exit
	.byt	no		disk
	.byt	no		def
	.byt	ao		poke
	.byt	ao		print
	.byt	ao		cont
	.byt	ao		list
	.byt	no		clear
	.byt	no		new
	.byt	no		tab(
	.byt	ba		to
	.byt	bo		fn
	.byt	bo		spc(
	.byt	ba		then
	.byt	ba		not
	.byt	ba		step
	.byt	no		+
	.byt	no		-
	.byt	no		*
	.byt	no		/
	.byt	no		^
	.byt	ba		and
	.byt	ba		or
	.byt	no		>
	.byt	no		=
	.byt	no		<
	.byt	bo		sgn
	.byt	bo		int
	.byt	bo		abs
	.byt	bo		usr
	.byt	bo		fre
	.byt	bo		pos
	.byt	bo		sqr
	.byt	bo		rnd
	.byt	bo		log
	.byt	bo		exp
	.byt	bo		cos
	.byt	bo		sin
	.byt	bo		tan
	.byt	bo		atn
	.byt	bo		peek
	.byt	bo		len
	.byt	bo		str$
	.byt	bo		val
	.byt	bo		asc
	.byt	bo		chr$
	.byt	bo		left$
	.byt	bo		right$
	.byt	bo		mid$
;token table for basic
tkntbl	.byt	'EN','D'+128
	.byt	'FO','R'+128
	.byt	'NEX','T'+128
	.byt	'DAT','A'+128
	.byt	'INPU','T'+128
	.byt	'DI','M'+128
	.byt	'REA','D'+128
	.byt	'LE','T'+128
	.byt	'GOT','O'+128
	.byt	'RU','N'+128
	.byt	'I','F'+128
	.byt	'RESTOR','E'+128
	.byt	'GOSU','B'+128
	.byt	'RETUR','N'+128
	.byt	'RE','M'+128
	.byt	'STO','P'+128
	.byt	'O','N'+128
	.byt	'NUL','L'+128
	.byt	'WAI','T'+128
	.byt	'EXI','T'+128
	.byt	'DIS','K'+128
	.byt	'DE','F'+128
	.byt	'POK','E'+128
	.byt	'PRIN','T'+128
	.byt	'CON','T'+128
	.byt	'LIS','T'+128
	.byt	'CLEA','R'+128
	.byt	'NE','W'+128
	.byt	'TAB','('+128
	.byt	'T','O'+128
	.byt	'F','N'+128
	.byt	'SPC','('+128
	.byt	'THE','N'+128
	.byt	'NO','T'+128
	.byt	'STE','P'+128
	.byt	'+'+128
	.byt	'-'+128
	.byt	'*'+128
	.byt	'/'+128
	.byt	'^'+128
	.byt	'AN','D'+128
	.byt	'O','R'+128
	.byt	'>'+128
	.byt	'='+128
	.byt	'<'+128
	.byt	'SG','N'+128
	.byt	'IN','T'+128
	.byt	'AB','S'+128
	.byt	'US','R'+128
	.byt	'FR','E'+128
	.byt	'PO','S'+128
	.byt	'SQ','R'+128
	.byt	'RN','D'+128
	.byt	'LO','G'+128
	.byt	'EX','P'+128
	.byt	'CO','S'+128
	.byt	'SI','N'+128
	.byt	'TA','N'+128
	.byt	'AT','N'+128
	.byt	'PEE','K'+128
	.byt	'LE','N'+128
	.byt	'STR','$'+128
	.byt	'VA','L'+128
	.byt	'AS','C'+128
	.byt	'CHR','$'+128
	.byt	'LEFT','$'+128
	.byt	'RIGHT','$'+128
	.byt	'MID','$'+128
	.byt	0		just in case
;set up file pointers and calculate bytes to read
suossf	jsr	getbyt		get low and high of start
	sta	first
	jsr	getbyt
	sta	first+1
	jsr	getbyt		then do same for last+1
	sta	last
	jsr	getbyt
	sta	last+1
	jsr	getbyt		then get number tracks
	sta	tracks
	sec			calculate bytes in file
	lda	last
	sbc	first
	sta	numcnv
	lda	last+1
	sbc	first+1
	sta	numcnv+1
	sec			now calculate how many to skip
	lda	first
	sbc	#<ldestr
	sta	skplng
	lda	first+1
	sbc	#>ldestr
	sta	skplng+1
skplpe	lda	skplng		see if any left
	ora	skplng+1
	beq	endskp		if not then ready to read
	lda	skplng		now drop count
	bne	*+4
	dec	skplng+1
	dec	skplng
	jsr	getwod		skip a byte
	jmp	skplpe		and loop
endskp	rts
;convert contents of buffer to dos/65
;and do any new track reads required
convrt	jsr	getbyt		skip first eol
	bcs	endosi		exit if eof
cnvlpe	jsr	getbyt		get first link byte
	bcs	endosi		done if eof
	sta	zerchk		else save for link check
	jsr	getbyt		then get second
	bcs	endosi		same for it
	ora	zerchk		then check both
	beq	endosi		done if zero
	jsr	dolnum		do line number
nxtchr	jsr	getbyt		get text char
	bcs	endosi		exit if eof
	bne	noteol		if not zero is ok
	lda	#cr		else send cr and lf
	jsr	outdos
	lda	#lf		else send linefeed
	jsr	outdos
	jmp	cnvlpe		then loop for new line
noteol	bmi	istokn		branch if token
	jsr	outdos		else just send
	jmp	nxtchr		and get next
istokn	sec			make counter
	sbc	#127
	tax			else move to x
	lda	spctbl-1,x	get space mode for token
	and	spcmde		and with user desires
	sta	spcflg		and save
	ldy	#$ff		set to -1
tknsrc	dex			drop counter
	beq	gottkn		there if zero
tknslp	iny			bump index
	lda	tkntbl,y	get char
	bpl	tknslp		loop until end
	bmi	tknsrc		then see if there
gottkn	sty	savind		save index
	bit	spcflg		test flag
	bpl	*+5		if no before then skip
	jsr	outspc		send a space
tkotlp	inc	savind		bump index
	ldy	savind		get index
	lda	tkntbl,y	get char
	bmi	endtkn		done if neg
	jsr	outdos		else send
	jmp	tkotlp		and loop
endtkn	and	#$7f		clear msb
	jsr	outdos		and send
	bit	spcflg		test flag
	bvc	*+5		if no after then skip
	jsr	outspc		send space
	jmp	nxtchr		and go get next char
;eof reached
endosi	rts
;convert two binary bytes to line number
dolnum	jsr	getbyt
	sta	lineno		get low
	jsr	getbyt		then high
	sta	lineno+1
	lda	#0		clear leading zero flag
	sta	leadzf
	lda	#<10000		do 10000s
	ldy	#>10000
	jsr	dodigt
	lda	#<1000		then 1000s
	ldy	#>1000
	jsr	dodigt
	lda	#100		then 100s
	ldy	#0
	jsr	dodigt
	lda	#10		then 10s
	ldy	#0
	jsr	dodigt
	lda	lineno		then always do 1s
	ora	#'0'
	jsr	outdos
	lda	#9		then send a tab
	jmp	outdos
;do a single digit
dodigt	sta	moduls		save modulus
	sty	moduls+1
	ldx	#$ff		clear digit
	sec
diglpe	lda	lineno		subtract until borrow
	sbc	moduls
	sta	lineno
	lda	lineno+1
	sbc	moduls+1
	sta	lineno+1
	inx			bump digit
	bcs	diglpe		loop if no borrow
	lda	lineno		now add modulus back
	adc	moduls
	sta	lineno
	lda	lineno+1
	adc	moduls+1
	sta	lineno+1
	txa			test digit
	beq	digzro		skip if zero
	sec			else set flag
	ror	leadzf
digzro	bit	leadzf		test flag
	bpl	dontpr		skip if clear
	ora	#'0'		else make ascii
	jsr	outdos		and send
dontpr	rts
	rts
;get byte from osi buffer but do not drop
;count of bytes to convert
;does not check for or set eof flag
;and does not return byte
getwod	inc	osipnt		bump pointer
	bne	*+4
	inc	osipnt+1
	lda	osipnt		check low
	cmp	osimax
	bne	rdntrq		no read required
	lda	osipnt+1	check high
	cmp	osimax+1
	bne	rdntrq		no read required
	inc	track		set up to read next
	dec	tracks		drop counter
	bne	mustrd		if not zero then read
	lda	#4		else error
	jmp	ftlerr
mustrd	jsr	rdetrk		read track
rdntrq	rts
;get byte from osi buffer
;also bump pointer, drop counter and do reread if necessary
;returns with c=1 if eof else c=0
getbyt	bit	eofflg		test flag
	bmi	sayeof		if set is eof
	ldy	#0		clear index
	lda	(osipnt),y	get byte
	pha			save on stack
	inc	osipnt		bump pointer
	bne	*+4
	inc	osipnt+1
	lda	numcnv		also drop count of size
	bne	*+4
	dec	numcnv+1
	dec	numcnv
	lda	numcnv		now see if that count is zero
	ora	numcnv+1
	bne	moredt		if not then more to get
	lda	#128		else set eof flag
	sta	eofflg
	bmi	nordrq		and exit w/o new read
moredt	lda	osipnt		check low
	cmp	osimax
	bne	nordrq		no read required
	lda	osipnt+1	check high
	cmp	osimax+1
	bne	nordrq		no read required
	inc	track		set up to read next
	dec	tracks		drop counter
	bne	oktord		if not zero then read
	lda	#4		else error
	jmp	ftlerr
oktord	jsr	rdetrk		read track
nordrq	pla			get char
	clc			say not eof
	rts
sayeof	sec			set carry for eof
	rts
;output space to dos/65
outspc	lda	#' '
;output char in a to dos/65 buffer and
;write buffer as needed.
outdos	ldy	#0		clear index
	sta	(bufpnt),y	put in buffer
	jsr	incbpt		bump pointer
	lda	bufpnt		compare pointer to max
	cmp	#<bufmax
	bne	extout		done if not there
	lda	bufpnt+1	same for high
	cmp	#>bufmax
	bne	extout		exit if zero
dmpbuf	jsr	intbuf		setup pointer again
	lda	rectwr		get records in buffer
	sta	reccnt		set counter
	beq	intbuf		exit if zero
movrec	ldy	#0		clear index
movlpe	lda	(bufpnt),y	get char
	sta	dflbuf,y	put in buffer
	iny			bump index
	bpl	movlpe		loop if more
	jsr	wrtfle		write sector
	clc			add 128 to pointer
	lda	bufpnt
	adc	#128
	sta	bufpnt
	bcc	*+4
	inc	bufpnt+1
	dec	reccnt		drop counter
	bne	movrec		loop if more records
	jsr	fileof		now fill buffer with eof
;set bufpnt to start of dosbuf
intbuf	lda	#<dosbuf	get start
	ldy	#>dosbuf
	sta	bufpnt		then set
	sty	bufpnt+1
extout	rts
;fill dos/65 buffer with eof
fileof	jsr	intbuf		set pointer to start
	ldx	#buflng		get number records
fill0	ldy	#0		clear index
	lda	#eof		get eof char
fill1	sta	(bufpnt),y	insert char
	iny			bump index
	bpl	fill1		loop until end of record
	clc			now bump pointer
	tya
	adc	bufpnt
	sta	bufpnt
	bcc	*+4
	inc	bufpnt+1
	dex			drop record counter
	bne	fill0		loop until all full
	jmp	intbuf		set pointer back to start
;bump dos/65 buffer pointer by one
incbpt	inc	bufpnt
	bne	*+4
	inc	bufpnt+1
	rts
;sim entries
shome	jsr	24		sim home offset
	jmp	home		then home for local
ssel	jmp	27		sim select drive offset
;pem entries
msgout	ldx	#9		get operation number
	jmp	pem		go do it
;read console input line
rdelin	lda	#<conbuf	point to buffer
	ldy	#>conbuf
	ldx	#10		do read
	jmp	pem
;single character input with echo
coninp	ldx	#1
	jsr	pem		read char
	cmp	#'a'		if lower case convert
	bcc	notlwr		it isn't
	cmp	#'z'+1
	bcs	notlwr		it isn't
	and	#$5f		convert
notlwr	rts
;select drive in a
seldrv	ldx	#14
	jmp	pem
;set dma address to value in ay
setdma	ldx	#26
	jmp	pem
;close file
clsfle	lda	#<dflfcb	point to fcb
	ldy	#>dflfcb
	ldx	#16		close code
	jmp	pem
;open file
opnfle	lda	#<dflfcb	point to fcb
	ldy	#>dflfcb
	ldx	#15		open code
	jmp	pem
;create file
crtfle	lda	#<dflfcb	point to fcb
	ldy	#>dflfcb
	ldx	#22		create code
	jmp	pem
;delete file
dltfle	lda	#<dflfcb	point to fcb
	ldy	#>dflfcb
	ldx	#19		delete code
	jmp	pem
;write to file
wrtfle	lda	#<dflfcb	point to fcb
	ldy	#>dflfcb
	ldx	#21		write code
	jmp	pem
;check for legal track
;returns c=0 if legal else c=1
chklgt	beq	illgtr		illegal if zero
	bcs	illgtr		or if > 99
	cmp	#numtrk		compare to max
	bcs	illgtr		error if too big
	rts
illgtr	lda	#1		illegal track error
	jsr	error
	sec			set error code
	rts
;general error handler
error	pha			save error number
	lda	#<errmsg	send general message
	ldy	#>errmsg
	jsr	msgout
	pla			get error code back
	asl	a		make an index
	tax
	lda	errtbl,x	get message address
	ldy	errtbl+1,x
	jmp	msgout
;error table
errmsg	.byt	cr,lf,'ERROR - $'
errtbl	.wor	erm000
	.wor	erm001
	.wor	erm002
	.wor	erm003
	.wor	erm004
	.wor	erm005
;error messages
erm000	.byt	'Invalid file name - all blanks$'
erm001	.byt	'Illegal track number$'
erm002	.byt	'Illegal decimal number$'
erm003	.byt	'OSI read error$'
erm004	.byt	'Inconsistent file header - not enough tracks$'
erm005	.byt	'Invalid file name - ambiguous$'
;fatal error
ftlerr	jsr	error		send message
	jmp	boot		then reboot
;read single decimal number (0 to 99)
;if result is zero then z=1
;if result is > 99 or has illegal format then error
;message is output and retry is attempted.
rdedec	jsr	rdelin		get console input
	ldy	#0		clear number
	sty	number
	lda	conlng		get length
	beq	zrores		if zero say ok and zero
	tax			make an index
	tya			set a to zero
	sta	contxt,x	and insert a zero
	dey			drop index for loop
frsdig	iny			bump index
	lda	contxt,y	get character
	beq	zrores		done if end
	cmp	#' '		see if blank
	beq	frsdig		loop if is
	jsr	numerc		make sure is numeric
	beq	frsdig		if zero is leading
	bcs	ilgdec		if error try again
	sta	number		save result
	iny			point to next
	lda	contxt,y	get char
	beq	zrores		done if zero
	cmp	#' '		or if space
	beq	zrores		done
	jsr	numerc		else check for numeric
	bcs	ilgdec		branch if error
	ldx	number		get tens part
	inx			bump for count
	sta	number		save low part
	clc			clear accum and carry
	lda	#0
mul10	dex			drop high
	beq	donm10		done if zero
	adc	#10		else add ten more
	jmp	mul10		and loop
donm10	adc	number		now add low
	sta	number		and save again
	iny			point to next 
	lda	contxt,y	and get it
	beq	zrores		done if zero
	cmp	#' '		or if blank
	beq	zrores
ilgdec	lda	#2		send error message
	jsr	error
	jsr	crlf		send cr and lf
	jmp	rdedec		and try again
zrores	clc			say no overflow
	lda	number		and get number
	rts
;check for ascii character in range 0 to 9
;if character is in 0 to 9 range then ascii part
;is pulled off, remainder is returned, and c=0.
;if not decimal then c=1.
numerc	cmp	#'0'		see if under 0
	bcc	notnum		if so is not decimal
	cmp	#'9'+1		see if over 9
	bcs	notnum		if so is not decimal
	and	#$f		look at low nibble
	clc
	rts
notnum	sec			set error code
	lda	#255		insure not zero
	rts
;output cr and lf to console
crlf	lda	#<crlmsg	point to string
	ldy	#>crlmsg
	jmp	msgout
;determine cpu speed
setspd	jsr	loadhd		load head
ind0	lda	flpsts		get status
	bmi	ind0		loop until index
ind1	lda	flpsts		get again
	bpl	ind1		loop until end of index
	ldx	#0		clear counters
	ldy	#0
chkrev	lda	flpsts		get again
	bpl	gotrev		branch if index
	nop			delay a bit
	inx
	bne	chkrev
	iny
	jmp	chkrev
gotrev	txa			see if should round
	bpl	*+3		branch if should not
	iny			else bump speed
	sty	speed		set speed
	jsr	unldhd
	rts
;home drive to track zero
home	lda	#0		set next track
	sta	curtrk		to zero
	jsr	stepin		step head in one
	jsr	dly12m		delay 12ms
hlp	lda	#%00000010	mask for track zero
	bit	flpsts		test it
	bne	*+3		continue if not there
	rts			else done
	jsr	stepot		step out
	jmp	hlp		and loop
;convert hex to bcd
hexbcd	sec			use x
	ldx	#$ff		as counter
hexlpe	inx			bump counter
	sbc	#10		drop by ten
	bcs	hexlpe		loop if no carry
	adc	#10		add ten back in
	sta	tmpbcd		save that result
	txa			get ten's
	asl	a		shift to high
	asl	a
	asl	a
	asl	a
	ora	tmpbcd		or with low
	rts
;step towards track zero
stepot	lda	flpcnt		get control
	ora	#%00000100	set direction to out
	bne	step
;step away from track zero
stepin	lda	flpcnt		get control
	and	#%11111011	set direction to in
step	sta	flpcnt		set it
	jsr	dly12		wait 12 cycles
	and	#%11110111	set step bit
	sta	flpcnt		set it
	jsr	dly24		delay 24 cycles
	ora	#%00001000	clear bit
	sta	flpcnt		set it
	ldx	#stprte		get rate in ms
	jmp	dlyxm		delay the right time
;delay 100us x times
dly100	lda	speed		get constant
d100lp	bit	$00		waste time
	sec
	sbc	#5		drop by five
	bcs	d100lp		loop if more
	dex			drop x
	bne	dly100		loop to start
	rts
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
;delay=24 cycles
dly24	jsr	dly12		do 12
	rts
;delay=12ms
dly12m	ldx	#12
;delay=xms
dlyxm	ldy	speed
	jsr	dlyy20		do 20 cycles
	dex
	bne	dlyxm		loop if more
	rts
;load head and wait 40 ms
loadhd	lda	#%01111111	set load bit
	and	flpcnt		to active
	sta	flpcnt
	ldx	#40		delay 40 ms
	jmp	dlyxm
;unload head
unldhd	lda	#%10000000	set load bit
	ora	flpcnt		to inactive
	sta	flpcnt
	rts
;set up to read or write sector into buffer
;if correct z=1 else z=0
rdytrk	lda	track		get track
	jsr	hexbcd		convert to bcd
	sta	bcdtrk		and save
	jsr	seek		seek to track
	jsr	loadhd		load head with settling delay
fndind	lda	flpsts		read status
	bmi	fndind		not there yet
gotind	lda	flpsts		read again
	bpl	gotind		loop while index
	lda	#%00000011	master reset
	sta	flpdta-1
	lda	#%01011000	no interrupt,rts* high,8+ep+s,/1
	sta	flpdta-1
trkstr	lda	flpsts		get status
	bpl	inderr		error if index
	jsr	rd1byt		read a byte
tryc	cmp	#'C'		see if start code
	bne	trkstr		if not keep looking
	jsr	rd1byt		read next byte
	cmp	#'W'		see if second half
	bne	tryc		if not try for C
	jsr	rd1byt		get another byte
	cmp	bcdtrk		see if correct
	bne	rdyext		error if wrong track
	jsr	rd1byt		get next byte
	cmp	#'X'		see if X
rdyext	rts
inderr	lda	#1		say error
	rts
;read a byte from disk into a (ignore parity)
rd1byt	lda	flpdta-1	get acia status
	lsr	a		check for ready
	bcc	rd1byt		loop if not
	lda	flpdta		get byte
	rts
;read sector into buffer
;if error then message printed and system booted
rdetrk	jsr	shome		force clear of A
	lda	#1		select drive B
	jsr	ssel		by direct sim call
	jsr	shome		and home to force write
	lda	#<osibuf	point to start of buffer
	ldy	#>osibuf
	sta	rr+1		set pointer
	sty	rr+2
	sta	osipnt		also set pointer for convert
	sty	osipnt+1
	sta	osimax		now calculate end+1
	tya
	clc
	adc	seclng		by adding number pages
	sta	osimax+1
	jsr	rdytrk		get ready to read
	bne	rdeerr		wrong track error
tryv	jsr	rd1byt		get next byte
	cmp	#'v'		see if v
	bne	tryv		loop until is
	jsr	rd1byt		and another
	cmp	sector		compare to desired
	bne	rdeerr		error if incorrect
	jsr	rd1byt		get sector length
	sta	seclng		and save
	tax			make a counter
	ldy	#0		clear index
rdelpe	lda	#%00000001	get mask for ready
tstflp	bit	flpdta-1	test acia
	beq	tstflp		loop if not ready
	lda	flpdta		get byte
	bvs	rdeerr		parity error
rr	sta	$ffff,y		put in memory
	iny			bump index
	bne	rdelpe		loop if more in page
	inc	rr+2		bump pointer
	dex			drop page count
	bne	rdelpe		loop if more pages
	jsr	unldhd		un load head
	lda	#<osibuf	point to start of buffer
	ldy	#>osibuf
	sta	osimax		now calculate end+1
	tya
	clc
	adc	seclng		by adding number pages
	sta	osimax+1
	lda	#0		select drive 0 again
	jsr	ssel
	jmp	shome		and home it
;read error
rdeerr	jsr	unldhd		un load head
	lda	#0		select drive 0 again
	jsr	ssel
	jsr	shome		and home it
	lda	#3		read error
	jmp	ftlerr		do as fatal error
;seek track in track
; if ok then c=0 else c=1
seek	lda	track		get next
	cmp	#numtrk		compare to number
	bcc	*+3		ok if less
	rts			else err r
tkcmp	lda	track		get next
	cmp	curtrk		compare to current
	beq	sttg43		if same set current
	bcc	goout		if smaller go out
	jsr	stepin		else g  in one
	inc	curtrk		bump current
	bpl	tkcmp		loop to check
goout	jsr	stepot		step once
	dec	curtrk		drop track
	bpl	tkcmp
sttg43	cmp	#44		see if > 43
	lda	flpcnt		get bit
	and	#%10111111	clear for > 43
	bcs	isgt43		it is
	ora	#%01000000	set for 0 to 43
isgt43	sta	flpcnt		set
	clc			and say ok
	rts
;data area
;messages
opnmsg	.byt	'Convert OSI BASIC file to DOS/65'
	.byt	cr,lf,'Version 2.00$'
spcmsg	.byt	cr,lf,'Add spaces around tokens? [y/n] $'
trkmsg	.byt	cr,lf,'Enter first track of OSI file [1-76] $'
conmsg	.byt	cr,lf,'Continue? [y/n] $'
crlmsg	.byt	cr,lf,'$'
eofmsg	.byt	cr,lf,'End of conversion$'
;buffers
;console input buffer
conbuf	.byt	127		maximum line length
conlng	.byt	0		input line length
contxt	*=	*+128
;dos/65 buffer
dosbuf	*=	buflng*128+*
bufmax
;osi sector buffer
osibuf
	.end
