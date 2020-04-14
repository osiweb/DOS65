;my dos/65 boot
;osi - c1p/sbii version
;version 2.03
;released:	29 july 1983 (2.00)
;last revision:	15 jun 1986 (2.01)
;			changed to 16 pages
;		27 july 1986 (2.02)
;			changed to 11 pages
;		12 August 2015 (2.03)
;			put semicolons in comments
;			corrected record - sector terminology
;			made .byt & .wor --> .byte & .word
;definitions
msize	=	40		;memory size in k (k=1024)
pages	=	11		;sim length in pages (page=256)
recrds	=	16		;records per track
systrk	=	4		;number system tracks
;derived parameters
memlng	=	msize*1024	;memory length in bytes
simlng	=	pages*256	;sim length in bytes
sim	=	memlng-simlng	;start of sim
pemlng	=	3072		;pem length in bytes
ccmlng	=	2048		;ccm length in bytes
ccm	=	sim-pemlng-ccmlng	;start of ccm
;actual boot
*	=	$00
ldeadr	.word	ccm		;load start address
simadr	.word	sim		;execution entry address
reclde	.byte	systrk*recrds-1	;amount to load (4 tracks - 1 record)
rectrk	.byte	recrds		;records per track
nxtrec	.byte	2		;first record
	.end
