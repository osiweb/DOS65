;program to read osi directory
;version 2.01
;released:	17 july 1983
;last revision:
;	26 may 2008
;		converted to TASM & ASM 2.11 format
;		moved page zero start to 2
;		changed parameters to 5 inch
;fixed definitions
boot	=	$100		;warm boot entry
pem	=	$103		;pem entry
;constants
cr	=	$d		;carriage return
lf	=	$a		;linefeed
numtrk	=	40		;number of tracks
stprte	=	8		;step rate in ms
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
savex				;save for x
	*=	*+1
savey				;save for y
	*=	*+1
outenb				;output enable flag
	*=	*+1
numsec				;number sectors to read
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
seclng				;sector length in pages
	*=	*+1
secnum				;sector number
	*=	*+1
sctosk				;sectors to skip
	*=	*+1
;start of main program
	*=	$200
	lda	boot+2		;get sim page
	sta	shome+2		;set page for direct home
	sta	ssel+2		;and select drive
	lda	#0		;enable output
	sta	outenb
	lda	#<opnmsg	;point to opening message
	ldy	#>opnmsg
	jsr	msgout		;send it
	ldx	#13		;reset system
	jsr	pem
	lda	#0		;select A
	jsr	seldrv
	jsr	setspd		;determine cpu speed
;set starting track and sector
	lda	#8		;track 8
	sta	track
	lda	#1		;sector 1 is first
	sta	sector
	lda	#2		;read two sectors total
	sta	numsec
	jsr	shome		;force clear of A
	lda	#1		;select drive B
	jsr	ssel		;by direct sim call
	jsr	shome		;and home to force write
nxtsec	jsr	rdetrk		;try to read
	bcc	ordeok		;continue if ok
	lda	#0		;else read error
	jmp	ftlerr
ordeok	ldx	#0		;clear index
;do one entry
dirlpe	jsr	crlf		;send cr and lf
	lda	#0		;enable output
	sta	outenb
	lda	osibuf,x	;get first char
	inx			;bump index
	cmp	#'#'		;see if empty flag
	bne	nosend		;no output if is
	ldy	#128		;else disable output
	sty	outenb
nosend	jsr	outsxy		;send first
	ldy	#5		;repeat for five more
sendnm	lda	osibuf,x	;get char
	jsr	outsxy		;send
	inx			;bump index
	dey			;and drop count
	bne	sendnm		;loop if more
	lda	#9		;else send tab
	jsr	outsxy
	lda	osibuf,x	;get first track
	inx			;bump index
	jsr	outbcd		;send as bcd
	lda	#'-'		;now send dash
	jsr	outsxy		;to screen
	lda	osibuf,x	;get last
	jsr	outbcd		;send as bcd
	inx			;bump index
	bne	dirlpe		;loop if more in buffer
	inc	sector		;else bump sector
	dec	numsec		;drop count
	bne	nxtsec		;loop if more
exit	lda	#0		;select drive 0
	jsr	ssel
	jsr	shome		;and home
	jmp	boot		;return with boot
;subroutines
;sim entries
shome	jsr	24		;sim home offset
	jmp	home		;then home for local
ssel	jmp	27		;sim select drive offset
;pem entries
msgout	ldx	#9		;get operation number
	jmp	pem		;go do it
;output bcd value
outbcd	pha			;save byte
	lsr	a
	lsr	a
	lsr	a
	lsr	a		;move high to low
	jsr	outnib		;send
	pla			;get byte back
;output bcd nibble
outnib	and	#$f		;clear msn
	ora	#'0'		;make a number in ascii
;single character output with save of x and y
outsxy	stx	savex		;save x
	sty	savey		;save y
	ldx	#2
	bit	outenb		;test flag
	bmi	noout		;skip if set
	and	#$7f		;clear msb
	jsr	pem		;else do output
noout	ldy	savey		;get y
	ldx	savex		;and x
	rts
;select drive in a
seldrv	ldx	#14
	jmp	pem
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
;error messages
erm000	.byte	"OSI read error$"
;fatal error
ftlerr	jsr	error		;send message
	jmp	exit		;then exit
;output cr and lf to console
crlf	lda	#cr
	jsr	outsxy		;send cr
	lda	#lf		;then lf
	jmp	outsxy
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
	rts			;else err r
tkcmp	lda	track		;get next
	cmp	curtrk		;compare to current
	beq	sttg43		;if same set current
	bcc	goout		;if smaller go out
	jsr	stepin		;else g  in one
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
opnmsg	.byte	"Read OSI Directory"
	.byte	cr,lf,"Version 2.01$"
crlmsg	.byte	cr,lf,"$"
;buffers
;osi sector buffer
osibuf
	.end
