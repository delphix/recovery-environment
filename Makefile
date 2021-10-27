prefix = /usr

all:
	mkdir bin/
	./scripts/stage1.sh $(CURDIR)/bin/recovery.img

install:
	install -D scripts/recovery_sync \
		$(DESTDIR)$(prefix)/bin/recovery_sync
	install -D bin/recovery.img \
		$(DESTDIR)/$(prefix)/share/recovery_environment/recovery.img
	install -D scripts/42_recovery \
		$(DESTDIR)/etc/grub.d/42_recovery

clean:
	rm -rf bin/recovery.img
	rm -rf bin

distclean: clean

uninstall:
	-rm -f $(DESTDIR)/$(prefix)/bin/recovery_sync
	-rm -f $(DESTDIR)/$(prefix)/share/recovery_environment/recovery.img
	-rm -f $(DESTDIR)/etc/grub.d/42_recovery

.PHONY: all install clean distclean uninstall
