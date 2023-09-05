#ifndef HWSHA3
#define HWSHA3

#include <stddef.h>

typedef unsigned char byte;

void hwsha3_init(void* sha3ctrl) ;
void hwsha3_update(void* sha3ctrl, const void* data, size_t size);
void hwsha3_final(void* sha3ctrl, byte* hash, const void* data, size_t size);

#endif
