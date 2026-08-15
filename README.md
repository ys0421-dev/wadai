# WADEE

WADEEは、相手ごとに会話の話題とメモを整理するFlutterアプリケーションです。

再利用できる話題をライブラリで管理し、同じ話題を複数の相手へ割り当てられます。話題そのものの説明と、その相手に固有のメモを分けて扱うことで、次に話したいことや以前話した内容を振り返りやすくします。

現在はAndroidでの利用を中心に開発しているプロトタイプです。

## 主な機能

### 相手

- 相手の追加・編集・削除
- 相手全般のメモ
- 関係性・親密度・年代、趣味、最近の出来事などの任意プロフィール
- 入力済みのプロフィールを相手詳細で確認（AIによる提案機能のための構造化情報）
- 複数の話題をまとめて割り当て
- 相手と話題の組み合わせごとのメモ
- 相手ごとの話題ステータス
  - これから話す
  - 話した
  - また話す
- 相手詳細の話題一覧を「話す（これから話す・また話す）」と「話した」に分けて表示
- 「話す」／「話した」はタブのタップまたは左右スワイプで切り替え
- 話題カードをステータスごとの淡い背景色で区別
- 割り当て済み・アーカイブ済み話題の重複追加防止

### 話題

- 10カテゴリ、36件の定番話題
- 自作話題の追加・編集
- お気に入り登録
- 話題の検索、絞り込み、並び替え
- 定番話題・自作話題のArchive／Restore
- Archive後も既存の相手別メモとステータスを維持

画面下部のNavigationは「相手」と「話題」の2つです。話題の作成や相手の追加は、それぞれの画面にあるActionから行います。

## データモデル

- `Person`: 相手の名前、全般メモ、作成日時、任意の`PersonProfile`
- `PersonProfile`: 関係性・親密度・年代と、相手について／会話のヒントを表す構造化プロフィール。名前だけの登録も可能
- `Topic`: 複数の相手で再利用できる話題。定番／自作の種別を持つ
- `PersonTopic`: `Person`と`Topic`の関連。その相手固有のメモ、ステータス、作成日時を持つ

同じ`Person`と`Topic`の組み合わせは1件だけ作成できます。お気に入りとArchive状態はTopic Library全体に対して管理します。

## データ保存

データは`shared_preferences`を使用して端末内へ保存します。

- schema version付きの単一スナップショット
- 保存成功後にのみ画面上の状態を更新
- 旧保存形式およびschema v1／v2／v3からschema v4へのMigration
- schema v2／v3のPersonには空の`PersonProfile`を補い、既存のメモ・話題ステータス・お気に入り・Archive状態を維持
- 未知のschema versionや壊れたデータを検出した場合は、既存データを上書きせずエラーを表示

アカウント、クラウド同期、外部サーバーへのデータ送信は現在実装していません。

## 開発環境と起動

Flutter SDKとAndroid開発環境を用意し、リポジトリのルートで次を実行します。

```shell
flutter pub get
flutter run
```

利用しているDart SDKの条件は[pubspec.yaml](pubspec.yaml)を参照してください。

## 検証

```shell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

テストでは、状態更新と保存失敗時の整合性、Legacy migration、Person／Topic／PersonTopicの操作、画面遷移、複数話題の一括割り当て、検索・Filter、相手別話題のステータスタブとスワイプ操作、狭幅・文字拡大表示などを確認しています。

## ディレクトリ構成

```text
lib/
├── app/       # App、Theme、2タブNavigation
├── data/      # 定番TopicとSharedPreferences永続化
├── features/  # 相手・話題ごとの画面とUI
├── models/    # Person、Topic、PersonTopic、Category
├── shared/    # 共通Widget
├── state/     # WadeeControllerと状態更新
└── main.dart  # アプリのエントリーポイント

test/
└── widget_test.dart  # Domain、Migration、Widget、操作フローのテスト
```

WADEEの開発方針とエージェント運用ルールは[AGENTS.md](AGENTS.md)に記載しています。

## 現在の対象外

- AIによる話題生成
- ニュースや外部コンテンツの取得
- ログイン・アカウント管理
- クラウド同期・複数端末同期
