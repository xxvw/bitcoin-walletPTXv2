import os
import subprocess
from mnemonic import Mnemonic
from pycoin.key.BIP32Node import BIP32Node

def compile_c_program():
    """Cプログラムをコンパイルする"""
    # アセンブリファイルをコンパイル
    subprocess.run(['as', '-o', 'seed_generator.o', 'seed_generator.s'])
    
    # OpenCLカーネルをコンパイル
    subprocess.run(['clang', '-c', '-o', 'bruteforce.o', 'bruteforce.cl'])
    
    # プログラムをリンク
    subprocess.run([
        'gcc', '-O3', '-march=native',
        'bruteforce.c', 'bruteforce.o', 'seed_generator.o',
        '-o', 'bruteforce',
        '-lOpenCL'
    ])

def get_wordlist():
    """BIP39の単語リストを取得する"""
    mnemo = Mnemonic("english")
    return mnemo.wordlist

def run_bruteforce(target_hash):
    """総当たり処理を実行する"""
    wordlist = get_wordlist()
    
    # プロセスを開始
    process = subprocess.Popen(
        ['./bruteforce', target_hash],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    # 単語リストを標準入力に書き込む
    for word in wordlist:
        process.stdin.write(word + '\n')
    process.stdin.close()
    
    # 結果を取得
    stdout, stderr = process.communicate()
    
    # デバッグ情報を出力
    if stderr:
        print(f"デバッグ情報: {stderr.strip()}")
    
    return stdout.strip()

def verify_seed(seed_phrase):
    """シードフレーズを検証する"""
    try:
        mnemo = Mnemonic("english")
        if not mnemo.check(seed_phrase):
            return False
        
        # シードからマスタープライベートキーを生成
        seed = mnemo.to_seed(seed_phrase)
        master = BIP32Node.from_master_secret(seed)
        
        # ここで必要に応じて追加の検証を行う
        return True
    except Exception:
        return False

def main():
    # Cプログラムをコンパイル
    compile_c_program()
    
    # ターゲットハッシュ（実際の使用時は適切なハッシュを設定）
    target_hash = "your_target_hash_here"
    
    # 総当たり処理を実行
    seed_phrase = run_bruteforce(target_hash)
    
    # 結果を検証
    if verify_seed(seed_phrase):
        print(f"シードフレーズが見つかりました: {seed_phrase}")
    else:
        print("有効なシードフレーズは見つかりませんでした。")

if __name__ == "__main__":
    main() 