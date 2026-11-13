-- Pixel 3 XL: loa CS35L36 x2 qua QUAT TDM (card "Pixel 3 XL").
-- Bỏ ACP (dò profile kiểu PulseAudio làm WirePlumber 0.4 không chọn được sink mặc định:
-- profile về "off", "no target node available"). use-acp=false -> node ALSA trực tiếp hw:0,0.
-- DSP chỉ nhận S16_LE; buffer playback >= ~522 KB bị ADSP từ chối -> giữ buffer nhỏ.
table.insert(alsa_monitor.rules, {
  matches = { { { "device.name", "equals", "alsa_card.platform-sound" } } },
  apply_properties = {
    ["api.alsa.use-acp"] = false,
    ["device.description"] = "Loa Pixel 3 XL",
  },
})
table.insert(alsa_monitor.rules, {
  matches = { { { "node.name", "matches", "alsa_output.platform-sound.*" } } },
  apply_properties = {
    ["api.alsa.period-size"] = 1024,
    ["api.alsa.period-num"] = 4,
    ["api.alsa.headroom"] = 0,
    ["audio.format"] = "S16LE",
    ["audio.rate"] = 48000,
    ["audio.channels"] = 2,
    ["audio.position"] = "FL,FR",
    ["node.description"] = "Loa Pixel 3 XL",
    ["priority.session"] = 1000,
    ["priority.driver"] = 1000,
  },
})
