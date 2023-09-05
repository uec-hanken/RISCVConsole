#include <string.h>
#include <stdint.h>
#undef memmove

/**
 * memmove - Copy one area of memory to another
 * @dest: Where to copy to
 * @src: Where to copy from
 * @count: The size of the area.
 *
 * Unlike memcpy(), memmove() copes with overlapping areas.
 */
void * memmove(void * dest,const void *src,size_t count)
{
	char *tmp, *s;

	if (dest <= src) {
		memcpy(dest, src, count);
	} else {
		tmp = (char *) dest + count;
		s = (char *) src + count;
		while (count--)
			*--tmp = *--s;
		}

	return dest;
}
