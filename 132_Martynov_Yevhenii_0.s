.section .note.GNU-stack,"",@progbits

.section .data
    MEMORY_SIZE_KB = 8192
    BLOCK_SIZE_KB = 8
    BLOCK_COUNT = 1024
    MAX_FILES = 255

    MEMORY: .zero BLOCK_COUNT*4
    FILE_IDS: .zero MAX_FILES*4
    FILE_START_BLOCKS: .zero MAX_FILES*4
    FILE_END_BLOCKS: .zero MAX_FILES*4

    fmt_scanf: .asciz "%d"
    fmt_error: .asciz "%d: (0, 0)\n"
    fmt_success: .asciz "%d: (%d, %d)\n"
    fmt_error2: .asciz "(0, 0)\n"
    fmt_get: .asciz "(%d, %d)\n"

.section .text
.global add
.global get
.global delete
.global defragmentation
.global print_memory
.global execute_operations
.global main

add:
    pushl %ebp
    movl %esp, %ebp
    pushl %ebx
    pushl %esi
    pushl %edi

    movl 8(%ebp), %ebx   
    movl 12(%ebp), %ecx 

    movl %ebx, %edi     

    cmp $0, %ebx
    jle invalid_id_add
    cmp $MAX_FILES, %ebx
    jg invalid_id_add

    dec %ebx
    movl FILE_IDS(,%ebx,4), %eax
    cmp $0, %eax
    jne invalid_id_add

    movl %ecx, %eax
    addl $BLOCK_SIZE_KB-1, %eax
    movl $BLOCK_SIZE_KB, %ecx
    xor %edx, %edx
    divl %ecx

    cmp $2, %eax
    jl invalid_id_add

    movl %eax, %esi
    movl $-1, %ecx
    xor %eax, %eax
    xor %edx, %edx

find_space:
    cmp $BLOCK_COUNT, %edx
    jge invalid_id_add
    
    cmpl $0, MEMORY(,%edx,4)
    jne reset_counters

    cmp $-1, %ecx
    jne next_count
    movl %edx, %ecx

next_count:
    incl %eax
    cmp %esi, %eax
    je found_space

    incl %edx
    jmp find_space

reset_counters:
    movl $-1, %ecx
    xor %eax, %eax
    incl %edx
    jmp find_space

found_space:
    # Fill memory blocks
    movl %ecx, %edx
    movl %ecx, %eax
    addl %esi, %eax

fill_loop_add:
    cmp %eax, %edx
    jge fill_done_add

    movl %edi, MEMORY(,%edx,4)
    incl %edx
    jmp fill_loop_add

fill_done_add:
    movl %edi, FILE_IDS(,%ebx,4)
    movl %ecx, FILE_START_BLOCKS(,%ebx,4)
    
    movl %ecx, %eax
    addl %esi, %eax
    decl %eax
    movl %eax, FILE_END_BLOCKS(,%ebx,4)

    pushl FILE_END_BLOCKS(,%ebx,4)
    pushl FILE_START_BLOCKS(,%ebx,4)
    pushl %edi
    pushl $fmt_success
    call printf
    add $16, %esp

    movl $1, %eax
    jmp end_add

invalid_id_add:
    pushl %edi
    pushl $fmt_error
    call printf
    add $8, %esp

    xor %eax, %eax

end_add:
    popl %edi
    popl %esi
    popl %ebx
    movl %ebp, %esp
    popl %ebp
    ret

get:
    pushl %ebp
    movl %esp, %ebp
    
    movl 8(%ebp), %eax
    
    cmp $0, %eax
    jle invalid_id_get
    
    cmp $MAX_FILES, %eax
    jg invalid_id_get
    
    dec %eax
    
    movl FILE_IDS(,%eax,4), %ecx
    cmp $0, %ecx
    je invalid_get
    
    movl FILE_START_BLOCKS(,%eax,4), %edx
    movl FILE_END_BLOCKS(,%eax,4), %ebx
    
    pushl %ebx
    pushl %edx
    pushl $fmt_get
    call printf
    add $12, %esp
    jmp end_get

invalid_id_get:
    pushl %edi
    pushl $fmt_error
    call printf
    add $8, %esp

    xor %eax, %eax

invalid_get:
    pushl $fmt_error2
    call printf
    add $4, %esp

end_get:
    movl %ebp, %esp
    popl %ebp
    ret


delete:
    pushl %ebp
    movl %esp, %ebp
    pushl %ebx
    pushl %esi

    movl 8(%ebp), %eax

    cmp $0, %eax
    jle delete_fail
    
    cmp $MAX_FILES, %eax
    jg delete_fail

    movl %eax, %ebx
    dec %eax

    cmpl $0, FILE_IDS(, %eax, 4)
    je delete_fail

    movl FILE_START_BLOCKS(, %eax, 4), %ecx
    movl FILE_END_BLOCKS(, %eax, 4), %esi

clear_loop_delete:
    cmp %esi, %ecx
    jg end_clear_delete

    movl $0, MEMORY(, %ecx, 4)
    inc %ecx
    jmp clear_loop_delete

end_clear_delete:
    movl $0, FILE_IDS(, %eax, 4)
    movl $0, FILE_START_BLOCKS(, %eax, 4)
    movl $0, FILE_END_BLOCKS(, %eax, 4)

    movl %ebx, %eax
    movl $1, %eax
    jmp end_delete

delete_fail:
    xor %eax, %eax

end_delete:
    popl %esi
    popl %ebx
    movl %ebp, %esp
    popl %ebp
    ret

defragmentation:
    pushl %ebp
    movl %esp, %ebp
    subl $1024, %esp
    pushl %ebx
    pushl %esi
    pushl %edi

    movl $0, -4(%ebp) # fileCount

    xorl %esi, %esi  # i = 0
collect_loop_def:
    cmpl $MAX_FILES, %esi
    jge collect_done_def
    
    movl FILE_IDS(,%esi,4), %eax # FILE_IDS[i] != 0
    testl %eax, %eax
    jz collect_next_def
    
    movl -4(%ebp), %edi  # fileCount
    movl %esi, -1024(%ebp,%edi,4)  # fileIndx[fileCount] = i
    movl FILE_START_BLOCKS(,%esi,4), %eax
    movl %eax, -2048(%ebp,%edi,4)  # fileStarts[fileCount] = FILE_START_BLOCKS[i]
    incl -4(%ebp)            # fileCount++

collect_next_def:
    incl %esi
    jmp collect_loop_def

collect_done_def:
    movl -4(%ebp), %ecx      # fileCount
    decl %ecx                # fileCount - 1
    
    xorl %esi, %esi          # i = 0
sort_outer:
    cmpl %ecx, %esi
    jge sort_done
    
    movl %esi, %edi          # j = i + 1
    incl %edi
sort_inner:
    cmpl -4(%ebp), %edi      # j < fileCount
    jge sort_inner_done
    
    movl -2048(%ebp,%esi,4), %eax  # fileStarts[i]
    cmpl -2048(%ebp,%edi,4), %eax
    jle sort_next
    
    movl -1024(%ebp,%esi,4), %eax  # fileIndx[i]
    movl -1024(%ebp,%edi,4), %ebx  # fileIndx[j]
    movl %ebx, -1024(%ebp,%esi,4)
    movl %eax, -1024(%ebp,%edi,4)
    
    movl -2048(%ebp,%esi,4), %eax  # fileStarts[i]
    movl -2048(%ebp,%edi,4), %ebx  # fileStarts[j]
    movl %ebx, -2048(%ebp,%esi,4)
    movl %eax, -2048(%ebp,%edi,4)

sort_next:
    incl %edi
    jmp sort_inner

sort_inner_done:
    incl %esi
    jmp sort_outer

sort_done:
    xorl %edi, %edi          
    xorl %esi, %esi    
   
defrag_loop:
    cmpl -4(%ebp), %esi
    jge defrag_done
    
    movl -1024(%ebp,%esi,4), %ebx
    
    movl FILE_END_BLOCKS(,%ebx,4), %eax
    subl FILE_START_BLOCKS(,%ebx,4), %eax
    incl %eax

    xorl %ecx, %ecx

move_blocks:
    cmpl %eax, %ecx
    jge move_done
    
    movl FILE_IDS(,%ebx,4), %edx
    movl %edx, MEMORY(,%edi,4)
    
    incl %edi
    incl %ecx
    jmp move_blocks

move_done:
    movl %edi, %edx
    subl %eax, %edx          # writeIdx - blocksNeeded
    movl %edx, FILE_START_BLOCKS(,%ebx,4)
    decl %edi
    movl %edi, FILE_END_BLOCKS(,%ebx,4)
    incl %edi
    
    incl %esi
    jmp defrag_loop

defrag_done:
clear_loop_def:
    cmpl $BLOCK_COUNT, %edi
    jge end_defragmentation
    
    movl $0, MEMORY(,%edi,4)
    incl %edi
    jmp clear_loop_def

end_defragmentation:
    popl %edi
    popl %esi
    popl %ebx
    movl %ebp, %esp
    popl %ebp
    ret

print_memory:
    pushl %ebp
    movl %esp, %ebp
    pushl %ebx
    pushl %ecx
    pushl %edx

    xor %ebx, %ebx

print_loop:
    cmp $BLOCK_COUNT, %ebx
    jge end_print

    movl MEMORY(, %ebx, 4), %eax
    cmp $0, %eax
    je skip_print

    movl %eax, %ecx
    dec %ecx
    movl FILE_START_BLOCKS(, %ecx, 4), %edx
    cmp %ebx, %edx
    jne skip_print

    pushl FILE_END_BLOCKS(, %ecx, 4)
    pushl FILE_START_BLOCKS(, %ecx, 4)
    incl %ecx
    pushl %ecx
    pushl $fmt_success
    call printf
    add $16, %esp

skip_print:
    incl %ebx
    jmp print_loop

end_print:
    popl %edx
    popl %ecx
    popl %ebx
    movl %ebp, %esp
    popl %ebp
    ret

execute_operations:
    pushl %ebp
    movl %esp, %ebp
    subl $8, %esp

    leal -4(%ebp), %eax
    pushl %eax
    pushl $fmt_scanf
    call scanf
    addl $8, %esp

    movl $0, -8(%ebp)    # i = 0

operations_loop:
    movl -8(%ebp), %eax
    cmpl -4(%ebp), %eax
    jge operations_end

    subl $4, %esp
    leal -12(%ebp), %eax
    pushl %eax
    pushl $fmt_scanf
    call scanf
    addl $8, %esp

    movl -12(%ebp), %eax
    cmpl $1, %eax
    je handle_add
    cmpl $2, %eax
    je handle_get
    cmpl $3, %eax
    je handle_delete
    cmpl $4, %eax
    je handle_defrag
    jmp continue_loop

handle_add:
    subl $4, %esp
    leal -16(%ebp), %eax
    pushl %eax
    pushl $fmt_scanf
    call scanf
    addl $8, %esp

    movl $0, -20(%ebp)   # j = 0
add_loop:
    movl -20(%ebp), %eax
    cmpl -16(%ebp), %eax
    jge continue_loop

    subl $8, %esp
    leal -24(%ebp), %eax  # fileId
    pushl %eax
    pushl $fmt_scanf
    call scanf
    addl $8, %esp

    leal -28(%ebp), %eax  # fileSize
    pushl %eax
    pushl $fmt_scanf
    call scanf
    addl $8, %esp

    pushl -28(%ebp)      # fileSize
    pushl -24(%ebp)      # fileId
    call add
    addl $8, %esp

    incl -20(%ebp)       # j++
    jmp add_loop

handle_get:
    sub $4, %esp
    leal -16(%ebp), %eax
    pushl %eax
    pushl $fmt_scanf
    call scanf
    addl $8, %esp

    pushl -16(%ebp)
    call get
    addl $4, %esp

    jmp continue_loop

handle_delete:
    subl $4, %esp
    lea -16(%ebp), %eax
    pushl %eax
    pushl $fmt_scanf
    call scanf
    addl $8, %esp

    pushl -16(%ebp)
    call delete
    addl $4, %esp

    call print_memory
    jmp continue_loop

handle_defrag:
    call defragmentation
    call print_memory
    jmp continue_loop

continue_loop:
    incl -8(%ebp)        # i++
    jmp operations_loop

operations_end:
    movl %ebp, %esp
    popl %ebp
    ret

main:
    pushl %ebp
    movl %esp, %ebp

    call execute_operations

    pushl $0
    call fflush
    popl %eax

    movl $1, %eax
    movl $0, %ebx
    int $0x80
