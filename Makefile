all:

clean:

build:
	mkdir -p bin/
	nim c --nimcache:/tmp --out:bin/roboclue -d:release src/roboclue.nim
