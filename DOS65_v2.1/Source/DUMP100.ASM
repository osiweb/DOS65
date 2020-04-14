;DUMP
;reads input file and displays hex data
;released:	26 February 2015
;
;DOS/65 parameters
pzstrt	=	16			;get past swap area
pem	=	$103			;dos entry point
DflFCB	=	$107			;file control block address
fcbcr	=	DflFCB+32		;current (next) record number (0 to 127)
DflBuf	=	$128			;input disk buffer address
tea	=	$200
;DOS/65 PEM functions
cons	=	1			;read console
typef	=	2			;type function
printf	=	9			;buffer print entry
brkf	=	11			;break key function (true if char ready)
openf	=	15			;file open
readf	=	20			;read function
;
;ASCII non graphic characters
ctlc	=	3			;control C
cr	=	13			;carriage return
lf	=	10			;line feed
;
;page zero storage
*	=	pzstrt
ibp					;pointer into input
	*=	*+1
chrnum					;character position in line
	*=	*+1
linnum					;line counter
	*=	*+2
;start of code section
*	=	tea
;start with sign on message
	lda	#<signon
	ldy	#>signon
	jsr	MsgOut
;read and print successive buffers
	jsr	setup			;set up input file
	cmp	#255			;255 if file not present
	bne	openok			;skip if open is ok
;file not there, give error message and return
	lda	#<opnmsg		;point to message
	ldy	#>opnmsg
	jsr	MsgOut
	jmp	finis			;to return
;open operation ok, set buffer index to end and set counters
openok	lda	#128
	sta	ibp			;set buffer pointer to 128
	lda	#0
	sta	chrnum			;clear pointers
	sta	linnum
	sta	linnum+1
gloop	jsr	gnb			;get next byte
	bcs	finis			;carry set by gnb if end file
	pha				;save char
;print hex values
;check for line fold
	lda	chrnum
	and	#%00001111		;check low 4 bits
	bne	nonum
;print line number
	jsr	crlf
;check for break key
	jsr	break
;A <> 0 if character ready
	bne	finis			;don't print any more
;
	lda	linnum+1
	jsr	phex
	lda	linnum
	jsr	phex
nonum	inc	linnum			;to next line number
	bne	L01
	inc	linnum+1
L01	lda	#' '
	jsr	pchar
	pla				;get char back
	jsr	phex
	inc	chrnum			;bump character number
;pause after 16 lines or every 256 characters
	lda	chrnum			;get counter
	bne	gloop
	lda	#<pause			;send pause message
	ldy	#>pause
	jsr	MsgOut
ploop	ldx	#6
	jsr	pem
	cmp	#ctlc			;see if control-c
	beq	finis			;if so quit else
	cmp	#' '			;see if space
	bne	ploop			;loo[ if not
	jmp	gloop
;
;end of dump
finis	jsr	crlf
	ldx	#0
	jmp	PEM			;do warm boot
;
;subroutines
;check break key (actually any key will do)
break	ldx	#brkf
	jmp	pem
;
;send cr and lf to console
crlf	lda	#cr
	jsr	pchar
	lda	#lf
;print a character
pchar	ldx	#typef
	jmp	pem
;
;print nibble in a
pnib	and	#%00001111		;low 4 bits
	ora	#'0'
	cmp	#'9'+1
	bcc	p10
;greater than '9'
	adc	#6
;greater or equal to 10
p10	jmp	pchar
;
;print hex char in reg a
phex	pha				;save char
	lsr	a
	lsr	a
	lsr	a
	lsr	a
	jsr	pnib	;print nibble
	pla
	jmp	pnib
;
;print message at AY
MsgOut	ldx	#printf			;print buffer function
	jsr	pem
	rts

;
;get next byte
gnb	ldx	ibp
	cpx	#128
	bne	g0
;read another buffer
	lda	#0			;clear index
	sta	ibp
	jsr	diskr
	cmp	#0			;zero value if read ok
	beq	g0			;for another byte
;end of data, return with carry set for eof
	sec
	rts
;read the byte at DflBuf+x
g0	ldx	ibp			;get index
	inc	ibp			;bump index for next
	lda	DflBuf,x		;get byte
	clc				;reset carry bit
	rts
;
;set up file 
;open the file for input
setup	lda	#0			;zero to accum
	sta	fcbcr			;clear current record
	lda	#<DflFCB
	ldy	#>DflFCB
	ldx	#openf
	jsr	pem
;255 in accum if open error
	rts
;
;read disk file record
diskr	lda	#<DflFCB
	ldy	#>DflFCB
	ldx	#readf
	jmp	pem
;
;	fixed message area
pause	.byte	cr,lf,'PRESS SPACE BAR TO CONTINUE - CTL-C TO ABORT$'
signon	.byte	'DOS/65 FILE DUMP V1.00$'
opnmsg	.byte	cr,lf,'NO INPUT FILE FOUND$'
;
	.end
