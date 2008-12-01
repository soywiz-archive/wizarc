import std.stdio, std.string, std.stream, std.format, std.file, std.path, std.c.windows.windows, std.traits;
import miface;

IFACE iface;

static this()
{
	static char[] WRAP(char[] name, char[] params, char[] v) { return "extern(C) static ReturnType!(IFACE." ~ name ~ ") iface_" ~ name ~ "(" ~ params ~ ") { return _." ~ name ~ "(" ~ v ~ "); } iface." ~ name ~ " = &iface_" ~ name ~ ";"; }
	
	mixin(WRAP("stream_read",        "STREAM _, void* ptr, long len",          "ptr, len"));
	mixin(WRAP("stream_write",       "STREAM _, void* ptr, long len",          "ptr, len"));
	mixin(WRAP("stream_seek",        "STREAM _, long  pos, SeekPos seek",      "pos, seek"));
	mixin(WRAP("stream_tell",        "STREAM _",                               ""));
	mixin(WRAP("stream_eof",         "STREAM _",                               ""));
	mixin(WRAP("stream_slice",       "STREAM _, long pos, long size",          "pos, size"));
	
	mixin(WRAP("list_encoding",      "LIST _, char* encoding",                 "toString(encoding)"));
	mixin(WRAP("list_column_finish", "LIST _",                                 ""));
	mixin(WRAP("list_column",        "LIST _, int cid, char* name",            "cid, toString(name)"));
	mixin(WRAP("list_value_int",     "LIST _, int cid, long value, IntType type",  "cid, value, type"));
	mixin(WRAP("list_value_str",     "LIST _, int cid, char* value, int len",  "cid, value[0..len]"));
	mixin(WRAP("list_push",          "LIST _",                                 ""));
	mixin(WRAP("list_error",         "LIST _, char* error",                    "toString(error)"));
	
	mixin(WRAP("entry_get_int",      "ENTRY _, int cid",                       "cid"));
	mixin(WRAP("entry_get_str",      "ENTRY _, int cid, char** value",         "cid, value"));
	mixin(WRAP("entry_progress",     "ENTRY _, long cur, long max",            "cur, max"));
}

class Module {
	extern(C) int   function() wa_version;
	extern(C) char* function() wa_name;
	extern(C) void  function(STREAM s, LIST l) wa_list;
	extern(C) int   function(STREAM s) wa_check;
	extern(C) void  function(IFACE* iface) wa_interface;
	extern(C) void  function(ENTRY e, STREAM s, STREAM d) wa_uncompress;
	
	this(char[] name) {
		HMODULE lib = LoadLibraryA(toStringz(name));
		
		static final char[] BindFuncMix(char[] t) { return "Module.BindFunc(lib, cast(void**)&this." ~ t ~ ", \"" ~ t ~ "\");"; }
		mixin(BindFuncMix("wa_version"));
		mixin(BindFuncMix("wa_name"));
		mixin(BindFuncMix("wa_interface"));
		mixin(BindFuncMix("wa_check"));
		mixin(BindFuncMix("wa_list"));
		mixin(BindFuncMix("wa_uncompress"));
		
		if (wa_version is null) throw(new Exception("Invalid module"));
	}
	
	static bool BindFunc(HMODULE lib, void** ptr, char[] funcName) {
		void* func = GetProcAddress(lib, std.string.toStringz(funcName));
		*ptr = func;
		return func !is null;
	}
	
	static Module[] modules;
	
	char[] name() {
		return std.string.toString(wa_name());
	}

	void init() {
		if (!&wa_interface) return;
		wa_interface(&iface);
		modules ~= this;
	}
	
	static struct ModulePriority {
		Module m;
		int p;
		
		//this(Module m, int p) { this.m = m; this.p = p; }
		
		char[] toString() {
			return format("%s:%d", m.name, p);
		}
		
		int opCmp(ModulePriority that) {
			return p - that.p;
		}
	}
	
	static ModulePriority[] MagicCheck(Stream s) {
		ubyte[] temp = new ubyte[0x400]; s.read(temp); s.position = 0;
		auto ss = new STREAM(new MemoryStream(temp));

		ModulePriority[] r;
		foreach (m; modules) {
			ss.stream_seek(0);
			int p = m.wa_check(ss);
			//if (p >= 10) { r = [ModulePriority(m, 10)]; break; }
			if (p > 0) r ~= ModulePriority(m, p);
		}
		
		if (!r.length) throw(new Exception("No modules match"));
		
		return r.sort.reverse;
	}
	
	static ModulePriority[] MagicCheck(char[] name) {
		auto s = new BufferedFile(name); scope(success) s.close();
		return MagicCheck(s);
	}
}

void module_add(char[] name) {
	auto m = new Module(name);
	m.init();
	
	/*
	auto list = new LIST();
	m.wa_list(list);
	writefln("%d", m.check("5-poly-dem.zip"));
	*/
}

void main() {
	foreach (name; listdir(".")) {
		if (name.length >= 11 && name[0..7] == "wizarc_" && name[name.length - 4..name.length] == ".dll") {
			module_add(name);
		}
	}

	auto l = new LIST();
	auto fin = new STREAM("test.zip");
	auto fout = new STREAM("out.bin", FileMode.OutNew);
	
	Module m = Module.MagicCheck(fin.s)[0].m;
	m.wa_list(fin, l);
	auto e = l[0];
	m.wa_uncompress(e, fin, fout);
}