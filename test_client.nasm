SIGPIPE equ 0xD
SIG_IGN equ 0x1
NULL    equ 0x0

;*****************************
struc sockaddr_in_type
; defined in man ip(7) because it's dependent on the type of address
    .sin_family:        resw 1
    .sin_port:          resw 1
    .sin_addr:          resd 1
    .sin_zero:          resd 2          ; padding       
endstruc

;*****************************

section .text
global _start

_start:
    push rbp
    mov rbp, rsp

    mov qword [client_live], 0x0

 ; set the SIGPIPE signal to ignore
    mov rdi, rsp
    push SIG_IGN        ; new action -> SIG_IGN 
    mov rsi, rsp        ; pointer to action struct
    mov edx, NULL       ; old action -> NULL
    mov edi, SIGPIPE    ; SIGPIPE    
    mov rax, 0xD        ; rt_sigaction syscall
    mov r10, 0x8        ; size of struc (8 bytes)
    syscall

    add rsp, 0x8        ; restore stack

    call _network.init
    ;jmp _exit
    call _network.connect

    .retry:
        call _network.accept

         ; write Hello message to socket
        push qword [read_buffer_fd] ; get the fd global variable into local variable 
        push hello_msg_l
        push hello_msg
        call _write_text_to_socket

        jmp _exit


_network:
    .init:
        ; socket, based on IF_INET to get tcp
        mov rax, 0x29                       ; socket syscall
        mov rdi, 0x02                       ; int domain - AF_INET = 2, AF_LOCAL = 1
        mov rsi, 0x01                       ; int type - SOCK_STREAM = 1
        mov rdx, 0x00                       ; int protocol is 0
        syscall     
        cmp rax, 0x00
        jl _socket_failed                   ; jump if negative
        mov [socket_fd], rax                 ; save the socket fd to basepointer
        call _socket_created

        ; bind, use sockaddr_in struct
        ;       int bind(int sockfd, const struct sockaddr *addr,
        ;            socklen_t addrlen);
        mov rax, 0x31                       ; bind syscall
        mov rdi, qword [socket_fd]          ; sfd
        mov rsi, sockaddr_in                ; sockaddr struct pointer
        mov rdx, sockaddr_in_l              ; address length 
        syscall
        cmp rax, 0x00
        jl _bind_failed                     ; bind failed 
        call _bind_created                  ; bind created
        ret

    .accept:
        ; accept
        ;        int accept(int sockfd, struct sockaddr *restrict addr,
        ;              socklen_t *restrict addrlen);
        mov rax, 0x2B                       ; accept syscall
        mov rdi, qword [socket_fd]          ; sfd
        mov rsi, sockaddr_in                ; sockaddr struc pointer
        mov rdx, peer_address_length        ; populated with peer address length
        syscall

        mov qword [read_buffer_fd], rax     ; save new fd of buffer
        mov qword [client_live], 0x1                ; set client connection flag to 1
        ret

    .connect:
        mov rax, 0x2a
        mov rdi, qword [socket_fd]
        mov rsi, sockaddr_in
        mov rdx, sockaddr_in_l
        syscall
        cmp rax, 0x00
        jl _connection_failed
        call _connection_created
        ret

        

_print:
    ; prologue
    push rbp
    mov rbp, rsp
    push rdi
    push rsi

    ; [rbp + 0x10] -> buffer pointer
    ; [rbp + 0x18] -> buffer length
    
    mov rax, 0x1
    mov rdi, 0x1
    mov rsi, [rbp + 0x10]
    mov rdx, [rbp + 0x18]
    syscall

    ; epilogue
    pop rsi
    pop rdi
    pop rbp
    ret 0x10    

_write_text_to_socket:        
    ; prologue
    push rbp
    mov rbp, rsp
    push rdi
    push rsi

    ; [rbp + 0x10] -> buffer pointer
    ; [rbp + 0x18] -> buffer length
    ; [rbp + 0x20] -> fd of the socket

    mov rax, 0x1
    mov rdi, [rbp + 0x20]
    mov rsi, [rbp + 0x10]
    mov rdx, [rbp + 0x18]
    syscall
    cmp rax, 0x0
    jge .end_fun
    call _client_conn_handler

    .end_fun:
    ; epilogue
    pop rsi
    pop rdi
    pop rbp
    ret 0x18                                ; clean up the stack upon return - not strictly following C Calling Convention    
  

_socket_failed:
    ; print socket failed
    push socket_f_msg_l
    push socket_f_msg
    call _print
    jmp _exit

_socket_created:
    ; print socket created
    push socket_t_msg_l
    push socket_t_msg
    call _print
    ret

_bind_failed:
    ; print bind failed
    push bind_f_msg_l
    push bind_f_msg
    call _print
    jmp _exit

_bind_created:
    ; print bind created
    push bind_t_msg_l
    push bind_t_msg
    call _print
    ret

_connection_failed:
    push connection_f_msg_l
    push connection_f_msg
    call _print
    jmp _exit

_connection_created:
    push connection_t_msg_l
    push connection_t_msg
    call _print
    jmp _exit

_client_conn_handler:
    mov qword [client_live], 0x00
    ret

_exit:
    ;call _network.close
    ;call _network.shutdown

    mov rax, 0x3C       ; sys_exit
    mov rdi, 0x00       ; return code  
    syscall



section .data

    socket_f_msg:   db "Socket failed to be created.", 0xA, 0x0
    socket_f_msg_l: equ $ - socket_f_msg

    socket_t_msg:   db "Socket created.", 0xA, 0x0
    socket_t_msg_l: equ $ - socket_t_msg

    bind_f_msg:   db "Socket failed to bind.", 0xA, 0x0
    bind_f_msg_l: equ $ - bind_f_msg

    bind_t_msg:   db "Socket bound.", 0xA, 0x0
    bind_t_msg_l: equ $ - bind_t_msg

    hello_msg:   db "Welcome.", 0xA, 0x00
    hello_msg_l: equ $ - hello_msg

    connection_t_msg:  db "Connection created.", 0xA, 0x0
    connection_t_msg_l:  equ $ - connection_t_msg

    connection_f_msg:  db "Connection failed.", 0xA, 0x0
    connection_f_msg_l:  equ $ - connection_f_msg




 sockaddr_in: 
        istruc sockaddr_in_type 

            at sockaddr_in_type.sin_family,  dw 0x02            ;AF_INET -> 2 
            at sockaddr_in_type.sin_port,    dw 0x27D9          ;(DEFAULT, passed on stack) port in hex and big endian order, 8080 -> 0x901F
            at sockaddr_in_type.sin_addr,    dd 0xB886EE8C      ;(DEFAULT) 00 -> any address, address 127.0.0.1 -> 0x0100007F

        iend
    sockaddr_in_l: equ $ - sockaddr_in




section .bss

    ; global variables
    peer_address_length:     resd 1             ; when Accept is created, the connecting peer will populate this with the address length
    msg_buf:                 resb 1024          ; message buffer
    random_byte:             resb 1             ; reserve 1 byte
    socket_fd:               resq 1             ; socket file descriptor
    read_buffer_fd           resq 1             ; file descriptor for read buffer
    chars_received           resq 1             ; number of characters received from socket
    client_live              resq 1             ; T/F is client connected