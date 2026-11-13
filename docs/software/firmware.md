# Firmware

## Riêng máy (ký Google) — trích từ factory image `crosshatch-sp1a.210812.016.c2` (12.0.0, 06/2022, bản cuối)
Factory zip SHA-256 `27f59137f9802f6913f92d820bb0cbd80793f6e4a80c5f05e1242810903d4aea` (bản sao trong `archive/*/stock/`).
Đích: `/lib/firmware/qcom/sdm845/Google/blueline/` (DTS dùng chung "blueline" cho cả 3 XL).

| File | Nguồn trong factory | Cách | Dùng cho |
|---|---|---|---|
| `adsp.mbn` | vendor.img `/firmware/adsp.mdt+b00..b15` | gộp (`pil_squash.py`) | ADSP |
| `cdsp.mbn` | vendor.img `/firmware/cdsp.mbn` | copy | CDSP |
| `mba.mbn` | modem.img `/image/mba.mbn` | copy | modem MBA |
| `modem.mbn` | modem.img `/image/modem.mdt+b00..b29` | gộp (67 MB) | MPSS |
| `venus.mbn` | vendor.img | copy | video |
| `a630_zap.mbn` | vendor.img `a630_zap.mdt+b00..b02` | gộp | GPU zap shader |
| `ipa_fws.mbn` | vendor.img `ipa_fws.mdt+b00..b04` | gộp | IPA |
| `wlanmdsp.mbn` | vendor.img | copy | firmware Wi-Fi (modem nạp qua tqftpserv) |
| `adspr.jsn adspua.jsn cdspr.jsn modemr.jsn modemuw.jsn` | modem + vendor | copy | pd-mapper |

- **modem.img không nằm trong image-*.zip** mà trong `radio-crosshatch-*.img` dạng **FBPK v1** (1 entry "modem", FAT16, data @0x8C)
  → `scripts/lib/fbpk_unpack.py` (CRC32 khớp).
- vendor.img là Android sparse → `scripts/lib/simg2img.py` → `debugfs rdump /firmware`.
- Phiên bản: `MPSS.AT.4.0.c2.17-00182-SDM845_GEN_PACK-1` (`ver_info.txt`).
- Bản BT/board riêng máy (chưa dùng, để so sánh): `crbtfw21.tlv`, `crnv21.bin`, `bdwlan-crosshatch.bin`, `a630_gmu.bin`, `a630_sqe.fw` → `firmware/device-extra/`.

## Chung — linux-firmware tag `20261019` (`scripts/12-upstream-firmware.sh`)
`ath10k/WCN3990/hw1.0/{board-2.bin,firmware-5.bin,notice.txt_wlanmdsp}`, `qcom/a630_sqe.fw`, `qcom/a630_gmu.bin`,
`qca/crbtfw21.tlv`, `qca/crnv21.bin`; + `regulatory.db` (gói wireless-regdb).
⚠️ Gói `linux-firmware` noble (20240318) quá cũ → không dùng; `board-2.bin` phải có `variant=Google_crosshatch`.

Checksum: `generated/firmware.sha256`, `archive/*/firmware/SHA256SUMS-*`.
