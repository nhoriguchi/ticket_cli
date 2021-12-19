# Ticket CLI
==========

本ツールはチケットシステムの CLI 用ツールで、現時点で以下のチケットシステムをサポートしている。

- [Redmine](https://www.redmine.org/)
- [Growi](https://github.com/weseek/growi) (Experimental)

# 設定方法

- [設定ファイル](https://github.com/nhoriguchi/ticket_cli/blob/main/config.template) を参考に、対象となるチケットシステムの情報を記載する。
- 設定ファイルのデフォルトパスは `$HOME/.ticket/config` としているが、
  環境変数 `TICKET_CONFIG` が設定されている場合、
  指定されたパスから設定ファイルを読み込む。

# 依存性

- Ruby を利用しているので、ruby, rubygems をインストールしておく必要がある。
- また `gem install diffy nokogiri` 等で依存ライブラリをインストールしておく必要がある。
