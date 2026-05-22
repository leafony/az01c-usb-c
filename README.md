# Leafony AZ01C USB-C シリアル変換リーフ

## 概要

本基板は、Leafony USB Type-C シリアル変換機能を提供する **USB-C to UART リーフ** である。USB接続時は FT234XD による USB-UART 変換と 3.3V 電源供給を Leafony Bus 経由で他リーフへ提供し、USB未接続時は消費電流が最小限になるよう設計されている。

## 　主な用途

- Leafony リーフへのMCU書き込み・デバッグ用 USB シリアル変換
- Leafony Bus 経由の 3.3V 電源供給（USB から最大 500mA）

## 仕様

### 電気的仕様

| 項目 | Min | Typ | Max | 単位 | 備考 |
|---|---|---|---|---|---|
| USB VBUS入力電圧 | 4.5 | 5.0 | 5.5 | V | USB 2.0規格準拠 |
| Buck出力電圧 (P3V3_BUCK) | 3.27 | 3.30 | 3.33 | V | TPS6282533 ±1% |
| Leafony Bus 3.3V出力 | - | 3.26 | - | V | MAX40200通過後。500mA時の代表電圧降下43mVを含む |
| 3.3V出力電流 (最大) | - | - | 500 | mA | TPS6282533は2A品、MAX40200は1A品。本設計で500mA指定 |
| UART通信ボーレート | 300 | - | 3,000,000 | baud | FT234XD仕様 |
| USB未接続時消費電流 | - | ~0 | - | µA | VBUS/外部3.3Vとも無印加時 |
| MAX40200逆方向リーク | - | 0.07 | 1.5 | µA | Leafony Bus +3.3V → P3V3_BUCK方向 |
| USB接続時アイドル消費 | - | 12 | - | mA | FT234XD 8mA + Buck Iq 4µA + MAX40200 Iq 7µA + α |
| UART I/O論理電圧 | - | 3.3 | - | V | VCCIOを3.3V railに固定 |
| 動作温度範囲 | -40 | 25 | +85 | ℃ | 構成部品の最小共通範囲 |

### 機械的仕様

| 項目 | 仕様 |
|---|---|
| 外形寸法 | Leafony  20×20 mm |
| 基板厚 | 0.8 mm (推奨) |
| 層数 | 4層 |
| 実装 | 両面実装 |
| USBコネクタ | Hirose CX90M-16P |
| 外部接続 | Leafony Bus 29ピン |

### USB仕様

| 項目 | 仕様 |
|---|---|
| USB規格 | USB 2.0 Full Speed (12 Mbps) |
| コネクタ | USB Type-C (UFP: Upstream Facing Port) |
| CC抵抗 | 5.1kΩ × 2 (CC1, CC2にそれぞれ独立) |
| 電源ロール | Sink Only (Power Source機能なし) |
| USB PD | 非対応 |
| ドライバ | FTDI VCP / D2XX (Windows, macOS, Linux) |

---

## 回路設計

### 電源アーキテクチャ

本設計の中核となる低消費電力アーキテクチャ：

```
[USB VBUS 5V] ──┬──► FB1 ──► FT234XD.VCC
                │                 (USB接続時のみ動作)
                │                       │
                │                       └► FT234XD.3V3OUT (Pin3)
                │                          ─► TS3A4741.IN1/IN2
                │                            (FT234XD稼働時のみ Switch ON)
                │
                └──► TPS6282533.VIN
                        EN = VIN直結 (USB接続で自動ON)
                        DCS-Control自動PFM/PWM切替
                        出力: P3V3_BUCK 3.3V / 500mA
                              │
                              └──► MAX40200AUK+T ideal diode
                                      VDD/IN = P3V3_BUCK
                                      EN = VDD/IN
                                      OUT = +3.3V rail
                                            │
                                            ├──► FT234XD.VCCIO
                                            ├──► TS3A4741.V+
                                            ├──► LED1プルアップ
                                            └──► CN1 F1/B1 (Leafony Bus 3.3V)
```

**USB未接続時の動作:**

- VBUS = 0V → TPS6282533 EN = 0V → Buck完全OFF
- FT234XD VCC = 0V → FT234XD完全OFF → 3V3OUT = 0V
- 他リーフからLeafony Bus +3.3Vが印加されても、MAX40200が+3.3V rail → P3V3_BUCK → TPS6282533.SW/VIN方向の逆流を遮断
- TS3A4741 IN1/IN2 = 0V → 全chOFF → TX/RX物理切断

### バックフィード対策

MCU側（他リーフ）が3.3V電源で動作し続けているとき、以下2種類の「バックフィード」が発生する可能性がある。

1. TX信号がFT234XDのRXDピン内部ESDダイオードを通ってVCCに逆流する信号ライン経由のバックフィード
2. Leafony Bus +3.3VがTPS6282533のSW/L1側からVIN(VBUS)へ逆流する電源ライン経由のバックフィード

信号ライン経由のバックフィードを防ぐため、TS3A4741(2ch SPSTアナログスイッチ)をTX/RXラインに直列挿入している。アナログスイッチ(U1)の制御IN1/IN2をFT234XDの3V3OUT(内部LDO出力, Pin3)に接続することで、USB接続時(FT234XD稼働時)のみ自動的にスイッチON、USB未接続時は自動OFFとなる。専用制御信号は不要。

電源ライン経由のバックフィードを防ぐため、TPS6282533の3.3V出力(P3V3_BUCK)とLeafony Bus +3.3V railの間にMAX40200AUK+Tを直列挿入する。MAX40200のVDD/INをP3V3_BUCK、OUTをLeafony Bus +3.3V rail、ENをVDD/INに接続する。これによりUSB接続時はTPS6282533からLeafony Busへ給電し、USB未接続時に他リーフから+3.3Vが印加されてもTPS6282533およびVBUS側へ逆流しない。

MAX40200の代表電圧降下は500mA時43mV、1A時85mVである。本設計ではLeafony Busへの供給電流を500mA以下に制限し、3.3V railの実効電圧はTPS6282533出力からMAX40200の電圧降下を差し引いた値として扱う。

### USB Type-C UFP構成

USB-Cポートをデバイス側(UFP)として動作させるため、以下のとおり構成する：

| 信号 | 処理 |
|---|---|
| CC1, CC2 | 各々独立に5.1kΩでGNDへプルダウン (Rd) |
| VBUS | 4ピン(A4, A9, B4, B9)すべてをまとめて5V入力に接続 |
| GND | 4ピン(A1, A12, B1, B12)すべてをGNDプレーンに接続 |
| D+, D- | A/B両面同士を基板上で接続し1本化 |
| SBU1, SBU2 | 未接続 (NC) |

USB PD非対応のため、CC抵抗のみで識別完了。

### ESD保護

D+/D-ラインにUSBLC6-2P6 (SOT-666) を配置。USB-Cコネクタ近傍に最短スタブで接続。VBUSにはフェライトビーズのみ（コスト優先、必要に応じてTVSダイオード追加余地あり）。

### 通信インジケータLED

FT234XDのCBUS0ピンをFT_PROGで `TX&RXLED#` モードに設定し、LED1を駆動する。TX/RXいずれかで点灯する兼用インジケータ。

### Leafony Bus ピンアサイン

| ピン名 | F面 / B面 | 信号 | 用途 |
|---|---|---|---|
| 3.3V | F1 / B1 | +3.3V (MAX40200通過後) | 他リーフへ給電 (最大 500mA)、USB未接続時の逆流遮断 |
| VBUS | F3 / B3 | VBUS (5V) | 他リーフが必要なら使用可 |
| D0 | F18 / B18 | UART TX (FT234XD → 他リーフ MCU の RX) | TS3A4741 Ch1 経由 |
| D1 | F20 / B20 | UART RX (他リーフ MCU の TX → FT234XD) | TS3A4741 Ch2 経由 |
| GND | F27 / B27 | GND | 共通グラウンド |

---

## ソフトウェア

### ドライバ

FTDI公式のVCP(Virtual COM Port)またはD2XXドライバを使用する。

| OS | ドライバ | 備考 |
|---|---|---|
| Windows 10/11 | 標準ドライバ自動インストール | FTDI社サイトから最新版入手可 |
| macOS | 標準Apple FTDIドライバ | macOS 10.9以降 |
| Linux | カーネル内蔵 ftdi_sio | ほぼすべてのディストリビューションで自動認識 |

### 初期設定 (FT_PROG)

量産前に各基板のFT234XD内蔵EEPROMに以下を書き込む：

| パラメータ | 設定値 | 備考 |
|---|---|---|
| CBUS0 Function | `TX&RXLED#` | LED1通信インジケータ用 |
| Manufacturer Name | (任意) | 例: "mitdir" |
| Product Description | (任意) | 例: "USB-UART Bridge" |
| Serial Number | ユニーク値 | 複数台接続時の識別用 |
| USB Vendor ID | 0x0403 (FTDIデフォルト) | 変更不要 |
| USB Product ID | 0x6015 (FT-Xデフォルト) | 変更不要 |

書き込み方法: FT_PROGツール (FTDI公式、Windows) をUSB経由で使用。
