rem	basic-e/65 system status routine for dos/65
rem	Version 2.12
rem	Yes, I know it is slow but it sure is easier to write
rem	released:
rem		10 april 2008
rem	last revision:
rem		12 april 2008
rem			corrected version number
rem			corrected default drive at exit
REM		3 march 2011
rem			changed drives to alpha
rem			reformatted drive data output
rem	constant definitions
rem	tea must be set to correct address for system
	tea=512
rem	following five lines calculate and save special
rem	i/o links in RUN.COM
	pem=tea+9
	sim=tea+12
	a.reg=tea+15
	y.reg=tea+16
	x.reg=tea+17
rem	these two parameters are the same for all versions
	pem.entry=259
	dfl.buf=296
	e5=229

rem	set up block size array
	dim blk.size$(5)
	blk.size$(0)="1KB "
	blk.size$(1)="2KB "
	blk.size$(2)="4KB "
	blk.size$(3)="8KB "
	blk.size$(4)="16KB "
	
rem	set up hex digit array
	dim hex$(16)
	hex$(0)="0"
	hex$(1)="1"
	hex$(2)="2"
	hex$(3)="3"
	hex$(4)="4"
	hex$(5)="5"
	hex$(6)="6"
	hex$(7)="7"
	hex$(8)="8"
	hex$(9)="9"
	hex$(10)="A"
	hex$(11)="B"
	hex$(12)="C"
	hex$(13)="D"
	hex$(14)="E"
	hex$(15)="F"
	
rem	set up 2**n array for hex conversion
	dim bin.mod(4)
	bin.mod(0)=1
	bin.mod(1)=16
	bin.mod(2)=256
	bin.mod(3)=4096

rem	set up dcb address table
	dim dcb.tbl(8)
	
rem	set up dcb contents table
	dim dcb(8,8)

	print "DOS/65 System Status - V2.12-S"
	
rem	first display TEA start
	a=tea
	gosub 9070
	print "TEA set to ";tea;"or ";a$
	
rem	now display PEM start address
	pem.start=peek(pem.entry+1)+(256*peek(pem.entry+2))
	a=pem.start
	gosub 9070
	print "PEM starts at ";pem.start;"or ";a$
	
rem	calculate amount of free memory from TEA to PEM
	free=pem.start-tea
	a=free
	gosub 9070
	print "Available memory is ";free;"or ";a$

rem	determine how many disks are defined
rem	first get and save default drive
	poke x.reg,25		rem get default
	dfl.drv=call(pem) and 7
	print "Default drive is ";chr$(asc("A")+dfl.drv)
	poke x.reg,13		rem reset system
	dummy=call(pem)

rem	now try to select all eight drives allowed through SIM
	num.drvs=0
	for i=0 to 7
	  a=i
	  gosub 9010
	  dcb.tbl(i)=dcb.addr
	  if dcb.addr <>0 then num.drvs=num.drvs+1
	next i

rem	print number of drives defined
	print num.drvs;"drives defined"
	
rem	populate dcb table with dcb contents
	for i=0 to 7
	  if dcb.tbl(i)<>0 \
	    then \
	      dcb(i,0)=peek(dcb.tbl(i))+(256*peek(dcb.tbl(i)+1)): \
	      dcb(i,1)=peek(dcb.tbl(i)+2)+(256*peek(dcb.tbl(i)+3)): \
	      dcb(i,2)=peek(dcb.tbl(i)+4)+(256*peek(dcb.tbl(i)+5)): \
	      dcb(i,3)=peek(dcb.tbl(i)+6): \
	      dcb(i,4)=peek(dcb.tbl(i)+7)+(256*peek(dcb.tbl(i)+8)): \
	      dcb(i,5)=peek(dcb.tbl(i)+9)+(256*peek(dcb.tbl(i)+10)): \
	      dcb(i,6)=peek(dcb.tbl(i)+11): \
	      dcb(i,7)=peek(dcb.tbl(i)+12)+(256*peek(dcb.tbl(i)+13))
	next i

rem	print dcb contents
	for i=0 to 7
	  if dcb.tbl(i)<>0 \
	    then \
	      print tab(2);"Drive ";chr$(asc("A")+i);" has "; \
		dcb(i,0)+1;blk.size$(dcb(i,3));"blocks, "; \
		dcb(i,1);"records per track, ": \
	      print tab(5);dcb(i,2);"system tracks, and "; \
		dcb(i,4)+1;"directory entries"
	next i
	
rem	reset system
	poke x.reg,13
	dummy=call(pem)
rem	reset drive to default
	a=dfl.drv
	gosub 9000
	
	stop

rem	subroutines

9000	rem set drive to value in a through pem
	poke a.reg,a
	poke x.reg,14
	dummy=call(pem)
	return
	
9010	rem set drive to value in a through sim
	rem and get dcb address
	poke a.reg,a
	poke x.reg,27
	dcb.addr=call(sim)
	return

9050	rem restore default drive
	a=dfl.drv
	gosub 9000
	return

9070	rem convert decimal number in a to
	rem hexadecimal mnumber in $a.
	rem if a<0 or >65535 print error
	rem message and abort program
	if (a<0) or (a>65535) \
	  then \
	    print "Illegal 16 bit number aborting": \
	    stop
	a$="$"
	rem do four digits
	for i=1 to 4
	  for j=1 to 16
	    a=a-bin.mod(4-i)
	    if a<0 \
	      then \
	        a=a+bin.mod(4-i): \
		a$=a$+hex$(j-1): \
		goto 9071
	  next j
9071	next i
	return

	end
