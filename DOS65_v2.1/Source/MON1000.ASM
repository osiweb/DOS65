	globals	on
	case	off
	chip	65c02
	pw	132
	pl	59
;monitor version 10.00
;1.75k rom based monitor for 65C02 with
; suntronics ufdc-1 for 8" and 5"
; S100 Computers SERIAL IO for terminal i/o with wy-50
; S100 Computers DUAL IDE-CF ROM board
;Basic memory parameters are set for DOS/65 V2.1x in terms
;of CCM & PEM length. That is
ccmlng	equ	2048		;CCM length in bytes
pemlng	equ	3072		;PEM length in bytes
;This version is configured for the following disk drives:
;	A	5.25 in, 80t, DSHD - 1 track reserved
;	B	5.25 in, 40t, DSDD (Kaypro 4)
;	C	CF 8 MB drive
;	D	CF 8 MB drive
;	E	CF 8 MB drive (planned only)
;	F	CF 8 MB drive (planned only)
;	G	5.25 in, 40t, SSDD (Kaypro 2)
;	H	5.25 in, 80t, DSHD - 2 tracks reserved
;released:	29 January 2015 (10.00)
;			Based on V9 & Z80 V10.
;			reduced floppy error reporting to fit
;			eliminated RTC code - it was dummy anyway
;last revised:
;fixed parameters
rtcnt	equ	10		;retry limit for disk ops
clreol	equ	1		;clear to eol (ctl-a)
clreos	equ	2		;clear to eos (ctl-b)
bs	equ	8		;backspace (ctl-h)
lf	equ	$a		;linefeed
cr	equ	$d		;carriage return
esc	equ	$1b		;escape char
delete	equ	$7f		;delete char
;**********************************************************************
;i/o port assignments and data definitions
;**********************************************************************
;base page for io
io	equ	$f800
;ufdc-1 disk controller
disk	equ	io+$98
dcom	equ	disk+4
dstat	equ	disk+4
track	equ	disk+5
sectp	equ	disk+6
ddata	equ	disk+7
wait	equ	disk+2		;RDY enabling port
dcont	equ	disk		;same as wait but no RDY!
;disk controller related parameters
;control bit for floppy side control
csdmsk	equ	%11011111	;clear bit
csd0	equ	%00100000	;side 0
csd1	equ	%00000000	;side 1
;1795 command bit
xsdmsk	equ	%11111101	;clear bit
xsdck	equ	%00000010	;check it
xsdnc	equ	%00000000	;do not check it
;SERIALIO board - port A only for now
SCCBase	equ	io+$a0		;base address of SCC on SERIALIO
ACTL	equ	SCCBase+1	;port a control address
ADTA	equ	SCCBase+3	;data address for port a
BCTL	equ	SCCBase		;port b control address
BDTA	equ	SCCBase+2	;port b data register
;define address of dual IDE-CF board as well as related
;parameters
;
;Ports for 8255 chip. Change these to specify where your 8255 is addressed,
;The first three control which 8255 ports have the control signals,
;upper and lower data bytes.  The last one (IDEportCtrl), is for mode setting for the
;8255 to configure its actual I/O ports (A,B & C).  
;
;Note most drives these days don't use the old Head,Track, Sector terminology. Instead
;we use "Logical Block Addressing" or LBA. This is what we use below. LBA treats the drive
;as one continuous set of sectors, 0,1,2,3,... 3124,....etc.  However as seen below we need to 
;convert DOS/65 track and record parameters to LBA.
;
;This code uses 28-bit LBA addressing.
;
;NOTE: If you have only one drive/CF card, be sure it is in drive #0 (RHS of board). The IDE hardware gets 
;confused if there is only a drive in slot #1.
;
idebase		equ	io+$30		;base address of board
IDEPORTA	EQU	idebase		;Lower 8 bits of IDE interface (8255)
IDEPORTB	EQU	idebase+1	;Upper 8 bits of IDE interface
IDEPORTC	EQU	idebase+2	;Control lines for IDE interface
IDEPORTCTRL	EQU	idebase+3	;8255 configuration port
IDEDRIVE	EQU	idebase+4	;Bit 0 = 0 Drive A, =1 Drive B
;8255 configuration commands
READCFG8255	EQU	%10010010	;Set 8255 IDEportC to output, IDEportA/B input
WRITECFG8255	EQU	%10000000	;Set all three 8255 ports to output mode
;IDE control lines for use with IDEportC.  
IDEA0LINE	EQU	$01	;direct from 8255 to IDE interface
IDEA1LINE	EQU	$02	;direct from 8255 to IDE interface
IDEA2LINE	EQU	$04	;direct from 8255 to IDE interface
IDECS0LINE	EQU	$08	;inverter between 8255 and IDE interface
IDECS1LINE	EQU	$10	;inverter between 8255 and IDE interface
IDEWRLINE	EQU	$20	;inverter between 8255 and IDE interface
IDERDLINE	EQU	$40	;inverter between 8255 and IDE interface
IDERSTLINE	EQU	$80	;inverter between 8255 and IDE interface
;Symbolic constants for the IDE Drive registers, which makes the
;code more readable than always specifying the address bits
;lba register addresses for drive 0 (A)
lba0		equ	idecs0line+%00000011	;register 3
lba1		equ	idecs0line+%00000100	;register 4
lba2		equ	idecs0line+%00000101	;register 5
;Note that the high nibble of lba3 must be set to %1110 and only the lower
;nibble is used for the highest lba address data.
lba3		equ	idecs0line+%00000110	;register 6
;other register definitions
REGDATA		EQU	IDECS0LINE
REGERR		EQU	IDECS0LINE+IDEA0LINE
REGSECCNT	EQU	IDECS0LINE+IDEA1LINE
REGSECTOR	EQU	IDECS0LINE+IDEA1LINE+IDEA0LINE
REGCYLINDERLSB	EQU	IDECS0LINE+IDEA2LINE
REGCYLINDERMSB	EQU	IDECS0LINE+IDEA2LINE+IDEA0LINE
REGSHD		EQU	IDECS0LINE+IDEA2LINE+IDEA1LINE	;(0EH)
REGCOMMAND	EQU	IDECS0LINE+IDEA2LINE+IDEA1LINE+IDEA0LINE	;(0FH)
REGSTATUS	EQU	IDECS0LINE+IDEA2LINE+IDEA1LINE+IDEA0LINE
REGCONTROL	EQU	IDECS1LINE+IDEA2LINE+IDEA1LINE
REGASTATUS	EQU	IDECS1LINE+IDEA2LINE+IDEA1LINE+IDEA0LINE
;IDE Command Constants.  These should never change.
COMMANDRECAL	EQU	$10
COMMANDREAD	EQU	$20
COMMANDWRITE	EQU	$30
COMMANDINIT	EQU	$91
COMMANDID	EQU	$EC
COMMANDSPINDOWN	EQU	$E0
COMMANDSPINUP	EQU	$E1
; IDE Status Register:
;  bit 7: Busy	1=busy, 0=not busy
;  bit 6: Ready 1=ready for command, 0=not ready yet
;  bit 5: DF	1=fault occurred insIDE drive
;  bit 4: DSC	1=seek complete
;  bit 3: DRQ	1=data request ready, 0=not ready to xfer yet
;  bit 2: CORR	1=correctable error occurred
;  bit 1: IDX	vendor specific
;  bit 0: ERR	1=error occurred
;

;**********************************************************************
;ram assignments
;**********************************************************************
	page0
;zero page ram
	org	$f8
dma2	defs	2		;second half pointer
dma1	defs	2		;pointer for r/w
;the following two locations are used as the input buffer
;in the monitor - "in" and as a pointer in the cold or
;warm boot process - "btld".
in
btld	defs	2		;input buffer/msg pointer
;the next two locations are used as the main monitor
;pointer - "point" and as the pointer into the host
;buffer in the cold and warm boot process - "btmov".
point
btmov	defs	2		;monitor pointer
	ends

	udata
;system ram
sysrln	equ	64		;bytes of system ram
sysram	equ	io-sysrln	;start of system ram
;define common host buffer - this same area must be
;defined in SIM.
	org	sysram-512
hstbuf	defs	512		;host buffer
	org	sysram
;Variables associated with dual IDE-CF board
Seconds		defs	1	;seconds of delay
OuterDelay	defs	1	;delay timer save
InnerDelay	defs	1
lba		defs	4	;lba for ide/cf action
drivesec	defs	2	;save for display
drivetrk	defs	2	;same for track
;general variable area
nmi	defs	3		;nmi jump
irqbrk	defs	3		;irqbrk jump
dtalng	defs	1		;data block length (0=256,1=1,...,255=255)
curdrv	defs	1		;current drive
nxtdrv	defs	1		;drive to read/write
nxtsec	defs	2		;sector to read/write
nxttrk	defs	2		;track to read/write
trktab	defs	8		;eight drive track table
time	defs	3		;real time clock
;variables associated with floppy drives
ercnt	defs	1		;retry error count
sercnt	defs	1		;seek retry count
errcde	defs	1		;error code
optype	defs	1		;operation type
				;0=home,2=read,4=write
cntbit	defs	1		;control bit
selcde	defs	1		;select code
phytrk	defs	1		;physical track for floppy
physec	defs	1		;physical sector for floppy
chksid	defs	1		;mask for bit to set side
secoff	defs	1		;actual sector offset
offprm	defs	1		;second side offset
;The next 2 parameters are extracted from the boot record for use
;during 5.25 inch, 80t, dshd boot.
btex	defs	2		;execute address
;next parameter is decremented as each 128 byte record is
;transferred and when zero the load the stopped and execution
;initiated.
btln	defs	1		;length in 128 byte records
;last one is used to store record count in sector
btcount	defs	1		;max value is 4
	ends
	
	code
;**********************************************************************
;code section
;**********************************************************************
	org	$f900
;jump vectors
;initialize interrupts
	nop
	nop
	rts
;system halt
	jmp	($fffc)		;jump to monitor
;console status
	jmp	consts
;console read
	jmp	conrde
;console write
	jmp	conwrt
;set drive number
	jmp	setdrv
;set track
	jmp	settrk
;set sector
	jmp	setsec
;set buffer location
	jmp	setdma
;read sector
	jmp	rdesec
;write sector
	jmp	wrtsec
;home floppy drive
	jmp	home
;printer write
	jmp	prnwrt
;read clock
	nop			;read clock
	nop
	rts
;recal HD & controller
	jmp	IDEReset
;read CCM & PEM back from boot device
	jmp	warm
;send string to console
	jmp	outmsg
;show floppy or hard drive error message and restart monitor
SHOWERRORS
	lda	#<ioemsg	;point to error message
	ldy	#>ioemsg
	jsr	outmsg		;send it
;monitor entry
entry	ldx	#$ff		;set
	txs			;stack pointer
	inx			;clear
	txa			;all
clrsys	sta	sysram,x	;of
	inx
	cpx	#sysrln		;see if past end
	bne	clrsys		;of system ram
	lda	#$4c		;get jump op-code
	sta	irqbrk		;and set vector
	cld
	sei			;disable interrupts
;issue select for drive A
	lda	#$23		;select drive A
	sta	dcont
	jsr	forint		;force 1795 to known state
;initialize SCC Port A console port and Port B printer
	ldx	#0		;set index to start
initaloop
	lda	sccinita,x	;get value from table
	sta	actl		;send to port a control
	inx			;bump index
	cpx	#14		;see if done
	bne	initaloop	;loop if more
	ldx	#0		;now do port b
initbloop
	lda	sccinitb,x	;get parameter
	sta	bctl		;set value
	inx			;bump for next
	cpx	#14		;see if done
	bne	initbloop	;loop if not
;output opening message
	lda	#<opnmsg	;point to message
	ldy	#>opnmsg
	jsr	outmsg		;send it
;set point to valid ram
	lda	#2		;use valid loc for c64
	sta	point		;save
	stz	point+1
;Initialize HD and HD controller
	jsr	IDEReset
;main monitor loop
main	jsr	crlf
	lda	#'#'
;send prompt, address and data to console
	jsr	conwrt		;prompt
	jsr	outpnt		;address
	jsr	outsp		;a space
	ldy	#0
	lda	(point),y	;get pointer contents
	jsr	outbyt		;send memory contents
	jsr	outsp		;then a space
	jsr	execut		;get an execute command
	bra	main		;loop forever
;fetch, decode, and execute command
;y must be zero at entry as currently coded
execut	sty	in		;clear buffer
	sty	in+1
read	jsr	conrde		;get key
	cmp	#'a'		;see if lowercase
	bcc	notlc		;branch if not
	cmp	#'z'+1		;same at high end
	bcs	notlc
	and	#$5f		;else convert
notlc	jsr	conwrt		;then echo
;convert char to hex nibble
;if possible else just skip ahead
	cmp	#'0'		;see if < ascii 0
	bmi	pack3		;if so not a number
	cmp	#'9'+1		;see if <= ascii 9
	bmi	pack0		;if so is decimal
	cmp	#'A'		;see if < A
	bmi	pack3		;if so not hex
	cmp	#'F'+1		;see if > F
	bpl	pack3		;if so not hex
;at this point either 0-9 or A-F has been detected
pack0	pha			;save char
	cmp	#'A'-1
	bmi	pack1
	clc
	adc	#9
pack1	rol	a
	rol	a
	rol	a
	rol	a
;now roll new hex digit into input buffer in
	ldx	#4		;do four bits
pack2	rol	a
	rol	in
	rol	in+1
	dex
	bne	pack2
	pla			;get char back
;first see if GO = G
pack3	cmp	#'G'		;go at point
	bne	notg
	jmp	(|point)
;second see if OPEN = O, if so set address to hex value
;entered in "in". if user has entered more than four hex
;digits only the last four entered are used.
notg	cmp	#'O'		;open
	bne	noto
	lda	in
	sta	point
	lda	in+1
	sta	point+1
	rts
;see if SET = S, if so set memory contents at (point)
;to value in low part of "in". Note that if user
;has entered more than two hex digits only the last two
;are used.
noto	cmp	#'S'		;set
	bne	nots
	lda	in
	sta	(point),y	;store at point
;automatically bump pointer by one
noto1	inc	point
	bne	incpt1
	inc	point+1
incpt1	rts
;see if NEXT = N, if so bump memory address by one
nots	cmp	#'N'		;next
	beq	noto1
;see if PREVIOUS = P, if so decrement address by one
	cmp	#'P'		;previous
	bne	notp
	lda	point		;if low
	bne	nodchp		;do not do high
	dec	point+1		;else drop it
nodchp	dec	point		;then low
	rts
;see if Q, if so boot dos/65 from drive A
notp	cmp	#'Q'		;dos/65 boot
;else loop for more
	bne	read		;loop if not
;dos/65 bootstrap from drive A - this routine
;does not use sim but relies on routines in monitor.
boot	jsr	btsetup		;set up for cold boot
	jsr	btlp12		;do read
	jmp	(btex)		;execute
;warm boot dos/65 from drive A - this is called from
;SIM and returns where SIM executes refreshed system.
warm	jsr	btsetup		;read parameters
;now configure to just read CCM & PEM
	lda	#(ccmlng+pemlng)/128	;calculate number records
	sta	btln		;then modify what disk said
;	jmp	btlp12		;and read
;do the actual read and move of records from disk
;to memory.
btlp12
;move record starting at (btmov) to (btld) - at conclusion
	ldx	#128		;use x as byte counter
btlp	ldy	#0
	lda	(btmov),y	;get byte from buffer
	sta	(btld),y	;move to memory
;bump addresses
	inc	btmov		;start with source
	bne	btmovx		;skip if no carry
	inc	btmov+1		;bump high
btmovx	inc	btld		;now do destination
	bne	btldx		;skip if no carry
	inc	btld+1		;bump high
btldx	dex			;drop counter
	bne	btlp		;loop until end record
;both addresses have been incremented by 128.
;see if all records moved
	dec	btln		;drop count
	bne	btmore		;more to do
	rts
;more records remain - see if more in sector
btmore	dec	btcount		;drop count
	bne	btlp12		;loop if more
;now reset pointers, counters, read sector, and loop
	lda	#<hstbuf	;first reset btmov
	ldy	#>hstbuf	;to start of buffer
	sta	btmov
	sty	btmov+1
	jsr	setdma		;also reset pointer
	lda	#4		;now reset btcount
	sta	btcount		;to 4
	inc	nxtsec		;now bump sector
	bne	btsecx		;no carry
	inc	nxtsec+1
btsecx	jsr	rdesec		;read sector
	bra	btlp12		;loop
;set up for boot by setting basic parameters and reading
;first sector and record.
btsetup	lda	#0		;use drive A
	jsr	setdrv
;note that home also saves track as 0
	jsr	home		;send it to home
	lda	#<hstbuf	;use host buffer
	ldy	#>hstbuf
	jsr	setdma		;for all reads
	lda	#0		;start at sector 0
	tay
	jsr	setsec
;now read first sector to get parameters
	jsr	rdesec		;do the read
;host buffer now contains boot info in the first record
;and the first three records of the system.
;First extract parameters...
	lda	hstbuf		;start with btld
	ldy	hstbuf+1
	sta	btld
	sty	btld+1
	lda	hstbuf+2	;now do btex
	ldy	hstbuf+3
	sta	btex
	sty	btex+1
	lda	hstbuf+4	;now get length
	sta	btln
;Parameters are now saved in system area. Prepare
;for move of records from host buffer to memory.
;Always assume three records must be moved.
;First set source 128 bytes into host buffer.
	lda	#(hstbuf+128)*256/256	;do low
	ldy	#(hstbuf+128)/256	;then high
	sta	btmov		;save
	sty	btmov+1
;set counter to 3
	lda	#3		;last three records
	sta	btcount		;of sector
	rts
;subroutines
;get keyboard input
;this routine waits until a key is pressed. it also
;converts any input bs to a delete to match cp/m
;console behaviour.
conrde	jsr	consts
	beq	conrde
	lda	adta		;get data
	and	#$7f
;see if backspace and if so convert to delete
	cmp	#bs		;check for bs
	bne	conrdx		;use as is if not
	lda	#delete		;else make delete
conrdx	rts
;test keyboard status
consts	lda	actl		;read status
	and	#%00000001	;isolate receive status bit
	beq	conste		;done if zero
	lda	#$ff		;else set all bits
conste	rts
;monitor cr and lf
crlf	lda	#cr
	jsr	conwrt
	lda	#lf
	bne	conwrt		;send and return
;output a space
outsp	lda	#' '
;console write
;alters:a,p
conwrt	pha			;save char on stack
	and	#$7f		;clear msb
	cmp	#delete		;see if delete
	bne	notdlt		;isn't
	lda	#' '		;else make space
notdlt	cmp	#clreol		;see if clear to eol
	bne	ntceol		;not so skip
	lda	#esc		;else get an esc
	jsr	doout		;send it
	lda	#'T'		;then a cap T
	jsr	doout
	bra	endvid		;then exit
ntceol	cmp	#clreos		;see if clear to eos
	bne	ntceos		;not so jump
	lda	#esc		;send esc sequence
	jsr	doout
	lda	#'Y'		;and y
	jsr	doout
	bra	endvid		;then exit
ntceos	jsr	doout		;send as regular char
endvid	pla			;get char back
	rts
;actually send a char to SCC Port A
doout	pha			;save char
trmbsy	lda	actl		;get status
	and	#%00000100	;isolate bit
	beq	trmbsy		;not ready so loop
	pla			;get char back
	sta	adta		;then send it
	rts
;printer output to SERIAL IO port b
prnwrt	pha			;save character
prnrdy	lda	bctl		;get status
	and	#%00000100	;check ready
	beq	prnrdy		;loop if not
	pla			;get character back
	sta	bdta		;send to data register
	rts			;done
;output pointer as two bytes
outpnt	lda	point+1		;high byte
	jsr	outbyt
	lda	point
;output byte as two nibbles
outbyt	pha
	lsr	A
	lsr	A
	lsr	A
	lsr	A
	jsr	hex
	pla
;output a hex nibble
hex	and	#$F
	ora	#'0'
	cmp	#'9'+1
	bcc	hex1
	adc	#6
hex1	jmp	conwrt		;go to output
;message output routine
;message is located at ay and is terminated
;by a zero or after 256th character.
;since this routine calls conwrt, characters in
;the string will be expanded to full strings needed
;for terminal control.
;alters:a,p,y,in,in+1
outmsg	sta	in		;set pointer
	sty	in+1
	ldy	#0		;clear index
msgout	lda	(in),y
	beq	msgend
	jsr	conwrt
	iny
	bne	msgout
msgend	rts
;check for HD and set z=1 if HD is nxtdrv
testhd	lda	nxtdrv		;get next
	cmp	#2		;see if C:
	beq	ishd		;done if is
	cmp	#3		;see if D:
	beq	ishd		;done if is
	cmp	#4		;see if E:
	beq	ishd		;done if is
	cmp	#5		;see if F:
ishd	rts
;set drive for rdesec/wrtsec/home/rest
setdrv	sta	nxtdrv		;save
	rts
;do actual select for floppy
;if ok then z=1 else z=0 and errcde is set
;alters:a,p,x,trktab,curdrv,phytrk,physec,offprm,cntbit,chksid
;first see if single sided and if so skip ahead
dosel	ldx	nxtdrv
	lda	sidet,x
	beq	sngsid
;ok, we know it is double sided - now we need to determine
;which algorithm to use
;first see if Kaypro IV and if so skip ahead
	cmp	#1
	beq	kayp4
;now assume it is 1.2 mb 5 inch drive and set offset
	lda	#15
	bne	likek4
;here is Kaypro IV section - first set offset
kayp4	lda	#10
;common code for Kaypro 4 like drives
likek4	sta	offprm
;first assume it is side 0
	lda	#csd0
	sta	cntbit
	stz	secoff
	stz	chksid
;now actually find out side and other data
	lda	nxttrk
	and	#1
;if it really is side 0 then done
	beq	k4sd0
;else set up for side 1
	lda	#csd1
	sta	cntbit
	lda	offprm
	sta	secoff
;do the calculations
k4sd0	lda	nxtsec
	clc
	adc	secoff
	sta	physec
	lda	nxttrk
	lsr	a
	sta	phytrk
	bra	sdrdy
;here is single sided code - simple
sngsid	lda	nxtsec
	sta	physec
	lda	nxttrk
	sta	phytrk
	lda	#csd0
	sta	cntbit
	lda	#xsdnc
	sta	chksid
;ok - now we are ready to start sending and getting
;controller data
;first calculate correct control byte and set it
sdrdy	ldx	nxtdrv
	lda	contt,x
	and	#csdmsk
	ora	cntbit
;save for possible use later
	sta	selcde
	sta	dcont
	jsr	busy		;wait for 1795
	lda	track		;then get track from 1795
	ldx	curdrv		;get old drive number
	sta	trktab,x	;and put in table
	ldx	nxtdrv		;get new number
	stx	curdrv		;and update current
	lda	trktab,x	;get track
	sta	track		;set track
	sta	ddata		;and data also
;if supposed to be at track 0 - do restore
	bne	norest
	jsr	dohome
;now seek correct track
norest	lda	dcont		;get step rate
	and	#%00000011	;isolate bits
	ora	#%00011000	;seek with load
	jsr	ex1795		;head
	jsr	busy		;and wait for end
	lda	#0
	sta	errcde		;save in case bad
selext	rts			;return
;drive tables - base select code
contt	byte	$23,$22,0,0,0,0,$22,$23
;double side mode and algorithm table
; 0 single sided or not floppy
; 1 Kaypro IV (offset = 10)
; 2 1.2 MB (like Kaypro IV but offset = 15)
sidet	byte	2,1,0,0,0,0,0,2
;set sector number
setsec	sta	nxtsec		;save low and high
	sty	nxtsec+1
	rts
;set buffer address
;alters:none
setdma	sta	dma1		;store low
	sta	dma2
	sty	dma1+1		;and high
	iny			;bump high
	sty	dma2+1
	dey
	rts			;then return
;read dos/65 sector from floppy or IDE
; on return a=0 if no errors,=1 if error
rdesec	lda	#2		;say is read op
	sta	optype
	jsr	testhd		;see if winchester
	bne	fread		;if not do floppy
	jmp	ReadSector	;else do hard disk
;read sector from floppy
fread	jsr	dosel		;select drive
	bne	cmnerr		;exit if error
	jsr	seek		;and track
	bne	cmnerr		;exit if error
	lda	#rtcnt		;get retry limit
	sta	ercnt		;and set counter
rretry	ldy	#0		;set index to zero
	jsr	forint		;force interrupt
	jsr	busy		;wait for idle
	lda	physec		;get sector &
	sta	sectp		;store sector
	php			;save interrupt status
	sei			;disable interrupts
	lda	dstat		;get status
	and	#%00100000	;look at head load
	beq	readl		;if not loaded load head
	lda	#%10001000	;else read w/o load
	bne	reade		;do it
readl	lda	#%10001100	;read with load
;now set side control correctly
reade	and	#xsdmsk
	ora	chksid
	jsr	ex1795		;send command and wait
rdelp1	bit	dcont		;test intrq & drq
	bvc	rdelp1		;loop if no drq
	lda	ddata		;get byte
	sta	(dma1),y	;store it
	iny			;bump index
	bne	rdelp1		;and loop
rdelp2	bit	dcont		;test intrq & drq
	bvc	rdelp2		;loop for drq
	lda	ddata		;get byte
	sta	(dma2),y	;put in buffer
	iny			;bump index
	bne	rdelp2
rddone	jsr	busy		;wait for not busy
	lda	dstat		;read status
	plp			;restore interrupt status
	and	#%10011100	;look at error bits
	sta	errcde		;save for error
	beq	rdeok		;done if no error
check	jsr	erchk		;check error
	dec	ercnt		;count down
	bne	rretry		;and loop if not zero
	jsr	dskerr		;report error
	lda	#1		;and set for error
rdeok	rts			;on return
;check for not found error
erchk	and	#%00010000	;if not not found
	beq	rdeok		;then do no reseek
;do home and reseek
chksk	jsr	busy		;wait for 1795
	jsr	dohome		;and home
	jmp	seek		;do seek
;common floppy error link
cmnerr	jmp	dskerr		;do common
;write dos/65 sector to floppy or IDE
;return with a=0 if ok or a<>0 if error
wrtsec	lda	#4		;set op type
	sta	optype
	jsr	testhd		;see if HD
	bne	fwrit		;if not go do floppy
	jmp	WriteSector	;else do hard disk
;write sector to floppy
fwrit	jsr	dosel		;select drive
selbne	bne	cmnerr		;exit if error
	jsr	seek		;and track
	bne	cmnerr		;exit if error
	lda	#rtcnt		;get retry limit
	sta	ercnt		;and set counter
wretry	ldy	#0		;set index to zero
	jsr	forint		;force interrupt
	jsr	busy		;wait for idle
	lda	physec		;get sector
	sta	sectp		;store sector
	php			;save interrupt status
	sei			;disable interrupts
	lda	dstat		;look at status
	and	#%00100000	;look at head load
	beq	writel		;if not loaded do load
	lda	#%10101000	;else do not load
	bne	write2		;do command
writel	lda	#%10101100	;load head
;now set side bit correctly in command
write2	and	#xsdmsk
	ora	chksid
	jsr	ex1795		;send command and wait
wrtlp1	bit	dcont		;look for intrq & drq
	bvc	wrtlp1		;loop if no drq
	lda	(dma1),y	;get byte
	sta	ddata		;send
	iny			;bump index
	bne	wrtlp1		;and loop
wrtlp2	bit	dcont		;look for intrq & drq
	bvc	wrtlp2		;loop for drq
	lda	(dma2),y	;get byte
	sta	ddata		;and send
	iny			;bump index
	bne	wrtlp2		;and loop
wdone	jsr	busy		;wait for not busy
	lda	dstat		;look at status
	plp			;restore interrupt status
	and	#%11111100	;look at error bits
	sta	errcde		;save if error
	beq	wrtok		;done if no error
	jsr	erchk		;check error
	dec	ercnt		;and count down
	bne	wretry		;if not zero try again
	jsr	dskerr		;report error
	lda	#1		;return with error
wrtok	rts
;move to track zero
;note that for IDE this entry does nothing!!!
home	stz	nxttrk		;clear current track
	stz	nxttrk+1
	stz	phytrk
	stz	optype		;say is home
	jsr	testhd		;see if HD
	beq	homend		;done if is
	jsr	dosel		;select drive
	bne	selbne		;exit if error
;the following entry point is used in erchk
;to do a restore on drive if not found error.
dohome	jsr	busy		;wait until not busy
	lda	dcont		;get bits
	and	#%00000011	;isolate them
	ora	#%00001100	;make a restore
	jsr	ex1795		;command
homelp	bit	dcont		;test for intrq
	bpl	homelp		;loop if not
	lda	#0
	sta	errcde		;clear error code
homend	rts			;done
;set track
settrk	sta	nxttrk		;save number
	sty	nxttrk+1
	rts
;seek track
;if ok then z=1 else z=0
seek	lda	#rtcnt		;get limit
	sta	sercnt		;and set counter
sretry	jsr	busy		;wait for not busy
	lda	track		;then get track
	cmp	phytrk		;see if same
	beq	there		;done if same
	lda	phytrk		;get desired
	sta	ddata		;send as data
	lda	dcont		;get step rate
	and	#%00000011	;isolate bits
	ora	#%00011100	;make command
	jsr	ex1795		;and execute
seeklp	bit	dcont		;test for complete
	bpl	seeklp		;loop if not
	lda	dstat		;read status
	and	#%10011001	;look at error bits
	sta	errcde		;save error code
	beq	there		;if zero done
	dec	sercnt		;and count down
	bne	sretry		;if not zero loop
	lda	#$ff		;say major error
there	rts
;wait for 1795 not busy
busy	lda	dstat		;read status
	lsr	a		;get busy bit
	bcs	busy		;loop if set
	rts			;else done
;force interrupt and wait
forint	lda	#%11010000	;issue
;execute 1795 command
ex1795	sta	dcom		;send command
;do a big delay
	jsr	twelve		;wait 12 clock cycles
	jsr	twelve		;for each jsr-rts
	jsr	twelve
	jsr	twelve
;delay twelve microseconds
twelve	rts
;hard disk routines
;
;Delay A seconds. Times are for 2 MHz 65C02 clock.
DelayAx1Sec
	sta	Seconds		;save number seconds
Delay1	ldy	#174		;low byte of inner loop cycles
	stz	InnerDelay
	sty	OuterDelay
;Inner loop is 256x45x0.5usec=5760usec at 2MHz so
;1000000usec=(5760+6+3)n so n=174=loops needed at 2 MHz.
DELAY2	jsr	PadDly		;now delay a bunch
	jsr	PadDly		;in a way that does not
	jsr	PadDly		;alter flag
	dec	InnerDelay	;drop counter
	bne	delay2		;loop
	dec	OuterDelay
	bne	DELAY2		;loop
	DEC	seconds		;drop seconds
	bne	DELAY1		;loop if another Sec
PadDly	rts
;
;NOPs have been added to raise the inner loop delay to
;about 4.5usec at 2 MHz. With x=222 the overall delay
;is about 1msec. Therefore A specifies the number of mSec.
;Input:	A = number of mSec to delay
DelayAx1mSec
DELAY3	ldx	#222
M0	nop
	nop
	dex
	bne	m0
	DEC	A
	bne	DELAY3 
	RET	
;Wait for IDE drive not busy.
;IDE Drive not BUSY if status register has 0 in bit 7 (BSY)
IDEWAITNOTBUSY
	stz	OuterDelay	;set timers for both loops
	stz	InnerDelay
MOREWAIT
	ldx	#REGSTATUS
	jsr	IDERD8D
	AND	#%10000000	;test bit
	beq	DONENOTBUSY	;done if 0
	DEC	InnerDelay	;drop inner counter
	bne	MOREWAIT	;loop if no wrap
	dec	OuterDelay	;drop outer counter
	bne	MOREWAIT	;loop if no wrap
	sec			;Set carry to indicate an error
	rts
DONENOTBUSY
	clc			;Clear carry it indicate no error
	rts
;
;Wait for IDE drive ready
;IDE Drive READY if status register has 1 in bit 6 (RDY)
IDEWaitReady
	stz	OuterDelay	;set timers for both loops
	stz	InnerDelay
MOREWAITReady
	ldx	#REGSTATUS	;get read status command
	jsr	IDERD8D
	AND	#%01000000
	bne	DONEREADY	;ready if not zero
	DEC	InnerDelay	;drop inner counter	
	bne	MOREWAITReady	;loop if no wrap
	DEC	OuterDelay	;drop outer counter
	bne	MOREWAITReady	;loop if no wrap
	sec			;Set carry to indicate an error
	rts
DONEREADY
	clc			;Clear carry it indicate no error
	rts
;
;Wait for the drive to be ready to transfer data.
;Returns the BUSY and DRQ bits of drive status in A
IDEWAITDRQ
	stz	OuterDelay	;set timers for both loops
	stz	InnerDelay
MOREDRQ
	ldx	#REGSTATUS	;get read status command
	jsr	IDERD8D		;send it
	AND	#%10001000	;look at BUSY & DRQ
	cmp	#%00001000	;check for correct state
	beq	DONEDRQ		;done if correct
	DEC	InnerDelay	;drop inner counter
	bne	MOREDRQ		;loop if no wrap
	DEC	OuterDelay	;now drop outer
	bne	MOREDRQ
	sec			;Set carry to indicate error
	rts
DONEDRQ
	clc			;Clear carry
	rts
;------------------------------------------------------------------
; Low Level 8 bit R/W to the drive controller.  These are the routines that talk
; directly to the drive controller registers, via the 8255 chip.  
; Note the 16 bit I/O to the drive (which is only for SEC R/W) is done directly 
; in the routines READSECTOR & WRITESECTOR for speed reasons.
;
;READ 8 bits from IDE register in X, return info in A
IDERD8D
	LDA	#READCFG8255	;Config 8255 chip, read mode
	sta	IDEPORTCTRL	;just in case
	stx	IDEPORTC	;drive address onto control lines
	txa
	ORA	#IDERDLINE	;RD pulse pin (40H)
	sta	IDEPORTC	;assert read pin
	lda	IDEPORTA	;get register
	stx	IDEPORTC	;de-assert RD pin
	stz	IDEPORTC	;Zero all port C lines
	rts
;
;WRITE Data in A to IDE register in X
IDEWR8D:
	ldy	#WRITECFG8255	;Set 8255 to write mode
	sty	IDEPORTCTRL
	sta	ideporta	;Get data put it in 8255 A port
	stx	IDEPORTC
	txa
	ORA	#IDEWRLINE	;lower WR line
	sta	IDEPORTC
	stx	IDEPORTC	;de-assert WR pin
	stz	IDEPortC	;Deselect all lines including WR line
	LDA	#READCFG8255	;Config 8255 chip, read mode on return
	sta	IDEPORTCTRL
	rts
;
;Write the logical block address to the drive registers
;Note we do not need to set the upper nibble of the LBA
;It will always be 0 for these small drives.
;In the following description I show them as MSB | LSB
;At entry nxtsec contains 0 to 255
;			00000000|ssssssss
;and nxttrk contains 1 to 64 - starts at one because of
;reserved system track.
;			00000000|0ttttttt
;first step is to copy nxtsec to @lba with end result being
;			ssssssss in @lba
;then copy nxttrk to @lba+1 & clear @lba+2
;so @lba+2|@lba+1|@lba look like:
;			00000000|0ttttttt|ssssssss
;This is used as is for drive C and for other drives an
;offset of 16640 for each previous drive is added
;to the LBA number.
wrlba	lda	nxtsec		;start with sector and
;save in @lba
	sta	lba
;now copy nxttrk to chain
	lda	nxttrk		;get low
	sta	lba+1		;save and clear next
	stz	lba+2		;and clear high byte
	stz	lba+3		;and high nibble
;The LBA data assumed drive always started at LBA=0.
;Initially that means drive C: is used as calculated.
;Drives D - F must have an offset added in.
;Each drive = 8 MB + one tracks = 16640 512-byte sectors.
	lda	nxtdrv		;get drive number
	dec	a			;drop to HD 0-3
	dec	a
	asl	a		;multiply by two
	tax			;move offset index to
	clc			;clear carry
	lda	lba		;get lba
	adc	offset,x	;add low of offset
	sta	lba		;and save
	lda	lba+1		;do same for high
	inx
	adc	offset,x
	sta	lba+1
;no let's handle any carry - will possibly be in later partitions
	lda	lba+2		;get next two bytes
	adc	#0
	sta	lba+2		;only need to handle low
;at this point LBA address is calculated and stored now
;is the time to send it to the controller and drive.
;
;Check for drive BUSY before loading registers
	jsr	IDEWaitNotBusy	;wait for not busy
	bcc	OK001
	jmp	ShowErrors	;error if time out
OK001	lda	lba		;get first byte
	sta	DRIVESEC	;For Diagnostic Display Only
	ldx	#lba0		;Send info to drive
	jsr	IDEWR8D
	lda	lba+1		;now get next
	sta	drivesec+1	;display
	ldx	#lba1
	jsr	idewr8d		;send to drive
	lda	lba+2		;keep going	
	sta	DRIVETRK
	LDX	#lba2
	jsr	IDEWR8D
	LDA	lba+3
	sta	DRIVETRK+1
	ora	#%11100000	;lba mode master
	LDX	#lba3
	jsr	IDEWR8D
	LDA	#1		;For now, one sector at a time
	LDX	#REGSECCNT
	jmp	IDEWR8D		;do and return	
;Table of LBA offsets for drives C, D, E, & F
Offset	dw	0		;drive c
	dw	16640		;drive d
	dw	33280		;drive e
	dw	49920		;drive f
;Bump DMA1 pointer by one
BumpDMA1
	inc	dma1		;bump pointer again
	bne	NoWrap
	inc	dma1+1
NoWrap	rts
;Read a sector, specified by the 3.5 bytes in LBA
;Z on success, NZ call error routine if problem
READSECTOR
	jsr	WRLBA		;Compute which sector we want to read
	jsr	IDEWaitReady	;make sure drive is ready
	bcc	OK003
NOTOKR	JMP	SHOWERRORS	;error is time out
OK003	LDA	#COMMANDREAD
	LDX	#REGCOMMAND
	jsr	IDEWR8D		;Send sec read command to drive.
	jsr	IDEWAITDRQ	;wait until it's got the data
	bcs	NOTOKR		;exit if error
	LDA	#<hstbuf	;host buffer start
	ldy	#>hstbuf
	sta	dma1		;save pointer
	sty	dma1+1
	LDX	#0		;Read 512 bytes to buffer (256X2 bytes)
	ldy	#0		;clear index
MORERD16:
	LDA	#REGDATA	;REG register address
	STA	IDEPORTC
	ORA	#IDERDLINE	;08H+40H, Pulse RD line
	sta	IDEPORTC
	lda	IDEPORTA	;Read the lower byte first (Note very early versions had high byte then low byte
	sta	(dma1),y	;store lower byte
	jsr	BumpDMA1	;bump pointer
	lda	IDEPORTB	;THEN read the upper byte
	sta	(dma1),y	;store upper byte
	jsr	BumpDMA1
	LDA	#REGDATA	;De-assert RD line
	sta	IDEPORTC
	dex
	bne	MORERD16
	LDX	#REGSTATUS
	jsr	IDERD8D
	AND	#1
	bne	NotOKR		;If error display status
	RTS

;Write a sector, specified by the 3.5 bytes in LBA 
;Z on success, NZ to error routine if problem
WRITESECTOR:
	jsr	WRLBA		;Compute sector we want to write
	jsr	IDEWaitReady	;make sure drive is ready
	bcc	OK005
NotOKW	JMP	SHOWERRORS	;error if time out
OK005	LDA	#COMMANDWRITE
	LDX	#REGCOMMAND
	jsr	IDEWR8D		;tell drive to write a sector
	jsr	IDEWAITDRQ	;wait unit it wants the data
	bcs	NotOKW		;if error say so
	lda	#<hstbuf	;point to buffer
	ldy	#>hstbuf
	sta	dma1
	sty	dma1+1
	LDX	#0		;256X2 bytes
	ldy	#0		;clear index
	LDA	#WRITECFG8255	;set 8255 to write
	sta	IDEPORTCTRL)
WRSEC1:	LDA	(dma1),y	;get low byte
	sta	IDEPORTA	;Write the lower byte first (Note early versions had high byte then low byte
	jsr	BumpDMA1
	LDA	(dma1),y	;get high
	sta	IDEPORTB	;THEN send
	jsr	BumpDMA1	;bump pointer again
	LDA	#REGDATA
	sta	IDEPORTC	;Send write command
	ORA	#IDEWRLINE	;Send WR pulse
	sta	IDEPORTC
	lda	#regdata
	sta	IDEPORTC
	dex			;drop counter
	bne	WRSEC1
	LDA	#READCFG8255	;Set 8255 back to read mode
	sta	IDEPORTCTRL	
	LDX	#REGSTATUS
	jsr	IDERD8D
	AND	#1
	bne	NotOKW		;If error display status
	RTS
;
;reset the drive to 0 and initialize the controller
IDEReset
	stz	idedrive	;and fall through to initialize
;Initialize the 8255 
IDEINIT
	LDA	#READCFG8255	;Config 8255 chip (10010010B), read mode on return
	sta	IDEPORTCTRL	;Config 8255 chip, READ mode
;Hard reset the disk drive 
;For some reason some CF cards need to have the RESET line 
;pulsed very carefully. You may need to play around
;with the pulse length. Symptoms are: incorrect data coming   
;back from a sector read (often due to the wrong sector being read).
;I have seen references to IDE controllers that
;generate a 65 mSec reset pulse so I changed this.
;First assert (lower) the reset line.
	LDA	#IDERSTLINE	;No IDE control lines asserted (just bit 7 of port C)
	sta	IDEPORTC
	lda	#65		;do 65 mSec reset
	jsr	DelayAx1mSec
	stz	IDEPORTC
	lda	#40		;delay 40 mSec.
	jsr	DelayAx1mSec	;Short Delay
	jsr	IDEWaitNotBusy	;ensure drive not busy
	bcc	OK002
	jmp	showerrors	;abort if busy time out
OK002	lda	#%11100000	;Data for IDE SDH reg (512bytes, LBA mode,single drive,head 0000)
	LDX	#REGSHD		;00001110,(0EH) for CS0,A2,A1,  
	jsr	IDEWR8D		;Write byte to select the MASTER device
;Adjust cycle count or delay time for hard disks to get up to speed (Currently ~ 
;one cycle of two seconds.
;This delay need to be much longer for actual Hard Disks, OK for CF Cards.	
WAITINIT
	LDX	#REGSTATUS	;Get status after initialization
	jsr	IDERD8D		;Check Status (info in A)
	AND	#80
	bne	NOTOK001
	rts			;Return. We'll check for errors when we get back
NOTOK001
	LDA	#2		;wait two seconds because
	jsr	DelayAx1Sec	;drive has to get up to speed
	lda	#255		;set error flag
	rts
;
;floppy disk error handler/reporting
dskerr
;	lda	#<ioemsg	;do general error msg
;	ldy	#>ioemsg
;	jsr	outmsg
	jmp	showerrors	;else reboot
;SERIAL IO Port A initialization table
;Baseline BRG input is 4.9152 MHz
SCCInitA
	byte	4,%01000100	;WR4 = x16 clock, 1 stop, no p
	byte	3,%11000001	;WR3 = enable receiver, auto enable, receive 8 bits
	byte	5,%11101010	;WR5 = enable transmit, 8 bits, set rts & dtr
	byte	11,%01010110	;WR11 = rcv and xmit clock is brg
	byte	12,%00000010	;WR12 = low count for 38,400 bps
;WR 12 values for other bit rates are
;	byte	12,%01000000	;WR12 = low count for 2400 bps
;	byte	12,%00011110	;WR12 = low count for 4800 bps
;	byte	12,%00001110	;WR12 = low count for 9600 bps
;	byte	12,%00000110	;WR12 = low count for 19200 bps
;	byte	12,%00000000	;WR12 = low count for 76800 bps
	byte	13,%00000000	;WR13 = high byte for BRG
	byte	14,%00000001	;WR14 = enable BRG
;SERIAL IO Port B initialization table
;Baseline BRG input is 4.9152 MHz
SCCInitB
	byte	4,%01000100	;WR4 = x16 clock, 1 stop, no p
	byte	3,%11000001	;WR3 = enable receiver, auto enable, receive 8 bits
	byte	5,%11101010	;WR5 = enable transmit, 8 bits, set rts & dtr
	byte	11,%01010110	;WR11 = rcv and xmit clock is brg
;WR 12 values for other bit rates are
;	byte	12,%01000000	;WR12 = low count for 2400 bps
;	byte	12,%00011110	;WR12 = low count for 4800 bps
;	byte	12,%00001110	;WR12 = low count for 9600 bps
	byte	12,%00000110	;WR12 = low count for 19200 bps
;	byte	12,%00000010	;WR12 = low count for 38,400 bps
;	byte	12,%00000000	;WR12 = low count for 76800 bps
	byte	13,%00000000	;WR13 = high byte for BRG
	byte	14,%00000001	;WR14 = enable BRG
;messages
opnmsg	byte	cr,lf,"65C02 V10.00",0
ioemsg	byte	cr,lf,"IO ERROR",0
;basic reset etc. vectors
	org	$fffa
	word	nmi
	word	entry
	word	irqbrk
	ends

	end
