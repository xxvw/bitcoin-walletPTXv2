.section .text
.global generate_seed_asm

# シード生成のアセンブリ実装
generate_seed_asm:
    # レジスタの保存
    push %rbp
    mov %rsp, %rbp
    push %rbx
    push %r12
    push %r13
    push %r14
    push %r15

    # パラメータの設定
    mov %rdi, %r12      # current_seed
    mov %rsi, %r13      # wordlist
    mov %rdx, %r14      # wordlist_size
    mov %rcx, %r15      # idx

    # 並列処理用の組み合わせ生成
    mov %r15, %rax      # idxをraxにコピー
    xor %rdx, %rdx      # rdxをクリア
    div %r14            # idx / wordlist_size
    mov %rdx, %rbx      # 余りをrbxに保存

    # SIMD
    movdqu (%r13, %rbx, 8), %xmm0  # 単語をxmm0に読み込み
    movdqu %xmm0, (%r12)           # current_seedにコピー

    # スペースの追加
    movb $' ', 8(%r12)

    # 次の単語の処理
    mov %rax, %rbx      # 商をrbxにコピー
    xor %rdx, %rdx      # rdxをクリア
    div %r14            # 商 / wordlist_size
    mov %rdx, %rbx      # 余りをrbxに保存

    # 2番目の単語のコピー
    movdqu (%r13, %rbx, 8), %xmm0
    movdqu %xmm0, 9(%r12)

    # レジスタの復元
    pop %r15
    pop %r14
    pop %r13
    pop %r12
    pop %rbx
    pop %rbp
    ret 