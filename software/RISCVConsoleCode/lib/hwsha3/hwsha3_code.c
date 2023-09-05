#include "hwsha3/hwsha3.h"
#include "platform.h"
#include <stdint.h>



void hwsha3_init(void* sha3ctrl) {
  _REG32((char*)sha3ctrl, SHA3_REG_STATUS) = 1 << 24; // Reset, and also put 0 in size
}

void hwsha3_update(void* sha3ctrl, const void* data, size_t size) {
  uint64_t* d = (uint64_t*)data;
  _REG32((char*)sha3ctrl, SHA3_REG_STATUS) = 0;
  while(size >= 8) {
    _REG64((char*)sha3ctrl, SHA3_REG_DATA_0) = *d;
    _REG32((char*)sha3ctrl, SHA3_REG_STATUS) = 1 << 16;
    size -= 8;
    d += 1;
  }
  if(size > 0) {
    // WARNING: This hardware does not work with intermediates
    _REG64((char*)sha3ctrl, SHA3_REG_DATA_0) = *d;
    _REG32((char*)sha3ctrl, SHA3_REG_STATUS) = size & 0x7;
    _REG32((char*)sha3ctrl, SHA3_REG_STATUS) = (1 << 16) | (size & 0x7);
  }
}

void hwsha3_final(void* sha3ctrl, byte* hash, const void* data, size_t size) {
  uint64_t* d = (uint64_t*)data;
  _REG32((char*)sha3ctrl, SHA3_REG_STATUS) = 0;
  while(size >= 8) {
    _REG64((char*)sha3ctrl, SHA3_REG_DATA_0) = *d;
    _REG32((char*)sha3ctrl, SHA3_REG_STATUS) = 1 << 16;
    size -= 8;
    d += 1;
  }
  // When less of 8 bytes (64 bits) remain, do the final
  while(size > 0) _REG64((char*)sha3ctrl, SHA3_REG_DATA_0) = *d;
  _REG32((char*)sha3ctrl, SHA3_REG_STATUS) = size & 0x7;
  _REG32((char*)sha3ctrl, SHA3_REG_STATUS) = (3 << 16) | (size & 0x7);
  while(_REG32((char*)sha3ctrl, SHA3_REG_STATUS) & (1 << 10));
  for(int i = 0; i < 8; i++) {
    *(((uint64_t*)hash) + i) = *(((uint64_t*)(((uint64_t)sha3ctrl)+SHA3_REG_HASH_0)) + i);
  }
}

