;********************************************************
;*							*
;*	    CPU TYPE TESTER				*
;*							*
;********************************************************
;
;released:	14 August 2014 (1.00)
;last revision:	12 February 2015 (1.00X)
;			native assembler
;
;DOS/65 definitions
WBOOT	=	$100		;REBOOT ENTRY POINT
PEM	=	$103		;CPM ENTRY POINT
tea	=	$200		:TEA start
;DOS/65 PEM commands
STRING	=	9		;STRING PRINT FUNCTION
;character definitions
ALF	=	$a		;ASCII LINE FEED
ACR	=	$d		;ASCII CARRIAGE RETURN
;
;code section
	*=	tea
	ldx	#$ff		;set stack so must
	txs			;exit with warm boot
	lda	#<opnmsg	;point to welcome message
	ldy	#>opnmsg
	jsr	message		;send it
;now run the test
	lda	#$99
	clc
	sed
	adc	#$01
	cld
	beq	cmos
;we have an NMOS CPU
	lda	#<NMOSMsg	;point to message
	ldy	#>NMOSMsg
	jsr	message		;send it
	jmp	wboot		;and exit
;we have a CMOS CPU
cmos	lda	#<CMOSMsg	;point to message
	ldy	#>CMOSMsg
	jsr	message		;send it
	jmp	wboot
;normal message output for message at ay
MESSAGE	ldx	#STRING		;DISPLAY THE MESSAGE
	jmp	PEM		;and return
;
;messages
opnmsg	.byte	'DOS/65 CPU TYPE TESTER V1.00',acr,alf,'$'
NMOSMsg	.byte	acr,alf,'**** CPU is NMOS - 6502 ****',ACR,ALF,'$'
CMOSMsg	.byte	acr,alf,'**** CPU is CMOS - 65C02 ****',ACR,ALF,'$'
;
	.END
