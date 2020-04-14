;more
;Version 2.02-S
;released:	17 july 1983
;last revision:
;	8 april 2008
;		converted to TASM & ASM21x format
;		eliminated use of page zero 0 & 1
;		added tea as parameter
;		added opening message
;	28 february 2011
;		added parameter pzstrt
;		changed page zero def & init to use pzstrt
;		expanded opening message
;sends a screen full of data to the terminal at a time
;and waits for user to type a space before sending
;another screen full to the console.  if user
;types a ctl-c then execution will be halted.
;dos/65 references
pzstrt	=	$2		;start of free page zero RAM
boot	=	$100		;warm boot entry
PEM	=	$103		;pem entry
FCB	=	$107		;default fcb
BUF	=	$128		;default buffer
TEA	=	$200		;tea start address
;fixed parameters
NULL	=	0		;null
CTLC	=	3		;interrupt
CTLI	=	9		;tab
LF	=	$A		;linefeed
FF	=	$C		;formfeed
CR	=	$D		;return
EOF	=	$1A		;end of file
;page zero storage
	*=	pzstrt
MAXLIN				;max lines/page
	*=	*+1
maxchr				;max char/line
	*=	*+1
CHRCNT				;char count
	*=	*+1
LNCNT				;line count
	*=	*+1
BUFPNT				;buffer pointer
	*=	*+1
DFLDRV				;default drive
	*=	*+1
nrmvid				;normal video char
	*=	*+1
invvid				;invert video char
	*=	*+1
LZ
;main program
	*=	TEA
	JSR	CLRVAR		;clear variables
	lda	#<opnmsg	;send opening banner
	ldy	#>opnmsg
	jsr	strout
	LDX	#25		;get default
	JSR	PEM		;drive
	STA	DFLDRV		;and save
	JSR	TSTAMB		;test for afn
	BCS	EXIT		;done if bad
	JSR	OPENFL		;open file
	BCS	EXIT		;exit if can't
	jsr	setcdb		;get cdb contents
	JSR	PRINT		;print file
EXIT	LDA	DFLDRV		;get default
	LDX	#14		;and set
	JMP	PEM		;and return
;opening message
opnmsg	.byte	"DOS/65 MORE V2.02-S",cr,lf,"$"
;subroutines
;test for afn
TSTAMB	LDX	#11		;point to name
	LDA	#'?'		;if any char
TSTMRE	CMP	FCB,X		;a question
	BEQ	ISAFN		;then error
	DEX			;else try
	BNE	TSTMRE		;next until done
	CLC			;say ok
	RTS			;and quit
ISAFN	LDA	#<AMBMSG	;point to
	LDY	#>AMBMSG	;message
	JSR	STROUT		;send
	SEC			;say bad
	RTS			;and quit
AMBMSG	.byte	"NAME IS AMBIGUOUS!$"
;clear variables
CLRVAR	LDX	#pzstrt		;start
	LDA	#0		;clear A
CLRMRE	STA	0,X		;store 0
	INX			;bump index
	CPX	#LZ		;see if wrap
	BNE	CLRMRE		;loop if not
	RTS
;open file
OPENFL	LDX	#15		;try to
	JSR	SETFCB		;open
	BMI	BADFIL		;quit if bad
	CLC			;say ok
	RTS			;and quit
BADFIL	LDA	#<ERRMSG	;point to
	LDY	#>ERRMSG	;message
	JSR	STROUT		;send and
	SEC			;return
	RTS			;as error
ERRMSG	.byte	"CAN NOT OPEN!",CR,LF,"$"
;get contents of cdb from sim
setcdb	lda	boot+2		;get sim page
	sta	conout+2	;set console output page
	sta	coninp+2	;and input page
	sta	getlin+2	;then set addresses
	sta	getcln+2
	sta	getnrm+2
	sta	getinv+2
getlin	lda	$ff3c		;get lines per screen
	sta	maxlin
	dec	maxlin		;now drop to allow overlap
	dec	maxlin
getcln	lda	$ff3d		;get char per line
	sta	maxchr
getnrm	lda	$ff3a		;get normal video
	sta	nrmvid
getinv	lda	$ff3b		;get invert video
	sta	invvid
	rts
;print file
PRINT	LDA	#128		;set buffer index
	STA	BUFPNT		;to illegal
NXTCHR	JSR	GETCHR		;get char
	BCS	DONE		;done if end
	CMP	#EOF		;or if
	BEQ	DONE		;eof
	CMP	#CTLI		;if not tab
	BNE	NOTHT		;try cr
TABIT	JSR	SPCOUT		;else send space
	LDA	CHRCNT		;get count
	AND	#7		;if not mod 8
	BNE	TABIT		;loop
	BEQ	NXTCHR		;else get next char
NOTHT	CMP	#CR		;if not a cr
	BNE	NOTCR		;continue
	LDA	#0		;clear
	STA	CHRCNT		;char count
	LDA	LNCNT		;if line count
	CMP	MAXLIN		;at max
	bcs	PGEND		;end page
	LDA	#CR		;get cr again
	BNE	sendit		;and go send
pgend	jsr	coninp		;get input from sim
	cmp	#' '		;see if space
	beq	contin		;if so keep going
	cmp	#ctlc		;see if ctl-c
	bne	pgend		;else try again
	beq	done		;exit if was
contin	lda	#0
	sta	lncnt		;clear counters
	lda	#cr		;now send the cr
	bne	sendit		;to screen
notcr	cmp	#lf		;see if lf
	bne	notlf		;if not continue
	inc	lncnt		;else bump line count
	bne	sendit		;then go print
notlf	cmp	#' '		;see if other control
	bcs	sendit		;if not just send
	pha			;then save char
	lda	invvid		;get invert video
	jsr	chrout		;and send it
	pla			;get char back
	ora	#'@'		;make printing
	jsr	chrout		;then send it
	lda	nrmvid		;then get normal
sendit	jsr	chrout		;send char
	jmp	nxtchr		;and loop
done	rts
;pem file references
SETFCB	LDA	#<FCB		;point
	LDY	#>FCB		;to fcb
	JMP	PEM		;and execute
;get char from buffer
GETCHR	LDX	BUFPNT		;get index
	BPL	NOREAD		;use if ok
	LDX	#20		;else read
	JSR	SETFCB		;next record
	BNE	RDEERR		;error if not zero
	TAX			;set index
	STX	BUFPNT		;to zeror
NOREAD	INC	BUFPNT		;bump for next
	LDA	BUF,X		;get char
	AND	#$7F		;clear msb
	CLC			;say ok
	RTS			;and quit
RDEERR	LDA	#<RERMSG	;point to
	LDY	#>RERMSG	;error message
	JSR	STROUT		;and send
	SEC			;say end
	RTS			;and quit
RERMSG	.byte	CR,LF,"FILE READ ERROR!$"
;string output
STROUT	LDX	#9
	JMP	PEM
;console output
conout	jmp	$ff0c		;send direct to sim
;console input
coninp	jmp	$ff09		;get from sim
;character output routines
SPCOUT	LDA	#' '		;get a space
chrout	PHA			;save again
	JSR	CONOUT		;send
	PLA			;get once more
	CMP	#' '		;if control
	BCC	CHREXT		;done
	INC	CHRCNT		;else bump count
	lda	chrcnt		;get count
	cmp	maxchr		;see if too big
	bcc	chrext		;exit if not
	inc	lncnt		;else bump line counter
	lda	#0		;then clear char counter
	sta	chrcnt
CHREXT	RTS			;quit
	.END
