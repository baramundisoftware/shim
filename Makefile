CC		= $(CROSS_COMPILE)gcc
LD		= $(CROSS_COMPILE)ld
OBJCOPY		= $(CROSS_COMPILE)objcopy

ARCH		= $(shell $(CC) -dumpmachine | cut -f1 -d- | sed s,i[3456789]86,ia32,)

SUBDIRS		= Cryptlib lib

#LIB_PATH	= /usr/lib64

EFI_INCLUDE	:= /usr/include/efi
EFI_INCLUDES	= -nostdinc -ICryptlib -ICryptlib/Include -I$(EFI_INCLUDE) -I$(EFI_INCLUDE)/$(ARCH) -I$(EFI_INCLUDE)/protocol -Iinclude
#EFI_PATH	:= /usr/lib64/gnuefi

LIB_GCC		= $(shell $(CC) -print-libgcc-file-name)
EFI_LIBS	= -lefi -lgnuefi --start-group Cryptlib/libcryptlib.a Cryptlib/OpenSSL/libopenssl.a --end-group $(LIB_GCC) 

EFI_CRT_OBJS 	= $(EFI_PATH)/crt0-efi-$(ARCH).o
EFI_LDS		= elf_$(ARCH)_efi.lds

DEFAULT_LOADER	:= \\\\grub.efi
CFLAGS		= -ggdb -O0 -fno-stack-protector -fno-strict-aliasing -fpic \
		  -fshort-wchar -Wall -Wsign-compare -Werror -fno-builtin \
		  -Werror=sign-compare \
		  "-DDEFAULT_LOADER=L\"$(DEFAULT_LOADER)\"" \
		  "-DDEFAULT_LOADER_CHAR=\"$(DEFAULT_LOADER)\"" \
		  $(EFI_INCLUDES)

ifneq ($(origin OVERRIDE_SECURITY_POLICY), undefined)
	CFLAGS	+= -DOVERRIDE_SECURITY_POLICY
endif

ifeq ($(ARCH),x86_64)
	CFLAGS	+= -mno-mmx -mno-sse -mno-red-zone -nostdinc -maccumulate-outgoing-args \
		-DEFI_FUNCTION_WRAPPER -DGNU_EFI_USE_MS_ABI
endif
ifeq ($(ARCH),ia32)
	CFLAGS	+= -mno-mmx -mno-sse -mno-red-zone -nostdinc -maccumulate-outgoing-args -m32
endif

ifeq ($(ARCH),aarch64)
	CFLAGS	+= -ffreestanding -I$(shell $(CC) -print-file-name=include)
endif

ifeq ($(ARCH),arm)
	CFLAGS	+= -ffreestanding -I$(shell $(CC) -print-file-name=include)
endif

ifneq ($(origin VENDOR_CERT_FILE), undefined)
	CFLAGS += -DVENDOR_CERT_FILE=\"$(VENDOR_CERT_FILE)\"
endif
ifneq ($(origin VENDOR_DBX_FILE), undefined)
	CFLAGS += -DVENDOR_DBX_FILE=\"$(VENDOR_DBX_FILE)\"
endif

LDFLAGS		= -nostdlib -znocombreloc -T $(EFI_LDS) -shared -Bsymbolic -L$(EFI_PATH) -L$(LIB_PATH) -LCryptlib -LCryptlib/OpenSSL $(EFI_CRT_OBJS)

VERSION		= 0.8

TARGET	= shim.efi
OBJS	= shim.o netboot.o cert.o replacements.o version.o
SOURCES	= shim.c shim.h netboot.c include/PeImage.h include/wincert.h include/console.h replacements.c replacements.h version.c version.h

all: $(TARGET)

version.c : version.c.in
	sed	-e "s,@@VERSION@@,$(VERSION)," \
		-e "s,@@UNAME@@,$(shell uname -a)," \
		-e "s,@@COMMIT@@,$(shell if [ -d .git ] ; then git log -1 --pretty=format:%H ; elif [ -f commit ]; then cat commit ; else echo commit id not available; fi)," \
		< version.c.in > version.c

shim.o: $(SOURCES)

cert.o : cert.S
	$(CC) $(CFLAGS) -c -o $@ $<

shim.so: $(OBJS) Cryptlib/libcryptlib.a Cryptlib/OpenSSL/libopenssl.a lib/lib.a
	$(LD) -o $@ $(LDFLAGS) $^ $(EFI_LIBS)

Cryptlib/libcryptlib.a:
	$(MAKE) -C Cryptlib

Cryptlib/OpenSSL/libopenssl.a:
	$(MAKE) -C Cryptlib/OpenSSL

lib/lib.a:
	$(MAKE) -C lib

ifeq ($(ARCH),aarch64)
FORMAT		:= -O binary
SUBSYSTEM	:= 0xa
LDFLAGS		+= --defsym=EFI_SUBSYSTEM=$(SUBSYSTEM)
endif

ifeq ($(ARCH),arm)
FORMAT		:= -O binary
SUBSYSTEM	:= 0xa
LDFLAGS		+= --defsym=EFI_SUBSYSTEM=$(SUBSYSTEM)
endif

FORMAT		?= --target efi-app-$(ARCH)

%.efi: %.so
	$(OBJCOPY) -j .text -j .sdata -j .data \
		-j .dynamic -j .dynsym  -j .rel* \
		-j .rela* -j .reloc -j .eh_frame \
		-j .vendor_cert \
		$(FORMAT)  $^ $@
	$(OBJCOPY) -j .text -j .sdata -j .data \
		-j .dynamic -j .dynsym  -j .rel* \
		-j .rela* -j .reloc -j .eh_frame \
		-j .debug_info -j .debug_abbrev -j .debug_aranges \
		-j .debug_line -j .debug_str -j .debug_ranges \
		$(FORMAT) $^ $@.debug

clean:
	$(MAKE) -C Cryptlib clean
	$(MAKE) -C Cryptlib/OpenSSL clean
	$(MAKE) -C lib clean
	rm -rf $(TARGET) $(OBJS)
	rm -f *.debug *.so *.efi *.tar.* version.c

GITTAG = $(VERSION)

test-archive:
	@rm -rf /tmp/shim-$(VERSION) /tmp/shim-$(VERSION)-tmp
	@mkdir -p /tmp/shim-$(VERSION)-tmp
	@git archive --format=tar $(shell git branch | awk '/^*/ { print $$2 }') | ( cd /tmp/shim-$(VERSION)-tmp/ ; tar x )
	@git diff | ( cd /tmp/shim-$(VERSION)-tmp/ ; patch -s -p1 -b -z .gitdiff )
	@mv /tmp/shim-$(VERSION)-tmp/ /tmp/shim-$(VERSION)/
	@git log -1 --pretty=format:%H > /tmp/shim-$(VERSION)/commit
	@dir=$$PWD; cd /tmp; tar -c --bzip2 -f $$dir/shim-$(VERSION).tar.bz2 shim-$(VERSION)
	@rm -rf /tmp/shim-$(VERSION)
	@echo "The archive is in shim-$(VERSION).tar.bz2"

tag:
	git tag --sign $(GITTAG) refs/heads/master

archive: tag
	@rm -rf /tmp/shim-$(VERSION) /tmp/shim-$(VERSION)-tmp
	@mkdir -p /tmp/shim-$(VERSION)-tmp
	@git archive --format=tar $(GITTAG) | ( cd /tmp/shim-$(VERSION)-tmp/ ; tar x )
	@mv /tmp/shim-$(VERSION)-tmp/ /tmp/shim-$(VERSION)/
	@git log -1 --pretty=format:%H > /tmp/shim-$(VERSION)/commit
	@dir=$$PWD; cd /tmp; tar -c --bzip2 -f $$dir/shim-$(VERSION).tar.bz2 shim-$(VERSION)
	@rm -rf /tmp/shim-$(VERSION)
	@echo "The archive is in shim-$(VERSION).tar.bz2"

export ARCH CC LD OBJCOPY EFI_INCLUDE
