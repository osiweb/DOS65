;diskcopy
;version 2.05-S
;released:	17 october 1982 (2.00)
;last revision:
;	28 december 1985 (2.01)
;		made dos/65 2.1 compatible
;	18 may 1996 (2.02)
;		changed name to diskcopy
;	11 april 2008
;		reformatted for TASM 7 ASM21x
;		eliminated page zero 0 & 1
;		changed sector start to read translation for #
;		changed compare to use high nsectr
;	17 decemeber 2009
;		added parameter pzstrt
;		changed page zero def & init to use pzstrt
;	1 march 2011
;		changed opening message - split out signon
;		moved opening message
;DISKCOPY will work with all floppy disk formats
;but may not work with some hard disk formats.
;The key limitation is in the amount of memory
;needed for a single track. Since diskcopy
;works on a track at a time at least one track's
;worth of memory must be available.
;Also note that some formats, e.g., C64 1541 format
;as used by CP/M & DOS/65, have regions that
;are not included either in the data or system area. These
;regions are not copied by DISKCOPY. A copy program
;unique to those formats is required to copy the entire
;diskette.
;
;Allowable syntax forms for ccm command line are
;DISKCOPY ALL	copies data & system
;DISKCOPY DATA	copies only data
;DISKCOPY SYSTEM	copies only system
;
;DOS/65 references
pzstrt	=	$2		;start of free page zero RAM
BOOT	=	$100		;bootstrap
PEM	=	$103		;pem entry
DFLFCB	=	$107		;default fcb
DFLBUF	=	$128		;default buffer
TEA	=	$200		;transient start
;fixed parameters
CR	=	$D		;return
LF	=	$A		;linefeed
CTLC	=	3		;break
;page zero storage
	*=	pzstrt
TRK				;current track
	*=	*+2
BUFADR				;buffer address
	*=	*+2
FIRST				;first track
	*=	*+2
LAST				;last track + 1
	*=	*+2
SECT				;current sector (counter from 1 to nsectr)
	*=	*+2
hstsec				;host sector (starts at 0 or 1)
	*=	*+2
CMPERR				;compare error count
	*=	*+1
BUFPNT				;buffer pointer
	*=	*+2
SECCNT				;sector counter
	*=	*+2
dcba				;dcb address for a
	*=	*+2
dcbb				;dcb address for b
	*=	*+2
dfldrv				;default drive
	*=	*+1
maxblk				;max block number
	*=	*+2
nsectr				;number sectors
	*=	*+2
nsystr				;number system tracks
	*=	*+2
blkscd				;block size code
	*=	*+1
	*=	*+2		;max dir num (checked only)
buf1				;buf1 start
	*=	*+2
tracks				;track count
	*=	*+3
sector				;sector count
	*=	*+3
countr				;counter
	*=	*+1
;main program
	*=	TEA
;send opening message
	lda	#<opnmsg	;first point to it
	ldy	#>opnmsg
	jsr	msgout		;then send
	ldx	#25		;get current drive
	jsr	pem
	sta	dfldrv		;and save
;get SIM page and set SIM entry jumps
	ldy	boot+2		;get sim page
	STY	SELDRV+2
	STY	SETTRK+2
	STY	SETSEC+2
	STY	SETDMA+2
	STY	READ+2
	sty	xlate+2
	STY	WRITE+4
;find dcb addresses
	lda	#0
	jsr	seldrv		;first do a
	sta	dcba
	sty	dcba+1
	lda	#1
	jsr	seldrv		;then do b
	sta	dcbb
	sty	dcbb+1
;compare dcbs
	ldy	#8		;set counter
cmpdcb	lda	(dcba),y	;get from a
	sta	maxblk,y	;save for later
	cmp	(dcbb),y	;compare to b
	beq	*+5		;ok if same
	jmp	faild		;else error
	dey			;drop count
	bpl	cmpdcb		;loop if more
;calculate number sectors
	ldx	blkscd		;get block size code
	lda	blksht,x	;then get shift
	tax			;and save in x
	lda	maxblk		;get ready
	ldy	maxblk+1
	sta	sector		;set sectors
	sty	sector+1
	lda	#0		;clear high
	sta	sector+2
	inc	sector		;bump for count rather than one minus
	bne	clcsec
	inc	sector+1
	bne	clcsec
	inc	sector+2
clcsec	asl	sector		;calculate number using block size
	rol	sector+1
	rol	sector+2
	dex
	bne	clcsec
	lda	sector		;now move to track register
	ldy	sector+1
	ldx	sector+2
	sta	tracks
	sty	tracks+1	
	stx	tracks+2
;calculate number tracks
	ldx	#0		;clear counter
	stx	countr
clctrk	inx			;bump count
	bne	*+4
	inc	countr
	sec
	lda	tracks		;drop count by sectors per track
	sbc	nsectr
	sta	tracks
	lda	tracks+1
	sbc	nsectr+1
	sta	tracks+1
	lda	tracks+2
	sbc	#0
	sta	tracks+2
	bcc	done		;done if borrow
	ora	tracks		;see if zero
	ora	tracks+1
	bne	clctrk		;loop if not
done	txa			;now add to number system tracks
	clc			;to get total
	adc	nsystr
	sta	tracks
	lda	countr
	adc	nsystr+1
	sta	tracks+1
;now calculate track length in bytes
	lda	nsectr
	ldy	nsectr+1
	sta	buf1
	sty	buf1+1		;set length
	ldx	#7
clctln	asl	buf1		;multiply by 128
	rol	buf1+1
	bcc	*+5		;ok if no carry
	jmp	badser		;else no room error
	dex	
	bne	clctln		;loop if more
;save length for later check
	lda	buf1
	ldy	buf1+1
	sta	countr
	sty	countr+1
;set actual buf1 address
	clc
	lda	#<buf0		;add to buf0 start
	adc	buf1
	sta	buf1
	lda	#>buf0
	adc	buf1+1
	sta	buf1+1
	bcc	*+5		;ok if no carry
	jmp	badser		;else room error
	cmp	pem+2		;see if under pem
	bcc	*+5		;ok if is
	jmp	badser		;else error
	clc			;now check for end
	lda	buf1
	adc	countr
	lda	buf1+1
	adc	countr+1
	bcc	*+5		;ok if no carry
	jmp	badser		;else room error
	cmp	pem+2		;also check end
	bcc	*+5		;ok if less
	jmp	badser		;else error
;get object length and insert a $
	LDX	DFLBUF		;get length
	BNE	*+5		;continue if not zero
	JMP	NOMSG		;else exit
	INX			;bump index
	LDA	#'$'		;then insert
	STA	DFLBUF,X	;the $
;test first character
	LDA	DFLBUF+2	;get first char
	CMP	#'S'		;if S
	BEQ	SYSSET		;may be system
	CMP	#'D'		;if D
	BEQ	DATSET		;may be data
	CMP	#'A'		;if A
	BEQ	ALLSET		;may be all
	JMP	BADMSG		;else is bad
;system
SYSSET	LDX	#5		;set index
	LDA	DFLBUF+3,X	;get input
	CMP	SYSMSG,X	;compare
	BEQ	*+5		;continue if ok
	JMP	BADMSG		;else error
	DEX			;count down
	BPL	SYSSET+2	;and loop if more
	lda	#0
	sta	first
	sta	first+1		;set first track
	lda	nsystr
	ldy	nsystr+1
	sta	last
	sty	last+1		;set last track
	ora	last+1		;make sure their are tracks
	bne	agin		;do copy if room
	jmp	badser		;but error if none
;data
DATSET	LDX	#3		;set index
	LDA	DFLBUF+3,X	;compare input
	CMP	DATMSG,X	;to full
	BEQ	*+5		;continue if ok
	JMP	BADMSG		;else error
	DEX			;count down
	BPL	DATSET+2	;loop if more
	lda	nsystr		;get first
	ldy	nsystr+1
	sta	first
	sty	first+1
dodt	lda	tracks
	ldy	tracks+1
	sta	last
	sty	last+1		;set last
	ora	last+1
	bne	agin		;do if ok
	jmp	badser		;error if none
;all
ALLSET	LDX	#2		;set index
	LDA	DFLBUF+3,X	;compare input
	CMP	ALLMSG,X	;to full
	BEQ	*+5		;continue if ok
	JMP	BADMSG		;else error
	DEX			;count down
	BPL	ALLSET+2	;loop if more
	LDA	#0		;first = 0
	sta	first
	sta	first+1
	jmp	dodt		;then continue
;send opening message
AGIN	LDA	#<SIGNON	;send
	LDY	#>SIGNON	;sign-on
	JSR	MSGOUT		;message
	JSR	RDECNS		;get input
	CMP	#CTLC		;if not ctl-c
	bne	docopy		;then do copy
	lda	dfldrv		;get default
	jsr	seldrv		;and select it
	JMP	BOOT		;and do boot
docopy	CMP	#CR		;if not a cr
	BNE	AGIN		;then try again
	LDA	#<CRLF		;send
	LDY	#>CRLF		;a cr
	JSR	MSGOUT		;and lf
;main routine call
	JSR	COPY		;do the copy
	LDA	#<DONMSG	;send
	LDY	#>DONMSG	;complete
	JSR	MSGOUT		;message
EXIT	LDA	#<SINOFF	;send
	LDY	#>SINOFF	;sign-off
	JSR	MSGOUT		;message
	JSR	RDECNS		;get response
	CMP	#'&'		;if ampersand
	BEQ	AGIN		;do again
	CMP	#CR		;if no cr
	BNE	EXIT		;get another input
quit	lda	dfldrv		;get default
	jsr	seldrv		;and select it
	JMP	BOOT		;else done
;subroutines
;select drive
SELDRV	JMP	27
;set track
SETTRK	JMP	30
;set sector
SETSEC	JMP	33
;set dma
SETDMA	JMP	36
;read sector
READ	JMP	39
;write sector
write	lda	#1		;say directory
	JMP	42
;translate sector
xlate	jmp	51
;message output
MSGOUT	LDX	#9
	JMP	PEM
;read console
RDECNS	LDX	#1
	JMP	PEM
;initialize for read/write for BUF0
INTRW0	lda	#0		;start with logical sector 0
	tay
	jsr	xlate		;get first sector
	sta	hstsec		;save for actual call
	sty	hstsec+1
	lda	#1		;now set counter
	ldy	#0
	STA	SECT		;for sector
	sty	sect+1
	LDA	TRK		;do
	ldy	trk+1
	JSR	SETTRK		;seek
INT0	LDA	#<BUF0		;and
	LDY	#>BUF0		;initialize
	STA	BUFADR		;buffer
	STY	BUFADR+1	;address
	RTS
;bump buffer address
BMPBUF	CLC			;clear
	LDA	BUFADR		;carry
	ADC	#128		;and
	STA	BUFADR		;add
	BCC	*+4		;128
	INC	BUFADR+1	;to
	RTS			;address
;erroneous command
BADMSG	LDA	#<CMDER1	;send
	LDY	#>CMDER1	;first
	JSR	MSGOUT		;message
	LDA	#DFLBUF+1*256/256	;then
	LDY	#DFLBUF+1/256	;send
	JSR	MSGOUT		;input
	LDA	#<CMDER2	;then
	LDY	#>CMDER2	;second
	JSR	MSGOUT		;part
NOMSG	LDA	#<CMDINF	;and
	LDY	#>CMDINF	;finally the
	JSR	MSGOUT		;instructions
	lda	dfldrv		;select default
	jsr	seldrv		;drive
	JMP	BOOT		;and exit
;read track
READT	JSR	INTRW0		;initialize
RT2	LDA	BUFADR		;set buffer
	LDY	BUFADR+1	;address
	JSR	SETDMA		;for sim
	LDA	hstsec		;get sector
	ldy	hstsec+1
	JSR	SETSEC		;and set
	JSR	READ		;read sector
	and	#$ff		;see if error
	beq	*+5		;continue if none
	JMP	FAILR		;else error
	JSR	BMPBUF		;bump address
	inc	hstsec		;bump actual host sector
	bne	*+4
	inc	hstsec+1
	LDA	SECT		;get sector counter
	ldy	sect+1		;before bumping
	INC	SECT		;bump next
	bne	*+4
	inc	sect+1
	cmp	nsectr		;compare to last
	BNE	RT2		;loop if more
	cpy	nsectr+1
	bne	rt2
	RTS
;write track
WRITET	JSR	INTRW0		;initialize
WT2	LDA	BUFADR		;get buffer
	LDY	BUFADR+1	;address
	JSR	SETDMA		;and set
	LDA	hstsec		;get sector
	ldy	hstsec+1
	JSR	SETSEC		;and set
	JSR	WRITE		;write sector
	and	#$ff		;see if error
	beq	*+5		;ok if none
	JSR	FAILW		;else error
	JSR	BMPBUF		;bump address
	inc	hstsec		;bump actual host sector
	bne	*+4
	inc	hstsec+1
	LDA	SECT		;get current sector
	ldy	sect+1
	INC	SECT		;bump next
	bne	*+4
	inc	sect+1
	cmp	nsectr		;see if at end
	BNE	WT2		;loop if not
	cpy	nsectr+1
	bne	wt2
	RTS
;compare tracks
COMPT	JSR	INTRW0		;initialize
	LDA	BUF1		;but then
	ldy	buf1+1		;correct
	STA	BUFADR		;buffer
	STY	BUFADR+1	;address
	JSR	RT2		;read it
	JSR	INT0		;set buffer address to start
	lda	buf1		;set
	ldy	buf1+1		;buffer pointer
	STA	BUFPNT		;to
	STY	BUFPNT+1	;start
	LDA	#0		;clear sector
	STA	SECCNT		;counter
	sta	seccnt+1
CMPLP	LDA	(BUFPNT),Y	;get from 1
	CMP	(BUFADR),Y	;compare to 0
	BNE	CERR		;branch if error
	INY			;else bump index
	BPL	CMPLP		;loop if < 128
	CLC			;else
	TYA			;add 128
	ADC	BUFPNT		;to
	STA	BUFPNT		;pointer
	BCC	*+4		;for
	INC	BUFPNT+1	;1
	CLC			;and
	TYA			;do
	ADC	BUFADR		;same
	STA	BUFADR		;for
	BCC	*+4		;pointer
	INC	BUFADR+1	;0
	LDY	#0		;clear index
	INC	SECCNT		;bump count
	bne	*+4
	inc	seccnt+1
	LDA	SECCNT		;get it
	cmp	nsectr		;if not last
	BNE	CMPLP		;loop
	lda	seccnt+1
	cmp	nsectr+1
	bne	cmplp
	RTS			;else done
;compare error
CERR	LDA	#<MESGA		;send
	LDY	#>MESGA		;error
	JSR	MSGOUT		;message
	lda	#'$'
	jsr	prtchr
	lda	trk+1
	jsr	prthex
	LDA	TRK		;then track
	JSR	PRTHEX		;number
	LDA	#<MESGB		;then
	LDY	#>MESGB		;sector
	JSR	MSGOUT		;message
	lda	#'$'
	jsr	prtchr
	LDX	SECCNT		;get count
	ldy	seccnt+1
	INX			;bump
	bne	*+3
	iny
	txa			;save low
	pha
	tya			;do high
	jsr	prthex
	pla			;get low
	JSR	PRTHEX		;print it
	INC	CMPERR		;bump error count
	LDA	CMPERR		;get count
	CMP	#10		;see if 10
	BEQ	*+3		;branch if so
	RTS			;else try again
;permanent error
	LDA	#<MESGC		;send
	LDY	#>MESGC		;permanent
	JSR	MSGOUT		;message
	LDA	#0		;set z to 1
	RTS
;copy tracks (first) through (last)-1 from a to b
COPY	LDA	FIRST		;set trcak
	ldy	first+1
	STA	TRK		;to first
	sty	trk+1
RDLOOP	LDA	#0		;clear
	STA	CMPERR		;error count
	JSR	SELDRV		;select a
	JSR	READT		;read track
RETRYW	LDA	#1		;select
	JSR	SELDRV		;b
	JSR	WRITET		;write track
	JSR	COMPT		;then compare
	BNE	RETRYW		;loop if bad
	INC	TRK		;else bump track
	bne	*+4
	inc	trk+1
	LDA	TRK		;and get it
	CMP	LAST		;compare to limit
	BNE	RDLOOP		;loop if more
	lda	trk+1
	cmp	last+1
	bne	rdloop
	RTS
;print byte as hex
PRTHEX	PHA			;save byte
	LSR	A		;shift
	LSR	A		;high
	LSR	A		;nibble
	LSR	A		;to low
	JSR	PRTNBL		;convert and print
	PLA			;get byte
PRTNBL	AND	#$F		;mask out high
	ORA	#'0'		;make a number
	CMP	#'9'+1		;if 0-9
	BCC	*+4		;go use
	ADC	#6		;else make A-F
prtchr	LDX	#2		;then print
	JMP	PEM		;on console
;read error
FAILR	LDA	#<MESGD		;send
	LDY	#>MESGD		;source error
	JSR	MSGOUT		;message
	JMP	quit		;and exit
;write error
FAILW	LDA	#<MESGE		;send
	LDY	#>MESGE		;destination
	JSR	MSGOUT		;error message
	JMP	quit		;and exit
;dcb mismatch error
faild	lda	#<mesgf		;point to message
	ldy	#>mesgf
	jsr	msgout		;send it
	jmp	quit
;no room to copy
badser	lda	#<mesgg		;point to message
	ldy	#>mesgg
	jsr	msgout		;send it
	jmp	quit
;block shift table
blksht	.byte	3,4,5,6,7
;messages and strings
opnmsg	.byte	"DOS/65 DISKCOPY V2.05-S",CR,LF,"$"
signon	.byte	CR,LF,"+SOURCE ON A"
	.byte	CR,LF,"+DESTINATION ON B"
	.byte	CR,LF,"+TYPE <RET> WHEN READY$"
SYSMSG	.byte	"YSTEM$"
DATMSG	.byte	"ATA$"
ALLMSG	.byte	"LL$"
CMDER1	.byte	"+COMMAND DISKCOPY$"
CMDER2	.byte	" HAS SYNTAX ERROR",CR,LF,"$"
CMDINF	.byte	"+THIS PROGRAM IS INITIATED"
	.byte	" WITH THE COMMAND",CR,LF
	.byte	"+DISKCOPY SYSTEM, DISKCOPY"
	.byte	" DATA, OR DISKCOPY ALL$"
DONMSG	.byte	"+FUNCTION COMPLETE$"
CRLF	.byte	CR,LF,"$"
SINOFF	.byte	CR,LF,"+TYPE <RET> TO EXIT "
	.byte	"OR <&> TO REPEAT$"
MESGA	.byte	CR,LF,"+COMPARE ERROR ON TRACK $"
MESGB	.byte	", SECTOR $"
MESGC	.byte	CR,LF,"PERMANENT $"
MESGD	.byte	CR,LF,"+PERMANENT SOURCE ERROR"
	.byte	" - ABORTING$"
MESGE	.byte	CR,LF,"+PERMANENT DESTINATION "
	.byte	"ERROR - ABORTING$"
mesgf	.byte	cr,lf,"+DCBS DO NOT MATCH - "
	.byte	"ABORTING$"
mesgg	.byte	cr,lf,"+NO ROOM TO DO DISK COPY"
	.byte	" - ABORTING$"
;buffers
buf0
	.END
