section .text
global _start

_start:
    push rbp
    mov rbp, rsp


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
