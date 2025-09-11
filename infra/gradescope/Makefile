# List of source files to copy from ../../project2/
P2_SOURCES = util.py alu.py run_autograder

# Target
project2:
	mkdir -p build
	cp $(addprefix ../../project2/,$(P2_SOURCES)) build/
	docker build . \
		--build-arg COCOTB=1 \
		--build-arg ICARUS=1 \
		-t registry.doit.wisc.edu/engr/ece/ece552/wisc25-dist/gradescope:project2 \
		-t coderkalyan/ece552-gradescope:project2
	rm -rf build
