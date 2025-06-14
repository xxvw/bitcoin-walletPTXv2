# Bitcoin Wallet Seed Brute Force

このプロジェクトは、Bitcoinウォレットのシードフレーズを総当たりで検索するためのツールです。

## 必要条件

- Python 3.7以上
- GCCコンパイラ
- 必要なPythonパッケージ（requirements.txtに記載）

## インストール方法

1. リポジトリをクローン
2. 依存関係をインストール:
```bash
pip install -r requirements.txt
```

## 使用方法

1. プログラムを実行:
```bash
python main.py
```

## 注意事項

- このツールは教育目的でのみ使用してください
- 実際のウォレットに対して不正な使用はしないでください
- 処理には非常に長い時間がかかる可能性があります

## 技術的な詳細

- C言語で実装された高速な総当たり処理
- アセンブリ言語による最適化
- Pythonによる検証処理 