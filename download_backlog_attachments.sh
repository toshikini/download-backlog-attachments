#!/bin/bash

# 指定されたBacklogプロジェクトIDに関連する全ての課題から添付ファイルをダウンロードするスクリプトです。
# 各課題に関連する添付ファイルをローカルに保存します。
#
# 必要なコマンド:
#   - jq: JSONデータをパースするために使用します。インストールされていない場合は、事前にインストールしてください。
#   - curl: HTTPリクエストを送信するために使用します。インストールされていない場合は、事前にインストールしてください。
#
# 使用方法:
#   ./download_backlog_attachments.sh -k YOUR_API_KEY -s YOUR_SPACE_ID -p YOUR_PROJECT_ID
#
# オプション:
#   -k: Backlog APIキー
#   -s: BacklogスペースID
#       スペースIDは、BacklogのURLに含まれる文字列です。
#       例: https://[スペースID].backlog.com
#   -p: ダウンロード対象のプロジェクトID
#       プロジェクトIDは、プロジェクト設定のURLに含まれる数字です。
#       例: https://hlm.backlog.com/ViewPermission.action?projectId=[プロジェクトID]
#
# Backlog APIキーの取得方法:
#   Backlogにログインし、以下のページからAPIキーを取得してください。
#   https://hlm.backlog.com/EditApiSettings.action

SPACE_DIR=$(pwd)
COUNT=100

usage() {
  echo "Usage: $0 -k API_KEY -s SPACE_ID -p PROJECT_IDS"
  echo "  -k    Backlog API key"
  echo "  -s    Backlog space ID"
  echo "  -p    Project ID"
  exit 1
}

# コマンドラインのオプションを解析
while getopts "k:s:p:" opt; do
  case "${opt}" in
    k) API_KEY="${OPTARG}" ;;
    s) SPACE_ID="${OPTARG}" ;;
    p) PROJECT_ID="${OPTARG}" ;;
    *) usage ;;
  esac
done

if [ -z "${API_KEY}" ] || [ -z "${SPACE_ID}" ] || [ -z "${PROJECT_ID}" ]; then
  usage
fi

make_uri() {
  # Backlog API の URI を生成する関数
  #
  # 引数:
  #   1. endpoint (必須): 呼び出したい Backlog API のエンドポイント (例: '/api/v2/issues')
  #   2. params (任意): クエリパラメータを追加したい場合に指定 (例: 'projectId[]=123')
  #
  # 戻り値:
  #   生成されたURI
  #
  # 使用例:
  #   uri=$(make_uri "/api/v2/issues" "projectId[]=123")
  #   echo $uri
  #
  # 出力例:
  #   https://example.backlog.com/api/v2/issues?apiKey=YOUR_API_KEY&projectId[]=123

  local endpoint="$1"
  local params="$2"
  local uri="https://${SPACE_ID}.backlog.com${endpoint}?apiKey=${API_KEY}"

  if [ -n "$params" ]; then
    uri="${uri}&${params}"
  fi

  echo "$uri"
}

get_issues_from_project() {
  # 指定されたプロジェクトIDから全ての課題を取得する関数
  #
  # 引数:
  #   1. project_id (必須): 課題を取得したいプロジェクトのID
  #
  # 戻り値:
  #   - 正常終了時: プロジェクト内の各課題のキーと概要がカンマ区切りで出力
  #   - 異常終了時: エラーメッセージが標準エラー出力に出力され、関数は1を返す
  #
  # 使用例:
  #   get_issues_from_project "12345"
  #
  # 出力例:
  #   ISSUE-1,課題1の概要
  #   ISSUE-2,課題2の概要
  #   ISSUE-3,課題3の概要

  local project_id="$1"
  local issues=()
  local uri=$(make_uri "/api/v2/issues/count" "projectId[]=$project_id")
  local response=$(curl -s "$uri")

  if echo "$response" | jq . >/dev/null 2>&1; then
    local issue_count=$(echo "$response" | jq '.count')
  else
    echo "Error: Invalid JSON response for issue count"
    echo "Response: $response"
    return 1
  fi

  local loop_count=$((issue_count / COUNT))
  for i in $(seq 0 $loop_count); do
    local offset=$((i * COUNT))
    local uri=$(make_uri "/api/v2/issues" "projectId[]=$project_id&count=$COUNT&offset=$offset")
    local response=$(curl -s "$uri")

    if echo "$response" | jq . >/dev/null 2>&1; then
      echo "$response" | jq -c '.[] | {issueKey: .issueKey, summary: .summary}' | while read -r issue; do
      local issue_key=$(echo "$issue" | jq -r '.issueKey')
      local issue_summary=$(echo "$issue" | jq -r '.summary' | tr -d '\n\r')

      echo "$issue_key,$issue_summary"
    done
  else
    echo "Error: Invalid JSON response for issues"
    echo "Response: $response"
    return 1
    fi
  done
}

fetch_attachments() {
  # 指定された課題キーに関連付けられた添付ファイルを取得する関数
  #
  # 引数:
  #   1. issue_key (必須): 添付ファイルを取得したい課題のキー (例: 'ISSUE-1')
  #
  # 戻り値:
  #   - 正常終了時: 課題に関連する全ての添付ファイルの情報をJSON形式で標準出力に出力
  #   - 異常終了時: エラーメッセージが標準エラー出力に出力され、関数は1を返す
  #
  # 使用例:
  #   fetch_attachments "ISSUE-1"
  #
  # 出力例:
  #   {"id":1,"name":"sample1.png","size":1234,"createdUser":{...},"created":"2024-08-21T09:44:00Z"}
  #   {"id":2,"name":"sample2.png","size":5678,"createdUser":{...},"created":"2024-08-21T09:45:00Z"}
  #   {"id":3,"name":"sample3.png","size":9012,"createdUser":{...},"created":"2024-08-21T09:46:00Z"}

  local issue_key="$1"
  local uri=$(make_uri "/api/v2/issues/$issue_key/attachments")
  local response=$(curl -s "$uri")

  # Check if the response is valid JSON
  if echo "$response" | jq . >/dev/null 2>&1; then
    echo "$response" | jq -c '.[]'
  else
    echo "Error: Invalid JSON response for attachments"
    echo "Response: $response"
    return 1
  fi
}

construct_download_path() {
  # 指定された課題の添付ファイルを保存するためのローカルパスを生成する関数
  #
  # 引数:
  #   1. issue_key (必須): 課題のキー (例: 'ISSUE-1')
  #   2. issue_summary (必須): 課題の概要 (例: 'Sample Issue Summary')
  #   3. attachment_name (必須): 添付ファイルの名前 (例: 'attachment.png')
  #   4. attachment_id (必須): 添付ファイルのID (例: '123')
  #
  # 戻り値:
  #   生成されたローカルパスを標準出力に出力
  #
  # 使用例:
  #   construct_download_path "ISSUE-1" "Sample Issue Summary" "attachment.png" "123" "true"
  #
  # 出力例:
  #   /path/to/space/dir/SPACE_ID/ISSUE-1-Sample_Issue_Summary/123-attachment.png

  local issue_key="$1"
  local issue_summary="$2"
  local attachment_name="$3"
  local attachment_id="$4"

  local sanitized_summary=$(echo "$issue_summary" | sed 's/[\/:*?"<>|]/_/g')

  echo "$SPACE_DIR/${SPACE_ID}/${issue_key}-${sanitized_summary}/${attachment_id}-${attachment_name}"
}

download_attachment() {
  # 指定されたURIから添付ファイルをダウンロードし、ローカルの指定されたパスに保存する関数
  #
  # 引数:
  #   1. download_uri (必須): 添付ファイルのダウンロード元URI (例: 'https://example.backlog.com/download/12345')
  #   2. download_path (必須): 添付ファイルを保存するローカルパス (例: '/path/to/save/attachment.png')
  #
  # 戻り値:
  #   ファイルが既に存在する場合は「SKIP: ファイルパス」を出力し、ファイルをダウンロードした場合は「DL: ファイルパス」を出力
  #
  # 使用例:
  #   download_attachment "https://example.backlog.com/download/12345" "/path/to/save/attachment.png"

  local download_uri="$1"
  local download_path="$2"

  if [ -f "$download_path" ]; then
    echo "SKIP: $download_path"
  else
    mkdir -p "$(dirname "$download_path")"
    curl -s -o "$download_path" "$download_uri"
    echo "DL: $download_path"
  fi
}

download_attachment_from_issue() {
  # 指定された課題キーに関連する全ての添付ファイルをダウンロードし、ローカルに保存する関数
  #
  # 引数:
  #   1. issue_key (必須): 課題のキー (例: 'ISSUE-1')
  #   2. issue_summary (必須): 課題の概要 (例: 'Sample Issue Summary')
  #
  # 戻り値:
  #   課題に添付ファイルがある場合は各ファイルをダウンロードし、ダウンロードが成功したファイルのパスを出力。
  #   課題に添付ファイルがない場合は「no attachments: 課題キー - 課題概要」を出力。
  #
  # 使用例:
  #   download_attachment_from_issue "ISSUE-1" "Sample Issue Summary"
  #
  # 出力例（添付ファイルがある場合）:
  #   has attachments: ISSUE-1 - Sample Issue Summary
  #   DL: /path/to/save/ISSUE-1-Sample_Issue_Summary/123-attachment.png
  #   DL: /path/to/save/ISSUE-1-Sample_Issue_Summary/124-attachment.pdf
  #
  # 出力例（添付ファイルがない場合）:
  #   no attachments: ISSUE-1 - Sample Issue Summary

  local issue_key="$1"
  local issue_summary="$2"
  local attachments=$(fetch_attachments "$issue_key")

  if [ -n "$attachments" ]; then
    echo "has attachments: $issue_key - $issue_summary"

    echo "$attachments" | while read -r attachment; do
      local attachment_name=$(echo "$attachment" | jq -r '.name')
      local attachment_id=$(echo "$attachment" | jq -r '.id')
      local download_path=$(construct_download_path "$issue_key" "$issue_summary" "$attachment_name" "$attachment_id")
      local download_uri=$(make_uri "/api/v2/issues/$issue_key/attachments/$attachment_id")

      download_attachment "$download_uri" "$download_path"
    done
  else
    echo "no attachments: $issue_key - $issue_summary"
  fi
}

download_all_attachments_from_project() {
  # 指定されたプロジェクトIDに関連する全ての課題の添付ファイルをダウンロードする関数
  #
  # 引数:
  #   1. project_id (必須): 課題の添付ファイルをダウンロードしたいプロジェクトのID
  #
  # 戻り値:
  #   各課題の添付ファイルをダウンロードし、その結果を標準出力に出力
  #
  # 使用例:
  #   download_all_attachments_from_project "12345"

  local project_id="$1"
  local issues=$(get_issues_from_project "$project_id")

  echo "$issues" | while IFS=',' read -r issue_key issue_summary; do
    download_attachment_from_issue "$issue_key" "$issue_summary"
  done
}


# メイン処理
download_all_attachments_from_project "$PROJECT_ID"
