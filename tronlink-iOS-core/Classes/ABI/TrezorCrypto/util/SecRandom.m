@import Foundation;
@import Security;

#include <stdlib.h>
#include <string.h>
#include <os/lock.h>

#include "memzero.h"
#include "../trezor-crypto/rand.h"
#include "sha2.h"

enum {
    entropy_health_min_length = 16,
    entropy_health_max_length = 32,
    entropy_health_history_size = 3,
};

typedef struct {
    uint8_t digests[entropy_health_history_size][SHA256_DIGEST_LENGTH];
    uint8_t count;
    uint8_t next;
} entropy_history;

static os_unfair_lock entropy_health_lock = OS_UNFAIR_LOCK_INIT;
static entropy_history entropy_histories[entropy_health_max_length - entropy_health_min_length + 1];

static int buffer_is_uniform(const uint8_t *buf, size_t len) {
    if (len == 0) {
        return 0;
    }
    for (size_t i = 1; i < len; i++) {
        if (buf[i] != buf[0]) {
            return 0;
        }
    }
    return 1;
}

int random_buffer_checked(uint8_t *buf, size_t len) {
    if (!buf && len != 0) {
        return 0;
    }
    if (len == 0) {
        return 1;
    }

    const int key_sized = len >= entropy_health_min_length && len <= entropy_health_max_length;
    uint8_t probe[entropy_health_max_length] = {0};
    uint8_t digest[SHA256_DIGEST_LENGTH] = {0};

    // ponytail: one global lock and three retained digests cover the reported
    // concurrent A/B and A/B/C faults; widen only for a broader fault model.
    os_unfair_lock_lock(&entropy_health_lock);
    int status = SecRandomCopyBytes(kSecRandomDefault, len, buf);
    int healthy = status == errSecSuccess;

    if (healthy && key_sized) {
        status = SecRandomCopyBytes(kSecRandomDefault, len, probe);
        healthy = status == errSecSuccess
            && !buffer_is_uniform(buf, len)
            && !buffer_is_uniform(probe, len)
            && memcmp(buf, probe, len) != 0;
    }

    if (healthy && key_sized) {
        sha256_Raw(buf, len, digest);
        entropy_history *history = &entropy_histories[len - entropy_health_min_length];
        for (uint8_t i = 0; i < history->count; i++) {
            if (memcmp(history->digests[i], digest, sizeof(digest)) == 0) {
                healthy = 0;
                break;
            }
        }

        if (healthy) {
            memcpy(history->digests[history->next], digest, sizeof(digest));
            history->next = (history->next + 1) % entropy_health_history_size;
            if (history->count < entropy_health_history_size) {
                history->count++;
            }
        }
    }

    os_unfair_lock_unlock(&entropy_health_lock);
    memzero(probe, sizeof(probe));
    memzero(digest, sizeof(digest));
    if (!healthy) {
        memzero(buf, len);
    }
    return healthy;
}

uint32_t random32(void) {
    uint32_t value = 0;
    if (!random_buffer_checked((uint8_t *)&value, sizeof(value))) {
        abort();
    }
    return value;
}

void random_buffer(uint8_t *buf, size_t len) {
    if (!random_buffer_checked(buf, len)) {
        abort();
    }
}
