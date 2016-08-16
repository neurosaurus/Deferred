//
//  Atomics.h
//  Deferred
//
//  Created by Zachary Waldowski on 12/7/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#ifndef __BNR_ATOMIC_SHIMS__
#define __BNR_ATOMIC_SHIMS__

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdatomic.h>

#ifndef __has_feature
#define __has_feature(x) 0
#endif

#ifndef __has_extension
#define __has_extension(x) 0
#endif

#ifndef __has_attribute
#define __has_attribute(x) 0
#endif

#if !__has_feature(nullability)
#ifndef _Nullable
#define _Nullable
#endif
#ifndef _Nonnull
#define _Nonnull
#endif
#endif

#if __has_attribute(swift_name)
# define BNR_SWIFT_NAME(_name) __attribute__((swift_name(#_name)))
# define BNR_SWIFT_DECL(_name) static inline __attribute__((used, always_inline, swift_name(#_name)))
#else
# define BNR_SWIFT_NAME(_name)
# define BNR_SWIFT_DECL(_name)
#endif

#if !defined(SWIFT_ENUM)
#if __has_feature(objc_fixed_enum)
#if !defined(SWIFT_ENUM_EXTRA)
#define SWIFT_ENUM_EXTRA
#endif
#define SWIFT_ENUM(_name, _type, ...) enum _name : _type _name; enum SWIFT_ENUM_EXTRA _name : _type
#else
#define SWIFT_ENUM(_name, _type, ...) _type _name; enum
#endif
#endif

BNR_SWIFT_DECL(UnsafeAtomicInt32.spin()) void bnr_atomic_spin(void) {
#if defined(__x86_64__) || defined(__i386__)
    __asm__ __volatile__("pause" ::: "memory");
#elif defined(__arm__) || defined(__arm64__)
    __asm__ __volatile__("yield" ::: "memory");
#else
    do {} while (0);
#endif
}

BNR_SWIFT_NAME(AtomicMemoryOrder)
typedef SWIFT_ENUM(bnr_atomic_memory_order_t, int32_t) {
    bnr_atomic_memory_order_relaxed = __ATOMIC_RELAXED,
    bnr_atomic_memory_order_consume = __ATOMIC_CONSUME,
    bnr_atomic_memory_order_acquire = __ATOMIC_ACQUIRE,
    bnr_atomic_memory_order_release = __ATOMIC_RELEASE,
    bnr_atomic_memory_order_acq_rel BNR_SWIFT_NAME(acquireRelease) = __ATOMIC_ACQ_REL,
    bnr_atomic_memory_order_seq_cst BNR_SWIFT_NAME(sequentiallyConsistent) = __ATOMIC_SEQ_CST
};

BNR_SWIFT_NAME(UnsafeSpinLock)
typedef struct {
    _Atomic(_Bool) value;
} bnr_spinlock_t;

#define BNR_SPINLOCK_INIT { 0 }

BNR_SWIFT_DECL(UnsafeSpinLock.tryLock(self:))
bool bnr_spinlock_try(volatile bnr_spinlock_t *_Nonnull address) {
    return !__c11_atomic_exchange(&address->value, 1, __ATOMIC_ACQUIRE);
}

BNR_SWIFT_DECL(UnsafeSpinLock.lock(self:))
void bnr_spinlock_lock(volatile bnr_spinlock_t *_Nonnull address) {
#if __GNUC__
    while (!__builtin_expect(bnr_spinlock_try(address), true)) {
#else
    while (!bnr_spinlock_try(address)) {
#endif
        bnr_atomic_spin();
    }
}

BNR_SWIFT_DECL(UnsafeSpinLock.unlock(self:))
void bnr_spinlock_unlock(volatile bnr_spinlock_t *_Nonnull address) {
    __c11_atomic_store(&address->value, 0, __ATOMIC_RELEASE);
}

BNR_SWIFT_NAME(UnsafeAtomicInt32)
typedef struct {
    _Atomic(int32_t) value;
} bnr_atomic_int32_t;

BNR_SWIFT_DECL(UnsafeAtomicInt32.load(self:order:))
int32_t bnr_atomic_int32_load(volatile bnr_atomic_int32_t *_Nonnull target, bnr_atomic_memory_order_t order) {
    return __c11_atomic_load(&target->value, order);
}

BNR_SWIFT_DECL(UnsafeAtomicInt32.store(self:_:order:))
void bnr_atomic_int32_store(volatile bnr_atomic_int32_t *_Nonnull target, int32_t desired, bnr_atomic_memory_order_t order) {
    __c11_atomic_store(&target->value, desired, order);
}

BNR_SWIFT_DECL(UnsafeAtomicInt32.exchange(self:with:order:))
int32_t bnr_atomic_int32_exchange(volatile bnr_atomic_int32_t *_Nonnull target, int32_t desired, bnr_atomic_memory_order_t order) {
    return __c11_atomic_exchange(&target->value, desired, order);
}

BNR_SWIFT_DECL(UnsafeAtomicInt32.compareAndSwap(self:from:to:success:failure:))
bool bnr_atomic_int32_compare_and_swap(volatile bnr_atomic_int32_t *_Nonnull target, int32_t expected, int32_t desired, bnr_atomic_memory_order_t success, bnr_atomic_memory_order_t failure) {
    return __c11_atomic_compare_exchange_strong(&target->value, &expected, desired, success, failure);
}

BNR_SWIFT_DECL(UnsafeAtomicInt32.add(self:_:order:))
int32_t bnr_atomic_int32_add(volatile bnr_atomic_int32_t *_Nonnull target, int32_t amount, bnr_atomic_memory_order_t order) {
    return __c11_atomic_fetch_add(&target->value, amount, order) + amount;
}

BNR_SWIFT_DECL(UnsafeAtomicInt32.subtract(self:_:order:))
int32_t bnr_atomic_int32_subtract(volatile bnr_atomic_int32_t *_Nonnull target, int32_t amount, bnr_atomic_memory_order_t order) {
    return __c11_atomic_fetch_sub(&target->value, amount, order) - amount;
}

BNR_SWIFT_NAME(UnsafeAtomicRawPointer)
typedef struct {
    _Atomic(void *_Nullable) value;
} bnr_atomic_ptr_t;

BNR_SWIFT_DECL(UnsafeAtomicRawPointer.load(self:order:))
void *_Nullable bnr_atomic_ptr_load(volatile bnr_atomic_ptr_t *_Nonnull target, bnr_atomic_memory_order_t order) {
    return __c11_atomic_load(&target->value, order);
}

BNR_SWIFT_DECL(UnsafeAtomicRawPointer.store(self:_:order:))
void bnr_atomic_ptr_store(volatile bnr_atomic_ptr_t *_Nonnull target, void *_Nullable desired, bnr_atomic_memory_order_t order) {
    __c11_atomic_store(&target->value, desired, order);
}

BNR_SWIFT_DECL(UnsafeAtomicRawPointer.exchange(self:with:order:))
void *_Nullable bnr_atomic_ptr_exchange(volatile bnr_atomic_ptr_t *_Nonnull target, void *_Nullable desired, bnr_atomic_memory_order_t order) {
    return __c11_atomic_exchange(&target->value, desired, order);
}

BNR_SWIFT_DECL(UnsafeAtomicRawPointer.compareAndSwap(self:from:to:success:failure:))
bool bnr_atomic_ptr_compare_and_swap(volatile bnr_atomic_ptr_t *_Nonnull target, void *_Nullable expected, void *_Nullable desired, bnr_atomic_memory_order_t success, bnr_atomic_memory_order_t failure) {
    return __c11_atomic_compare_exchange_strong(&target->value, &expected, desired, success, failure);
}

#endif
