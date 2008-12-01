module miface;

import std.stream;
import std.string, std.stdio, std.file, std.path;

enum IntType { INT, SIZE, DATE, HEX32 }

class STREAM
{
	Stream s;
	
	this(Stream s) { this.s = s; }
	this(char[] name, FileMode mode = FileMode.In) {
		if (mode == FileMode.In) {
			this.s = new BufferedFile(name, mode);
		} else {
			this.s = new File(name, mode);
		}
	}
	
	long stream_read(void* ptr, long len) {
		return s.read((cast(ubyte *)ptr)[0..len]);
	}

	long stream_write(void* ptr, long len) {
		return s.write((cast(ubyte *)ptr)[0..len]);
	}
	
	long stream_seek(long pos, SeekPos seek = SeekPos.Set) {
		s.seek(pos, seek);
		return s.position;
	}
	
	long stream_tell() { return s.position; }
	bool stream_eof() { return s.eof; }
	
	STREAM stream_slice(long pos, long size) {
		return new STREAM(new SliceStream(s, pos, pos + size));
	}
}

struct VALUE
{
	enum Type { INT, STRING }

	Type type;
	IntType itype;
	
	union {
		long value;
		char[] text;
	}
	
	static VALUE opCall(char[] text) {
		VALUE rv = void;
		rv.type = Type.STRING;
		rv.text = text;
		return rv;
	}
	
	static VALUE opCall(long v, IntType itype = IntType.INT) {
		VALUE rv = void;
		rv.type = Type.INT;
		rv.value = v;
		rv.itype = itype;
		return rv;
	}
	
	char[] toString() {
		switch (type) {
			case Type.INT: {
				switch (itype) {
					case IntType.INT:
					default: return format("%d", value);
					case IntType.SIZE: return format("%d B", value);
					case IntType.DATE: return format("%d (date)", value);
					case IntType.HEX32: return format("%08X", value);
				}
			}
			case Type.STRING: return text;
			default: return "unknown";
		}
	}
}

class LIST
{
	VALUE[int][] rows;
	char[][int] columns;
	VALUE[int] current_row;

	bool list_add(char[] name, ulong id) {
		writefln("list_add('%s') : %d", name, id);
		return true;
	}
	
	void list_encoding(char[] encoding) {
	}
	
	void list_column(int cid, char[] name) {
		columns[cid] = name;
	}
	
	void list_column_finish() {
		writefln(columns.values);
	}
	
	void list_value_int(int cid, long value, IntType type = IntType.INT) {
		current_row[cid] = VALUE(value, type);
	}
	
	void list_value_str(int cid, char[] string) {
		current_row[cid] = VALUE(string);
	}
	
	bool list_push() {
		writefln(current_row.values);
		
		rows ~= current_row;
		current_row = null;
		return false;
	}
	
	bool list_error(char[] error) {
		writefln("error: '%s'", error);
		return false;
	}
	
	ENTRY opIndex(int n) {
		return new ENTRY(columns, rows[n]);
	}
}

class ENTRY
{
	char[][int] columns;
	VALUE[int] values;
	
	this(char[][int] columns, VALUE[int] values) {
		this.columns = columns;
		this.values = values;
	}

	long entry_get_int(int cid) {
		return values[cid].value;
	}
	
	int entry_get_str(int cid, char** string) {
		if (values[cid].type != VALUE.Type.STRING) return 0;
		*string = values[cid].text.ptr;
		return values[cid].text.length;
	}
	
	void entry_progress(long cur, long max) {
		writefln("progress: %d, %d", cur, max);
	}
}

struct IFACE
{
	extern(C) long function(STREAM s, void* ptr, long len) stream_read;
	extern(C) long function(STREAM s, void* ptr, long len) stream_write;
	extern(C) long function(STREAM s, long pos, SeekPos seek) stream_seek;
	extern(C) long function(STREAM s) stream_tell;
	extern(C) bool function(STREAM s) stream_eof;
	extern(C) STREAM function(STREAM s, long pos, long size) stream_slice;
	
	extern(C) void function(LIST l, char* encoding) list_encoding;
	extern(C) void function(LIST l, int cid, char* name) list_column;
	extern(C) void function(LIST l) list_column_finish;
	extern(C) void function(LIST l, int cid, long value, IntType type) list_value_int;
	extern(C) void function(LIST l, int cid, char* string, int length) list_value_str;
	extern(C) bool function(LIST l) list_push;
	extern(C) bool function(LIST l, char* error) list_error;
	
	extern(C) long function(ENTRY e, int cid) entry_get_int;
	extern(C) int  function(ENTRY e, int cid, char** string) entry_get_str;
	extern(C) void function(ENTRY e, long cur, long max) entry_progress;
}

version (wa_module) {
	IFACE* iface;
	alias iface i;
	
	template TA(T) { ubyte[] TA(inout T t) { return cast(ubyte[])(&t)[0..1]; } }
	
	long f_read (STREAM s, void[] data) { return i.stream_read (s, data.ptr, data.length); }
	long f_write(STREAM s, void[] data) { return i.stream_write(s, data.ptr, data.length); }
	long f_seek (STREAM s, long pos, SeekPos seek = SeekPos.Set) { return i.stream_seek(s, pos, seek); }
	long f_tell (STREAM s) { return i.stream_tell(s); }
	bool f_eof  (STREAM s)              { return i.stream_eof  (s); }
	STREAM f_slice(STREAM s, long pos, long size) { return i.stream_slice(s, pos, size); }
	
	void l_value(LIST l, int cid, char[] string) { i.list_value_str(l, cid, string.ptr, string.length); }
	void l_value(LIST l, int cid, long value, IntType type = IntType.INT) { i.list_value_int(l, cid, value, type); }
	bool l_push(LIST l) { return i.list_push(l); }
	
	long e_get_int(ENTRY e, int cid) { return i.entry_get_int(e, cid); }
	char[] e_get_str(ENTRY e, int cid) { char* string; return string[0..i.entry_get_str(e, cid, &string)]; }
}
