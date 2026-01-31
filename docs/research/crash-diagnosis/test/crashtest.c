/* Minimal test: generate a minidump of ourselves, then access-violate.
   Tests both on-demand dump generation and cdb analysis. */

#include <windows.h>
#include <dbghelp.h>
#include <stdio.h>

#pragma comment(lib, "dbghelp.lib")

static void write_minidump(const char *path, EXCEPTION_POINTERS *ep) {
    HANDLE file = CreateFileA(path, GENERIC_WRITE, 0, NULL,
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) {
        printf("Failed to create dump file: %lu\n", GetLastError());
        return;
    }

    MINIDUMP_EXCEPTION_INFORMATION mei;
    mei.ThreadId = GetCurrentThreadId();
    mei.ExceptionPointers = ep;
    mei.ClientPointers = FALSE;

    /* MiniDumpWithDataSegs includes global variable state */
    BOOL ok = MiniDumpWriteDump(
        GetCurrentProcess(), GetCurrentProcessId(),
        file, MiniDumpWithDataSegs,
        ep ? &mei : NULL,  /* NULL = on-demand dump without exception context */
        NULL, NULL);

    CloseHandle(file);
    printf("%s: %s\n", path, ok ? "written" : "FAILED");
}

/* SEH filter that writes a crash dump */
static LONG WINAPI crash_filter(EXCEPTION_POINTERS *ep) {
    printf("Exception 0x%08lX caught, writing crash dump...\n",
           ep->ExceptionRecord->ExceptionCode);
    write_minidump("crash.dmp", ep);
    return EXCEPTION_EXECUTE_HANDLER;
}

/* A function several frames deep so the stack trace is interesting */
static int global_state = 42;

static void inner_function(int *p) {
    global_state = 99;
    *p = 123;  /* access violation when p is NULL */
}

static void middle_function(int *p) {
    inner_function(p);
}

static void outer_function(void) {
    middle_function(NULL);
}

int main(void) {
    printf("=== Minidump / cdb test ===\n\n");

    /* 1. On-demand dump (no crash, process alive) */
    printf("1. Writing on-demand dump...\n");
    write_minidump("ondemand.dmp", NULL);

    /* 2. Crash with SEH catching it */
    printf("2. Triggering access violation...\n");
    SetUnhandledExceptionFilter(crash_filter);

    __try {
        outer_function();
    } __except(crash_filter(GetExceptionInformation())) {
        printf("3. Caught exception, crash.dmp should exist.\n");
    }

    printf("\nDone. Analyze with:\n");
    printf("  cdb -z ondemand.dmp -c \"kb; q\"\n");
    printf("  cdb -z crash.dmp -c \"!analyze -v; .ecxr; kb; q\"\n");
    return 0;
}
