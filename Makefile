prefix = /usr/

all:
	mkdir bin/
	./scripts/stage1.sh $(CURDIR)/bin/recovery.img

install:
	install -D scripts/recovery_localize \
		$(DESTDIR)$(prefix)/bin/recovery_localize
	install -D scripts/recovery_sync \
		$(DESTDIR)$(prefix)/bin/recovery_sync
	install -D bin/recovery.img \
		$(DESTDIR)/boot/recovery.img

clean:
	rm -rf bin/recovery.img
	rm -rf bin

distclean: clean

uninstall:
	-rm -f $(DESTDIR)$(prefix)/bin/recovery_localize
	-rm -f $(DESTDIR)$(prefix)/bin/recovery_sync
	-rm -f $(DESTDIR)/boot/recovery.img

.PHONY: all install clean distclean uninstall
