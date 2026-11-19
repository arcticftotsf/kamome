# kamome

セキュリティを最優先にして、そのぶん**利便性を意図的に犠牲にした** Todo アプリです。Ruby on Rails の学習を兼ねた個人プロジェクトです。

> **注意**: 学習目的のプロジェクトで、第三者によるセキュリティ監査は受けていません。実際の機密情報の保管には使わないでください。現時点では、ローカル環境(localhost)での利用だけを想定しています。

## 方針

- 便利さより安全さを優先する(迷ったら、使いにくいほうを選ぶ)
- 鍵とパスワードはコードに置かない
- 1つの防御が破られても、次の防御が残るようにする(多層防御)

## 技術構成

- Ruby 3.4 / Rails 8.1
- PostgreSQL(アプリ用ロールは最小権限。スーパーユーザーは使わない)
- Propshaft / importmap / Turbo(Rails 8 の標準構成)

## 実装済みの機能

### 認証とセッション

- Rails 8 標準の認証を土台に、アカウント作成画面を追加
- パスワードは 12 文字以上(上限は bcrypt の制限に合わせて 72 文字)
- 無操作 5 分でセッション失効(絶対期限もあり)。設定値は `app/models/session.rb`
- セッション cookie は署名付き、`HttpOnly`、`SameSite=Strict`。本番では `Secure`
- ログイン中の端末一覧(Active sessions)と、他の端末のセッションを終了する機能
- ログイン、アカウント作成、2FA まわりにレート制限

### 二要素認証(2FA)

- 認証アプリの 6 桁コード(TOTP)
- 同じコードの再利用を拒否(使用済みの時刻を記録)
- バックアップコード 10 個(1 回限り。保存するのはハッシュだけ)
- 2FA の無効化とバックアップコードの再発行には、パスワードの再入力が必要
- QR コードは外部サービスを使わず、サーバー内で生成して画像として表示

### データの保護

- Active Record Encryption で、Todo のタイトルと 2FA の秘密鍵を暗号化して保存
- Todo は `Current.user.todos` の範囲だけで検索するため、他人の Todo は URL を直接指定しても 404 になる(自動テストあり)

### ブラウザ側の防御

- Content Security Policy を強制(`default-src 'none'` から必要なものだけ許可)
- `Referrer-Policy`、`Permissions-Policy`、`Cross-Origin-Opener-Policy`、`Cross-Origin-Resource-Policy` を設定

### 継続的な検査

GitHub Actions で次を実行します。Dependabot で依存ライブラリの更新も監視しています。

- `scan_ruby`: Brakeman(コードの脆弱性)と bundler-audit(ライブラリの既知の脆弱性)
- `scan_js`: importmap の脆弱性チェック
- `lint`: RuboCop
- `test`: 自動テスト

## 実装中・予定

- ログイン失敗によるアカウントロックアウト(解除は `rails console` からのみ)
- 監査ログ(ログイン、2FA の変更、セッション終了などを記録。アプリからは変更不可)
- 重要な操作の前の再認証(パスワードと 6 桁コード)
- ログイン時の IP とブラウザへのセッション固定
- パスキー
- デプロイ向けの強化(HTTPS の強制、HSTS、新しい場所からのログインの通知)

## 既知の制限

- アカウント作成画面は誰でも開ける(招待コードは未実装)。公開サーバーに置く前に制限が必要
- メール送信を設定していないため、パスワードリセットのメールは届かない
- HSTS など、本番向けのヘッダーは未設定

## セットアップ

前提: Ruby 3.4(mise などで導入)、PostgreSQL、Git。

### 1. 取得と依存ライブラリ

```bash
git clone https://github.com/arcticftotsf/kamome.git
cd kamome
bundle install
```

### 2. PostgreSQL のロールを作る

スーパーユーザー権限は付けません。

```sql
CREATE ROLE kamome LOGIN CREATEDB PASSWORD '長いランダムなパスワード';
```

パスワードは環境変数で渡します。`~/.bashrc` などに書いて、`source` してください。

```bash
export KAMOME_DB_PASSWORD='上で決めたパスワード'
```

`config/database.yml` は、この値を `.to_json` で YAML に埋め込みます。記号を含むパスワードでも壊れません。

### 3. 暗号化キーを用意する

リポジトリには `master.key` が含まれません。自分の環境で credentials を作り直します。

```bash
rm config/credentials.yml.enc
bin/rails db:encryption:init       # 3 つのキーが表示される
EDITOR=nano bin/rails credentials:edit
```

エディタが開くので、表示された内容を次の形で書いて保存します。新しい `config/master.key` も作られます。

```yaml
active_record_encryption:
  primary_key: ...
  deterministic_key: ...
  key_derivation_salt: ...
```

**`config/master.key` は必ずバックアップしてください。失くすと、暗号化したデータは二度と読めません。** 漏らすと、暗号化の意味がなくなります。Git には入れません(`.gitignore` 済み)。

### 4. DB を作って起動する

```bash
bin/rails db:create db:migrate
bin/rails server
```

`http://localhost:3000/users/new` でアカウントを作り、設定画面から 2FA を有効にします。

## テスト

```bash
bin/rails test
```

- `config/environments/test.rb` で、fixtures の外部キー検査を止めています。この検査には PostgreSQL のスーパーユーザー権限が必要で、最小権限のロールでは実行できないためです。
- CI の DB は使い捨てのコンテナで、専用のダミーパスワードを使います。

## 運用メモ

### 脆弱性の確認

```bash
bin/brakeman --no-pager
bin/bundler-audit
```

### セッションの掃除

```bash
bin/rails runner 'Session.expired.delete_all'
```

