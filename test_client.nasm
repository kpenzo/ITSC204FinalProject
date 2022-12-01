section .text
global _start

_start:
    push rbp
    mov rbp, rsp

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
    call _network.listen

network:
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
        ; we are stablishing the connection to the socket
        mov rax, 0x31                       ; bind syscall
        mov rdi, qword [socket_fd]          ; sfd
        mov rsi, sockaddr_in                ; sockaddr struct pointer
        mov rdx, sockaddr_in_l              ; address length 
        syscall
        cmp rax, 0x00
        jl _bind_failed
        call _bind_created
        ret

    .listen:
        ; listen
        ; int listen(int sockfd, int backlog);
        mov rax, 0x32                       ; listen syscall
        mov rdi, qword [socket_fd]          ; sfd
        mov rsi, 0x03                       ; maximum backlog of 3 connections
        syscall

        cmp rax, 0x00
        jl _listen_failed
        call _listen_created
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

    .read:
        mov rax, 0x00                       ; read syscall
        mov rdi, qword [read_buffer_fd]     ; read buffer fd
        mov rsi, msg_buf                    ; buffer pointer where message will be saved
        mov rdx, 1024                       ; message buffer size
        syscall
        
        mov qword [chars_received], rax     ; save number of received chars to global
        ret

    .close:
        mov rax, 0x3                        ; close syscall
        mov rdi, qword [read_buffer_fd]     ; read buffer fd
        syscall
        
        cmp rax, 0x0
        jne _network.close.return
        call _socket_closed
        
        .close.return:
            ret

    .shutdown:
        mov rax, 0x30                       ; close syscall
        mov rdi, qword [socket_fd]          ; sfd
        mov rsi, 0x2                        ; shuwdown RW
        syscall
        
        cmp rax, 0x0
        jne _network.shutdown.return
        call _buffer_closed
        .shutdown.return:
            ret

section .data
 sockaddr_in: 
        istruc sockaddr_in_type 

            at sockaddr_in_type.sin_family,  dw 0x02            ;AF_INET -> 2 
            at sockaddr_in_type.sin_port,    dw 0x901F          ;(DEFAULT, passed on stack) port in hex and big endian order, 8080 -> 0x901F
            at sockaddr_in_type.sin_addr,    dd 0xB886EE8C            ;(DEFAULT) 00 -> any address, address 127.0.0.1 -> 0x0100007F

        iend
    sockaddr_in_l: equ $ - sockaddr_in

;*****************************
struc sockaddr_in_type
; defined in man ip(7) because it's dependent on the type of address
    .sin_family:        resw 1
    .sin_port:          resw 1
    .sin_addr:          resd 1
    .sin_zero:          resd 2          ; padding       
endstruc

;*****************************


section .bss

    ; global variables
    peer_address_length:     resd 1             ; when Accept is created, the connecting peer will populate this with the address length
    msg_buf:                 resb 1024          ; message buffer
    random_byte:             resb 1             ; reserve 1 byte
    socket_fd:               resq 1             ; socket file descriptor
    read_buffer_fd           resq 1             ; file descriptor for read buffer
    chars_received           resq 1             ; number of characters received from socket
