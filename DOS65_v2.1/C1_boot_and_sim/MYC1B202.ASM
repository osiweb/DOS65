;my dos/65 boot
;osi - c1p/sbii version
;version 2.02
;released:	29 july 1983
;last revision:	15 jun 1986
;			changed to 16 pages
;		27 july 1986
;			changed to 11 pages
;definitions
msize	=	40		memory size in k (k=1024)
pages	=	11		sim length in pages (page=256)
sectrs	=	16		sectrs per track
systrk	=	4		number system tracks
;derived parameters
memlng	=	msize*1024	memory length in bytes
simlng	=	pages*256	sim length in bytes
sim	=	memlng-simlng	start of sim
pemlng	=	3072		pem length in bytes
ccmlng	=	2048		ccm length in bytes
ccm	=	sim-pemlng-ccmlng	start of ccm
;actual boot
*	=	$00
ldeadr	.wor	ccm		load start address
simadr	.wor	sim		execution entry address
seclde	.byt	systrk*sectrs-1	amount to load (4 tracks - 1 sector)
sectrk	.byt	sectrs		sectors per track
nxtsec	.byt	2		first sector
	.end
