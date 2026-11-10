# ⚡ ESP32-C3 BLE Remote Controller

Sistem kontrol jarak jauh (remote control) berbasis **ESP32-C3 Super Mini** dan aplikasi **Flutter** via Bluetooth Low Energy (BLE). Proyek ini dirancang untuk mengontrol sakelar daya utama (*Power Up / Relay 12V*), memantau telemetri tegangan secara *real-time*, serta dilengkapi fitur *Auto-Charging* pintar dan pengaman otomatis (*Proximity Cut-Off*).

---

## 🌟 Fitur Utama

- **Remote Power Switch:** Kontrol Relay 12V *Power Up* via BLE (ON/OFF) dengan isolasi Optocoupler (PC817).
- **Auto Cut-Off (Keamanan):** Relay otomatis memutus arus daya jika koneksi BLE terputus atau pengguna menjauh.
- **Monitoring Telemetri 3-Jalur (Real-time):**
  - **$V_{\text{in}}$:** Pemantauan tegangan input daya utama / Aki (maks. 36V).
  - **$V_{\text{out}}$:** Pemantauan tegangan output booster Power Up (maks. 36V).
  - **$V_{\text{bat}}$:** Pemantauan tegangan & persentase kapasitas baterai internal ESP32.
- **Smart Auto-Charging System:** 
  - Menggunakan sirkuit 4x BC547 Paralel dengan kontrol otomatis berbasis ambang persentase baterai ($<30\%$ ON, $\ge85\%$ OFF) untuk menjaga keawetan baterai LiPo.
- **Fitur Alarm / Buzzer:** Pemicu nada alarm dari aplikasi untuk indikator status / pencarian lokasi modul.
- **Akurasi Tinggi:** Menggunakan metode *Oversampling ADC* (30x sample) + penyesuaian attenuasi 11dB untuk pembacaan voltase yang stabil dan presisi.

---

## 🛠️ Arsitektur & Spesifikasi Hardware

| Komponen | Spesifikasi / Konfigurasi |
| :--- | :--- |
| **Microcontroller** | ESP32-C3 Super Mini |
| **Driver Relay 12V** | Optocoupler PC817 (Low-Side Switching + Resistor 220Ω-330Ω di Anode) |
| **Sirkuit Charging** | Modulator Step-Down 5V + Dioda 1N4007 + Resistor Pembatas 4.7Ω 2W + 4x BC547 Paralel (*Low-Side Switch* di input regulator) + Resistor Emiter Ballast 2.2Ω |
| **Baterai Backup** | LiPo/Polymer 3.7V 500mAh + BMS Internal |
| **Pembagi Tegangan 1** | $V_{\text{in}}$ & $V_{\text{out}}$: Resistor $100\text{k}\Omega$ & $10\text{k}\Omega$ (Skala Max 36V) |
| **Pembagi Tegangan 2** | $V_{\text{bat}}$: Resistor $10\text{k}\Omega$ & $10\text{k}\Omega$ (Titik tengah terhubung ke GPIO 2) |
| **Alarm / Buzzer** | Buzzer Pasif via Transistor BC547 |

---

## 📌 Alokasi Pinout ESP32-C3

```text
  [GPIO 0] ◄── Pembagi Tegangan 100K/10K (Vin Aki / Power Up)
  [GPIO 1] ◄── Pembagi Tegangan 100K/10K (Vout Booster)
  [GPIO 2] ◄── Pembagi Tegangan 10K/10K (Vbat LiPo - Titik Tengah Node)
  [GPIO 3] ───► Resistor 220Ω-330Ω ──► Pin 1 Optocoupler (Relay 12V)
  [GPIO 4] ───► Resistor 10K ───────► Basis BC547 (Buzzer Pasif)
  [GPIO 5] ───► 4x Resistor 1K ─────► Basis 4x BC547 Paralel (Auto-Charge)
