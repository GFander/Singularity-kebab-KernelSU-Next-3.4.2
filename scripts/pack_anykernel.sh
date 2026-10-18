#!/usr/bin/env bash
# 把新编出来的 Image 塞进作者发布的 AnyKernel3 骨架里，重新打包成可刷的 zip。
#
# 需要的环境变量：
#   AK3_RELEASE   AnyKernel3 骨架来源 release tag（如 V17）
#   AK3_ASSET     骨架 zip 文件名
#   KSU_REF       本次编进内核的 KernelSU-Next tag（写进 anykernel.sh 提示文案）
#   KERNEL_REF    内核源码 ref（写进提示文案）
#   LOCALVERSION_ST 版本后缀（写进提示文案）
#   RUNNER_TEMP   GitHub Actions 自动提供
#
# 输入文件：
#   $RUNNER_TEMP/artifacts/Image-KSU    必需
#   $RUNNER_TEMP/artifacts/Image-NoKSU  可选
#
# 输出：
#   $RUNNER_TEMP/artifacts/Singularity-kebab-<ksu_ref>-<日期>.zip

set -euo pipefail

: "${AK3_RELEASE:?}"
: "${AK3_ASSET:?}"
: "${KSU_REF:?}"
: "${KERNEL_REF:?}"
: "${LOCALVERSION_ST:?}"
: "${RUNNER_TEMP:?}"

ART="$RUNNER_TEMP/artifacts"
WORK="$RUNNER_TEMP/ak3"
IMAGE_KSU="$ART/Image-KSU"
IMAGE_NOKSU="$ART/Image-NoKSU"

[ -s "$IMAGE_KSU" ] || { echo "!! 缺少 $IMAGE_KSU"; exit 1; }

URL="https://github.com/The-Anomalist/Singularity/releases/download/${AK3_RELEASE}/${AK3_ASSET}"
echo "==> 下载 AnyKernel3 骨架: $URL"
rm -rf "$WORK" && mkdir -p "$WORK"
curl -sSL --retry 5 --retry-delay 5 -o "$RUNNER_TEMP/ak3-base.zip" "$URL"
unzip -q "$RUNNER_TEMP/ak3-base.zip" -d "$WORK"

# 骨架完整性检查：这几个文件缺一个都不该继续
for f in anykernel.sh META-INF/com/google/android/update-binary "devices/kebab/dtb.img" "devices/kebab/dtbo.img"; do
  [ -e "$WORK/$f" ] || { echo "!! 骨架缺少 $f"; exit 1; }
done

echo "==> 替换内核镜像"
cp -f "$IMAGE_KSU" "$WORK/Image-KSU"
if [ -s "$IMAGE_NOKSU" ]; then
  cp -f "$IMAGE_NOKSU" "$WORK/Image-NoKSU"
else
  echo "   （没有 No-KSU 镜像，沿用骨架里自带的旧 Image-NoKSU）"
fi

# 让 recovery 里显示的提示带上版本号，方便确认刷的是哪个 build
# 分隔符用 #：模式与替换文本里都不含 #（此前用 | 和 , 都因为文本里同名符号踩过坑）
sed -i.bak \
  "s#^kernel.string=.*#kernel.string=Singularity kebab (KSU-Next ${KSU_REF}, ${KERNEL_REF}, ${LOCALVERSION_ST})#" \
  "$WORK/anykernel.sh"
rm -f "$WORK/anykernel.sh.bak"
grep -m1 '^kernel.string=' "$WORK/anykernel.sh"

DATE="$(date +%Y%m%d)"
OUT="$ART/Singularity-kebab-${KSU_REF}-${DATE}.zip"
rm -f "$OUT"
( cd "$WORK" && zip -q -r9 "$OUT" . )

# 附带一份说明，方便下载后核对
{
  echo "kernel repo   : ${KERNEL_REF}"
  echo "KernelSU-Next : ${KSU_REF}"
  echo "localversion-st: ${LOCALVERSION_ST}"
  echo "base AnyKernel3: ${AK3_RELEASE}/${AK3_ASSET}"
  echo "built at      : $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "sha256        : $(sha256sum "$OUT" | cut -d' ' -f1)"
} > "${OUT%.zip}.txt"

echo "==> 产物:"
ls -l "$ART"
