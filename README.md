# Leafony AZ01C USB-C シリアル変換リーフ

## 概要

Leafony AZ01C は、Leafony Bus 向けの USB-C to UART リーフである。USB 接続時は FT234XD による USB-UART 変換と、USB VBUS から生成した 3.3V 電源を Leafony Bus へ供給する。

USB 未接続時に他リーフ側から 3.3V が供給される構成でも、UART 信号線と 3.3V 電源ラインのバックフィードを抑えることを設計方針とする。信号線は TS3A4741 で物理的に切断し、電源ラインは TPS6282533 出力と Leafony Bus 3.3V の間に MAX40200AUK+T ideal diode を入れて逆流を遮断する。

## 主な用途

- Leafony リーフへの MCU 書き込み
- Leafony リーフの UART デバッグ
- USB から Leafony Bus への 3.3V 電源供給

## 仕様

### 電気的仕様

| 項目 | Min | Typ | Max | 単位 | 備考 |
|---|---:|---:|---:|---|---|
| USB VBUS 入力電圧 | 4.5 | 5.0 | 5.5 | V | USB-C UFP/Sink として使用 |
| Buck 出力電圧 `P3V3_BUCK` | 3.27 | 3.30 | 3.33 | V | TPS6282533 固定 3.3V、精度 ±1% |
| Leafony Bus 3.3V 出力 | - | 3.26 | - | V | MAX40200 通過後。500mA 時は約 43mV 低下 |
| Leafony Bus 3.3V 出力電流 | - | - | 500 | mA | TPS6282533 は 2A 品、MAX40200 は 1A 品。本設計では 500mA 上限 |
| MAX40200 逆方向リーク | - | 0.07 | 1.5 | µA | Leafony Bus +3.3V から `P3V3_BUCK` 方向 |
| UART 通信速度 | 300 | - | 3,000,000 | baud | FT234XD 仕様 |
| UART I/O 論理電圧 | - | 3.3 | - | V | FT234XD VCCIO を Leafony Bus 3.3V rail に接続 |
| USB 接続時アイドル消費 | - | 12 | - | mA | FT234XD、Buck、MAX40200、LED 周辺を含む概算 |
| 動作温度範囲 | -40 | 25 | +85 | ℃ | 構成部品の最小共通範囲 |

### 機械的仕様

| 項目 | 仕様 |
|---|---|
| 外形寸法 | Leafony 20mm x 20mm |
| 基板厚 | 0.8mm 推奨 |
| 層数 | 4層 |
| 実装 | 両面実装 |
| USB コネクタ | Hirose CX90M-16P |
| 外部接続 | Leafony Bus 29ピン |

### USB 仕様

| 項目 | 仕様 |
|---|---|
| USB 規格 | USB 2.0 Full Speed (12Mbps) |
| コネクタ | USB Type-C |
| Type-C ロール | UFP / Sink Only |
| CC 抵抗 | CC1, CC2 それぞれ 5.1kΩ で GND へプルダウン |
| USB PD | 非対応 |
| ドライバ | FTDI VCP / D2XX |

## 回路設計

### 電源アーキテクチャ

```
USB VBUS 5V
  |
  +-- FB1 ---------------------> FT234XD.VCC
  |                                |
  |                                +--> FT234XD.3V3OUT
  |                                      |
  |                                      +--> TS3A4741.IN1/IN2
  |
  +----------------------------> TPS6282533.VIN
                                   |
                                   +-- EN = VIN
                                   |
                                   +-- SW -- L1 --> P3V3_BUCK
                                                   |
                                                   +--> MAX40200AUK+T
                                                        VDD = P3V3_BUCK
                                                        EN  = VDD
                                                        OUT = +3.3V rail
                                                              |
                                                              +--> FT234XD.VCCIO
                                                              +--> TS3A4741.V+
                                                              +--> LED1 pull-up
                                                              +--> Leafony Bus 3.3V (CN1 F1/B1)
```

`P3V3_BUCK` は TPS6282533 と MAX40200 の間のローカル電源レール、`+3.3V rail` は MAX40200 後段の Leafony Bus 側電源レールとする。

MAX40200 を入れることで、USB 未接続時に他リーフから Leafony Bus 3.3V が供給されても、`+3.3V rail -> P3V3_BUCK -> TPS6282533.SW/VIN -> VBUS` 方向の逆流を遮断する。MAX40200 の電圧降下により、Leafony Bus 側の実効電圧は TPS6282533 出力より低くなる。

### 動作状態

| 状態 | 電源 | UART 信号線 | 備考 |
|---|---|---|---|
| USB 接続、外部 3.3V なし | TPS6282533 から Leafony Bus へ 3.3V 供給 | TS3A4741 ON | 通常の USB-UART 動作 |
| USB 未接続、外部 3.3V なし | VBUS=0V、`P3V3_BUCK`=0V、Leafony Bus 3.3V=0V | TS3A4741 OFF | 基板側は実質停止 |
| USB 未接続、他リーフから 3.3V 供給 | Leafony Bus 3.3V は外部から印加。MAX40200 が Buck/VBUS 方向の逆流を遮断 | TS3A4741 OFF | FT234XD.3V3OUT=0V のためスイッチ制御は OFF |
| USB 接続、他リーフも 3.3V 供給 | 電源競合に注意 | TS3A4741 ON | 複数電源の同時接続を許容する場合はシステム側で電源 ORing 方針を確認 |

USB 未接続で他リーフから 3.3V が供給される場合、MAX40200 後段の `+3.3V rail` 配下である FT234XD.VCCIO、TS3A4741.V+、LED1 pull-up には電圧がかかる。一方で FT234XD.VCC は VBUS 由来のため 0V であり、FT234XD.3V3OUT も 0V となる。UART の TX/RX は TS3A4741 により切断される。

### バックフィード対策

バックフィード経路は大きく 2 つに分ける。

| 経路 | リスク | 対策 |
|---|---|---|
| UART TX/RX 信号線 | 他リーフ MCU の TX/RX が FT234XD の I/O 保護素子を通じて FT234XD 側を半端に給電する | TS3A4741 を TX/RX に直列挿入し、USB 未接続時は OFF |
| 3.3V 電源ライン | 他リーフの 3.3V が TPS6282533 の SW/L1 側から VIN/VBUS へ逆流する | MAX40200AUK+T を `P3V3_BUCK` と Leafony Bus 3.3V の間に直列挿入 |

TS3A4741 の IN1/IN2 は FT234XD.3V3OUT に接続する。USB 接続時は FT234XD が動作して 3V3OUT が High になり、TX/RX が接続される。USB 未接続時は 3V3OUT が 0V になり、TX/RX が物理的に切断される。

MAX40200 は VDD を `P3V3_BUCK`、OUT を Leafony Bus 3.3V、EN を VDD に接続する。USB 接続時は TPS6282533 から Leafony Bus へ給電し、USB 未接続時は Leafony Bus 3.3V から Buck/VBUS 側への逆流を遮断する。

### USB Type-C UFP 構成

| 信号 | 処理 |
|---|---|
| CC1, CC2 | 各々 5.1kΩ で GND へプルダウン |
| VBUS | A4, A9, B4, B9 をまとめて 5V 入力へ接続 |
| GND | A1, A12, B1, B12 を GND プレーンへ接続 |
| D+, D- | A面/B面の同名信号を基板上で接続し、FT234XD へ配線 |
| SBU1, SBU2 | NC |

USB PD には対応しない。CC 抵抗のみで USB Type-C の Sink/UFP として認識させる。

### ESD 保護

D+/D- ラインには USBLC6-2P6 を配置する。USB-C コネクタ近傍に置き、D+/D- へのスタブを短くする。VBUS は FB1 を通して基板内へ引き込む。必要に応じて、VBUS 用 TVS ダイオードの追加余地を検討する。

### 通信インジケータ LED

FT234XD の CBUS0 を FT_PROG で `TX&RXLED#` に設定し、LED1 を TX/RX 共用インジケータとして使用する。

## Leafony Bus ピンアサイン

| ピン名 | F面 / B面 | 信号 | 用途 |
|---|---|---|---|
| 3.3V | F1 / B1 | +3.3V rail | MAX40200 通過後の 3.3V 電源。USB から他リーフへ最大 500mA 供給 |
| VBUS | F3 / B3 | VBUS 5V | USB VBUS。必要な他リーフで参照可能 |
| D0 | F18 / B18 | UART TX | FT234XD TXD から他リーフ MCU RX へ。TS3A4741 Ch1 経由 |
| D1 | F20 / B20 | UART RX | 他リーフ MCU TX から FT234XD RXD へ。TS3A4741 Ch2 経由 |
| GND | F27 / B27 | GND | 共通グラウンド |

## 主要部品

| Ref | 型番 | 役割 |
|---|---|---|
| U1 | TS3A4741DCNR | UART TX/RX 切断用 2ch SPST アナログスイッチ |
| U2 | USBLC6-2P6 | USB D+/D- ESD 保護 |
| U3 | FT234XD | USB-UART ブリッジ |
| U4 | TPS6282533DMQR | 5V から 3.3V を生成する Buck コンバータ |
| U5 | MAX40200AUK+T | 3.3V 電源ライン逆流防止用 ideal diode |
| J1 | CX90M-16P | USB Type-C レセプタクル |
| L1 | 0.47uH | TPS6282533 用インダクタ |
| FB1 | 600Ω @ 100MHz | VBUS 入力ノイズ抑制 |

## ソフトウェア

### ドライバ

FTDI 公式の VCP または D2XX ドライバを使用する。

| OS | ドライバ | 備考 |
|---|---|---|
| Windows 10/11 | 標準ドライバ自動インストール | 必要に応じて FTDI 公式ドライバを使用 |
| macOS | 標準 Apple FTDI ドライバ | macOS 10.9 以降 |
| Linux | `ftdi_sio` | 多くのディストリビューションで自動認識 |

### 初期設定 (FT_PROG)

量産前に FT234XD 内蔵 MTP へ以下を設定する。

| パラメータ | 設定値 | 備考 |
|---|---|---|
| CBUS0 Function | `TX&RXLED#` | LED1 通信インジケータ用 |
| Manufacturer Name | 任意 | 例: `mitdir` |
| Product Description | 任意 | 例: `Leafony USB-UART Bridge` |
| Serial Number | ユニーク値 | 複数台接続時の識別用 |
| USB Vendor ID | `0x0403` | FTDI デフォルト |
| USB Product ID | `0x6015` | FT-X デフォルト |

## 設計反映メモ

この README は、MAX40200AUK+T を追加した電源構成を前提とする。KiCad 回路図、PCB、BOM を更新する場合は、少なくとも以下を反映する。

- `U5: MAX40200AUK+T` を追加する
- TPS6282533 の出力側を `P3V3_BUCK` とし、Leafony Bus 側 `+3.3V rail` と分離する
- MAX40200 の VDD を `P3V3_BUCK`、OUT を `+3.3V rail`、EN を VDD に接続する
- Leafony Bus 3.3V、FT234XD.VCCIO、TS3A4741.V+、LED1 pull-up は MAX40200 後段の `+3.3V rail` に接続する
- BOM に MAX40200AUK+T と対応フットプリントを追加する

あわせて以下を実機またはデータシートで確認する。

- USB 未接続かつ他リーフから 3.3V が供給される状態で、FT234XD.VCC=0V、FT234XD.VCCIO=3.3V となることを許容できるか
- USB 接続中に他リーフ側の 3.3V 電源も同時に有効になるシステム構成を許容するか
- MAX40200 の電圧降下込みで、Leafony Bus 側 3.3V rail の最小電圧が接続先リーフの要求を満たすか
