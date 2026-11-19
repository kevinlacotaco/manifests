#!/bin/bash
set -euo pipefail

textfile_dir="${TEXTFILE_DIR:-/var/lib/node_exporter/textfile_collector}"
tmp_file="${textfile_dir}/raspberry_pi.prom.tmp"
out_file="${textfile_dir}/raspberry_pi.prom"

temp_c="0.0"
if [[ -r /sys/class/thermal/thermal_zone0/temp ]]; then
  temp_raw="$(cat /sys/class/thermal/thermal_zone0/temp)"
  temp_c="$(awk -v t="${temp_raw}" 'BEGIN { printf "%.1f", t / 1000 }')"
fi

{
  echo "# HELP raspberry_pi_temp_celsius Raspberry Pi SoC temperature in degrees Celsius."
  echo "# TYPE raspberry_pi_temp_celsius gauge"
  echo "raspberry_pi_temp_celsius ${temp_c}"

  if command -v vcgencmd >/dev/null 2>&1; then
    throttled_hex="$(vcgencmd get_throttled | sed -n 's/^throttled=//p')"
    if [[ -n "${throttled_hex}" ]]; then
      throttled=$((throttled_hex))
      echo "# HELP raspberry_pi_throttled_raw Raspberry Pi throttled bitmask from vcgencmd get_throttled."
      echo "# TYPE raspberry_pi_throttled_raw gauge"
      echo "raspberry_pi_throttled_raw ${throttled}"
      for entry in \
        "under_voltage_now:0" \
        "arm_frequency_capped_now:1" \
        "currently_throttled:2" \
        "soft_temperature_limit_now:3" \
        "under_voltage_since_boot:16" \
        "arm_frequency_capped_since_boot:17" \
        "throttled_since_boot:18" \
        "soft_temperature_limit_since_boot:19"; do
        name="${entry%%:*}"
        bit="${entry##*:}"
        value=$(( (throttled >> bit) & 1 ))
        echo "# HELP raspberry_pi_${name} Raspberry Pi ${name} flag (1 = active)."
        echo "# TYPE raspberry_pi_${name} gauge"
        echo "raspberry_pi_${name} ${value}"
      done
    fi
  fi
} > "${tmp_file}"

chmod 0644 "${tmp_file}"
mv "${tmp_file}" "${out_file}"
