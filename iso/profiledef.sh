# GnegnoliOS overrides, appended by build.sh to the releng profiledef.sh of
# the installed archiso, so boot modes always match the mkarchiso version.
# shellcheck disable=SC2034,SC2154

iso_name="gnegnolios"
iso_label="GNEGNOLIOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="GnegnoliOS"
iso_application="GnegnoliOS Live / Install"
install_dir="gnegnolios"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')

file_permissions=(
  ["/usr/local/bin/gnegnolios-install"]="0:0:755"
  ["/usr/local/bin/gnegnolios-live-setup"]="0:0:755"
  ["/usr/local/bin/gnegnolios-flatpaks"]="0:0:755"
)
