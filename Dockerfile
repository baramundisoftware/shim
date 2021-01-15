FROM ubuntu:18.04

RUN apt update -y
RUN DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
  make \
  openssl \
  gcc-4.8 \
  bsdmainutils \
  gnu-efi

COPY ./ /shim_source/

#build shim for x64 systems
WORKDIR /shim_x64
RUN LIB_PATH=/usr/lib64 \
	&& make -C /shim_source clean \
	&& make -C /shim_source shim.efi CC=gcc-4.8 ARCH=x86_64 EFI_PATH=/usr/lib DEFAULT_LOADER=bblefi-x64/grub2_x64.efi VENDOR_CERT_FILE=bsAG_EV_productive_2020.cer \
	&& cp /shim_source/shim.efi ./shim_x64.efi
	
#build shim for x86 systems
WORKDIR /shim_x86
RUN LIB_PATH=/usr/lib32 \
	&& make -C /shim_source clean \
	&& make -C /shim_source shim.efi CC=gcc-4.8 ARCH=ia32 EFI_PATH=/usr/lib32 DEFAULT_LOADER=bblefi-x86/grub2_x86.efi VENDOR_CERT_FILE=bsAG_EV_productive_2020.cer \
	&& cp /shim_source/shim.efi ./shim_x86.efi

WORKDIR /