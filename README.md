# About

This is an [LZW](https://web.archive.org/web/20180904074021/https://marknelson.us/posts/1989/10/01/lzw-data-compression.html)
compressor/decompressor for the Commodore 64 compatible with UNIX 
[compress](https://en.wikipedia.org/wiki/Compress).

Today, on modern Linux distributions, you can use [ncompress](https://vapier.github.io/ncompress/).

LZW was first introduced by Terry Welch in [A Technique for High-Performance Data Compression, 1984](https://courses.cs.duke.edu/spring03/cps296.5/papers/welch_1984_technique_for.pdf).

File compressed on Linux can be uncompressed on a C64 and vice-versa, with a 
caveat. You cannot use more than 12 bits per code when compressing and 13 bits 
when decompressing. Use compress -b 13 on Linux to create a file readable by 
a C64.

Original source code was developed in 1996 using GeoProgrammer. This is not a 
GEOS program but I liked its usage of macros. After many years, I dumped the 
disk with the source code, converted it to a text file using [geowrite2rtf](https://github.com/mist64/geowrite2rtf)
and ported to ca65. I'm not a cc65 expert, therefore there may be naivety
and inaccuracies.

It should be possibile to improve the program and use [GEORAM](https://www.c64-wiki.com/wiki/GeoRAM) 
avoiding the limit on the number of bits/code. Or it can be adapted to perform 
[GIF](https://www.w3.org/Graphics/GIF/spec-gif89a.txt) decompression. GIF uses
at most 12 bits per code.

My implementation is faster than the one made by Bill Lucier published on [C= Hacking 6](https://codebase64.org/doku.php?id=magazines:chacking6#lzw_compression). 
As far as I can remember, it is due to a better hash function.

# Building

Just type `make` on a recent Linux distro with ca65 and vice installed.

A d64 file containing compress will be created.

# Usage

```
load"compress",8,1
new
```

It uses memory locations $C000-CFFF.

Logical filenumber 2 is used for the input file, logical filenumber 3 is 
used for the output file.

You can decompress with:

```
poke 52994,1 :rem use magic header
open 2,8,2,"filename.z,s,r"
open 3,8,3,"filename,s,w"
sys 49152
close 3
close 2
```

You can compress with:

```
poke 52993,12 :rem maxbits
poke 52994,1 :rem use magic header
poke 52995,128 :rem block compress
open 2,8,2,"filename,s,r"
open 3,8,3,"filename.z,s,w"
sys 49155
close 3
close 2
```

Errors can be read with:

```
print peek(52992)
```

2: header not found<br>
3: maxbits > #MAX_BITS (13)

# Further readings

[A Universal Algorithm for Sequential Data Compression](http://www.nemenmanlab.org/~ilya/images/e/e9/Ziv-lempel-77.pdf)

[The Secret of Fast LZW Crunching](http://codebase64.org/doku.php?id=base:the_secret_of_fast_lzw_crunching)

