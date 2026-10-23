#if defined(TL_SECRANDOM_PROTOTYPE_ONLY)

@import Security;

#include <stddef.h>

int tl_fake_SecRandomCopyBytes(SecRandomRef random, size_t count, void *bytes);

#else

@import Security;

#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#include "ecdsa.h"
#include "rand.h"
#include "secp256k1.h"

typedef enum {
    TL_RNG_HEALTHY,
    TL_RNG_FAIL,
    TL_RNG_ZERO_ONCE,
    TL_RNG_ZERO_ALWAYS,
    TL_RNG_ZERO_THEN_FAIL,
} tl_rng_behavior;

static tl_rng_behavior tl_rng_behavior_value = TL_RNG_HEALTHY;
static size_t tl_rng_call_count = 0;
static uint64_t tl_entropy_state = UINT64_C(0x6a09e667f3bcc909);

static void tl_configure_rng(tl_rng_behavior behavior) {
    tl_rng_behavior_value = behavior;
    tl_rng_call_count = 0;
    tl_entropy_state = UINT64_C(0x6a09e667f3bcc909);
}

static int tl_buffer_is_all_zero(const uint8_t *buffer, size_t count) {
    for (size_t index = 0; index < count; index++) {
        if (buffer[index] != 0) {
            return 0;
        }
    }
    return 1;
}

int tl_fake_SecRandomCopyBytes(SecRandomRef random, size_t count, void *bytes) {
    (void)random;
    tl_rng_call_count++;

    if (tl_rng_behavior_value == TL_RNG_FAIL ||
        (tl_rng_behavior_value == TL_RNG_ZERO_THEN_FAIL && tl_rng_call_count > 1)) {
        return errSecNotAvailable;
    }
    if (tl_rng_behavior_value == TL_RNG_ZERO_ALWAYS ||
        (tl_rng_behavior_value == TL_RNG_ZERO_ONCE && tl_rng_call_count == 1) ||
        (tl_rng_behavior_value == TL_RNG_ZERO_THEN_FAIL && tl_rng_call_count == 1)) {
        memset(bytes, 0, count);
        return errSecSuccess;
    }

    uint8_t *output = bytes;
    for (size_t index = 0; index < count; index++) {
        tl_entropy_state ^= tl_entropy_state << 13;
        tl_entropy_state ^= tl_entropy_state >> 7;
        tl_entropy_state ^= tl_entropy_state << 17;
        output[index] = (uint8_t)(tl_entropy_state >> 24);
    }
    return errSecSuccess;
}

static const uint8_t tl_private_key[32] = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
};

static const uint8_t tl_digest[32] = {
    0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11,
    0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11,
    0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11,
    0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11,
};

static const uint8_t tl_expected_signature[65] = {
    0xe7, 0xc9, 0x37, 0x26, 0xa8, 0x65, 0x57, 0x85,
    0x04, 0x44, 0x2b, 0x1a, 0x68, 0x27, 0xf6, 0x76,
    0xe0, 0xed, 0x74, 0xbd, 0xff, 0x2b, 0xe3, 0x96,
    0x0d, 0x1e, 0x25, 0x3b, 0xbc, 0xfc, 0x44, 0x62,
    0x6a, 0xa7, 0x72, 0xb8, 0x78, 0xbc, 0x91, 0x2b,
    0xdb, 0xb3, 0x3a, 0x00, 0x14, 0xec, 0x50, 0x7c,
    0x4b, 0x38, 0x96, 0xea, 0x85, 0xaa, 0x91, 0x4b,
    0x74, 0xde, 0xe9, 0xb7, 0xac, 0x3e, 0x56, 0xda,
    0x01,
};

static int tl_run_sign(int expect_fixed_signature) {
    uint8_t signature[64] = {0};
    uint8_t recovery_id = 0;
    int result = ecdsa_sign_digest(
        &secp256k1,
        tl_private_key,
        tl_digest,
        signature,
        &recovery_id,
        NULL
    );
    if (result != 0) {
        return 65;
    }
    if (expect_fixed_signature &&
        (memcmp(signature, tl_expected_signature, sizeof(signature)) != 0 ||
         recovery_id != tl_expected_signature[64])) {
        return 66;
    }
    return 0;
}

static int tl_run_checked_rng_test(const char *mode) {
    uint8_t output[16];
    memset(output, 0xa5, sizeof(output));

    if (strcmp(mode, "rng-zero-once-checked") == 0) {
        tl_configure_rng(TL_RNG_ZERO_ONCE);
        if (!random_buffer_checked(output, 4) || tl_rng_call_count != 2 ||
            tl_buffer_is_all_zero(output, 4)) {
            return 86;
        }
        return 0;
    }
    if (strcmp(mode, "rng-zero-always-checked") == 0) {
        tl_configure_rng(TL_RNG_ZERO_ALWAYS);
        if (random_buffer_checked(output, 4) || tl_rng_call_count != 2 ||
            !tl_buffer_is_all_zero(output, 4)) {
            return 87;
        }
        return 0;
    }
    if (strcmp(mode, "rng-zero-then-failure-checked") == 0) {
        tl_configure_rng(TL_RNG_ZERO_THEN_FAIL);
        if (random_buffer_checked(output, 4) || tl_rng_call_count != 2 ||
            !tl_buffer_is_all_zero(output, 4)) {
            return 88;
        }
        return 0;
    }
    if (strcmp(mode, "rng-first-failure-checked") == 0) {
        tl_configure_rng(TL_RNG_FAIL);
        if (random_buffer_checked(output, 4) || tl_rng_call_count != 1 ||
            !tl_buffer_is_all_zero(output, 4)) {
            return 89;
        }
        return 0;
    }
    if (strcmp(mode, "rng-failure-then-success-checked") == 0) {
        tl_configure_rng(TL_RNG_FAIL);
        if (random_buffer_checked(output, 4) || tl_rng_call_count != 1 ||
            !tl_buffer_is_all_zero(output, 4)) {
            return 90;
        }
        tl_configure_rng(TL_RNG_HEALTHY);
        if (!random_buffer_checked(output, 4) || tl_rng_call_count != 1 ||
            tl_buffer_is_all_zero(output, 4)) {
            return 91;
        }
        return 0;
    }
    if (strcmp(mode, "rng-zero-once-key-sized-checked") == 0) {
        tl_configure_rng(TL_RNG_ZERO_ONCE);
        if (!random_buffer_checked(output, sizeof(output)) || tl_rng_call_count != 3 ||
            tl_buffer_is_all_zero(output, sizeof(output))) {
            return 92;
        }
        return 0;
    }
    if (strcmp(mode, "rng-short-length-checked") == 0) {
        tl_configure_rng(TL_RNG_ZERO_ONCE);
        if (!random_buffer_checked(output, 1) || tl_rng_call_count != 2 || output[0] == 0) {
            return 93;
        }
        tl_configure_rng(TL_RNG_ZERO_ALWAYS);
        if (random_buffer_checked(output, 1) || tl_rng_call_count != 2 || output[0] != 0) {
            return 94;
        }
        return 0;
    }
    if (strcmp(mode, "rng-boundaries-checked") == 0) {
        tl_configure_rng(TL_RNG_FAIL);
        if (!random_buffer_checked(NULL, 0) || random_buffer_checked(NULL, 1) ||
            tl_rng_call_count != 0) {
            return 95;
        }
        return 0;
    }
    return -1;
}

static int tl_run_operation(const char *mode) {
    int checked_result = tl_run_checked_rng_test(mode);
    if (checked_result >= 0) {
        return checked_result;
    }
    if (strcmp(mode, "healthy-sign") == 0) {
        tl_configure_rng(TL_RNG_HEALTHY);
        return tl_run_sign(1);
    }
    if (strcmp(mode, "rng-zero-once-sign") == 0) {
        tl_configure_rng(TL_RNG_ZERO_ONCE);
        return tl_run_sign(1);
    }
    if (strcmp(mode, "rng-zero-always-sign") == 0) {
        tl_configure_rng(TL_RNG_ZERO_ALWAYS);
        return tl_run_sign(0) == 0 ? 82 : 83;
    }
    if (strcmp(mode, "rng-zero-then-failure-sign") == 0) {
        tl_configure_rng(TL_RNG_ZERO_THEN_FAIL);
        return tl_run_sign(0) == 0 ? 84 : 85;
    }

    tl_configure_rng(TL_RNG_FAIL);
    if (strcmp(mode, "rng-failure-sign") == 0) {
        return tl_run_sign(0) == 0 ? 67 : 68;
    }
    if (strcmp(mode, "rng-failure-public-key") == 0) {
        uint8_t public_key[65] = {0};
        ecdsa_get_public_key65(&secp256k1, tl_private_key, public_key);
        return 69;
    }
    if (strcmp(mode, "rng-failure-recovery") == 0) {
        uint8_t public_key[65] = {0};
        int result = ecdsa_recover_pub_from_sig(
            &secp256k1,
            public_key,
            tl_expected_signature,
            tl_digest,
            tl_expected_signature[64]
        );
        return result == 0 ? 70 : 71;
    }
    if (strcmp(mode, "timeout-probe") == 0) {
        for (;;) {
            pause();
        }
    }
    return 64;
}

typedef enum {
    TL_EXPECT_EXIT_ZERO,
    TL_EXPECT_SIGABRT,
    TL_EXPECT_TIMEOUT,
} tl_expected_child_result;

static int64_t tl_monotonic_milliseconds(void) {
    struct timespec value;
    if (clock_gettime(CLOCK_MONOTONIC, &value) != 0) {
        return -1;
    }
    return (int64_t)value.tv_sec * INT64_C(1000) + value.tv_nsec / 1000000;
}

static int tl_kill_and_reap(pid_t child) {
    if (kill(child, SIGKILL) != 0 && errno != ESRCH) {
        return 76;
    }

    int wait_status = 0;
    for (;;) {
        pid_t wait_result = waitpid(child, &wait_status, 0);
        if (wait_result == child) {
            return 0;
        }
        if (wait_result < 0 && errno == EINTR) {
            continue;
        }
        return 77;
    }
}

static int tl_supervise_child(
    const char *executable_path,
    const char *mode,
    tl_expected_child_result expected_result,
    int64_t timeout_milliseconds
) {
    int64_t start = tl_monotonic_milliseconds();
    if (start < 0 || timeout_milliseconds <= 0 || start > INT64_MAX - timeout_milliseconds) {
        return 78;
    }

    pid_t child = fork();
    if (child < 0) {
        return 72;
    }
    if (child == 0) {
        alarm(10);
        execl(executable_path, executable_path, mode, (char *)NULL);
        _exit(127);
    }

    int64_t deadline = start + timeout_milliseconds;
    int wait_status = 0;
    for (;;) {
        pid_t wait_result = waitpid(child, &wait_status, WNOHANG);
        if (wait_result == child) {
            if (expected_result == TL_EXPECT_EXIT_ZERO) {
                return WIFEXITED(wait_status) && WEXITSTATUS(wait_status) == 0 ? 0 : 74;
            }
            if (expected_result == TL_EXPECT_SIGABRT) {
                return WIFSIGNALED(wait_status) && WTERMSIG(wait_status) == SIGABRT ? 0 : 75;
            }
            return 79;
        }
        if (wait_result < 0 && errno != EINTR) {
            int cleanup_result = tl_kill_and_reap(child);
            return cleanup_result == 0 ? 73 : cleanup_result;
        }

        int64_t now = tl_monotonic_milliseconds();
        if (now < 0) {
            int cleanup_result = tl_kill_and_reap(child);
            return cleanup_result == 0 ? 78 : cleanup_result;
        }
        if (now >= deadline) {
            int cleanup_result = tl_kill_and_reap(child);
            if (cleanup_result != 0) {
                return cleanup_result;
            }
            return expected_result == TL_EXPECT_TIMEOUT ? 0 : 80;
        }

        struct timespec sleep_interval = { .tv_sec = 0, .tv_nsec = 10000000 };
        if (nanosleep(&sleep_interval, NULL) != 0 && errno != EINTR) {
            int cleanup_result = tl_kill_and_reap(child);
            return cleanup_result == 0 ? 81 : cleanup_result;
        }
    }
}

int main(int argc, char *argv[]) {
    if (argc == 2 && strcmp(argv[1], "--verify-timeout-supervision") == 0) {
        return tl_supervise_child(argv[0], "timeout-probe", TL_EXPECT_TIMEOUT, 100);
    }
    if (argc == 2) {
        return tl_run_operation(argv[1]);
    }
    if (argc == 3 && strcmp(argv[1], "--expect-exit-zero") == 0) {
        return tl_supervise_child(argv[0], argv[2], TL_EXPECT_EXIT_ZERO, 5000);
    }
    if (argc == 3 && strcmp(argv[1], "--expect-sigabrt") == 0) {
        return tl_supervise_child(argv[0], argv[2], TL_EXPECT_SIGABRT, 5000);
    }
    return 64;
}

#endif
