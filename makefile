# define some Makefile variables for the compiler and compiler flags
ASM = nasm
LINKER = gcc
ASMFLAGS = -g -f elf
LINKERFLAGS = -m32 -Wall
OBJS = calc.o

# All Targets
all: calc

# Tool invocations
calc: $(OBJS)
	@echo 'Invoking Linker'
	$(LINKER) $(LINKERFLAGS) $(OBJS) -o calc
	@echo 'Finished building target.'
	@echo ' '

calc.o: calc.s
	$(ASM) $(ASMFLAGS) calc.s -o calc.o


.PHONY: clean

#Clean the build directory
clean:
	rm -f *.o calc
