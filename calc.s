; define boolean true and false
%define true 1
%define false 0

; define program constants
%define base 15
%define stack_size 5
%define buffer_len 82

; define program macro subroutines
%macro print_debug 2
   mov esi, %1
   mov edi, %2
   mov ebx, dword [stderr]
   push esi
   push edi
   push ebx
   call fprintf
   pop edi
   pop esi
   pop ebx
%endmacro

%macro print_str 1
   mov esi, %1
   mov edi, string_format
   push esi
   push edi
   call printf
   pop edi
   pop esi
%endmacro

%macro inc_op_count 0
   mov ecx, [op_count]
   inc ecx
   mov [op_count], ecx
%endmacro

%macro print_hex 2
   mov esi, %1
   mov edi, %2
   push esi
   push edi
   call printf
   pop edi
   pop esi
%endmacro

; allocates memory for a new link
%macro alloc_link 0
   mov edx, dword lnk_size
   push dword 1
   push edx               ; Size to get from the heap and pass the size to the malloc function
   call calloc         ; Call the malloc function - now eax has the address of the allocated mem
   pop edx
   add esp, 4
%endmacro

; assignes a value to a newly created link
%macro assign_lnk_val 0
   push esi
   call two_bytes_to_hex
   pop esi
   cmp byte [err_flag], true
   je list_done
   mov bl, byte [curr_lnk_val]

   mov [ecx + num], bl
   sub esi, 2
   sub edi, 2
%endmacro

; compares current stack size with given parameter
%macro cmp_stack_size 1
   mov ebx, [curr_stack_size]
   cmp ebx, %1
%endmacro

%macro free_list 1
   push dword %1
   call free_list_from_stack
   add esp, 4
%endmacro

; pushes given parameter address to stack and increases stack size
%macro push_stack 1
   mov ebx, [curr_stack_size]
   mov eax, stack
   mov [eax+ebx*4], %1
   inc ebx
   mov [curr_stack_size], ebx
%endmacro

; returns in eax register the address saved in top of the stack
%macro peek_stack 0
   mov ebx, [curr_stack_size]
   dec ebx
   mov edx, stack
   mov eax, [edx+ebx*4]
%endmacro

; removes and returnes top of the stack, decreases current stack size
%macro pop_stack 0
   mov ebx, [curr_stack_size]
   dec ebx
   mov edx, stack
   mov eax, [edx+ebx*4]
   mov [curr_stack_size], ebx
%endmacro

section .rodata
   ;define string formats to call printf with
   string_format: db "%s", 0
   out_format_first: db "%X", 0
   out_format_first_last: db "%X", 10, 0
   out_format: db "%02X", 0
   out_format_last: db "%02X", 10, 0

   prompt: db "calc: ", 0

   ; define debug mode messages
   dbg_read: db "Debug: Number pushed is ", 0
   dbg_result: db "Debug: Result pushed is ", 0

   ; define error messages
   err_pow: db "wrong Y value", 10, 0
   err_illegal: db "Error: Illegal Input", 10, 0
   err_overflow: db "Error: Operand Stack Overflow", 10, 0
   err_underflow: db "Error: Insufficient Number of Arguments on Stack", 10, 0

section .data
   ; define link structure
   struc link
       num: resb  1  ; link data
       next: resd  1 ; next link address
   endstruc
   lnk_size: equ 5

section .bss
   stack: resb stack_size*4 ; 32 bit address size times current defines stack size
   curr_stack_size: resd 1  ; current stack allocations

   buffer: resb buffer_len
   input: resd 1
   reversed_input: resd 1

   debug: resb 1
   input_len: resd 1
   input_odd: resb 1
   op_count: resd 1
   curr_lnk_val: resb 1
   quit_flag: resb 1
   err_flag: resb 1

section .text
   align 16
      global main
      extern fprintf
      extern printf
      extern getchar
      extern calloc
      extern free
      extern fgets

      extern stdin
      extern stderr

main:
   push ebp
   mov ebp, esp
   pushad

   ; assign initial values to global variables
   mov dword [curr_stack_size], 0
   mov byte [quit_flag], false
   mov dword eax, stack
   sub eax, 4
   debug_arg:
      mov dword [debug], false      ; initialize
      cmp dword [ebp + 8], 1        ; check argc is greater than 1
      je calc                       ; start my calc in regular mode if argc = 1
      mov eax, dword [ebp + 16]     ; get second param address
      mov ebx, dword [eax]          ; get second param represented string
      sub ebx, 3
      ; check the argument given is "-d"
      cmp byte [ebx], '-'
      jne calc
      cmp byte [ebx + 1],'d'
      jne calc
      cmp byte [ebx + 2], 0
      jne calc
      mov dword [debug], true       ; assign debug mode flag

   calc:
   call myCalc                      ; start main program function
   mov eax, [op_count]
   print_hex eax, out_format_first_last      ; print returned operation counter

   popad; Restore caller state (registers)
   pop ebp; Restore caller state
   ret; Back to caller

myCalc:
   push ebp
   mov ebp, esp
   pushad

   main_loop:
      mov byte [err_flag], false
      mov eax, 0
      ; clear input buffer
      clear_buffer:
         mov ebx, buffer
         mov [ebx+eax], byte 0
         inc eax
         cmp eax, buffer_len
         jne clear_buffer

      ; print prompt calc:
      print_str prompt
      ; read input from user
      call read_input
      ; check if error was thrown, and if it was re-enter main loop
      cmp byte [err_flag], true
      je main_loop
      ; parse input given from user (number or operation symbol)
      call parse_input

      ; check if exit flag is on
      mov bl, [quit_flag]
      cmp bl, true
      jne main_loop

   popad; Restore caller state (registers)
   pop ebp; Restore caller state
   ret; Back to caller


read_input:
   push dword [stdin]              ;fgets need 3 parameters
   push buffer_len
   push buffer+1
   call fgets
   add esp, 12
   mov ebx, eax
   mov ecx, buffer_len
   xor edx, edx
   ; iterates input to replace '\n' and initialize current input length
   iterate_input:
      cmp byte [ebx], 10
      je trim
      inc edx
      inc ebx
      loop iterate_input, ecx
      call illegal_input
      ret
   trim:
      mov byte [ebx], 0
      mov dword [input_len], edx
   ret

; iterate to replace all input character to upper case
buffer_to_upper:
   mov ebx, buffer + 1
   mov ecx, buffer_len
   iterate_upper:
      cmp byte [ebx], 0
      je finish_buffer_upper
      call to_upper
      inc ebx
      loop iterate_upper, ecx
   finish_buffer_upper:
   ret

to_upper:
   push ebp
   mov ebp, esp
   pushad

   ; subtracts 32 from lower case alphabetic characters to replace them with upper case
   cmp byte [ebx], 'a'
   jge convert_to_upper
   jmp finish_upper
   convert_to_upper:
      mov ecx, [ebx]
      sub ecx, 32
      mov [ebx], ecx
   finish_upper:
      popad; Restore caller state (registers)
      pop ebp; Restore caller state
      ret; Back to caller

parse_input:
   mov ecx, [input_len]
   mov ebx, buffer + 1
   cmp ecx, 1
   jne parse_hex

   ; if input size is 1 check if it is a legal defines operation and call correspoding function
   cmp [ebx], byte '+'
   jne no_addition
   mov ecx, dword true
   push ecx
   call addition
   pop ecx
   ret

   no_addition:
   cmp [ebx], byte 'p'
   jne no_print
   push dword true
   call pop_and_print
   add esp, 4
   ret

   no_print:
   cmp [ebx], byte '^'
   jne no_pow
   xor ecx, ecx
   mov ecx, dword true
   push ecx
   call pow
   pop ecx
   ret

   no_pow:
   cmp [ebx], byte 'v'
   jne no_neg_pow
   xor ecx, ecx
   mov ecx, dword false
   push ecx
   call pow
   pop ecx
   ret

   no_neg_pow:
   cmp [ebx], byte 'n'
   jne no_one_bit
   call count_one_bit
   ret

   no_one_bit:
   cmp [ebx], byte 'q'
   jne no_quit
   call quit
   ret

   no_quit:
   cmp [ebx], byte 'd'
   jne parse_hex
   mov ecx, dword true
   push ecx
   call duplicate
   pop ecx
   ret

   parse_hex:
      cmp_stack_size stack_size
      jne no_overflow
      call stack_overflow
      ret

      ; if input is not an operation parse it as hex value
      no_overflow:
      call buffer_to_upper ; assign input to upper case
      call remove_input_leading_zeros ; removes any leading '0' characters
      mov ecx, dword [input_len]
      mov ebx, dword [reversed_input]
      push ecx
      push ebx
      call create_list  ; create a list representing the given input hex
      pop ebx
      pop ecx
      push dbg_read
      call print_debug_message   ; print debug message for input given
      add esp, 4
   ret

remove_input_leading_zeros:
   xor ebx, ebx
   mov eax, buffer + 1
   jmp remove_loop
   ; removes leading zeros from input buffer
   remove_zero:
      inc eax
      inc ebx
      loop remove_loop, ecx
   remove_loop:
      cmp [eax], byte '0'
      je remove_zero

   ; checks if the length of the input is odd or even after removal
   mov ecx, [input_len]
   sub ecx, ebx
   cmp ecx, 0
   je set_input_odd
   push ecx
   call is_input_len_odd
   pop ecx
   mov bl, [input_odd]
   cmp bl, false
   je finish_remove

   set_input_odd:
      dec eax
      mov [eax], byte '0'
      inc ecx
      cmp ecx, 1
      je assign_zero
      jmp finish_remove

   ; if input length is odd assigns additional zero before the input and after leading zeros removal
   assign_zero:
      inc eax
      mov [eax], byte '0'
      dec eax
      inc ecx

   finish_remove:
      mov dword [input], eax
      mov dword [input_len], ecx
      call reverse_input
      mov [reversed_input], eax
   ret; Back to caller

is_input_len_odd:
   push ebp
   mov ebp, esp
   pushad


   mov eax, dword [ebp+8]
   xor edx, edx
   mov ecx, 2
   div ecx ; check if the length of the input is divisable by 2 and update odd flag
   cmp edx, 0
   je not_odd
   odd:
      mov byte [input_odd], true
      jmp ret_len_odd
   not_odd:
      mov byte [input_odd], false
   ret_len_odd:
      popad
      pop ebp; Restore caller state
      ret; Back to caller

reverse_input:
   ; returnes a pointer to last character in input
   mov eax, dword [input]
   mov ecx, dword [input_len]
   cmp ecx, 1
   je reversed
   dec ecx
   reverse:
      inc eax
      loop reverse, ecx
   reversed:
      ret

two_bytes_to_hex:
   push ebp
   mov ebp, esp
   pushad

   xor ebx, ebx
   xor esi, esi
   mov edi, dword [ebp+8]

   convert:
      ; converts 2 characters into a hexadecimal value
      neg esi
      mov al, byte [edi+esi]
      ; check input hex number is valid hex
      cmp al, byte '0'
      jl illegal_hex
      cmp al, byte 'F'
      jg illegal_hex
      cmp al, byte '9'
      jle numeric_hex
      jmp alpha_hex
      numeric_hex:
         sub al, byte 48
         jmp compute
      alpha_hex:
         sub al, byte 55
         compute:
         xor ecx, ecx
         neg esi
         mov cl, al
         mov eax, base
         mul esi
         mul ecx
         add eax, ecx
         add ebx, eax
         inc esi
         cmp esi, 2
         jne convert
         jmp assign_val

   illegal_hex:
      pop_stack
      free_list eax
      call illegal_input

   assign_val:
      mov [curr_lnk_val], bl
      popad
      pop ebp; Restore caller state
      ret; Back to caller

create_list:
   push ebp
   mov ebp, esp
   pushad

   mov esi, dword [ebp+8]
   mov edi, dword [ebp+12]

   ; allocate first link for the list and push the pointer to argument stack
   alloc_link
   mov ecx, eax
   push_stack ecx

   assign_lnk_val
   cmp edi, 0
   je created

   ; make the rest of the links of the list while updating next link addresses to create the list
   make_links:
      mov ebx, ecx
      alloc_link
      mov [ebx + next], eax
      mov ecx, eax

      assign_lnk_val
      cmp edi, 0
      jne make_links

   created:
      mov [ecx + next], dword 0
   list_done:
      popad
      pop ebp; Restore caller state
      ret; Back to caller

addition:
   push ebp
   mov ebp, esp
   pushad
   sub esp, 24

   mov ebx, [ebp + 8]
   cmp ebx, true
   jne check_legal
   inc_op_count

   check_legal:
   cmp_stack_size 2
   jae no_addition_underflow
   call stack_underflow
   jmp end_addition_no_free

   no_addition_underflow:
   mov [ebp - 4], dword 0

   ; pops first two arguments from operand stack
   pop_stack
   mov edi, eax
   pop_stack
   mov ebx, eax

   mov [ebp - 20], edi
   mov [ebp - 24], ebx

   ; add leading zeros to shortest number to make the numbers same length
   push edi
   push ebx
   call add_zeros_to_shortest
   pop ebx
   pop edi
   mov [ebp - 12], ebx
   mov [ebp - 16], edi

   ; allocate and push to operand stack the first link of the result
   alloc_link
   mov ecx, eax
   push_stack ecx
   mov [ebp - 8], ecx

   add_loop:
      mov ebx, [ebp - 12]
      mov edi, [ebp - 16]
      xor eax, eax
      xor edx, edx
      mov al, byte [ebx + num]
      mov dl, byte [edi + num]
      add eax, edx               ; add two link numbers
      add eax, dword [ebp - 4]   ; add the saved carry from previous addition
      xor edx, edx
      mov ecx, 0x100
      div ecx                    ; take only first two hex values to current result link
      mov [ebp - 4], eax         ; if the number had 3 digits update carry flag
      mov ecx, [ebp - 8]
      mov [ecx + num], byte dl
      cmp [ebx + next], dword 0
      je done_addition
      mov ebx, [ebx + next]      ; iterate to next links in the operands
      mov edi, [edi + next]
      mov [ebp - 12], ebx
      mov [ebp - 16], edi
      alloc_link                 ; allocate new link for the result
      mov ecx, [ebp - 8]
      mov [ecx + next], eax
      mov [ebp - 8], eax
      jmp add_loop

   done_addition:
      cmp [ebp - 4], dword 0
      je close_output
      alloc_link                 ; update last link in result
      mov ecx, [ebp - 8]
      mov [ecx + next], eax
      mov ebx, [ebp - 4]
      mov [eax + num], ebx
      mov [ebp - 8], eax
      close_output:
         mov ebx, [ebp - 8]
         mov [ebx + next], dword 0

      mov ebx, [ebp + 8]
      cmp ebx, true
      jne end_addition
      push dbg_result
      call print_debug_message
      add esp, 4

      ; free poped operands
      end_addition:
      free_list [ebp - 20]
      free_list [ebp - 24]
      end_addition_no_free:
      add esp, 24
      popad
      pop ebp; Restore caller state
      ret; Back to caller

add_zeros_to_shortest:
   push ebp
   mov ebp, esp
   sub esp, 16

   mov esi, dword [ebp+8]
   mov edi, dword [ebp+12]
   mov [ebp - 12], esi
   mov [ebp - 16], edi

   ; check the length of two given argument lists
   xor edx, edx
   xor ebx, ebx
   first_length:
      inc edx
      mov [ebp - 4], esi
      mov eax, dword [esi + next]
      cmp eax, dword 0
      mov esi, eax
      jne first_length

   second_length:
      inc ebx
      mov [ebp - 8], edi
      mov eax, dword [edi + next]
      cmp eax, dword 0
      mov edi, eax
      jne second_length

   cmp edx, ebx
   je done_adding_zeros
   jg append_zeros_second

   ;  append zeros to complete to same length to the shorter list
   append_zeros_first:
      sub ebx, edx
      mov esi, ebx
      mov ebx, [ebp - 4]
      append_loop_first:
         alloc_link
         mov [ebx + next], dword eax
         mov edx, eax
         mov [edx + num], byte 0x00
         mov ebx, edx
         dec esi
         cmp esi, 0
         jne append_loop_first
         jmp done_adding_zeros

   append_zeros_second:
      sub edx, ebx
      mov esi, edx
      mov ebx, [ebp - 8]
      append_loop_second:
         alloc_link
         mov [ebx + next], dword eax
         mov edx, eax
         mov [edx + num], byte 0x00
         mov ebx, edx
         dec esi
         cmp esi, 0
         jne append_loop_second

   done_adding_zeros:
      mov eax, [ebp - 12]
      mov edx, [ebp - 16]
      add esp, 16
      pop ebp; Restore caller state
      ret; Back to caller


pop_and_print:
   push ebp
   mov ebp, esp
   pushad

   sub esp, 8

   cmp_stack_size 0
   jg no_print_underflow
   call stack_underflow
   inc_op_count
   jmp end_print_no_free

   no_print_underflow:
   mov ebx, [ebp + 8]
   cmp ebx, true
   jne no_count_operation
      inc_op_count

   ; pop or peek first operand from stack according to argument flag
   no_count_operation:
   xor ecx, ecx
   cmp ebx, true
   jne peek_top
   pop_stack
   jmp pop_top
   peek_top:
      peek_stack
   pop_top:
   mov [ebp - 8], eax
   mov ebx, eax
   iterate_number:
      inc ecx
      mov dl, byte [ebx + num]
      push edx                   ; push to stack to reverse printing order
      cmp [ebx + next], dword 0
      je print
      mov ebx, [ebx + next]
      jmp iterate_number

   print:
      xor edi, edi
      mov [ebp - 4], ecx
      mov edi, true
      print_number:
         pop edx              ; pop to get number in reveresed order
         mov [curr_lnk_val], dl
         cmp edi, true
         je print_first
         cmp [ebp - 4], dword 1
         je print_last

         mov eax, [ebp + 8]
         cmp eax, true
         jne print_out_debug
         print_hex [curr_lnk_val], out_format
         jmp next_hex
         ;  print with the correct format according to current printed link
         print_out_debug:
            print_debug [curr_lnk_val], out_format
            jmp next_hex
         print_first:
            cmp [ebp - 4], dword 1
            je print_first_last
            mov eax, [ebp + 8]
            cmp eax, true
            jne print_out_first_debug
            print_hex [curr_lnk_val], out_format_first
            jmp next_hex
            print_out_first_debug:
               print_debug [curr_lnk_val], out_format_first
               jmp next_hex
            print_first_last:
               mov eax, [ebp + 8]
               cmp eax, true
               jne print_out_first_last_debug
               print_hex [curr_lnk_val], out_format_first_last
               jmp next_hex
               print_out_first_last_debug:
                  print_debug [curr_lnk_val], out_format_first_last
                  jmp next_hex
         print_last:
            mov eax, [ebp + 8]
            cmp eax, true
            jne print_out_last_debug
            print_hex [curr_lnk_val], out_format_last
            jmp next_hex
            print_out_last_debug:
               print_debug [curr_lnk_val], out_format_last
         next_hex:
         mov edi, false
         mov esi, [ebp - 4]
         dec esi
         mov [ebp - 4], esi
         cmp esi, 0
         jne print_number

   end_print:
   mov ebx, [ebp + 8]
   cmp ebx, true
   jne end_print_no_free
   free_list [ebp - 8]     ; free poped list
   end_print_no_free:
   add esp, 8
   popad
   pop ebp; Restore caller state
   ret; Back to caller

pow:
   push ebp
   mov ebp, esp
   pushad

   sub esp, 12
   inc_op_count

   cmp_stack_size 2
   jge no_pow_underflow
   call stack_underflow
   jmp end_pow_no_free

   no_pow_underflow:
      pop_stack
      mov edi, eax
      pop_stack
      mov ebx, eax

      mov [ebp - 4], edi ; X
      mov [ebp - 8], ebx ; Y
      mov [ebp - 16], edi

      ; check Y is less or equal C8 (200 in decimal)
      mov ebx, [ebx + next]
      cmp ebx, dword 0
      jne illegal_pow
      xor edx, edx
      mov ebx, [ebp - 8]
      mov dl, byte [ebx + num]
      xor ebx, ebx
      mov bl, byte 0xC8
      cmp edx, ebx
      jle compute_pow

      illegal_pow:
         ; we add illegal Y value return poped operands to operand stack
         mov ecx, [ebp - 8]
         push_stack ecx
         mov ecx, [ebp - 4]
         push_stack ecx
         call illegal_power
         jmp end_pow_no_free

   compute_pow:
      xor ecx, ecx
      mov edx, [ebp - 8]
      mov cl, [edx + num]
      mov [ebp - 12], dword ecx
      mov edx, [ebp - 4]
      push_stack edx
      cmp cl, byte 0
      je end_pow
      power_loop:
         ; negetive power divides X by 2 Y times
         cmp [ebp + 8], dword false
         jne pos_pow
         call divide_peek_lst_by_2
         xor ecx, ecx
         mov ecx, dword [ebp - 12]
         dec ecx
         mov [ebp - 12], ecx
         cmp ecx, 0
         jne power_loop
         jmp end_pow
         ; duplicates the top of stack and adds two equal numbers Y times to achieve X*2^Y
      pos_pow:
         xor ecx, ecx
         mov ecx, dword false
         push ecx
         call duplicate
         pop ecx
         push ecx
         call addition
         pop ecx
         xor ecx, ecx
         mov ecx, dword [ebp - 12]
         dec ecx
         mov [ebp - 12], ecx
         cmp ecx, 0
         jne power_loop

   end_pow:
   mov eax, [ebp - 8]
   push eax
   call free_list_from_stack
   pop eax

   push dbg_result
   call print_debug_message
   add esp, 4

   end_pow_no_free:
   add esp, 12
   popad
   pop ebp; Restore caller state
   ret; Back to caller

divide_peek_lst_by_2:
   push ebp
   mov ebp, esp
   pushad
   sub esp, 16

   mov [ebp - 12], dword false

   pop_stack
   mov ecx, eax
   mov [ebp - 8], ecx

   xor edx, edx
   ; gets the length of the divided number list
   get_lst_len:
      inc edx
      mov ecx, [ecx + next]
      cmp ecx, dword 0
      jne get_lst_len

   dec edx
   mov [ebp - 4], edx

   divide:
   mov edx, [ebp - 8]
   mov ecx, [ebp - 4]
   cmp ecx, 0
   je found_current
   ; iterates to current link that needs to be divided
   get_to_current:
      mov edx, [edx + next]
      mov [ebp - 16], edx
      loop get_to_current, ecx
      jmp compute_div

   found_current:
      mov [ebp - 16], edx
   compute_div:
      ; if we add remainder from last link divised, add 0x100 to the number and than divide
      xor eax, eax
      mov al, byte [edx + num]
      cmp [ebp - 12], dword true
      jne no_add_remainder
      add eax, 0x100
      mov [ebp - 12], dword false
   no_add_remainder:
      ; divide current link value by 2 and check if had remainder
      xor edx, edx
      mov ecx, 2
      div ecx
      cmp edx, 1
      jne no_remainder
      mov [ebp - 12], dword true
   no_remainder:
      mov edx, [ebp - 16]
      mov [edx + num], byte al
      mov ecx, [ebp - 4]
      dec ecx
      mov [ebp - 4], ecx
      cmp ecx, -1
      jne divide

   finish_divide:
   mov edx, [ebp - 8]
   go_to_last_lnk:
      ; check if last link got zeroed and remove it
      mov [ebp - 4], edx
      mov edx, [edx + next]
      cmp edx, 0
      je finish_no_trim
      cmp [edx + next], dword 0
      jne go_to_last_lnk
   cmp [edx + num], byte 0
   jne finish_no_trim
   push edx
   call free      ; free removed link
   pop edx
   mov edx, [ebp - 4]
   mov [edx + next], dword 0

   finish_no_trim:
      mov ecx, [ebp - 8]
      push_stack ecx
      add esp, 16
      popad
      pop ebp; Restore caller state
      ret; Back to caller


count_one_bit:
   push ebp
   mov ebp, esp
   pushad

   sub esp, 20
   inc_op_count

   cmp_stack_size 0
   jg no_count_underflow
   call stack_underflow
   jmp end_count_no_free

   no_count_underflow:
   mov [ebp - 12], dword 0
   pop_stack         ; pop top of operand stack to count 1 bits in
   mov [ebp - 4], eax
   mov [ebp - 20], eax

   alloc_link        ; alloc first link of the result
   mov ecx, eax
   push_stack ecx
   mov [ebp - 8], ecx

   count_ones_list:
      check_ones:
         xor edx, edx
         xor ecx, ecx
         mov eax, [ebp - 4]
         add cl, byte [eax + num]
         cmp cl, byte 0
         je next_number
         xor eax, eax
         mov al, cl
         mov ebx, dword 2
         div ebx           ; if divided by two with remainder meaning lsb was 1
         cmp edx, 0
         jne increment_ones
         mov cl, al
         mov eax, [ebp - 4]
         mov [eax + num], byte cl
         jmp check_ones
         increment_ones:
            xor edx, edx
            mov edx, dword [ebp - 12]  ; increment local variable storing the 1 bit count
            inc edx
            mov dword [ebp - 12], edx
            mov cl, al
            mov eax, [ebp - 4]
            mov [eax + num], byte cl
            jmp check_ones
         next_number:
            mov eax, [ebp - 4]
            mov eax, [eax + next]
            cmp eax, 0
            je finish_counting
            mov [ebp - 4], eax
            jmp check_ones

   finish_counting:  ; assign to list the result of the count
   xor edx, edx
   mov eax, [ebp - 12]
   mov ecx, 0x100    ; take last 2 numbers to current link value
   div ecx
   mov ecx, [ebp - 8]
   mov [ecx + num], byte dl
   cmp eax, 0
   je finish_count_result
   mov [ebp - 12], eax

   alloc_link        ; allocate current link for result
   mov ecx, [ebp - 8]
   mov [ecx + next], eax
   mov [ebp - 8], eax
   jmp finish_counting

   finish_count_result:
   mov ecx, [ebp - 8]
   mov [ecx + next], dword 0

   push dbg_result
   call print_debug_message
   add esp, 4

   end_count:
   mov eax, [ebp - 20]
   push eax
   call free_list_from_stack
   pop eax

   end_count_no_free:
   add esp, 20
   popad
   pop ebp; Restore caller state
   ret; Back to caller


duplicate:
   push ebp
   mov ebp, esp
   pushad
   sub esp, 8

   mov ebx, [ebp + 8]
   cmp ebx, true
   jne check_legal_duplicate
   inc_op_count

   check_legal_duplicate:
   cmp_stack_size stack_size
   jne check_stack_empty
   call stack_overflow
   jmp done_duplicate

   check_stack_empty:
   cmp_stack_size 0
   jne no_overflow_duplicate
   call stack_underflow
   jmp done_duplicate

   no_overflow_duplicate:
   peek_stack
   mov [ebp - 4], eax        ; store list peeked from stack (top of stack)

   alloc_link                 ; allocate new result first link
   mov ebx, eax
   mov [ebp - 8], ebx
   mov ecx, ebx
   push_stack ecx
   mov ebx, [ebp - 8]

   mov ecx, [ebp - 4]
   mov cl, byte [ecx + num]
   mov [ebx + num], byte cl
   mov ecx, [ebp - 4]
   cmp [ecx + next] , dword 0
   je created_duplicate

   duplicate_loop:         ; copy to result link all values from peeked list
      alloc_link           ; allocate current link for result
      mov ebx, [ebp - 8]
      mov [ebx + next], eax
      mov ebx, eax
      mov [ebp - 8], ebx

      mov ecx, [ebp - 4]
      mov ecx, [ecx + next]
      mov [ebp - 4], ecx

      mov cl, byte [ecx + num]
      mov [ebx + num], byte cl

      mov ecx, [ebp - 4]
      cmp [ecx + next] , dword 0
      jne duplicate_loop

   created_duplicate:
      mov ebx, [ebp - 8]
      mov [ebx + next], dword 0
      mov ebx, [ebp + 8]
      cmp ebx, true
      jne done_duplicate
      push dbg_result
      call print_debug_message
      add esp, 4
   done_duplicate:
      add esp, 8
      popad
      pop ebp; Restore caller state
      ret; Back to caller

quit:
   push ebp
   mov ebp, esp
   pushad

   call free_stack            ; free all current lists stored in stack
   mov [quit_flag], byte true ; assign quit flag with true

   popad
   pop ebp; Restore caller state
   ret; Back to caller

print_debug_message:
   push ebp
   mov ebp, esp
   pushad

   cmp byte [err_flag], true
   je finish_printing_debug

   cmp byte [debug], true
   jne finish_printing_debug

   mov ecx, [ebp + 8]

   print_debug ecx, string_format
   mov eax, dword false
   push eax
   call pop_and_print
   pop eax

   finish_printing_debug:
      popad
      pop ebp; Restore caller state
      ret; Back to caller

; print error messages and assign error flag with true
stack_overflow:
   push ebp
   mov ebp, esp
   print_str err_overflow
   mov byte [err_flag], true
   pop ebp; Restore caller state
   ret; Back to caller

stack_underflow:
   push ebp
   mov ebp, esp
   print_str err_underflow
   mov byte [err_flag], true
   pop ebp; Restore caller state
   ret; Back to caller

illegal_input:
   push ebp
   mov ebp, esp
   print_str err_illegal
   mov byte [err_flag], true
   pop ebp; Restore caller state
   ret; Back to caller

illegal_power:
   push ebp
   mov ebp, esp
   print_str err_pow
   mov byte [err_flag], true
   pop ebp; Restore caller state
   ret; Back to caller

free_list_from_stack:
   push ebp
   mov ebp, esp
   pushad

   mov eax, [ebp + 8]
   mov ebx, [eax + next]

   push eax
   call free
   pop eax

   cmp ebx, dword 0
   jne free_loop
   jmp end_free

   free_loop:  ; free all links from given argument list pointer
      mov eax, ebx
      mov ebx, [eax + next]

      push eax
      call free
      pop eax
      cmp ebx, dword 0
      jne free_loop

   end_free:
   popad
   pop ebp; Restore caller state
   ret; Back to caller

free_stack:
   push ebp
   mov ebp, esp
   pushad

   mov ecx, [curr_stack_size]
   cmp ecx, 0
   je end_free_stack
   dec ecx
   mov [curr_stack_size], ecx
   mov ebx, stack
   free_stack_loop:
      mov eax, [ebx + ecx*4]
      push eax
      call free_list_from_stack     ; call free list from stack for every list currently in stack and is still allocated
      pop eax
      mov ebx, stack
      mov ecx, [curr_stack_size]
      dec ecx
      mov [curr_stack_size], ecx
      cmp ecx, -1
      jne free_stack_loop

   end_free_stack:
   popad
   pop ebp; Restore caller state
   ret; Back to caller
