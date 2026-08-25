#include <string.h>

#include "memzero.h"

// Everything this wipes lives in automatic storage and is dead once the caller returns,
// which makes a plain memset() a legal dead-store elimination target under LTO. Going
// through a volatile pointer denies the compiler that proof, so the wipe always happens.
static void *(*const volatile memset_ptr)(void *, int, size_t) = memset;

void memzero(void *s, size_t n)
{
	(memset_ptr)(s, 0, n);
}
