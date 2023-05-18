#!/bin/bash
set -Ceuo pipefail

# 引数に Slack の Webhook URL を指定
SLACK_URL="$1"

# 中間処理用の CSV ファイルを用意
TEMPFILE="temp.csv" && rm -f $TEMPFILE && touch $TEMPFILE

# 対象のプロジェクト名のリスト (以下は例)
projects=("app" "list" "utilities")

# 指定したプロジェクトの C0 カバレッジ情報を返す関数
# - 入力: プロジェクト名
# - 出力: "プロジェクト名,テストでカバーされた命令行数,全命令行数"
get_coverage() {
  local file="build/reports/jacoco/test/jacocoTestReport.csv"
  if [ -f "$1/$file" ]; then
    # カバーされた総命令行数 (5列目の総和)
    local covered=$(
      awk -F ',' '{ it += $5 } END { print it }' "$1/$file"
    )
    # すべての総命令行数 (4列目と5列目の総和)
    local instructions=$(
      awk -F ',' '{ it += $4 + $5 } END { print it }' "$1/$file"
    )
    echo "$1,$covered,$instructions"
  else
    # プロジェクトにテストが 1 件もないと、
    # レポートファイル自体が出力されないため、この分岐に入る。
    # ゼロ除算回避のため、「全命令行数」にごく小さい数字を入れておく。
    echo "$1,0,0.0001"
  fi
}

# 各プロジェクトの C0 カバレッジ情報を算出し、中間処理用のファイルに出力
for each_project in "${projects[@]}"; do
  get_coverage "$each_project" >> $TEMPFILE
done

# 全プロジェクト横断のカバレッジ情報を算出し、中間処理用のファイルに出力
total_covered=$(
  awk -F ',' '{ it += $2 } END { print it }' $TEMPFILE
)
total_instructions=$(
  awk -F ',' '{ it += $3 } END { print it }' $TEMPFILE
)
echo "TOTAL,$total_covered,$total_instructions" >> $TEMPFILE

# 出力用に結果を整形
projects+=("TOTAL")
results=()
for each_project in "${projects[@]}"; do
  each_result=$(
    grep "$each_project" $TEMPFILE \
    | awk -F ',' \
    '{ printf "%-10s: %.2f %% (%d/%d)", $1, $2 / $3 * 100, $2, $3 }'
  )
  results+=("$each_result")
done

# Slack に投稿
curl "$SLACK_URL" \
  --header 'Content-Type: application/json' \
  --data "{\"text\":\"XXXXXプロジェクトのC0カバレッジです:
\`\`\`
$(printf '%s\n' "${results[@]}")
\`\`\`\"}"
