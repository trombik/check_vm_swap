SRC_DIR=	src
SRC=		${SRC_DIR}/check_vm_swap.pl
BIN=		${SRC:C/.pl//}

.SUFFIXES:	.pl

all:	${BIN} README

.pl:
	cp ${.IMPSRC} ${.TARGET}
	chmod +x ${.TARGET}

update_README:	rm_README README

rm_README:
	rm README

README:
	pod2text ${SRC} > ${.TARGET}

clean:
	rm -f ${BIN}
