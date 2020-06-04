prefix = /usr

all:
	mkdir bin/
	./scripts/stage1.sh $(CURDIR)/bin/recovery.img

install:
	install -D scripts/recovery_sync \
		$(DESTDIR)$(prefix)/bin/recovery_sync
	install -D bin/recovery.img \
		$(DESTDIR)/boot/recovery.img
	install -D scripts/42_bootcount \
		$(DESTDIR)/etc/grub.d/42_bootcount
	install -D scripts/42_recovery \
		$(DESTDIR)/etc/grub.d/42_recovery

clean:
	rm -rf bin/recovery.img
	rm -rf bin

distclean: clean

uninstall:
	-rm -f $(DESTDIR)$(prefix)/bin/recovery_sync
	-rm -f $(DESTDIR)/boot/recovery.img
	-rm -f $(DESTDIR)/etc/grub.d/42_bootcount
	-rm -f $(DESTDIR)/etc/grub.d/42_recovery

shellcheck:
	shellcheck --exclude=SC1090,SC1091 $$(shfmt -f .)

shfmtcheck:
	shfmt -d .

.PHONY: all install clean distclean uninstall shellcheck shfmtcheck
