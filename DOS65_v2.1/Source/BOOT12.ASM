;boot12.asm
;dos/65 coldstart loader
;released:	17 April 2011
;This version establishes the boot parameters for the MON910 "Q"
;command to boot from the 5.25 inch, 80t, dshd drive.
;It enables MON to load CCM, PEM and SIM and then enter SIM.
;variables
msize	=	62		;memory size in decimal KB
;next parameter defines the total space allocated to SIM
;including all undefined data areas.
pages	=	12		;sim length in pages (max is tbd)
;derived parameters
memlng	=	msize*1024	;memory length in bytes
simlng	=	pages*256	;sim length in bytes
pemlng	=	3072		;pem length in bytes
ccmlng	=	2048		;ccm length in bytes
sim	=	memlng-simlng	;start of SIM
pem	=	sim-pemlng	;start of PEM
ccm	=	pem-ccmlng	;start of CCM
;next parameter defines how much of ccm, pem, and sim
;to load from the system track. CCM & PEM lengths
;are fixed in dos/65 v2.1x at 2048 and 3072 bytes or a total
;of 5120 bytes or 40 records. That allows the code and
;initialized data areas of SIM to be up to 19 records or
;2432 bytes. That is much longer than the current version
;needs so SIM length is OK and all 2432 bytes will be
;loaded during the boot process even though much of the
;end of that region is garbage. This means that the last
;location altered is $f57f. Since that is lower than the
;start of the host buffer at $f5c0 the boot process will not
;cause memory conflicts.
numrec	=	15*4-1		;128 byte records to load
;actual data block starts here
		*=	0
Boot
		.word	ccm	;load address
		.word	sim	;cold start address
		.byte	numrec	;number of 128 byte records
		.end
