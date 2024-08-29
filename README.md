## download_backlog_attachments.sh

指定されたBacklogプロジェクトIDに関連する全ての課題から添付ファイルをダウンロードするスクリプトです。各課題に関連する添付ファイルをローカルに保存します。

## 事前に必要なコマンド:
- jq
- curl

## 使用方法:

```bash
$ chmod +x download_backlog_attachments.sh
$ ./download_backlog_attachments.sh -k YOUR_API_KEY -s YOUR_SPACE_ID -p YOUR_PROJECT_ID
```

## オプションの説明:

**-k: Backlog APIキー**

Backlogにログインし、以下のページからAPIキーを取得してください。
https://hlm.backlog.com/EditApiSettings.action

**-s: BacklogスペースID**

スペースIDは、BacklogのURLに含まれる文字列です。

例: https://[スペースID].backlog.com

**-p: ダウンロード対象のプロジェクトID**

プロジェクトIDは、プロジェクト設定のURLに含まれる数字です。

例: https://hlm.backlog.com/ViewPermission.action?projectId=[プロジェクトID]
