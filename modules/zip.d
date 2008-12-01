import miface;

import std.stdio, std.file, std.path, std.stream;
import etc.c.zlib;

export extern(C):

const uint module_version = 0_001_000;
const char* module_name = "zip";

int   wa_version() { return module_version; }
void  wa_interface(IFACE* iface) { .iface = iface; }
char* wa_name() { return module_name; }

alias iface i;

align(1) struct LocalFileHeader {
	ushort   _version;
	ushort   flags;
	ushort   method;
	ushort   file_time;
	ushort   file_date;
	uint     crc32;
	uint     size_comp;
	uint     size_uncomp;
	ushort   name_length;
	ushort   extra_length;
}

char[] StringMethod(int method) {
	switch (method) {
		case 0: return "uncompressed";
		case 8: return "deflate";
		dfault: return "unknown";
	}
}

void wa_list(STREAM s, LIST l) {
	i.list_encoding(l, "UTF-8");
	i.list_column(l, 0, "name");
	i.list_column(l, 1, "compressed_size");
	i.list_column(l, 2, "uncompressed_size");
	i.list_column(l, 3, "method");
	i.list_column(l, 4, "crc32");
	i.list_column_finish(l);
	
	char[4] signature;
	
	while (!f_eof(s)) {
		f_read(s, signature);
		
		switch (signature) {
			default:
				i.list_error(l, "Invalid header");
				return;
			break;
			case "PK\3\4":
				LocalFileHeader lfh;
				
				f_read(s, TA(lfh));
				
				char[]  filename = new char[lfh.name_length];
				ubyte[] extra    = new ubyte[lfh.extra_length];
				
				f_read(s, filename);
				f_read(s, extra);

				//enum IntType { INT, SIZE, DATE, HEX32 }

				l_value(l, -1, f_tell(s));
				l_value(l, -2, lfh.method);
				
				l_value(l, 0, filename);
				
				l_value(l, 1, lfh.size_comp, IntType.SIZE);
				l_value(l, 2, lfh.size_uncomp, IntType.SIZE);
				l_value(l, 3, StringMethod(lfh.method));
				l_value(l, 4, lfh.crc32, IntType.HEX32);
				
				l_push(l);
				
				//writefln(filename);
				//writefln(signature);

				f_seek(s, lfh.size_comp, SeekPos.Current);
			break;
			case "PK\1\2":
				return;
			break;
		}
	}
}

int wa_check(STREAM s) {
	char[4] data; f_read(s, data);
	return (data == "PK\3\4") ? 10 : 0;
}

void wa_uncompress(ENTRY e, STREAM s, STREAM d) {
	long pos  = e_get_int(e, -1);
	long size = e_get_int(e, 1);
	STREAM s2 = f_slice(s, pos, size);

	ubyte[] inbuf = new ubyte[0x4000];
	ubyte[] outbuf = new ubyte[0x4000];
	
	// Update the progress
	void progress() {
		i.entry_progress(e, f_tell(s2), size); 
	}

	// Uncompresed
	void decompress_00() {
		while (true) {
			progress();
			
			
			long readed = f_read(s2, inbuf);
			f_write(d, inbuf[0..readed]);
			
			if (f_eof(s2)) break;
		}
	}

	// Deflated
	void decompress_08() {
		z_stream z;
		
		z.zalloc = null;
		z.zfree = null;
		z.opaque = null;

		if (inflateInit2(&z, -15) != Z_OK) {
			writefln("error");
			return;
		}
		
		while (true) {
			progress();
			
			if (z.avail_out == 0) {
				z.next_out = outbuf.ptr;
				z.avail_out = outbuf.length;
			}

			if (z.avail_in == 0) {
				z.next_in = inbuf.ptr;
				z.avail_in = f_read(s2, inbuf);
			}
			
			int status = inflate(&z, Z_NO_FLUSH);

			if (z.avail_out >= 0) {
				int count = outbuf.length - z.avail_out;
				if (f_write(d, outbuf[0..count]) != count) {
					writefln("error3");
					break;
				}
			}

			if (status == Z_STREAM_END) break;

			if (status != Z_OK) {
				writefln("inflate: %s\n", (z.msg) ?  std.string.toString(z.msg) : "???");
				break;
			}
		}
		
		inflateEnd(&z);
	}
	
	int method = e_get_int(e, -2);
	
	switch (method) {
		case 0: // uncompressed
			decompress_00();
		break;
		case 8: // 
			decompress_08();
		break;
	}
}
