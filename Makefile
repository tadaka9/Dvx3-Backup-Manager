# Makefile for Dvx3 Backup Manager GUI

.PHONY: all clean

all:
	./build_gui.sh

clean:
	rm -rf backup-manager-gui backup-manager-gui.moc.cpp resources.rcc.cpp qt.conf env.sh platforms
	rm -rf gen-c build/gen-c
	rm -f *.o *.a *.so *.dll *.exe
	rm -f *.log
	rm -f backup-manager-gui*
