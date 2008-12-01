version = wa_module; import miface;

import std.stdio, std.file, std.path, std.stream;

export extern(C):

const uint module_version = 1_000_000;
const char* module_name = "test";

int   wa_version() { return module_version; }
void  wa_interface(IFACE* iface) { .iface = iface; }
char* wa_name() { return module_name; }

alias iface i;

void wa_list(STREAM s, LIST l) {
	i.list_encoding(l, "UTF-8");
	i.list_column(l, 0, "file_name");
	i.list_column(l, 1, "file_size");
	/*
	extern(C) void function(LIST l, char* encoding) list_encoding;
	extern(C) void function(LIST l, int cid, char* name) list_column;
	extern(C) void function(LIST l, int cid, long  value, int type) list_value_int;
	extern(C) void function(LIST l, int cid, char* string, int length) list_value_string;
	extern(C) bool function(LIST l) list_push;
	extern(C) bool function(LIST l, char* error) list_error;

	//writefln("wa_list");
	i.list_add(l, "test1");
	i.list_add(l, "test2");
	*/
}

int wa_check(STREAM s) {
	return 2;
}

void wa_uncompress(STREAM archive, ulong id, STREAM fout) {
}