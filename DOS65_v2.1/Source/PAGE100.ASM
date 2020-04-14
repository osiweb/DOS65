	module	main
	heading DOS/65 PAGE V1.00-S 14 Aug 2014
	inclist	on
	pw	132
	pl	59
	case	off
	chip	65C02
	globals	on
;********************************************************
;*							*
;*	    FILE SCREEN PAGING UTILITY			*
;*							*
;********************************************************
;
;released:	14 August 2014 (1.00)
;last revision:
;
;DOS/65 definitions
pzstrt	equ	2		;start of page zero storage
WBOOT	EQU	$100		;REBOOT ENTRY POINT
PEM	EQU	$103		;CPM ENTRY POINT
TFCB	EQU	$107		;TRANSIENT PROGRAM FCB
tea	equ	$200		:TEA start
;DOS/65 PEM commands
charout	equ	2		;send character to console
charin	equ	6		;get input key without echo
STRING	EQU	9		;STRING PRINT FUNCTION
STATUS	EQU	11		;CONSOLE STATUS FUNCTION
OPEN	EQU	15		;OPEN FUNCTION CODE
READ	EQU	20		;READ FUNCTION CODE
SetBuf	equ	26		;set buffer address
;display definitions
PAGE	EQU	23		;LINES/PAGE
WIDTH	EQU	79		;CHARACTERS/LINE
;character definitions
ctlc	equ	3		;control-c
TAB	EQU	9		;ASCII TAB
ALF	EQU	$a		;ASCII LINE FEED
ACR	EQU	$d		;ASCII CARRIAGE RETURN
eof	equ	$1a		;end of file
ESC	EQU	$1b		;ASCII ESCAPE
SPACE	EQU	$20		;ASCII SPACE
;
	page0
;page zero variable storage
	org	pzstrt
line	defs	1		;screen row
col	defs	1		;screen column
bufpos	defs	1		;disk buffer (0-127 valid - 128=wrap)
	ends
;
;code section
	ORG	tea
	ldx	#$ff		;set stack so must
	txs			;exit with warm boot
	lda	#<opnmsg	;point to welcome message
	ldy	#>opnmsg
	jsr	message		;send it
	lda	#<buffer	;change to local buffer
	ldy	#>buffer
	ldx	#SetBuf
	jsr	pem
	lda	#<tfcb		;point to FCB
	ldy	#>tfcb
	ldx	#OPEN		;FILE OPEN FUNCTION
	jsr	PEM
	bpl	openok		;if OK
	jmp	ERROR1		;IF ERROR, EXIT
openok	jsr	RESET
	lda	#128		;set disk buffer pointer
	sta	bufpos		;to wrapped value
LOOP	jsr	FetchByte	;GET NEXT BYTE FROM FILE
	bcc	fetchok		;ok if c=0
	jmp	ERROR2		;error if c=1
fetchok	cmp	#eof		;see if text eof
	bne	noteof		;ok if not eof
	jmp	EXIT		;but if is done
noteof	cmp	#ACR		;see if cr
	bne	notacr		;ok if not
	jmp	CRET		;if is UPDATE COLUMN COUNT
notacr	cmp	#ALF		;see if lf
	bne	notalf		;if not OK
	jmp	LFEED		;but if is uPDATE LINE COUNT
notalf	cmp	#TAB		;see if tab
	beq	TABloop		;if is expand
	cmp	#SPACE		;ANOTHER CONTROL CHARACTER?
	bcs	DISPLAY		;NO, PRINT CHARACTER
	jmp	LOOP		;YES, IGNORE IT
;
;expand tab modulo 8
TABLOOP	lda	#space		;GET A SPACE
	jsr	FeedDisplay	;DISPLAY IT
	lda	col		;GET CURRENT COLUMN
	AND	#00000111b	;MOD 8, AT TAB STOP?
	bne	TABLOOP		;NO, ANOTHER SPACE
	jmp	LOOP
;
DISPLAY	jsr	FeedDisplay	;DISPLAY THE CHARACTER
	jmp	LOOP
;
;zero column and echo cr
CRET	lda	#0
	sta	COL		;RESET COLUMN COUNT
	lda	#ACR		;GET A CARRIAGE RETURN
	jmp	DISPLAY
;
;bump line count and pause if page
LFEED	lda	LINE		;GET LINE COUNT
	cmp	#PAGE		;SCREEN FULL?
	beq	NEXTPAGE	;YES, WAIT FOR KEYPRESS
	INC	line		;NO, BUMP LINE COUNT
	lda	#ALF		;GET A LINE FEED
	jmp	DISPLAY
;
NEXTPAGE
	jsr	KEYLOOP		;WAIT FOR KEYPRESS
	lda	#ALF		;GET A LINE FEED
	jmp	DISPLAY
;
;At page end wait for console key entry.
;Clear pending char without echo but if
;control-c exit the program.
KeyLoop	ldx	#status		;check status
	jsr	PEM
	beq	keyloop		;loop if no key
	ldx	#charin		;else get key
	jsr	PEM
	cmp	#ctlc		;see if ctl-c
	bne	reset		;ignore if not
	jmp	wboot		;else do warm boot
;Initialize display position
RESET	lda	#0
	sta	LINE		;RESET LINE COUNT
	sta	COL		;RESET COLUMN COUNT
	rts
;
;Send characters to feed display and check for line wrap
;and adjust as needed.
FeedDisplay
	pha			;save char
	jsr	chartopem	;send to console
	pla			;get character back
	cmp	#space		;see if cr or lf
	bcc	cont		;if so do not change position
	inc	col		;else bump column
	lda	col		;get it
	cmp	#width		;see if at EOL
	bne	cont		;if not continue
	lda	#acr		;else send cr
	jsr	chartopem	;to console
	lda	#0		;now clear col
	sta	col
	lda	line		;now get line
	cmp	#page		;see if page end page
	bne	cont2		;if not OK
	jsr	keyloop		else wait for response
cont2	lda	#alf		;then get lf
	jsr	chartopem	;send it
	inc	line		;and bump line
cont	rts			;else done
;
;send character to PEM for console
chartopem:
	ldx	#charout	;send to console
	jsr	pem		;send to console
	rts
;
EXIT	lda	#<MESSG4	;POINT TO EOF MESSAGE
	ldy	#>messg4
error	jsr	MESSAGE		;send it
done	jmp	wboot		;then do warm boot
;file read error
ERROR2	lda	#<MESSG2	;POINT TO READ MESSAGE
	ldy	#>messg2
	jmp	error
;error opening file
ERROR1	lda	#<MESSG1	;POINT TO OPEN MESSAGE
	ldy	#>messg1
	jmp	error
;normal message output for message at ay
MESSAGE	ldx	#STRING		;DISPLAY THE MESSAGE
	jsr	PEM
	rts			;and return
;
;ROUTINE TO READ A BYTE
FetchByte:
	ldy	bufpos		;get index
	bmi	NextBlock	;if invalid read new block
	lda	buffer,y	;else get character
	and	#01111111b	;clear msb in case
	inc	bufpos		;bump index
	clc			;clear carry
	rts			;and return with char
NextBlock:
	lda	#<tfcb		;point to fcb
	ldy	#>tfcb
	ldx	#read		;do read
	jsr	pem		;record
;return codes are as follows:
;a=0 OK
;a=1 physical EOF
;a=2 read from unwritten block
;a=255 error
	cmp	#255		;check for error
	beq	inerror		;error = error of course
	cmp	#2		;text file should never
	beq	inerror		;have unwritten block
;next two conditions are good so reset index
	ldy	#0		;point index to start
	sty	bufpos
	cmp	#0		;check for normal read
	beq	FetchByte	;if so go to start
	lda	#eof		;only condition left is eof
	sta	buffer		;so stuff EOF into buffer
	jmp	FetchByte	;and start over
;error during read
INERROR	sec			;SET CARRY
	rts
;
;messages
opnmsg	DEFB	'DOS/65 TYPE TEXT FILE BY PAGE V1.00',acr,alf,'$'
MESSG1	DEFB	acr,alf,'**** File Open Error ****',ACR,ALF,'$'
MESSG2	DEFB	acr,alf,'**** File Read Error ****',ACR,ALF,'$'
MESSG4	DEFB	acr,alf,'**** End of Input File Reached ****',acr,alf,'$'
;
;disk buffer
buffer	defs	128
;
	END
