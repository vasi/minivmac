CC = clang
OPT = -g -O0
CFLAGS = -arch i386 -mmacosx-version-min=10.4 $(OPT)
LDFLAGS = -arch i386 $(OPT) -Wl,-no_pie -framework Carbon -framework Cocoa -framework AGL -framework OpenGL
OBJECTS = GLOBGLUE.o IWMEMDEV.o KBRDEMDV.o M68KITAB.o MOUSEMDV.o MYOSGLUE.o PROGMAIN.o ROMEMDEV.o RTCEMDEV.o SCCEMDEV.o SCRNEMDV.o SCSIEMDV.o SNDEMDEV.o SONYEMDV.o VIAEMDEV.o MINEM68K.o SPARSEBL.o

minivmac: $(OBJECTS)
	$(CC) $(LDFLAGS) -o $@ $^

%.o: %.S
	$(CC) $(CFLAGS) -o $@ -c $<

%.o: %.c
	$(CC) $(CFLAGS) -o $@ -c $<

clean:
	rm -f minivmac *.o

.PHONY: clean
