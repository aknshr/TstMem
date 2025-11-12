[Org 0x7C00]

jmp 0x0000:Inicio

Inicio:
  xor ax, ax
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax

  ;Copia os 16 primeiros setores do disco para a mem�ria
  mov ax, 0x0210
  mov bx, 0x7C00
  mov cx, 0x0001
  xor dh, dh
  int 0x13

  ;Move o cursor para a posi��o 80,25
  mov ah, 0x02
  xor bh, bh
  mov dx, 0x2050
  int 0x10

  ;Desliga o motor do drive
  xor al, al
  mov dx, 0x03F2
  out dx, al

  ;Habilita o Gate A20
  mov al, 0xD0
  out 0x64, al
  in  al, 0x60
  mov bl, al
  or  bl, 0x02

  mov al, 0xD1
  out 0x64, al
  mov al, bl
  out 0x60, al

  cli

  ;Configura o processador para trabalhar no Modo Protegido de 32 bits
  LGDT [GDTR]
  LIDT [IDTR]
  mov eax, CR0
  or  al, 0x01
  mov CR0, eax
  jmp SelCod:MP32

times (505 - ($ - Inicio)) db 0x00
dw 0xAA55

  [Bits 32]
  MP32:

  invd

  mov ax, SelLin
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax

  sti

  ;Prepara a Tela
  call LmpTela

  mov ax, PosMsgT
  mov cl, CorT
  mov esi, MsgT
  call ImprMsg

  ;Configura o Timer do Sistema
  mov al, 0xFF - 0x03
  out 0x21, al

  ;Calcula o desempenho da mem�ria (em conjunto com a Int 08h)
  mov esi, EndInic
  xor ecx, ecx
  Desemp:
    inc ecx

    cmp byte [TRC], 0x00
  ja Desemp

  ;Finaliza o Timer de Sistema e Habilita o Teclado
  Desemp_C1:
  mov al, 0xFF - 0x02
  out 0x21, al

  ReInicDet:
    ;Detecta a quantidade de mem�ria RAM instalada
    mov esi, EndInic
    Det:
      add esi, TamBlc

      mov eax, [esi]
      not eax
      mov [esi], eax
      mov ebx, [esi]

      cmp eax, ebx
    je Det

    add esi, [Mnl]
    mov [Tot], esi

    mov eax, esi
    shr eax, 20
    mov cl, 4
    mov edi, QntM
    call ConvDec

    mov ax, PosMsgM
    mov cl, CorM
    mov esi, MsgM
    call ImprMsg
  C_ReInicDet:

  ;Prepara a �rea de informa��es de blocos
  mov ecx, [Tot]
  shr ecx, 20
  xor eax, eax
  mov edi, EndTBD
  cld
  rep stosd

  ReInic:
    xor al, al
    mov [Rnc], al
    mov [AmoAtl], al
  Ciclo:

  ;Exibe a barra de progresso geral
  mov ax, PosMsgB1
  mov cl, CorM
  mov esi, MsgB1
  call ImprMsg

  movzx eax, byte [AmoAtl]
  xor edx, edx
  mov ebx, 100
  mul ebx
  mov ebx, NumAmo
  div ebx
  mov cl, al
  mov ax, PosBarB1
  call DesBar

  ;Seleciona a pr�xima amostra
  movzx esi, byte [AmoAtl]
  shl esi, 2
  add esi, Amos
  mov eax, [esi]
  mov [Amo], eax
  inc byte [AmoAtl]
  cmp byte [AmoAtl], NumAmo
  jbe Ciclo_C1
    jmp Fim
  Ciclo_C1:

  ;Prepara para a exibi��o dos gr�ficos
  mov ax, PosMsgGF
  mov cl, CorM
  mov esi, MsgGF
  call ImprMsg
  xor dx, dx
  mov ax, PosGF
  mov cl, CorGB
  call DesGrf

  mov ax, PosMsgB2
  mov cl, CorM
  mov esi, MsgB2
  call ImprMsg
  mov ax, PosMsgB4
  mov esi, MsgB4
  call ImprMsg

  xor cl, cl
  mov ax, PosBarB2
  call DesBar
  mov ax, PosBarB4
  call DesBar

  ;Grava dados na mem�ria
  mov dword [End], EndInic
  Grv:
    mov edx, [End]
    test edx, (TamBlc - 1)
    jnz Grv_C0
      shr edx, 20

      mov esi, edx
      shl esi, 2
      add esi, EndTBD

      cmp dword [esi], 0x00000000
      je Grv_C00a
        mov cl, CorGD
      jmp Grv_C00b
      Grv_C00a:
        mov cl, CorGF
      Grv_C00b:

      mov ax, PosGF
      call DesGrf

      mov eax, [End]
      xor edx, edx
      mov ebx, 100
      mul ebx
      mov ebx, [Tot]
      div ebx
      cmp al, [Pct]
      je Grv_C01
        mov [Pct], al

        mov cl, al
        mov ax, PosBarB2
        call DesBar
      Grv_C01:
    Grv_C0:

    mov esi, [End]
    mov eax, [Amo]
    not eax
    mov [esi] ,eax
    not eax
    mov [esi], eax

    add dword [End], 0x00000004
    mov eax, [End]
    cmp eax, [Tot]
  jb Grv

  ;Verifica se os dados gravados s�o lidos corretamente
  mov ax, PosMsgB3
  mov cl, CorM
  mov esi, MsgB3
  call ImprMsg
  xor cl, cl
  mov ax, PosBarB3
  call DesBar

  mov dword [End], EndInic
  Vrf:
    mov eax, [End]
    and eax, (TamBlc - 1)
    jz Vrf_C0
      jmp Vrf_C1
    Vrf_C0:
      cmp dword [Def], 0x00000000
      je Vrf_C00
        mov esi, [End]
        shr esi, 20
        dec esi
        shl esi, 2
        add esi, EndTBD
        mov eax, [Def]
        cmp eax, [esi]
        jbe Vrf_C000
          mov [esi], eax

          mov ecx, [Tot]
          shr ecx, 20
          xor edx, edx
          mov esi, EndTBD
          cld
          Vrf_L0000:
            lodsd
            add edx, eax
          loop Vrf_L0000

          mov eax, edx
          mov cl, 10
          mov edi, DefB
          call ConvDec
          shr eax, 10
          mov cl, 7
          mov edi, DefK
          call ConvDec
          shr eax, 10
          mov cl, 4
          mov edi, DefM
          call ConvDec

          mov ax, PosEst
          mov cl, CorED
          mov esi, MsgD
          call ImprMsg
        Vrf_C000:

        mov dword [Def], 0x00000000
      Vrf_C00:

      mov edx, [End]
      shr edx, 20
      mov ax, PosGF

      mov ebx, [End]
      cmp ebx, [Tot]
      jae Vrf_C01
        mov cl, CorGV
        call DesGrf
      Vrf_C01:

      dec edx
      mov esi, edx
      shl esi, 2
      add esi, EndTBD
      cmp dword [esi], 0x00000000
      je Vrf_C02a
        mov cl, CorGD
        mov byte [BD], 0xFF
      jmp Vrf_C02b
      Vrf_C02a:
        mov cl, CorGB
      Vrf_C02b:
      call DesGrf

      mov eax, [End]
      xor edx, edx
      mov ebx, 100
      mul ebx
      mov ebx, [Tot]
      div ebx
      mov cl, al
      mov ax, PosBarB3
      call DesBar
    Vrf_C1:

    cmp byte [Rnc], 0xFF
    jne Vrf_C2a
      jmp ReInic
    Vrf_C2a:

    cmp byte [Rnc], 0xFE
    jne Vrf_C2b
      jmp ReInicDet
    Vrf_C2b:

    mov eax, [End]
    and eax, (TamBlc - 1)
    jnz Vrf_C3
      mov eax, TamBlc
    Vrf_C3:
    xor edx, edx
    mov ebx, 100
    mul ebx
    mov ebx, TamBlc
    div ebx
    cmp al, [Pct]
    je Vrf_C4
      mov [Pct], al
      mov cl, al
      mov ax, PosBarB4
      call DesBar
    Vrf_C4:

    mov eax, [Amo]
    mov esi, [End]
    cmp esi, [Tot]
    jb Vrf_C5
      jmp Ciclo
    Vrf_C5:

    wbinvd
    cmp [esi], eax
    je VrfBlc_C6
      not eax
      mov [esi], eax
      add dword [Def], 0x00000004
    VrfBlc_C6:

    add dword [End], 0x00000004
  jmp Vrf

  Fim:
  ;Finaliza o programa
  mov ax, PosFim
  mov cl, CorF
  mov esi, MsgC
  call ImprMsg

  mov ax, PosEst
  cmp byte [BD], 0x00
  jne Vrf_C4a
    mov cl, CorFN
    mov esi, MsgN
  jmp Vrf_C4b
  Vrf_C4a:
    mov cl, CorFD
    mov esi, MsgD
  Vrf_C4b:
  call ImprMsg

Infn:
  cmp byte [Rnc], 0xFF
  jne Infn
jmp ReInic

;Vari�veis/Constantes
MsgT db ' --- Teste de Memoria RAM v2.0 --- Andre Kanashiro -- 09.07.2002-14.11.2006 --- ', 0x00

MsgM db 'Quantidade de memoria detectada: '
QntM db '0000', ' MB, desempenho: '
QntT db '0000', ' MB/s', 0x00

MsgB1 db '      Total: ', 0x00
BarB1 equ $ - MsgB1 - 1

MsgB2 db '   Gravando: ', 0x00
BarB2 equ $ - MsgB2 - 1

MsgB3 db 'Verificando: ', 0x00
BarB3 equ $ - MsgB3 - 1

MsgB4 db 'Bloco Atual: ', 0x00
BarB4 equ $ - MsgB4 - 1

MsgP db '('
PctP db '000', '%)', 0x00

MsgGF db 'Grafico (blocos de 16x1 MB): ', 0x00

MsgC db 'Concluido.', 0x00

MsgN db 'Nenhum problema foi encontrado.', 0x00

MsgD db 'Foram encontrados '
DefB db '0000000000', ' bytes ('
DefK db '0000000', 'kb, '
DefM db '0000', 'mb)'
     db ' em areas defeituosas...', 0x00

Digs db '0123456789ABCDEF'
CarBP equ 0xB1
EndInic equ 0x00100000

Rnc db 0x00
Dsp db 0x00
Dsl dd 0x00000000
End dd 0x00000000
Tot dd 0x00000000
Def dd 0x00000000
Mnl dd 0x00000000
Pct db 0xFF
BD db 0x00
TRA db 18
TRM db 18
TRC db 5

Amo dd 0x00000000
AmoAtl db 0x00
Amos:
  dd 0x55555555
  dd 0xAAAAAAAA

  dd 0x00000000
  dd 0xFFFFFFFF

  dd 0x0F0F0F0F
  dd 0xF0F0F0F0

  dd 0x5A5A5A5A
  dd 0xA5A5A5A5

  dd 0x05050505
  dd 0xA0A0A0A0

  dd 0x0A0A0A0A
  dd 0x50505050

  dd 0x55555555
  dd 0xAAAAAAAA

  dd 0x00000000
  dd 0xFFFFFFFF
NumAmo equ ($ - Amos) / 4

TamBlc equ 0x00100000
EndTBD equ 0x00080000

PosMsgT equ 0x0000
PosMsgM equ 0x0001
PosMsgB1 equ 0x0002
PosMsgB2 equ 0x0003
PosMsgB3 equ 0x0003
PosMsgB4 equ 0x0004
PosBarB1 equ (BarB1 * 0x0100) + 0x02
PosBarB2 equ (BarB2 * 0x0100) + 0x03
PosBarB3 equ (BarB3 * 0x0100) + 0x03
PosBarB4 equ (BarB4 * 0x0100) + 0x04
PosFim equ 0x0005
PosEst equ 0x0006
PosMsgGF equ 0x0007
PosGF equ 0x0008

CorT equ 0x09
CorM equ 0x08
CorEN equ 0x02
CorED equ 0x04
CorBF equ 0x08
CorBB equ 0x09
CorGF equ 0x08
CorGV equ 0x09
CorGB equ 0x02
CorGD equ 0x04
CorF equ 0x08
CorFN equ 0x82
CorFD equ 0x84

;Fun��es
LmpTela:
  pushf
  pusha

  cld
  mov edi, 0x000B8000
  xor ax, ax
  mov ecx, 80*25
  rep stosw

  popa
  popf
ret

ImprMsg:
  ;entrada:
  ;  ah -> X
  ;  al -> Y
  ;  cl -> Cor
  ;  ds:esi -> Mensagem

  pushfd
  pushad

  mov bx, ax
  xor ah, ah
  mov bl, 80
  mul bl
  shr bx, 8
  add ax, bx
  shl ax, 1

  cld
  xor dl, dl
  mov edi, 0x000B8000
  add di, ax
  IM_L0:
    lodsb

    cmp al, 0xFF
    jne IM_L0_C0
      inc dl
      jmp IM_L0
    IM_L0_C0:

    cmp al, 0x00
    je IM_C0

    stosb
    mov al, cl
    stosb
  jmp IM_L0
  IM_C0:

  cmp dl, 0x00
  je IM_C1
    IM_L1:
      mov al, 32
      stosb
      mov al, cl
      stosb

      dec dl
    jnz IM_L1
  IM_C1:

  popad
  popfd
ret

DesGrf:
  ;entrada:
  ;  ah -> X
  ;  al -> Y
  ;  cl -> Cor
  ;  dx -> Deslocamento

  pushad

  mov ch, ah
  xor ah, ah
  mov bl, 80
  mul bl
  movzx bx, ch
  add ax, bx
  add ax, dx
  add ax, 2

  mov bx, dx
  shr bx, 0x0004
  shl bx, 2
  add ax, bx

  mov edi, 0x000B8000
  shl ax, 1
  add di, ax

  mov ah, cl
  mov al, CarBP
  mov [edi], ax

  popad
ret

DesBar:
  ;entrada:
  ;  ah -> X
  ;  al -> Y
  ;  cl -> Porcentagem

  pushfd
  pushad

  push cx
  push eax
  xor eax, eax
  mov al, cl
  mov cl, 3
  mov edi, PctP
  call ConvDec
  pop eax
  push eax
  add ah, 50
  mov cl, CorM
  mov esi, MsgP
  call ImprMsg
  pop eax
  pop cx

  mov bx, ax
  xor ah, ah
  mov bl, 80
  mul bl
  shr bx, 8
  add ax, bx
  shl ax, 1

  std
  mov edi, 0x000B8000
  add di, ax
  add edi, 100 - 2

  xor eax, eax
  mov al, cl
  shr al, 1
  mov bl, al

  mov ecx, 50
  DB_L0:
    mov al, CarBP
    stosb

    cmp cl, bl
    ja DB_L0_C0a
      mov al, CorBB
    jmp DB_L0_C0b
    DB_L0_C0a:
      mov al, CorBF
    DB_L0_C0b:
    stosb
  loop DB_L0

  popad
  popfd
ret

ConvDec:
  ;entrada:
  ;  eax    -> Numero
  ;  cl     -> Digitos
  ;  ds:edi -> Destino

  pushfd
  pushad

  and ecx, 0x000000FF
  add edi, ecx
  dec edi
  std

  cmp eax, 0x00000000
  jne CD_C0a
    mov esi, Digs
    movsb
    dec ecx

    CD_L0:
      mov al, 0xFF
      stosb
    loop CD_L0
  jmp CD_C0b
  CD_C0a:
    CD_L1:
      cmp eax, 0x00000000
      je CD_L0_C1a
        xor edx, edx
        mov ebx, 10
        div ebx

        mov esi, Digs
        add esi, edx
        movsb
      jmp CD_L0_C1b
      CD_L0_C1a:
        push eax
        mov al, 0xFF
        stosb
        pop eax
      CD_L0_C1b:
    loop CD_L1
  CD_C0b:

  popad
  popfd
ret

IntInut:
  push eax

  mov al, 0x20
  out 0x20, al

  pop eax
iret

Int0x08:
  push eax
  push esi
  push edi

  dec byte [TRA]
  jnz Int0x08_C0
    mov al, [TRM]
    mov [TRA], al

    mov eax, ecx
    shr eax, 20 - 2
    mov cl, 4
    mov edi, QntT
    call ConvDec

    mov ax, PosMsgM
    mov cl, CorM
    mov esi, MsgM
    call ImprMsg

    xor ecx, ecx
    cmp byte [Dsp], 0xFF
    je Int0x08_C00
      dec byte [TRC]
    Int0x08_C00:
  Int0x08_C0:

  mov al, 0x20
  out 0x20, al

  pop edi
  pop esi
  pop eax
iret

Int0x09:
  pushad

  in al, 0x60

  cmp al, 01
  jne Int0x09_C0
    jmp 0x000FFFF0
  Int0x09_C0:

  cmp al, 67
  jne Int0x09_C1
    add dword [Mnl], TamBlc
    mov byte [Rnc], 0xFE
    not byte [Dsp]
  Int0x09_C1:

  cmp al, 68
  jne Int0x09_C2
    mov byte [Rnc], 0xFF
    not byte [Dsp]
  Int0x09_C2:

  mov al, 0x20
  out 0x20, al

  popad
iret

;Tabela de Descritores Globais
GDTR:
  dw FTDG - ITDG ;limite
  dd ITDG        ;base
ITDG:
  dw 0x0000 ;limite 15:00
  dw 0x0000 ;base 15:00
  db 0x00   ;base 23:16
  db 0x00   ;atributos
  db 0x00   ;limite 19:16/atributos
  db 0x00   ;base 31:24

  SelCod equ $ - ITDG
  dw 0xFFFF ;limite 15:00
  dw 0x0000 ;base 15:00
  db 0x00   ;base 23:16
  db 0x9A   ;atributos
  db 0xCF   ;limite 19:16/atributos
  db 0x00   ;base 31:24

  SelLin equ $ - ITDG
  dw 0xFFFF ;limite 15:00
  dw 0x0000 ;base 15:00
  db 0x00   ;base 23:16
  db 0x92   ;atributos
  db 0xCF   ;limite 19:16/atributos
  db 0x00   ;base 31:24
FTDG:

;Tabela de Interrup��es
IDTR:
  dw FTDI - ITDI ;limite
  dd ITDI        ;base
ITDI:
  ;Int 0x00
  dw IntInut ;deslocamento 15:00
  dw SelCod  ;seletor
  db 0x00    ;reservado
  db 0x8E    ;atributos
  dw 0x0000  ;deslocamento 31:16

  ;Int 0x01
  dw IntInut ;deslocamento 15:00
  dw SelCod  ;seletor
  db 0x00    ;reservado
  db 0x8E    ;atributos
  dw 0x0000  ;deslocamento 31:16

  ;Int 0x02
  dw IntInut ;deslocamento 15:00
  dw SelCod  ;seletor
  db 0x00    ;reservado
  db 0x8E    ;atributos
  dw 0x0000  ;deslocamento 31:16

  ;Int 0x03
  dw IntInut ;deslocamento 15:00
  dw SelCod  ;seletor
  db 0x00    ;reservado
  db 0x8E    ;atributos
  dw 0x0000  ;deslocamento 31:16

  ;Int 0x04
  dw IntInut ;deslocamento 15:00
  dw SelCod  ;seletor
  db 0x00    ;reservado
  db 0x8E    ;atributos
  dw 0x0000  ;deslocamento 31:16

  ;Int 0x05
  dw IntInut ;deslocamento 15:00
  dw SelCod  ;seletor
  db 0x00    ;reservado
  db 0x8E    ;atributos
  dw 0x0000  ;deslocamento 31:16

  ;Int 0x06
  dw IntInut ;deslocamento 15:00
  dw SelCod  ;seletor
  db 0x00    ;reservado
  db 0x8E    ;atributos
  dw 0x0000  ;deslocamento 31:16

  ;Int 0x07
  dw IntInut ;deslocamento 15:00
  dw SelCod  ;seletor
  db 0x00    ;reservado
  db 0x8E    ;atributos
  dw 0x0000  ;deslocamento 31:16

  ;Int 0x08
  dw Int0x08 ;deslocamento 15:00
  dw SelCod  ;seletor
  db 0x00    ;reservado
  db 0x8E    ;atributos
  dw 0x0000  ;deslocamento 31:16

  ;Int 0x09
  dw Int0x09 ;deslocamento 15:00
  dw SelCod  ;seletor
  db 0x00    ;reservado
  db 0x8E    ;atributos
  dw 0x0000  ;deslocamento 31:16
FTDI:

;Padding para VFD de 720KB
times ((737280 - 5) - ($ - Inicio)) db 0x00
