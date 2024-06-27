#ifndef Types_H
#define Types_H

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
#define ExternC_Start extern "C" {
#define ExternC_End };
#define nil nullptr
#else
#define EXTERN_C_BEGIN
#define EXTERN_C_END
#define nil ((void*)0)
#endif

typedef signed char int8;
typedef signed short int int16;
typedef signed long int int32;
typedef signed long long int int64;

typedef unsigned char uint8;
typedef unsigned short int uint16;
typedef unsigned long int uint32;
typedef unsigned long long int uint64;

typedef unsigned int uint;
typedef uint8 byte;
typedef wchar_t rune;
typedef size_t size;

typedef float float32;
typedef double float64;

#ifndef Platform_Windows
#define PACK_ENUM __attribute__ ((__packed__))
#else
#define PACK_ENUM
#endif

#endif // Types_H