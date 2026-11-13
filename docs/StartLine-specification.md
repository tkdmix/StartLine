# StartLine 製品仕様

## 1. 文書の位置づけ

この文書をStartLineの現行製品仕様の正本とする。

この文書は今後のバージョンでも現行仕様に合わせて更新する。

## 2. 製品コンセプト

StartLineは、開始条件をEdit画面で選び、Focus画面で正式なカウントダウンを開始・管理するアプリである。

```text
Edit  = 次に何を開始するかを選択・設定する
Focus = 正式に開始したカウントダウンを表示・管理する
```

Edit画面に表示されるScheduledの目標時刻と残り時間はリアルタイムプレビューであり、正式なタイマーとして保存しない。正式なカウントダウンは、Edit画面の `Focus` またはFocus画面の次区間開始ボタンを押した時点で生成する。

## 3. カウントダウン種別

以下の3種類を区別して保持する。

```swift
enum CountdownType {
    case scheduled
    case pomodoro
    case breakTime
}
```

- `Scheduled`: 選択した実時刻までのカウントダウン
- `Pomodoro`: ユーザーが設定した集中時間のカウントダウン
- `Break`: Pomodoro完了後に開始できる固定5分の休憩

すべてのカウントダウンは0秒で停止する。ユーザー操作なしで次の区間を自動開始しない。

## 4. Edit画面

### 4.1 基本構成

Edit画面では、3×3に並ぶ9個の選択ボタンを使って、Focus画面で開始するカウントダウンを選ぶ。

```text
Scheduled候補 × 8
Pomodoro      × 1（右下）
```

Version 1.0で表示していた9番目の、最も遠いScheduled候補をPomodoroボタンへ置き換える。これは常に厳密な「45分後」ではなく、直近の5分境界から生成した候補列の9番目に相当する。

9個のボタンは、縦画面と横画面のどちらでも同じ外形寸法にする。

グリッド上部には独立した `To` ラベルを表示しない。Scheduledボタン自体に `To` を含める。

### 4.2 Scheduled設定

Scheduled候補は、現在時刻より後の直近の5分境界から5分刻みで生成し、先頭8個を表示する。

ボタン例:

```text
To 10:30
```

選択中の候補には、既存の色系統に応じた明るい枠線を表示する。

リングには、選択した実時刻までの残り時間をリアルタイムに表示する。Edit画面のScheduled表示は正式なタイマーではなく、選択中候補のプレビューである。

リング例:

```text
4m 32s
To 10:30
```

リング内とボタン内の対象時刻表記は、大文字の `To` で統一する。

Edit画面でScheduledプレビューが0秒に達した場合は、次の直近候補へ自動的に進める。

Scheduledを選択して `Focus` を押すと、その時点の目標時刻を確定し、正式なScheduledカウントダウンを開始する。

Scheduledの選択操作には、画面上に常時表示される候補ボタンを使用する。
Scheduledリングは残り時間を示す表示に限定し、候補変更のためのスワイプ操作を割り当てない。
Pomodoro設定リングの操作性と表面的に揃えるためだけに、発見しにくく重複するジェスチャーを追加しない。
実機利用で候補ボタンによる選択に明確な問題が確認された場合に限り、代替操作を再検討する。

### 4.3 Pomodoro設定の選択

Pomodoroボタンは3×3グリッドの右下に配置する。独立したPomodoroボタンや `Back to Schedule` ボタンは設けない。

Pomodoroボタンを押しただけではカウントダウンを開始しない。Pomodoro設定状態へ切り替えるだけである。

Pomodoro選択中もScheduledボタンは操作可能とし、いずれかを押すとScheduled設定へ切り替える。

Pomodoroボタンには、Scheduledの寒色系と一目で区別できる、落ち着いたアンバー系の色を使用する。文字はScheduled候補と同じ白、背景は暗いアンバー、通常の枠線は背景より明るいアンバーとする。選択中は同系色のさらに明るい枠線を表示する。

### 4.4 Pomodoro設定リング

Pomodoro設定中のリングは停止した設定用コントロールであり、自動的にカウントダウンしない。

```text
25m 00s
Pomodoro
```

設定範囲は以下とする。

- 5〜60分
- 5分刻み
- 初回値は25分
- 0分は設定不可
- リング1周は60分

ドラッグ操作は現在値を起点とする相対操作方式とする。ドラッグを開始しただけでは、触れた位置へ値を即座にジャンプさせない。

- 時計回りで増加
- 反時計回りで減少
- 約30度分の累積移動につき5分変更
- 60分で止まり、それ以上時計回りに動かしても増加しない
- 5分で止まり、それ以上反時計回りに動かしても減少しない
- `60 → 5` または `5 → 60` へ循環しない
- ドラッグ中も表示値を更新する
- 指を離した時点で確定する
- 触覚フィードバックは使用しない

相対ドラッグに加えて、リング上の位置をタップして時間を直接設定できるようにする。タップ操作では、リング1周の表示位置をそのまま設定時間へ対応させる。

- 12時位置は60分
- 時計回りに5分刻み
- 6時位置は30分
- タップした時間を即時に確定・永続化する
- リング中央付近のタップでは時間を変更しない

端末画面端には独自のスワイプ操作を割り当てない。ドラッグ操作領域はリング周辺に限定する。

VoiceOverではリングを調整可能な値として公開し、上下スワイプで5分ずつ増減できるようにする。画面上に常設の＋／－ボタンは設けず、必要性は実機テスト後に再検討する。

### 4.5 Pomodoro時間の保存

確定したPomodoro時間は永続化する。

実際にPomodoroを開始したかどうかに関係なく、設定変更は以後のすべてのPomodoro開始に有効とする。

保存値は以下に使用する。

- 次回Pomodoro設定を開いたときの初期表示
- Break完了後の `Start Xm Pomodoro`
- そのボタンから開始する次のPomodoro

Scheduledプレビューの目標時刻、残り時間、候補列は永続化しない。

### 4.6 Focusボタン

`Focus` はScheduledとPomodoroに共通する唯一の正式な開始操作である。

```text
Scheduled選択 → Focus → Scheduled開始
Pomodoro選択  → Focus → Pomodoro開始
```

Pomodoroを開始する際、Scheduledプレビューを別のアクティブタイマーとして保持しない。複数タイマーを同時管理しない。

## 5. Focus画面

### 5.1 共通動作

Focus画面では正式に開始されたカウントダウンだけを表示する。

カウントダウン中は、Scheduled、Pomodoro、Breakのいずれも操作ボタンを `Edit` のみにする。

以下は現行仕様では提供しない。

- Pause
- Resume
- 確認ダイアログ
- 自動的な次区間開始

`Edit` を押すと、確認なしで現在の正式なカウントダウンを終了し、Edit画面へ戻る。

### 5.2 Scheduled

ScheduledのFocus画面はVersion 1.0の基本動作を維持する。

- Focusへ入った時点をリングの満周とする
- 選択した実時刻までカウントダウンする
- 0秒で停止する
- 終了後も追加の開始ボタンを表示しない
- 表示する操作は `Edit` のみ

### 5.3 PomodoroとBreakのリング

PomodoroとBreakでは、EditのPomodoro設定リングと同じく、Focus中も60分をリング1周として扱う。

例:

```text
25分Pomodoro → 開始時は25/60周
5分Break     → 開始時は5/60周
```

Pomodoroカウントダウン中のリングはアンバー系とする。Breakは現時点ではPomodoroと調和する暫定的な暖色を使用してよい。

## 6. 完了後の手動継続

### 6.1 共通

すべての種別で、完了時は以下の表示で停止する。

```text
0m 00s
```

ユーザーが明示的にボタンを押すまで次の区間を開始しない。

### 6.2 Scheduled完了後

追加の開始ボタンを表示しない。

```text
[ Edit ]
```

### 6.3 Pomodoro完了後

既存のEditボタンの位置は動かさず、その上に以下を表示する。

```text
[ Start 5m Break ]
[ Edit ]
```

`Start 5m Break` を押すと、確認なしで5分のBreakを開始し、Focus画面に留まる。開始後は追加ボタンを隠し、カウントダウン中は再び `Edit` のみ表示する。

### 6.4 Break完了後

既存のEditボタンの上に以下を表示する。

```text
[ Start Xm Pomodoro ]
[ Edit ]
```

`X` は保存済みのPomodoro時間である。

ボタンを押すと、確認なしでその時間のPomodoroを開始し、Focus画面に留まる。

`Start 5m Break` と `Start Xm Pomodoro` には、Pomodoroと同じアンバー系の色を使用する。

## 7. Edit画面への復帰

復帰先は終了したカウントダウン種別によって異なる。

### Scheduledからの復帰

対象時刻がまだ到来していない場合は、Version 1.0と同様に選択していたScheduled候補を維持する。到来済みの場合は次の直近候補へ進める。

### Pomodoroからの復帰

Pomodoroの実行中または完了後に `Edit` を押した場合は、Pomodoroが選択されたEdit画面へ戻る。リングには保存済みPomodoro時間を表示する。

### Breakからの復帰

Breakの実行中または完了後に `Edit` を押した場合は、Scheduledが選択されたEdit画面へ戻る。

## 8. 表記

時間の単位は小文字の `m` と `s` を使用する。分はゼロ埋めしない。分と秒の間には空白を入れる。

```text
4m 32s
0m 00s
5m 00s
25m 00s
Start 5m Break
Start 25m Pomodoro
```

Scheduledの対象時刻表記は、リングと候補ボタンの両方で大文字の `To` に統一する。

```text
To 10:30
```

## 9. 色

- メイン画面背景: Light appearanceは90%グレイ、Dark appearanceは10%グレイとする
- 情報シート: システム標準の背景色と階層表現に従う
- Scheduled: Version 1.0の寒色系を維持する
- Pomodoro: ボタン背景は暗いアンバー、文字は白、通常枠と選択枠は段階的に明るいアンバーとする。設定リング、Focusリング、次区間開始ボタンも落ち着いたアンバー系で統一する
- Break: 初期実装ではPomodoroと調和する暫定的な暖色を使用し、実機テスト後に再検討できる

派手な黄色や鮮やかすぎるオレンジは避ける。Light／Dark appearanceの両方で文字、枠、進捗を判別できることを確認する。

## 10. 永続化とバックグラウンド

永続化する値:

- 最後に確定したPomodoro時間

永続化しない値:

- Scheduledプレビューの対象時刻と残り時間
- Scheduled候補列
- 実行中の正式なカウントダウン
- Pomodoro／Breakの継続状態

アプリプロセスが生存している間は、終了日時と現在時刻の差から残り時間を計算し、バックグラウンド滞在後も経過時間を反映する。

アプリ終了後のアクティブタイマー復元、バックグラウンド実行、通知、Live Activityは現行仕様へ追加しない。

## 11. 現行仕様の対象外

- PomodoroとBreakの自動切り替え
- Pause／Resume
- 確認ダイアログ
- Pomodoro回数の記録
- 集中時間の統計
- 4セットごとの長時間休憩
- Break時間の編集
- 1分刻みの設定
- 0分設定
- リング操作時の触覚フィードバック
- Scheduledプレビューの永続化
- アクティブタイマーの終了後復元
- 通知、音、バックグラウンド実行、Live Activity
- アカウント、独自サーバー、広告、分析、トラッキング
- 複数タイマーの同時管理
- 常設のPomodoro＋／－ボタン

## 12. チップジャー

Version 2.1では、任意の支援手段として情報シート内にチップジャーを置く。

- 商品は `Small Coffee` 1種類とする
- Product IDは `io.github.inadaman.StartLine.tip.smallCoffee` とする
- 商品種別は消費型（Consumable）とする
- 日本での基準価格は200円とし、実際の表示価格はStoreKitが返すローカライズ済み価格を使用する
- 購入は何度でも可能とする
- 購入の有無によって機能、コンテンツ、利用権を変えない
- 購入履歴、累計回数、支援者状態をアプリ内へ保存しない
- 消費型商品のため、購入復元ボタンは設けない
- タイマー画面には購入導線を置かず、情報シート内だけに表示する

購入UIは、読み込み中、購入可能、処理中、承認待ち、成功、キャンセル、失敗、商品取得不可を区別する。失敗または商品取得不可でもタイマー機能は影響を受けず、商品取得は再試行できること。

検証済みトランザクションは処理後に `finish()` する。未検証トランザクションを成功として扱わない。

ローカル検証用のStoreKit ConfigurationはUI TestターゲットとAutomation Schemeだけで使用する。Releaseアプリへテスト商品や検証専用処理を同梱しない。

App Store Connectでの商品作成、価格設定、審査提出、および有料アプリ契約・税務・銀行情報の有効化は、製品コードの実装とは分離したリリース作業として行う。

## 13. レイアウト要件

- iPhone SEなどの小型端末で使用できること
- 大型iPhoneで余白や要素間隔が不自然にならないこと
- Portrait、Landscape Left、Landscape Rightをサポートすること
- SwiftUIが提供するSafe Area内の利用可能領域を配置基準とすること
- 背景色は画面端まで延ばしてよいが、主要UIはSafe Area内へ収めること
- 3×3の9ボタンはすべて同じ外形寸法にすること
- すべての操作領域を44×44ポイント以上にすること
- リング、候補グリッド、主要操作の独立した領域間に8ポイント以上の空きを設けること
- `Pomodoro`、`To HH:mm`、`Start 60m Pomodoro` がクリップしないこと
- Focus画面の既存Editボタン位置を動かさないこと
- 完了後の追加ボタンはリングとEditの間へ配置すること
- タイトル、Aboutボタン、リング、候補グリッド、操作ボタンを重ねないこと
- 選択状態を色だけに依存させず、枠線でも判別できること

## 14. 検証条件

最低限、以下の端末と向きで確認する。

- iPhone SE 第3世代: Portrait、Landscape Left、Landscape Right
- iPhone 17 Pro Max: Portrait、Landscape Left、Landscape Right

主要な確認項目:

- 起動時はScheduled選択
- Scheduled候補8個＋右下Pomodoroの3×3配置
- 9ボタンの外形寸法が同じ
- `To` 表記がリングとボタンで一致
- Scheduledプレビューがリアルタイムに変化
- Scheduledプレビューが0秒で次候補へ進む
- Pomodoro設定リングが停止している
- Pomodoro時間を5〜60分、5分刻みで変更できる
- リング上のタップで対応するPomodoro時間を直接設定できる
- 上下限で循環しない
- 設定値がアプリ再起動後も保持される
- Scheduled、Pomodoro、Breakが0秒で停止する
- Pomodoro／Breakリングが60分基準で表示される
- 完了種別に対応する追加ボタンだけが表示される
- 次区間がユーザー操作なしで始まらない
- PomodoroからEditへ戻るとPomodoro選択を維持する
- BreakからEditへ戻るとScheduled選択になる
- 回転前後で選択状態、Pomodoro設定値、正式な終了日時を維持する
- Light／Dark appearanceで色と選択状態を判別できる
- VoiceOverでPomodoro時間を5分ずつ調整できる
- Edit / Scheduled、Edit / Pomodoro、Focus / Scheduled、Focus / Pomodoro、Pomodoro完了、Break完了、情報シートの各状態で重なり、クリップ、画面外表示がない
- `0m 00s`、`10m 00s`、`60m 00s`、`Start 5m Break`、`Start 60m Pomodoro`を折り返しや意図しない省略なしで表示する
- 情報シートでStoreKitのローカライズ済み価格を表示する
- チップ購入の成功、キャンセル、承認待ち、失敗、商品取得不可からの再試行でタイマー機能が変化しない

### 14.1 自動検証と最終確認の役割

検証を以下の3層に分ける。

1. Unit Test
   - 固定日時を使ったScheduled候補生成
   - 時刻境界、残り秒数、表示文字列
   - Scheduledリングの色フェーズ境界
2. Automation UI Test
   - iPhone SE 第3世代とiPhone 17 Pro Maxを実行先として切り替える
   - Portrait、Landscape Left、Landscape Right
   - Light／Dark appearance
   - Edit／Focus／完了状態と手動継続
3. Release相当の最終確認
   - 実際の時計を使うScheduled終了を代表1ケース確認する
   - リリース時点で準備できる実機を使って最終確認する

Automation UI Testは、待ち時間を短縮する目的で製品とは異なるカウントダウン時間を使用してよい。ただし、時間以外の残り時間計算、色判定、完了判定、次状態への遷移は製品と同じコードを使用する。

短縮Scheduledの役割を区別する。

- 3秒: 終了直前色、0秒停止、Edit復帰
- 12秒: 警告色から終了直前色、0秒停止
- 65秒: 通常色、警告色、終了直前色、0秒停止の自然遷移
- 60秒、59秒、10秒、9秒、0秒: Unit Testで色フェーズの境界を即時確認

3秒のScheduledテストだけでリングの全色遷移を検証済みとは扱わない。

### 14.2 Automationビルド

自動検証には `StartLine-Automation` Schemeと `Automation` Build Configurationを使用する。

Automation専用処理は `STARTLINE_AUTOMATION` コンパイル条件内に限定し、Releaseでは起動引数の解析コードをコンパイルしない。Archiveは常にRelease Build Configurationを使用する。

Automationビルドでは以下の起動引数を使用できる。

```text
-startline-scheduled-seconds 65
-startline-pomodoro-seconds 3
-startline-break-seconds 1
-startline-tip-test-price ¥200
-startline-tip-test-result success
-startline-tip-test-unavailable
-startline-tip-test-unavailable-once
```

テスト用時間は1〜3600秒だけを受け付け、Pomodoroの保存値や他の製品設定には書き込まない。

チップジャーのAutomation UI Testでは、`-startline-tip-test-result` に `success`、`pending`、`failure`、`cancelled` のいずれかを指定する。継続的な商品取得不可は `-startline-tip-test-unavailable`、初回だけの取得不可と再試行による回復は `-startline-tip-test-unavailable-once` で再現し、StoreKit外部状態に依存せずUI分岐を検証する。この注入処理は `STARTLINE_AUTOMATION` 内だけへ置く。StoreKitとの結合はローカルStoreKit Configurationおよび申請前のSandbox購入で別途確認する。

AutomationビルドとReleaseビルドは厳密には異なるバイナリーである。Automationで反復検証を高速化した後、Release相当ビルドで実時計との結合と主要動作を最終確認する。

## 15. プロジェクト上の制約

- 既存Xcodeプロジェクトを使用し、新規プロジェクトを作成しない
- Bundle Identifier、署名、deployment target、capabilityを無断で変更しない
- 外部依存を追加しない
- Scheduledの既存動作を不用意に変更しない
- 変更は小さくレビュー可能な単位に保つ
