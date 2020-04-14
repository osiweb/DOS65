	heading HEXtoCOM.asm V2.00 24 May 2014
	pw	132
	pl	59
	case	off
	chip	65c02
;HEXtoCOM
;derived from MKCOM205.ASM
;convert .HEX files to .COM files for dos/65
;version 2.00-S
;released:	24 may 2014
;last revision:
;read Intel hex format object code files and generate
;executable command (.COM) file beginning at tea.
;conversion is terminated by eof record
;or physical eof.  records must be
;monotonically increasing but may have gaps.
;any gaps are filled with zeros. upon entry
;file type is or is assumed to be "hex".
;future updates will check record types and at least
;actively examine any address records.
;base addresses
pzstrt	equ	$2		;start of free page zero RAM
boot	equ	$100		;warm boot
pem	equ	$103		;PEM entry point
dflfcb	equ	$107		;source FCB
dflbuf	equ	$128		;source buffer
tea	equ	$200		;tea start
;fixed parameters
null	equ	0		;null
lf	equ	10		;linefeed $a
cr	equ	13		;return $d
eof	equ	26		;end of file $1a
colon	equ	58		;colon $3a
;zero page storage
	page0
	org	pzstrt
hexpnt	ds	1		;.HEX record index
compnt	ds	2		;.COM record pointer
curent	ds	2		;current .COM pc
start	ds	2		;current hex start
count	ds	1		;current record byte count
bytes	ds	2		;number bytes read
record	ds	2		;number records read
number	ds	1		;byte assembly buffer
commax	ds	2		;max .COM pointer
;put .COM fcb outside area subject to PEM saves
	org	32
comfcb	ds	33		;com fcb
lastzp	ds	1
	ends
;main program
	code
	org	tea
;send opening message
	lda	#<opnmsg
	ldy	#>opnmsg
	jsr	outbuf
;first clear page zero including .COM fcb
	ldx	#pzstrt		;set index to start
	lda	#0		;clear accum
clrmre	sta	0,x		;clear
	inx			;bump index
	cpx	#lastzp		;if more
	bne	clrmre		;loop
;start .COM file build at TEA
	lda	#<tea		;set current
	sta	curent		;to tea
	ldy	#>tea		;both low
	sty	curent+1	;and high
;calculate maximum .COM file buffer length 
	sec			;set carry
	lda	pem+1		;get pem
	ldy	pem+2		;destination
	sbc	#<combuf	;start
	and	#128		;make mod 128
	sta	commax		;and save
	tya			;get high
	sbc	#>combuf	;subtract again
	sta	commax+1	;and save it
;commax is maximum length - now drop by a page
	dec	commax+1
;now calculate end of buffer + 1 byte
	clc			;then
	lda	commax		;add
	adc	#<combuf	;start
	sta	commax		;back
	lda	commax+1	;in to
	adc	#>combuf	;get buffer
	sta	commax+1	;limit
;initialize pointers
	jsr	clrcom		;clear com pointer
	lda	#128		;set pointers
	sta	hexpnt		;to invalid
;check to make sure file name is UFN
	ldx	#11		;check all char
	lda	#'?'		;for ambiguous
tstamb	cmp	dflfcb,x	;if not try
	bne	tstnxt		;for next
	jmp	inperr		;else an error
tstnxt	dex			;count down
	bne	tstamb		;and loop
;now see if type either hex or blank
	ldx	#2		;if type
chkmhx	lda	hextyp,x	;is not
	cmp	dflfcb+9,x	;hex then
	bne	chkspc		;try for spaces
	dex			;else count down
	bpl	chkmhx		;and loop
	bmi	typeok		;ok if hex
chkspc	ldx	#2		;check for
	lda	#' '		;spaces
chkmsp	cmp	dflfcb+9,x	;if so
	beq	tnxspc		;test next
	jmp	inperr		;else error
tnxspc	dex			;count down
	bpl	chkmsp		;and loop
;input file name is OK so build .COM FCB from input
typeok	ldx	#8		;set up
movfcb	lda	dflfcb,x	;and move
	sta	comfcb,x	;name to
	dex			;.COM
	bpl	movfcb		;FCB
;set input extension to hex and output to COM
	ldx	#2		;then make
settyp	lda	hextyp,x	;sure HEX
	sta	dflfcb+9,x	;type is
	lda	comtyp,x	;set and COM
	sta	comfcb+9,x	;type is set
	dex			;in
	bpl	settyp		;FCBs
;file name are OK so see if .HEX exists
	jsr	srhhex		;search for hex
	bne	hexok		;if there ok
	jmp	inperr		;else error
;input exists so delete and then create .COM file
hexok	jsr	dltcom		;delete com file
	jsr	crtcom		;create new com
	bne	comok		;if ok continue
	jmp	outerr		;else error
;finally we open the .HEX and .COM files
comok	jsr	opnhex		;open source
	bne	hexopn		;continue if ok
	jmp	inperr		;else error
hexopn	jsr	opncom		;open com file
	bne	main		;continue if ok
	jmp	outerr		;else error
;read loop - get characters from .HEX file and process them
main	jsr	getchr		;get char
	cmp	#eof		;if eof
	beq	endit		;then done
	cmp	#colon		;if not file
	bne	main		;mark try again
;first two characters after : are number of bytes of data in record (count)
	jsr	gettwo		;get length
	beq	chktyp		;if zero may be eof record
	sta	count		;else set count
;update cumulative count
	clc			;add to 
	adc	bytes		;cumulative count
	sta	bytes		;and 
	bcc	nohiby		;save
	inc	bytes+1		;low and high
;next four characters are start address of record in HL order
;but save in usual 65xx LH order for later use.
nohiby	jsr	gettwo		;get high
	sta	start+1		;address
	jsr	gettwo		;and get
	sta	start		;low
;get record type from file and confirm it is valid
	jsr	gettwo		;range is 0 to 5
	beq	typdat		;should be 0 for data
	jmp	recerr		;error if not
;make sure start >= current to satisfy monotonic criterion.
typdat	lda	start		;get low back
	cmp	curent		;compare to
	lda	start+1		;start
	sbc	curent+1	;address saved
	bcs	tsteql		;if >= then ok
	jmp	seqerr		;else error
;see if start > current and fill buffer with 0 until current = start
tsteql	lda	start		;see if
	cmp	curent		;same as current
	bne	fillmr		;if not fill more
	lda	start+1		;try high
	cmp	curent+1	;comparison
	beq	fillok		;if same begin read
fillmr	lda	#null		;else
	jsr	insert		;fill com
	inc	curent		;then 
	bne	tsteql		;bump
	inc	curent+1	;current and
	jmp	tsteql		;loop
;update current <-- current + count
fillok	lda	count		;first
	clc			;update
	adc	curent		;current
	sta	curent		;pointer
	bcc	dofill		;with
	inc	curent+1	;carry
;get count bytes from .HEX and convert to binary and put in .COM buffer
dofill	jsr	gettwo		;get byte
	jsr	insert		;put in .COM
	dec	count		;count down
	bne	dofill		;and loop
;ignore checksum byte
	jsr	gettwo		;ignore checksum
	jmp	main		;and get next
;check record type as it is likely that an EOF record has been found
;and if so load offset shown by 4 characters (2 bytes) should =0.
chktyp	jsr	gettwo		;get a byte
	bne	badrec		;0 data but non-zero address
	jsr	gettwo		;get low byte
	bne	badrec		;
;now get record type that should be 2
	jsr	gettwo		;get byte
	cmp	#2		;see if EOF
	beq	endit		;if so then done
	jmp	main		;else look for next record
;record offset and byte count mismatch
badrec	jmp	recerr		;go issue message
;exit sequence
;Flush the .COM buffer and report what was read and
;written.
endit	sec			;set carry
	lda	compnt		;if pointer
	sbc	#<combuf	;at even
	and	#127		;record
	beq	noexcy		;then ok
	lda	#eof		;else add
	jsr	insert		;eof and
	jmp	endit		;loop
noexcy	lda	compnt		;get
	ldy	compnt+1	;pointer
	sta	commax		;and set
	sty	commax+1	;limit
	jsr	wrtbuf		;do one more
	jsr	bufcom		;go back to front of buffer
wrtdne	jsr	clscom		;close com file
	bne	wrtcls		;if ok continue
	jmp	outerr		;else error
wrtcls	lda	#<nxtadr	;point to
	ldy	#>nxtadr	;next message
	jsr	outbuf		;and send
	lda	curent+1	;send high
	jsr	outbyt		;byte
	lda	curent		;and low
	jsr	outbyt		;byte
	lda	#<bytrde	;point to
	ldy	#>bytrde	;number read message
	jsr	outbuf		;and send
	lda	bytes+1		;send high
	jsr	outbyt		;byte
	lda	bytes		;and low
	jsr	outbyt		;byte
	lda	#<recwrt	;point to
	ldy	#>recwrt	;number written message
	jsr	outbuf		;send
	lda	record+1	;get high
	jsr	outbyt		;count
	lda	record		;and low
	jsr	outbyt		;then return
	jmp	boot		;with warm boot
;subroutines
;get character from .HEX file
;If hexpnt is 0-127 at entry then existing buffer contents are
;used. If hexpnt is 128 then a new record of 128
;bytes is read and hexpnt is reset to 0 so first byte
;in record is fetched. hexpnt is then incremented to prepare
;for next character fetch. If the record read returns
;an EOF indication then the first character in the
;buffered record is set to an EOF ($1A) and returned
;to the calling code.
getchr	ldx	hexpnt		;get pointer
	bpl	noread		;if ok use
	jsr	bufhex		;point to hex
	jsr	rdehex		;read record
	bne	*+5		;if no error check for eof
	jmp	inperr		;else input error
	cmp	#0		;if not eof
	beq	readok		;continue
	lda	#eof		;else an eof
	sta	dflbuf		;insert in buffer
	lda	#0		;clear for ok
readok	tax			;set pointer
	stx	hexpnt		;and save
noread	inc	hexpnt		;bump pointer
	lda	dflbuf,x	;get char
	and	#%01111111	;mask out msb
	rts			;return
;get byte
;This routine reads two ASCII characters in order to create
;a byte wide value that is returned in A.
gettwo	jsr	getone		;get first and continue
;get nibble
;This routine reads one ASCII character in order to create
;part of a byte-wide value.
getone	jsr	getchr		;get char
	cmp	#'0'		;if less than "0"
	bmi	packer		;is an error
	cmp	#'9'+1		;if 0 to 9 is
	bmi	decnum		;decimal
	cmp	#'A'		;if less than a
	bmi	packer		;is error
	cmp	#'F'+1		;if more than f
	bpl	packer		;is error
	clc			;add 9
	adc	#9		;for a to f
decnum	rol	a		;shift
	rol	a		;to 
	rol	a		;high
	rol	a		;nibble
	ldx	#4		;then
packlp	rol	a		;shift a
	rol	number		;to number
	dex			;four
	bne	packlp		;times
	lda	number		;return
	rts			;with number
packer	jmp	nthxer		;error handler
;nibble to ascii
;Outputs the ASCII for either the high or low
;nibble of a byte. Nibble must be the low nibble
;of A at entry. Output is to console.
hex	and	#$f		;look at low
	ora	#'0'		;add "0"
	cmp	#'9'+1		;if 0 to 9
	bmi	notalp		;ok
	clc			;else add
	adc	#7		;7 for a to f
notalp	jmp	chrout		;send
;byte to ascii
;Outputs the ASCII representation of the byte in A
;by calling hex twice. High nibble always shown
;first followed by low nibble. Output is to console.
outbyt	pha			;save byte
	lsr	a		;move
	lsr	a		;high
	lsr	a		;to
	lsr	a		;low
	jsr	hex		;convert and print
	pla			;same
	jmp	hex		;for low
;hex file references for PEM operations
bufhex	lda	#<dflbuf 	;point to
	ldy	#>dflbuf	;buffer
	ldx	#26		;set buffer
	bne	pemgo
srhhex	ldx	#17		;search for first
	bne	sethex
opnhex	ldx	#15		;open
	bne	sethex
rdehex	ldx	#20		;read record
sethex	lda	#<dflfcb	;set fcb
	ldy	#>dflfcb	;to default
	jmp	pemgo
;com file references for PEM operations
bufcom	lda	#<combuf	;set buffer
	ldy	#>combuf	;to com
	ldx	#26		;set buffer
	bne	pemgo
dltcom	ldx	#19		;delete file
	bne	setcom
crtcom	ldx	#22		;create file
	bne	setcom
wrtcom	ldx	#21		;write record
	bne	setcom
clscom	ldx	#16		;close file
	bne	setcom
opncom	ldx	#15		;open file
setcom	lda	#<comfcb	;point to
	ldy	#>comfcb	;com fcb
	jmp	pemgo
;general pem references
wrmbte	ldx	#0		;warm boot
	beq	pemgo
chrout	ldx	#2		;character output
	bne	pemgo
outbuf	ldx	#9		;string output
pemgo	jsr	pem		;execute
	cmp	#255		;test for invalid
	rts
;error routines
recerr	lda	#<rcerms	;record content mismatch
	ldy	#>rcerms
	jmp	errsnd
inperr	lda	#<inerms	;input file error
	ldy	#>inerms
	jmp	errsnd
nthxer	lda	#<icerms	;invalid character
	ldy	#>icerms
	jmp	errsnd
outerr	lda	#<oterms	;output file error
	ldy	#>oterms
	jmp	errsnd
seqerr	lda	#<sqerms	;sequence error
	ldy	#>sqerms
errsnd	jsr	outbuf		;send
	jmp	wrmbte		;do warm boot
;error messages
inerms	db	"INPUT ERROR$"
oterms	db	"OUTPUT ERROR$"
sqerms	db	"BAD SEQUENCE ERROR$"
icerms	db	"INVALID CHARACTER$"
rcerms	db	"RECORD TYPE-LENGTH MISMATCH$"
;clear com pointer
clrcom	lda	#<combuf	;get low
	ldy	#>combuf	;and high
	sta	compnt		;pointer
	sty	compnt+1	;and set
	rts
;insert byte into .COM file buffer
;If pointer is past end of buffer then buffer
;is written to disk.
insert	ldx	compnt		;compare low pointer
	cpx	commax		;to max
	bne	nocmwr		;branch if not there
	ldx	compnt+1	;do same
	cpx	commax+1	;for high
	bne	nocmwr		;bytes
	pha			;save byte
	jsr	wrtbuf		;write file
	pla			;get byte
nocmwr	ldy	#0		;clear index
	sta	(compnt),y	;save byte
	inc	compnt		;bump
	bne	*+4		;pointer
	inc	compnt+1	;for next
	rts
;write .COM buffer to disk one record at a time.
;First step is to set buffer pointer to start of buffer.
;That pointer becomes the pointer to the PEM buffer
;address. Once the pointer passes the end of the
;buffer the write is complete and the pointer is
;again set to the start of the buffer.
wrtbuf	jsr	clrcom		;clear pointer
wrtclp	lda	compnt		;set
	ldy	compnt+1	;pointer
	ldx	#26		;and set
	jsr	pem		;buffer address
	lda	compnt		;get low pointer
	cmp	commax		;compare to max
	bne	docwrt		;write if not there
	lda	compnt+1	;also check
	cmp	commax+1	;high pointer
	bne	docwrt		;write if different
	jmp	clrcom		;else clear pointer and exit
docwrt	jsr	wrtcom		;write record
	cmp	#0		;test for ok
	beq	*+5		;continue if ok
	jmp	outerr		;else error
	clc			;bump
	lda	compnt		;pointer
	adc	#128		;by 128
	sta	compnt		;and
	bcc	*+4		;save for
	inc	compnt+1	;next
	inc	record		;also
	bne	*+4		;bump
	inc	record+1	;record count
	jmp	wrtclp		;and loop
;tables
hextyp	db	"HEX"
comtyp	db	"COM"
;messages
opnmsg	db	"DOS/65 .HEX TO .COM CONVERSION V2.00"
	db	cr,lf
	db	'$'
nxtadr	db	cr,lf,"NEXT ADDRESS=$"
bytrde	db	cr,lf,"BYTES READ=$"
recwrt	db	cr,lf,"RECORDS WRITTEN=$"
;.COM file buffer
	org	*/256*256+256
combuf	ds	1
	ends
	end
	