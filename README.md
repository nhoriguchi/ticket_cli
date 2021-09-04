# Ticket CLI
==========

チケットシステムの CLI ツール。
現時点でサポートしている

# 設定方法

- 設定ファイルに基づき、対象となるチケットシステムを登録する。
- 設定ファイルのデフォルトパスは `$HOME/.ticket/config` とするが、
  環境変数 `TICKET_CONFIG` が設定されている場合、
  指定されたパスの設定ファイルが使用される。

# 依存性

- Ruby を利用しているので、ruby, rubygems をインストールする必要がある。
- `gem install diffy nokogiri` 等で適宜パッケージがインストールしておく必要がある。
