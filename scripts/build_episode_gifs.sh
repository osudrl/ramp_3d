#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEDIA_DIR="$ROOT_DIR/docs/media"
OUTPUT_DIR="$ROOT_DIR/docs/resources/episodes"
FONT_FILE="/System/Library/Fonts/Supplemental/Arial.ttf"

RUNS=(5 50 53 58 60 66 71 73 76 77 78)

mkdir -p "$OUTPUT_DIR"

if [[ ! -f "$FONT_FILE" ]]; then
  echo "Missing font file: $FONT_FILE" >&2
  exit 1
fi

for run in "${RUNS[@]}"; do
  run_dir="$MEDIA_DIR/run_num_${run}"
  output_gif="$OUTPUT_DIR/run_num_${run}.gif"
  temp_dir="$(mktemp -d)"

  trajectory_dirs=()
  while IFS= read -r trajectory_dir; do
    trajectory_dirs+=("$trajectory_dir")
  done < <(find "$run_dir" -maxdepth 1 -type d -name 'trajectory_*' | sort)

  if [[ ${#trajectory_dirs[@]} -eq 0 ]]; then
    echo "No trajectory directories found in $run_dir" >&2
    exit 1
  fi

  for i in "${!trajectory_dirs[@]}"; do
    step_dir="${trajectory_dirs[$i]}"
    step_name="$(basename "$step_dir" | sed 's/^trajectory_//')"
    frame_name="$(printf 'frame_%03d.png' "$i")"
    frame_path="$temp_dir/$frame_name"

    ffmpeg -y \
      -loglevel error \
      -i "$step_dir/00.png" \
      -i "$step_dir/01.png" \
      -filter_complex "[0:v]scale=460:320:force_original_aspect_ratio=decrease,pad=460:320:(ow-iw)/2:(oh-ih)/2:color=white,setsar=1[obs];[1:v]scale=460:320:force_original_aspect_ratio=decrease,pad=460:320:(ow-iw)/2:(oh-ih)/2:color=white,setsar=1[act];[obs][act]hstack=inputs=2[row];[row]pad=920:396:0:76:color=white,drawbox=x=0:y=0:w=920:h=76:color=#edf4ea:t=fill,drawtext=fontfile=$FONT_FILE:text='Observation':fontcolor=#223122:fontsize=28:x=32:y=22,drawtext=fontfile=$FONT_FILE:text='Step $step_name':fontcolor=#223122:fontsize=28:x=220:y=22,drawtext=fontfile=$FONT_FILE:text='Predicted action masks':fontcolor=#223122:fontsize=28:x=w-tw-32:y=22" \
      -frames:v 1 \
      -update 1 \
      "$frame_path"
  done

  ffmpeg -y \
    -loglevel error \
    -framerate 4/3 \
    -pattern_type glob \
    -i "$temp_dir/frame_*.png" \
    -filter_complex "split[palette_src][gif_src];[palette_src]palettegen=reserve_transparent=0[p];[gif_src][p]paletteuse=dither=bayer:bayer_scale=3" \
    -loop 0 \
    "$output_gif"

  rm -rf "$temp_dir"
  echo "Built $output_gif"
done
