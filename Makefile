prefix = /usr

all:
	mkdir bin/
	./scripts/stage1.sh $(CURDIR)/bin/recovery.img

install:
	install -D scripts/recovery_sync \
		$(DESTDIR)$(prefix)/bin/recovery_sync
	install -D bin/recovery.img \
		$(DESTDIR)/$(prefix)/share/recovery_environment/recovery.img
	install -D scripts/42_bootcount \
		$(DESTDIR)/etc/grub.d/42_bootcount
	install -D scripts/42_recovery \
		$(DESTDIR)/etc/grub.d/42_recovery
	install -m 0644 -D scripts/delphix-bootcount.service \
		$(DESTDIR)/lib/systemd/system/delphix-bootcount.service

clean:
	rm -rf bin/recovery.img
	rm -rf bin

distclean: clean

uninstall:
	-rm -f $(DESTDIR)/$(prefix)/bin/recovery_sync
	-rm -f $(DESTDIR)/$(prefix)/share/recovery_environment/recovery.img
	-rm -f $(DESTDIR)/etc/grub.d/42_bootcount
	-rm -f $(DESTDIR)/etc/grub.d/42_recovery
	-rm -f $(DESTDIR)/lib/systemd/system/delphix-bootcount.service

.PHONY: all install clean distclean uninstall
