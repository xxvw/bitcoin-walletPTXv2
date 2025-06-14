.section .text
.global fast_strcmp
.global bruteforce_loop

# 高速な文字列比較関数
fast_strcmp:
    push %rbp
    mov %rsp, %rbp
    mov %rdi, %rsi    # 第1引数
    mov %rsi, %rdi    # 第2引数
    
    # SIMD 比較
    movdqu (%rsi), %xmm0
    movdqu (%rdi), %xmm1
    pcmpeqb %xmm0, %xmm1
    pmovmskb %xmm1, %eax
    cmp $0xFFFF, %ax
    je .equal
    
    # フォールバック
    .compare_loop:
        movb (%rsi), %al
        movb (%rdi), %cl
        cmp %cl, %al
        jne .not_equal
        test %al, %al
        jz .equal
        inc %rsi
        inc %rdi
        jmp .compare_loop
    
    .equal:
        xor %eax, %eax
        jmp .done
    
    .not_equal:
        mov $1, %eax
    
    .done:
        pop %rbp
        ret

# forの最適化実装
bruteforce_loop:
    push %rbp
    mov %rsp, %rbp
    
    # レジスタの保存
    push %rbx
    push %r12
    push %r13
    push %r14
    push %r15
    
    # パラメータの取得
    mov %rdi, %r12    # 現在のシード
    mov %rsi, %r13    # 単語リスト
    mov %rdx, %r14    # 単語リストサイズ
    mov %rcx, %r15    # 最大単語数
    
    # メインループ
    .main_loop:
        # 現在のシードのハッシュを計算
        mov %r12, %rdi
        call calculate_hash
        
        # ハッシュの比較
        mov %rax, %rdi
        mov target_hash, %rsi
        call fast_strcmp
        test %eax, %eax
        jz .found
        
        # 次の組み合わせを生成
        call generate_next_combination
        test %eax, %eax
        jnz .main_loop
    
    # 見つからなかった場合
    xor %eax, %eax
    jmp .done
    
    .found:
        mov $1, %eax
    
    .done:
        # レジスタの復元
        pop %r15
        pop %r14
        pop %r13
        pop %r12
        pop %rbx
        pop %rbp
        ret

# ハッシュ計算関数（SHA256の最適化実装）
calculate_hash:
    push %rbp
    mov %rsp, %rbp
    
    # SHA256の初期化
    movdqa sha256_init, %xmm0
    movdqa sha256_init+16, %xmm1
    movdqa sha256_init+32, %xmm2
    movdqa sha256_init+48, %xmm3
    
    # メッセージの処理
    .process_message:
        # メッセージブロックの読み込み
        movdqu (%rdi), %xmm4
        movdqu 16(%rdi), %xmm5
        
        # SHA256の変換
        sha256rnds2 %xmm0, %xmm1
        sha256rnds2 %xmm2, %xmm3
        
        add $32, %rdi
        sub $32, %rsi
        jnz .process_message
    
    # 最終的なハッシュ値の生成
    movdqa %xmm0, %xmm4
    movdqa %xmm1, %xmm5
    movdqa %xmm2, %xmm6
    movdqa %xmm3, %xmm7
    
    # 結果を返す
    movdqa %xmm4, (%rdi)
    movdqa %xmm5, 16(%rdi)
    movdqa %xmm6, 32(%rdi)
    movdqa %xmm7, 48(%rdi)
    
    pop %rbp
    ret

.section .data
sha256_init:
    .quad 0x6a09e667f3bcc908
    .quad 0xbb67ae8584caa73b
    .quad 0x3c6ef372fe94f82b
    .quad 0xa54ff53a5f1d36f1 