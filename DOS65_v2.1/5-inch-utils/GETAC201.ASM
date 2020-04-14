;program to interactively read osi ascii files and convert them to
;dos/65 format.
;version 2.01
;released:	17 july 1983
;last revision:
;	26 may 2008
;		converted to TASM & ASM 211 format
;		changed to 5 inch parameters
;		changed page zero start to 2
;fixed definitions
boot	=	$100		;warm boot entry
pem	=	$103		;pem entry
dflfcb	=	$107		;default fcb
dflbuf	=	$128		;default buffer
;constants
cr	=	$d		;carriage return
lf	=	$a		;linefeed
;next two parameters change as a function of OS65D disk size
;comments show values for 5.25 inch and 8 inch
numtrk	=	40		;number of OS65D tracks (40 or 77)
numsec	=	8		;number of OS65D sectors (8 or 13)
stprte	=	8		;step rate in ms
eof	=	$1a		;eof character
buflng	=	8		;records in dos/65 buffer
;disk controller definitions
;pia
flpsts	=	$c000		;status port
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
flpdta	=	$c011		;data port
;page zero data area
	*=	2
temp				;temporary
	*=	*+1
rectwr				;records to write
	*=	*+1
speed				;cpu speed constant (49=1 mhz)
	*=	*+1
track				;track to read
	*=	*+1
curtrk				;current track
	*=	*+1
sector				;sector to read
	*=	*+1
bcdtrk				;track in bcd
	*=	*+1
tmpbcd				;temp in hexbcd
	*=	*+1
drive				;drive selected
	*=	*+1
seclng				;sector length in pages
	*=	*+1
secnum				;sector number
	*=	*+1
number				;number result of decimal input
	*=	*+1
sctosk				;sectors to skip
	*=	*+1
bufpnt				;pointer into dosbuf
	*=	*+2
osipnt				;pointer into osibuf
	*=	*+2
osimax				;max value of osipnt
	*=	*+2
reccnt				;record counter for write
	*=	*+1
;start of main program
	*=	$200
	lda	boot+2		;get sim page
	sta	shome+2		;set page for direct home
	sta	ssel+2		;and select drive
	lda	#buflng		;get default buffer length
	sta	rectwr
	jsr	intbuf		;set pointer to start
	jsr	fileof		;fill buffer with eof
	lda	#<opnmsg	;point to opening message
	ldy	#>opnmsg
	jsr	msgout		;send it
	lda	dflfcb+1	;get first char in name
	cmp	#' '		;see if a space
	bne	nmeok		;ok if not
	lda	dflfcb+9	;get first char of type
	cmp	#' '		;see if a space
	bne	nmeok		;ok if not
	lda	#0		;else illegal name error
	jmp	ftlerr		;else fatal illegal name error
nmeok	jsr	tstamb		;test for afn
	bcc	isufn		;ok if ufn
	lda	#5
	jmp	ftlerr		;else is fatal error
isufn	ldx	#13		;reset system
	jsr	pem
	lda	#0		;select drive A
	sta	dflfcb		;force dos/65 to a
	jsr	seldrv
	jsr	dltfle		;delete file if it exists
	jsr	crtfle		;then go create it
	jsr	setspd		;determine cpu speed
	jmp	askftr		;ask for track
;determine if to continue
askcon	lda	#<conmsg	;ask for continue or not
	ldy	#>conmsg
	jsr	msgout
	jsr	coninp		;get result
	cmp	#'N'		;see if stop code
	beq	nrmext		;exit if is
	cmp	#'Y'		;see if continue
	bne	askcon		;try again if not
;determine track and sector
askftr	lda	#<trkmsg	;ask for first track
	ldy	#>trkmsg
	jsr	msgout
	jsr	rdedec		;then get answer
	jsr	chklgt		;check for legal track
	bcs	askcon		;if error try again
	sta	track		;save for seek and read
askfsc	lda	#<secmsg	;ask for sector
	ldy	#>secmsg
	jsr	msgout
	jsr	rdedec		;then get answer
	jsr	chklgs		;check for legal sector
	bcs	askcon		;if error try again
	sta	sector		;save for read
	jsr	shome		;force clear of A
	lda	#1		;select drive B
	jsr	ssel		;by direct sim call
	jsr	shome		;and home to force write
	jsr	rdetrk		;try to read
	bcc	ordeok		;continue if ok
	lda	#3		;else read error
	jsr	error
	jmp	askftr		;then try again
ordeok	jsr	convrt		;convert to dos/65
	bcc	askcon		;try another if not eof
	lda	#<eofmsg	;else say eof read
	ldy	#>eofmsg
	jsr	msgout
nrmext	lda	#0		;select drive 0
	jsr	ssel
	jsr	shome		;and home
	jsr	incbpt		;make sure at least one eof
	sec			;first determine
	lda	bufpnt		;distance modulo 128
	sbc	#<dosbuf	;that pointer is from start
	and	#$7f
	beq	nodmmy		;if zero no delta needed
	eor	#$ff		;complement
	tax			;and add one
	inx
adddmy	jsr	incbpt		;bump pointer by one
	dex			;drop count
	bne	adddmy		;loop if more
nodmmy	sec			;calculate length of buffer
	lda	bufpnt
	sbc	#<dosbuf
	sta	bufpnt
	lda	bufpnt+1
	sbc	#>dosbuf
	sta	bufpnt+1
	ldx	#7		;divide by 128
	lda	bufpnt
shftbp	lsr	bufpnt+1	;to calculate number records
	ror	a
	dex
	bne	shftbp
	sta	rectwr		;save as length
	jsr	dmpbuf		;write records
	jsr	clsfle		;close file
	jmp	boot		;return with boot
;subroutines
;test fcb for ambiguous file name
;if afn return with c=1 else c=0
tstamb	ldx	#1		;set index
tamlpe	lda	dflfcb,x	;get char
	cmp	#'?'		;see if ?
	beq	isafn		;if so is afn
	inx			;bump index
	cpx	#12		;see if end
	bne	tamlpe		;loop if not
	clc			;else say ok
isafn	rts
;convert contents of buffer to dos/65
convrt	lda	#0		;select drive 0 again
	jsr	ssel
	jsr	shome		;and home it
	lda	#<osibuf	;set osi pointer to start
	ldy	#>osibuf
	sta	osipnt
	sty	osipnt+1
	sta	osimax		;now calculate end+1
	tya
	clc
	adc	seclng		;by adding number pages
	sta	osimax+1
cnvrlp	ldy	#0		;clear index
	lda	(osipnt),y	;get char
	beq	cnveof		;eof if null
	cmp	#cr		;see if a return
	bne	usasis		;if not use as is
	jsr	outdos		;else send it
	lda	#lf		;then send a linefeed
usasis	jsr	outdos		;send to buffer
	inc	osipnt		;bump pointer
	bne	*+4
	inc	osipnt+1
	lda	osipnt		;check low
	cmp	osimax
	bne	cnvrlp		;loop if not there
	lda	osipnt+1	;check high
	cmp	osimax+1
	bne	cnvrlp		;loop if more
	clc			;clear of no eof
	rts			;else all converted
cnveof	sec			;say eof
	rts
;output char in a to dos/65 buffer and
;write buffer as needed.
outdos	ldy	#0		;clear index
	sta	(bufpnt),y	;put in buffer
	jsr	incbpt		;bump pointer
	lda	bufpnt		;compare pointer to max
	cmp	#<bufmax
	bne	extout		;done if not there
	lda	bufpnt+1	;same for high
	cmp	#>bufmax
	bne	extout		;exit if zero
dmpbuf	jsr	intbuf		;setup pointer again
	lda	rectwr		;get records in buffer
	sta	reccnt		;set counter
	beq	intbuf		;exit if zero
movrec	ldy	#0		;clear index
movlpe	lda	(bufpnt),y	;get char
	sta	dflbuf,y	;put in buffer
	iny			;bump index
	bpl	movlpe		;loop if more
	jsr	wrtfle		;write sector
	clc			;add 128 to pointer
	lda	bufpnt
	adc	#128
	sta	bufpnt
	bcc	*+4
	inc	bufpnt+1
	dec	reccnt		;drop counter
	bne	movrec		;loop if more records
	jsr	fileof		;now fill buffer with eof
;set bufpnt to start of dosbuf
intbuf	lda	#<dosbuf	;get start
	ldy	#>dosbuf
	sta	bufpnt		;then set
	sty	bufpnt+1
extout	rts
;fill dos/65 buffer with eof
fileof	jsr	intbuf		;set pointer to start
	ldx	#buflng		;get number records
fill0	ldy	#0		;clear index
	lda	#eof		;get eof char
fill1	sta	(bufpnt),y	;insert char
	iny			;bump index
	bpl	fill1		;loop until end of record
	clc			;now bump pointer
	tya
	adc	bufpnt
	sta	bufpnt
	bcc	*+4
	inc	bufpnt+1
	dex			;drop record counter
	bne	fill0		;loop until all full
	jmp	intbuf		;set pointer back to start
;bump dos/65 buffer pointer by one
incbpt	inc	bufpnt
	bne	*+4
	inc	bufpnt+1
	rts
;sim entries
shome	jsr	24		;sim home offset
	jmp	home		;then home for local
ssel	jmp	27		;sim select drive offset
;pem entries
msgout	ldx	#9		;get operation number
	jmp	pem		;go do it
;read console input line
rdelin	lda	#<conbuf	;point to buffer
	ldy	#>conbuf
	ldx	#10		;do read
	jmp	pem
;single character input with echo
coninp	ldx	#1
	jsr	pem		;read char
	cmp	#'a'		;if lower case convert
	bcc	notlwr		;it isn't
	cmp	#'z'+1
	bcs	notlwr		;it isn't
	and	#$5f		;convert
notlwr	rts
;select drive in a
seldrv	ldx	#14
	jmp	pem
;set dma address to value in ay
setdma	ldx	#26
	jmp	pem
;close file
clsfle	lda	#<dflfcb	;point to fcb
	ldy	#>dflfcb
	ldx	#16		;close code
	jmp	pem
;open file
opnfle	lda	#<dflfcb	;point to fcb
	ldy	#>dflfcb
	ldx	#15		;open code
	jmp	pem
;create file
crtfle	lda	#<dflfcb	;point to fcb
	ldy	#>dflfcb
	ldx	#22		;create code
	jmp	pem
;delete file
dltfle	lda	#<dflfcb	;point to fcb
	ldy	#>dflfcb
	ldx	#19		;delete code
	jmp	pem
;write to file
wrtfle	lda	#<dflfcb	;point to fcb
	ldy	#>dflfcb
	ldx	#21		;write code
	jmp	pem
;check for legal sector
;returns c=0 if legal else c=1
chklgs	beq	illgsc		;illegal if zero
	bcs	illgsc		;or if > 99
	cmp	#numsec		;compare to max
	bcs	illgsc		;error if too big
	rts
illgsc	lda	#4		;illegal sector error
	jsr	error
	sec			;set error code
	rts
;check for legal track
;returns c=0 if legal else c=1
chklgt	beq	illgtr		;illegal if zero
	bcs	illgtr		;or if > 99
	cmp	#numtrk		;compare to max
	bcs	illgtr		;error if too big
	rts
illgtr	lda	#1		;illegal track error
	jsr	error
	sec			;set error code
	rts
;general error handler
error	pha			;save error number
	lda	#<errmsg	;send general message
	ldy	#>errmsg
	jsr	msgout
	pla			;get error code back
	asl	a		;make an index
	tax
	lda	errtbl,x	;get message address
	ldy	errtbl+1,x
	jmp	msgout
;error table
errmsg	.byte	cr,lf,"ERROR - $"
errtbl	.word	erm000
	.word	erm001
	.word	erm002
	.word	erm003
	.word	erm004
	.word	erm005
;error messages
erm000	.byte	"Invalid file name - all blanks$"
erm001	.byte	"Illegal track number$"
erm002	.byte	"Illegal decimal number$"
erm003	.byte	"OSI read error$"
erm004	.byte	"Illegal sector number$"
erm005	.byte	"Invalid file name - ambiguous$"
;fatal error
ftlerr	jsr	error		;send message
	jmp	boot		;then reboot
;read single decimal number (0 to 99)
;if result is zero then z=1
;if result is > 99 or has illegal format then error
;message is output and retry is attempted.
rdedec	jsr	rdelin		;get console input
	ldy	#0		;clear number
	sty	number
	lda	conlng		;get length
	beq	zrores		;if zero say ok and zero
	tax			;make an index
	tya			;set a to zero
	sta	contxt,x	;and insert a zero
	dey			;drop index for loop
frsdig	iny			;bump index
	lda	contxt,y	;get character
	beq	zrores		;done if end
	cmp	#' '		;see if blank
	beq	frsdig		;loop if is
	jsr	numerc		;make sure is numeric
	beq	frsdig		;if zero is leading
	bcs	ilgdec		;if error try again
	sta	number		;save result
	iny			;point to next
	lda	contxt,y	;get char
	beq	zrores		;done if zero
	cmp	#' '		;or if space
	beq	zrores		;done
	jsr	numerc		;else check for numeric
	bcs	ilgdec		;branch if error
	ldx	number		;get tens part
	inx			;bump for count
	sta	number		;save low part
	clc			;clear accum and carry
	lda	#0
mul10	dex			;drop high
	beq	donm10		;done if zero
	adc	#10		;else add ten more
	jmp	mul10		;and loop
donm10	adc	number		;now add low
	sta	number		;and save again
	iny			;point to next 
	lda	contxt,y	;and get it
	beq	zrores		;done if zero
	cmp	#' '		;or if blank
	beq	zrores
ilgdec	lda	#2		;send error message
	jsr	error
	jsr	crlf		;send cr and lf
	jmp	rdedec		;and try again
zrores	clc			;say no overflow
	lda	number		;and get number
	rts
;check for ascii character in range 0 to 9
;if character is in 0 to 9 range then ascii part
;is pulled off, remainder is returned, and c=0.
;if not decimal then c=1.
numerc	cmp	#'0'		;see if under 0
	bcc	notnum		;if so is not decimal
	cmp	#'9'+1		;see if over 9
	bcs	notnum		;if so is not decimal
	and	#$f		;look at low nibble
	clc
	rts
notnum	sec			;set error code
	lda	#255		;ensure not zero
	rts
;output cr and lf to console
crlf	lda	#<crlmsg	;point to string
	ldy	#>crlmsg
	jmp	msgout
;determine cpu speed
setspd	jsr	loadhd		;load head
ind0	lda	flpsts		;get status
	bmi	ind0		;loop until index
ind1	lda	flpsts		;get again
	bpl	ind1		;loop until end of index
	ldx	#0		;clear counters
	ldy	#0
chkrev	lda	flpsts		;get again
	bpl	gotrev		;branch if index
	nop			;delay a bit
	inx
	bne	chkrev
	iny
	jmp	chkrev
gotrev	txa			;see if should round
	bpl	*+3		;branch if should not
	iny			;else bump speed
	sty	speed		;set speed
	jsr	unldhd
	rts
;home drive to track zero
home	lda	#0		;set next track
	sta	curtrk		;to zero
	jsr	stepin		;step head in one
	jsr	dly12m		;delay 12ms
hlp	lda	#%00000010	;mask for track zero
	bit	flpsts		;test it
	bne	*+3		;continue if not there
	rts			;else done
	jsr	stepot		;step out
	jmp	hlp		;and loop
;convert hex to bcd
hexbcd	sec			;use x
	ldx	#$ff		;as counter
hexlpe	inx			;bump counter
	sbc	#10		;drop by ten
	bcs	hexlpe		;loop if no carry
	adc	#10		;add ten back in
	sta	tmpbcd		;save that result
	txa			;get ten's
	asl	a		;shift to high
	asl	a
	asl	a
	asl	a
	ora	tmpbcd		;or with low
	rts
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
;delay 100us x times
dly100	lda	speed		;get constant
d100lp	bit	2		;waste time
	sec
	sbc	#5		;drop by five
	bcs	d100lp		;loop if more
	dex			;drop x
	bne	dly100		;loop to start
	rts
;delay=20*y+14 cycles
dlyy20	jsr	dly15		;delay 15 cycles
	dey			;drop count
	bne	dlyy20		;loop if more
	nop			;waste time
	rts
;delay=15 cycles (if z=0)
dly15	bne	*+2
;delay=12 cycles
dly12	rts
;delay=24 cycles
dly24	jsr	dly12		;do 12
	rts
;delay=12ms
dly12m	ldx	#12
;delay=xms
dlyxm	ldy	speed
	jsr	dlyy20		;do 20 cycles
	dex
	bne	dlyxm		;loop if more
	rts
;load head and wait 40 ms
loadhd	lda	#%01111111	;set load bit
	and	flpcnt		;to active
	sta	flpcnt
	ldx	#40		;delay 40 ms
	jmp	dlyxm
;unload head
unldhd	lda	#%10000000	;set load bit
	ora	flpcnt		;to inactive
	sta	flpcnt
	rts
;set up to read or write sector into buffer
;if correct z=1 else z=0
rdytrk	lda	track		;get track
	jsr	hexbcd		;convert to bcd
	sta	bcdtrk		;and save
	jsr	seek		;seek to track
	jsr	loadhd		;load head with settling delay
fndind	lda	flpsts		;read status
	bmi	fndind		;not there yet
gotind	lda	flpsts		;read again
	bpl	gotind		;loop while index
	lda	#%00000011	;master reset
	sta	flpdta-1
	lda	#%01011000	;no interrupt,rts* high,8+ep+s,/1
	sta	flpdta-1
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
;skip a sector
;reads a sector of variable length from disk
;but does not store any data.
skpsec	jsr	rd1byt		;read a byte
	cmp	#'v'		;see if start code
	bne	skpsec		;loop if not
	jsr	rd1byt		;read another and ignore
	jsr	rd1byt		;read another and ignore
	tay			;but make index
	ldx	#0		;clear byte counter
skppge	jsr	rd1byt		;get byte
	dex			;drop byte count
	bne	skppge		;loop until done
	dey			;drop page count
	bne	skppge		;loop until done
	rts
;read a byte from disk into a (ignore parity)
rd1byt	lda	flpdta-1	;get acia status
	lsr	a		;check for ready
	bcc	rd1byt		;loop if not
	lda	flpdta		;get byte
	rts
;read sector into buffer
; if ok then c=0 else c=1
rdetrk	lda	#<osibuf	;point to start of buffer
	ldy	#>osibuf
	sta	rr+1		;set pointer
	sty	rr+2
	jsr	rdytrk		;get ready to read
	bne	rdeerr		;wrong track error
	lda	sector		;get sector to read
	sta	sctosk		;save as counter
skplpe	dec	sctosk		;drop counter
	beq	tryv		;jump if done
	jsr	skpsec		;skip a sector
	beq	skplpe		;loop when done
tryv	jsr	rd1byt		;get next byte
	cmp	#'v'		;see if v
	bne	tryv		;loop until is
	jsr	rd1byt		;and another
	cmp	sector		;compare to desired
	bne	rdeerr		;error if incorrect
	jsr	rd1byt		;get sector length
	sta	seclng		;and save
	tax			;make a counter
	ldy	#0		;clear index
rdelpe	lda	#%00000001	;get mask for ready
tstflp	bit	flpdta-1	;test acia
	beq	tstflp		;loop if not ready
	lda	flpdta		;get byte
	bvs	rdeerr		;parity error
rr	sta	$ffff,y		;put in memory
	iny			;bump index
	bne	rdelpe		;loop if more in page
	inc	rr+2		;bump pointer
	dex			;drop page count
	bne	rdelpe		;loop if more pages
	clc			;else done and ok
	bcc	rdeext		;then exit
;read error
rdeerr	sec			;and error flag
;common read exit
rdeext	jmp	unldhd		;un load head
;seek track in track
; if ok then c=0 else c=1
seek	lda	track		;get next
	cmp	#numtrk		;compare to number
	bcc	*+3		;ok if less
	rts			;else error
tkcmp	lda	track		;get next
	cmp	curtrk		;compare to current
	beq	sttg43		;if same set current
	bcc	goout		;if smaller go out
	jsr	stepin		;else go in one
	inc	curtrk		;bump current
	bpl	tkcmp		;loop to check
goout	jsr	stepot		;step once
	dec	curtrk		;drop track
	bpl	tkcmp
sttg43	cmp	#44		;see if > 43
	lda	flpcnt		;get bit
	and	#%10111111	;clear for > 43
	bcs	isgt43		;it is
	ora	#%01000000	;set for 0 to 43
isgt43	sta	flpcnt		;set
	clc			;and say ok
	rts
;data area
;messages
opnmsg	.byte	"Convert OSI ASCII file to DOS/65"
	.byte	cr,lf,"Version 2.01$"
trkmsg	.byte	cr,lf,"Enter track of OSI file [1-76] $"
secmsg	.byte	cr,lf,"Enter sector to read [1-11] $"
conmsg	.byte	cr,lf,"Continue? [y/n] $"
crlmsg	.byte	cr,lf,"$"
eofmsg	.byte	cr,lf,"EOF read in file - exiting$"
;buffers
;console input buffer
conbuf	.byte	127		;maximum line length
conlng	.byte	0		;input line length
contxt	*=	*+128
;dos/65 buffer
dosbuf	*=	buflng*128+*
bufmax
;osi sector buffer
osibuf
	.end
