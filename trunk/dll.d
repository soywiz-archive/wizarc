// Public Domain
module dll;

import std.c.windows.windows;

HINSTANCE g_hInst;

extern (C) {
	void gc_init();
	void gc_term();
	void _minit();
	void _moduleCtor();
	void _moduleUnitTests();
}

extern (Windows) BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved) {
    switch (ulReason) {
		case DLL_PROCESS_ATTACH: gc_init(); _minit(); _moduleCtor(); _moduleUnitTests(); break;
		case DLL_PROCESS_DETACH: gc_term(); break;
		case DLL_THREAD_ATTACH, DLL_THREAD_DETACH: return false;
    }
    g_hInst = hInstance;
	
    return true;
}
