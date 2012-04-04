SRC_DIR=	src
SRC=		${SRC_DIR}/check_vm_swap.pl
BIN=		${SRC:C/.pl//}

.SUFFIXES:	.pl

all:	${BIN} pod

.pl:
	cp ${.IMPSRC} ${.TARGET}
	chmod +x ${.TARGET}

pod:	README.pod

README.pod:
	pod2text ${SRC} > ${.TARGET}

clean:
	rm -f ${BIN}
