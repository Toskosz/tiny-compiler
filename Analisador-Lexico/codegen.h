#ifndef CODEGEN_H
#define CODEGEN_H

void codegen_init(const char* output_filename);

void codegen_finalize();

void gen_loop_start();
void gen_after_condition();
void gen_loop_end();
void gen_if();
void gen_if_else();
void gen_assign(int address);
void gen_neg();
void gen_op(const char* op);
void gen_num(int value);
void gen_id(int address);
void gen_relop(const char* op);
void gen_read(int address);
void gen_write();

#endif 
