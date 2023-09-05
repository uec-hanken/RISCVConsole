#########################################################################################
# pre-process opentitan into a single blackbox file
#########################################################################################
base_dir=$(abspath ../../../../..)
chipyard_dir=$(base_dir)/hardware/chipyard
vsrc_dir=$(base_dir)/hardware/tee-hw-full/vsrc/
optvsrc_dir=$(base_dir)/hardware/riscvconsole/src/main/resources/

PREPROC_SCRIPT = $(base_dir)/hardware/insert-includes.py

#include chacha.mk
include aes_gcm.mk
include hmac_sha.mk
include sha3.mk
include aes.mk
#include poly1305.mk
include rsa.mk
#include chacha_poly_aead.mk
#include ecdsa_block.mk
#include edec_core.mk

all:   aes_gcm hmac_sha rsa sha3 aes
	#cp $(optvsrc_dir)/mem_wrapper/mem_wrapper.v mem_wrapper.v
	touch resources.checkpoint
#make hmac_sha VERSION_HMACSHA=v2

clean:
	rm -rfv *.preprocessed.sv *.preprocessed.v

