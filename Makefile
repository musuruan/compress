# Requires: cc65, vice

all: compress.prg compress.d64

compress.prg: compress.s
	cl65 -t none -o compress.prg compress.s

compress.d64: compress.prg
	c1541 -format "compress,ig" d64 compress.d64
	c1541 compress.d64 -write "compress.prg" "compress"
	c1541 compress.d64 -dir

clean:
	rm *.prg *.o *.d64

