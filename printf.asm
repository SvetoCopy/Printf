extern WriteFile
extern GetStdHandle

StackShadowStorage      equ 20h

%macro check_buff 0
        push rax
        call buff_len
        cmp rax, 511d
        jge .clear_buff
        jmp .check_buff_end

.clear_buff:
        call write_buff
        mov rsi, buff

.check_buff_end:
        pop rax
%endmacro

section .rodata
spec_sym_table:
                                dq fill_percent         ; %%
        times 'b' - '%' - 1     dq spec_sym_table_exit
                                dq fill_binary          ; %b
                                dq fill_char            ; %c
                                dq fill_dec             ; %d
        times 'o' - 'd' - 1     dq spec_sym_table_exit
                                dq fill_unsigned_octal  ; %o
        times 's' - 'o' - 1     dq spec_sym_table_exit
                                dq fill_string          ; %s
        times 'x' - 's' - 1     dq spec_sym_table_exit
                                dq fill_unsigned_hex    ; %x
        times 255 - 'x' - 1     dq spec_sym_table_exit

args_table:
        dq first_arg
        dq second_arg
        dq third_arg

section .data
buff            db 512d DUP(0)
num_buff        db 20  DUP(0)
HEX_ALPH        db '0123456789ABCDEF'

section .text
global ruzik_val_printf

ruzik_val_printf:

        push r12

        mov rsi, buff   ; fill_buff(buff, rsp + 8)
        mov r12, rsp
        add r12, 8
        call fill_buff

        pop r12

        call buff_len   ; write_buff(buff_len - 1)
        dec rax
        call write_buff

        ret
;----------------------------------------------------------------
;Fill buff from format text
;Entry:
;       rsi - buff ptr
;       r12 - args address in stack
;Destr: r10d, rcx, rsi
;
;----------------------------------------------------------------
fill_buff:

        xor r11, r11            ; r11 = 0 (args filled count)

.check:
        mov r10b, [rcx]

        cmp r10b, '%'           ; if ([rcx] == '%') .get_type_code
        je .get_type_code

        cmp r10b, 0             ; else if ([rcx] != '\0') .exit
        je .exit

.copy_char:                     ; else
        mov [rsi], r10b         ; buff[i] = [rsi]
        inc rsi
        inc rcx
        check_buff              ; check buff's count
        jmp .check

.get_type_code:
        inc rcx
        call fill_spec_sym      ; fill buff with arg

        inc r11
        inc rsi
        inc rcx
        jmp .check

.exit:
        ret

;----------------------------------------------------------------
;fill_spec_sym - replacing code to arg in buff        v
;Entry: (format, ...) cdecl (rcx - should be on %x)
;       r11 - args filled count
;       rsi - buff ptr
;       r12 - args address in stack
;Destr: r10b
;
;----------------------------------------------------------------
fill_spec_sym:

        xor r10, r10            ; r10 = 0

        mov r10b, [rcx]         ; r10b = buffer[i]
        sub r10b, 25h           ; r10b -= 25

        cmp r10b, 0             ; if (r10b < 0) .exit
        jl spec_sym_table_exit

        cmp r10b, 53h           ; if (r10b > 53h) .exit
        jg spec_sym_table_exit

        shl r10, 3              ; jmp [r10 * 8 + spec_sym_table]
        mov rax, spec_sym_table
        add r10, rax

        jmp [r10]

fill_char:
        call get_n_arg_val
        mov byte [rsi], al
        check_buff
        jmp spec_sym_table_exit

fill_string:
        call get_n_arg_val
        call write_str_to_buff
        jmp spec_sym_table_exit

fill_percent:
        mov byte [rsi], '%'
        check_buff
        jmp spec_sym_table_exit

fill_dec:
        call get_n_arg_val
        call write_str_from_dec
        jmp spec_sym_table_exit

fill_unsigned_hex:
        call get_n_arg_val

        mov r10, 16             ; base = 16
        call write_str_from_num
        jmp spec_sym_table_exit

fill_unsigned_octal:
        call get_n_arg_val

        mov r10, 8              ; base = 8
        call write_str_from_num
        jmp spec_sym_table_exit

fill_binary:
        call get_n_arg_val
        call write_str_from_bin
        jmp spec_sym_table_exit

spec_sym_table_exit:
        ret

;----------------------------------------------------------------
;get_n_arg_val - get n number arg value
;Entry: (format, ...) cdecl
;       rsi - buff ptr
;       r12 - args address in stack
;       r11 - n
;Return:
;       rax - n arg value
;Destr:
;----------------------------------------------------------------
get_n_arg_val:
        push r11

        cmp r11, 3              ; if (r11 not in registers) .other_args
        jge other_args

        shl r11, 3              ; else jmp [r11 * 8 + args_table]
        mov rax, args_table
        add r11, rax

        jmp [r11]

first_arg:
        mov rax, rdx
        jmp args_table_exit

second_arg:
        mov rax, r8
        jmp args_table_exit

third_arg:
        mov rax, r9
        jmp args_table_exit

other_args:
        push rbp

        sub r11, 2              ; r11 = (r11 - 3) * 8
        shl r11, 3
        mov rbp, r12            ; rbp = args address in stack + r11 + StackShadowStorage

        add rbp, r11
        add rbp, StackShadowStorage
        mov rax, [rbp]

        pop rbp

args_table_exit:
        pop r11
        ret

;----------------------------------------------------------------
;write_str_from_dec
;Entry: rax - decimal
;       rsi - buff
;Destr:
;----------------------------------------------------------------
write_str_from_dec:
        cmp rax, 0
        jg .start

        mov byte [rsi], '-'     ; if (rax < 0) printf('-'); rax = -rax
        inc rsi
        check_buff

        neg rax

.start:
        push r11
        xor r11, r11            ; r11 - digits count

        mov rdi, num_buff       ; rsi - buff for write digit ( then buff will reverse )
        xor r10, r10
        mov r10, 10d            ; r10 is divider

.while_cond:
        cmp rax, 0              ; while (num != 0) .while_body
        jne .while_body

        dec rdi                 ; else reverse_str(num_buff, digits count)
        mov r10, r11
        call reverse_str

        pop r11
        ret

.while_body:
        inc r11                 ; digits count++
        xor rdx, rdx

        idiv r10                ; dl = num % 10
        add rdx, 30h            ; rax /= 10
        mov byte [rdi], dl      ; num_buff[i] = dl

        inc rdi
        jmp .while_cond

;----------------------------------------------------------------
;reverse_str
;Entry: rdi - destination ( rdi should be on last byte)
;       rsi - source
;       r10 - count
;Destr: r10, r11
;----------------------------------------------------------------
reverse_str:

.reverse_copy:
        cmp r10, 0
        je .end

        mov byte r11b, [rdi]
        mov byte [rsi], r11b

        inc rsi
        check_buff
        dec rdi
        dec r10
        jmp .reverse_copy

.end:
        ret

;----------------------------------------------------------------
;write_str_from_num
;Entry: rax - num
;       rsi - buff
;       r10 - base
;Destr:
;----------------------------------------------------------------
write_str_from_num:
        push r11                ; r11 - digits count
        xor r11, r11

        mov rdi, num_buff

.while_cond:
        cmp rax, 0
        jne .while_body

        dec rdi
        mov r10, r11
        call reverse_str

        pop r11
        ret

.while_body:
        inc r11
        xor rdx, rdx

        idiv r10

        push rax
        push rbx

        mov al, dl
        mov rbx, HEX_ALPH
        xlat

        mov byte [rdi], al

        pop rbx
        pop rax
        inc rdi
        jmp .while_cond

;----------------------------------------------------------------
;write_str_from_bin
;Entry: rax - binary
;       rsi - buff
;Destr:
;----------------------------------------------------------------
write_str_from_bin:
        push r11        ; r11 - digits count
        xor r11, r11

        mov rdi, num_buff

.while_cond:
        cmp rax, 0
        jne .while_body

        dec rdi
        mov r10, r11
        call reverse_str

        pop r11
        ret

.while_body:
        inc r11

        mov dl, al      ; dl = al % 2
        and dl, 1       ; rax /= 2
        shr rax, 1

        add dl, 30h
        mov byte [rdi], dl

        inc rdi
        jmp .while_cond

;----------------------------------------------------------------
;write_str_to_buff
;Entry: rax - str
;       rsi - buff
;Destr:
;----------------------------------------------------------------
write_str_to_buff:

.cond:
        mov r10b, [rax]
        cmp r10b, 0
        jne .copy

        ret

.copy:
        mov [rsi], r10b
        inc rsi
        inc rax
        check_buff
        jmp .cond

;----------------------------------------------------------------
;write to console from buffer
;Entry:
;       rax - len
;Destr:
;----------------------------------------------------------------
write_buff:
        push rdx
        push rcx
        push r8
        push r9

        mov r8, rax
        mov rdx, buff

        sub rsp, 40                    ; allocate memory in stack
        mov rcx, -11                   ; STD_OUTPUT
        call GetStdHandle              ; GetStdHandle(STD_OUTPUT)

        mov rcx, rax

        xor r9, r9
        mov qword [rsp + 32], 0
        call WriteFile
        add rsp, 40

        pop r9
        pop r8
        pop rcx
        pop rdx

        ret

;----------------------------------------------------------------
;get buff len
;Entry: rsi - buff
;Destr:
;----------------------------------------------------------------
buff_len:
        push rsi
        push rdi

        mov rdi, buff
        sub rsi, rdi

        mov rax, rsi

        pop rdi
        pop rsi
        ret
