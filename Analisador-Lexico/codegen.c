#include "codegen.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

// TM Machine register's
#define AC 0 // Accumulator
#define AC1 1 // Second accumulator
#define GP 5  // Global Pointer (base for variables)
#define FP 6  // Frame Pointer (not used)
#define PC 7  // Program Counter
#define MAX_LOC_STACK 10

static FILE* code;
static int emitLoc = 0;
static int highEmitLoc = 0;

static int loc_stack[MAX_LOC_STACK];
static int top = -1;

void push_loc(int loc) {
	if (top >= MAX_LOC_STACK - 1) {
		printf("codegen: push_loc: Location stack overflow\n");
		exit(1);
	}
	loc_stack[++top] = loc;
}

int pop_loc(){
	if (top < 0) {
		printf("codegen: pop_loc: Location stack underflow\n");
		exit(1);
	}
	return loc_stack[top--];
}

void emitComment(const char* c) {
    if (c) fprintf(code, "* %s\n", c);
}

void emitRO(const char* op, int r, int s, int t, const char* c) {
    fprintf(code, "%3d: %5s %d,%d,%d\t%s\n", emitLoc++, op, r, s, t, c);
    if (highEmitLoc < emitLoc) highEmitLoc = emitLoc;
}

void emitRM(const char* op, int r, int d, int s, const char* c) {
    fprintf(code, "%3d: %5s %d,%d(%d)\t%s\n", emitLoc++, op, r, d, s, c);
    if (highEmitLoc < emitLoc) highEmitLoc = emitLoc;
}

int emitSkip(int howMany) {
    int i = emitLoc;
    emitLoc += howMany;
    if (highEmitLoc < emitLoc) highEmitLoc = emitLoc;
    return i;
}

void emitBackup(int loc) {
    emitLoc = loc;
}

void emitRestore() {
    emitLoc = highEmitLoc;
}

void codegen_init(const char* output_filename) {
    code = fopen(output_filename, "w");
    if (code == NULL) {
        printf("Unable to open file %s\n", output_filename);
        exit(1);
    }
    emitComment("TINY Compilation to TM Code");
    emitComment("Standard prelude:");
    emitRM("LD", GP, 0, 0, "Load global pointer");
    emitRM("LDA", FP, 0, GP, "Copy GP to FP");
    emitRM("ST", AC, 0, AC, "Clear location 0");
    // Jump to main program, skipping prelude
    int savedLoc = emitSkip(1);
    // ... (code for functions would go here) ...
    emitBackup(savedLoc);
    emitRM("LDC", PC, highEmitLoc, 0, "Jump to end of prelude");
    emitRestore();
    emitComment("End of standard prelude.");
}

void codegen_finalize() {
    emitRO("HALT", 0, 0, 0, "End of program");
    fclose(code);
}

void gen_if() {
    int savedLoc;
    emitComment("IF: jump to then part");
    savedLoc = emitSkip(1); // Skip a location for the conditional jump
    push_loc(savedLoc);     // Push location onto stack for backpatching
}

void gen_loop_start() {
    push_loc(emitLoc); // Push address of loop start
    emitComment("WHILE: loop start");
}

void gen_after_condition() {
    // The condition result is in AC. Jump if false (0).
    // We don't know where to jump yet, so we skip a location.
    emitComment("WHILE: test condition");
    int savedLoc = emitSkip(1);
    push_loc(savedLoc); // Push address of the JEQ for backpatching
}

void gen_loop_end() {
    emitComment("WHILE: end of loop body");
    int jmp_loc = pop_loc();   // Get the JEQ location
    int loop_start = pop_loc(); // Get the loop start location
    // Unconditional jump back to the start of the loop
    emitRM("LDC", PC, loop_start, 0, "Jump back to loop start");
    // Now backpatch the conditional jump
    int current_loc = emitLoc;
    emitBackup(jmp_loc);
    emitRM("JEQ", AC, current_loc, 0, "Jump out of loop if condition is false");
    emitRestore();
    emitComment("WHILE: end of loop");
}

// --- Expression and Statement Code Generation ---
void gen_assign(int address) {
    emitComment("ASSIGN: storing value");
    emitRM("ST", AC, address, GP, "Store result to variable");
}

void gen_id(int address) {
    emitComment("LOAD: loading variable");
    emitRM("LD", AC, address, GP, "Load variable value into AC");
}

void gen_num(int value) {
    emitComment("LOAD: loading constant");
    emitRM("LDC", AC, value, 0, "Load constant value into AC");
}

void gen_neg() {
    emitComment("NEGATE: value");
    emitRO("SUB", AC, AC1, AC, "Negate (0 - value)"); // Using 0 in AC1
}

void gen_op(const char* op) {
    emitComment("OP: combining values");
    emitRM("ST", AC, 0, GP, "Store left operand"); // Temporarily store left operand
    // Right operand is now in AC from previous expression parsing
    emitRM("LD", AC1, 0, GP, "Load left operand into AC1");
    if (strcmp(op, "ADD") == 0) {
        emitRO("ADD", AC, AC1, AC, "Op +");
    } else if (strcmp(op, "SUB") == 0) {
        emitRO("SUB", AC, AC1, AC, "Op -");
    } else if (strcmp(op, "MUL") == 0) {
        emitRO("MUL", AC, AC1, AC, "Op *");
    } else if (strcmp(op, "DIV") == 0) {
        emitRO("DIV", AC, AC1, AC, "Op /");
    }
}

void gen_relop(const char* op) {
    emitComment("RELOP: comparing values");
    emitRM("ST", AC, 0, GP, "Store left operand");
    emitRM("LD", AC1, 0, GP, "Load left operand into AC1");
    emitRO("SUB", AC, AC1, AC, "Compare by subtraction (L-R)");
    // The jump instruction will be emitted by the calling rule (e.g., gen_after_condition)
    // Here we just set the flags. The TM instructions JLT, JEQ, etc., test AC.
    // For this simple model, we assume the calling function handles the jump.
}

void gen_if_else() {
    emitComment("IF-ELSE: backpatch and setup else");
    int else_jump = pop_loc();  // Get the location to backpatch
    int skip_else = emitSkip(1); // Skip location for jump over else part
    
    // Backpatch the conditional jump to point to else part
    int current_loc = emitLoc;
    emitBackup(else_jump);
    emitRM("JEQ", AC, current_loc, 0, "Jump to else if condition is false");
    emitRestore();
    
    // After else statements, backpatch the skip jump
    current_loc = emitLoc;
    emitBackup(skip_else);
    emitRM("LDC", PC, current_loc, 0, "Jump over else part");
    emitRestore();
    emitComment("IF-ELSE: end");
}

void gen_read(int address) {
    emitComment("READ: input value");
    emitRO("IN", AC, 0, 0, "Read integer from input");
    emitRM("ST", AC, address, GP, "Store input value to variable");
}

void gen_write() {
    emitComment("WRITE: output value");
    emitRO("OUT", AC, 0, 0, "Write AC to output");
}
