#!/usr/bin/env python3
"""Assembles the 9:16 teaser from simulator recordings, rendered stills and the voiceover.

Usage: python3 tool/video/build_teaser.py <recordings-dir> <voiceover.mp3> <out.mp4>
  recordings-dir holds s2-feed.mp4, s3-shelf.mp4, s4-book.mp4, s5-circle.mp4
  (xcrun simctl io <device> recordVideo, demo mode). Stills come from
  `flutter test tool/video/render_video_frames_test.dart` (build/teaser/).
Cut points match the voiceover sentences; see tool/video/script.md.
"""
import pathlib
import subprocess
import sys

rec, vo, out = map(pathlib.Path, sys.argv[1:4])
stills = pathlib.Path("build/teaser")
tmp = pathlib.Path("build/teaser/clips")
tmp.mkdir(parents=True, exist_ok=True)

FPS = 30
T = 0.35          # crossfade length
VO_DELAY = 0.5    # voiceover starts after a short breath
# Scene cuts (s), aligned to the voiceover sentence starts + VO_DELAY.
cuts = [2.3, 4.7, 10.5, 14.2, 17.8]
end = 21.4
spans = list(zip([0.0] + cuts, cuts + [end]))
durations = [b - a + (T / 2 if i in (0, 5) else T) for i, (a, b) in enumerate(spans)]

# App scenes: (name, caption, [(start, end), ...] source segments, speed factor)
scenes = {
    1: ("s2-feed", "feed", [(0.8, 4.9)], None),
    2: ("s3-shelf", "shelf", [(0.3, 2.9), (18.0, 21.55)], None),
    3: ("s4-book", "book", [(3.3, 5.0), (14.3, 16.65)], None),
    4: ("s5-circle", "circle", [(0.9, 5.6)], None),
}
SX, SY, SW, SH = 180, 300, 720, 1565  # screen rect, matches render_video_frames_test.dart


def run(args):
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args], check=True)


def still_clip(img, dur, path):
    # Slow push-in on a still.
    frames = int(dur * FPS)
    run([
        "-loop", "1", "-i", str(img), "-t", f"{dur:.3f}",
        "-vf", f"scale=2160:-1,zoompan=z='1+0.06*on/{frames}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={frames}:s=1080x1920:fps={FPS},format=yuv420p",
        "-r", str(FPS), str(path),
    ])


def app_clip(idx, path):
    name, cap, segs, _ = scenes[idx]
    dur = durations[idx]
    src = rec / f"{name}.mp4"
    total = sum(b - a for a, b in segs)
    speed = total / dur  # >1 = faster
    parts, labels = [], []
    for k, (a, b) in enumerate(segs):
        parts.append(f"[0:v]trim={a}:{b},setpts=PTS-STARTPTS[p{k}]")
        labels.append(f"[p{k}]")
    chain = ";".join(parts)
    chain += f";{''.join(labels)}concat=n={len(segs)}:v=1:a=0,setpts=PTS/{speed:.4f},fps={FPS},scale={SW}:{SH}[app]"
    chain += f";color=c=black:s=1080x1920:r={FPS}:d={dur:.3f}[bg];[bg][app]overlay={SX}:{SY}:shortest=1[s1]"
    chain += f";[s1][1:v]overlay=0:0[s2]"
    chain += f";[2:v]format=rgba,fade=in:st=0.15:d=0.45:alpha=1[cap];[s2][cap]overlay=0:0"
    # Gentle push-in over the whole scene.
    chain += f",scale=w='trunc(1080*(1+0.035*t/{dur:.3f})/2)*2':h=-2:eval=frame,crop=1080:1920,format=yuv420p[v]"
    run([
        "-i", str(src),
        "-loop", "1", "-t", f"{dur:.3f}", "-i", str(stills / "frame.png"),
        "-loop", "1", "-t", f"{dur:.3f}", "-i", str(stills / f"caption-{cap}.png"),
        "-filter_complex", chain, "-map", "[v]", "-t", f"{dur:.3f}", "-r", str(FPS), str(path),
    ])


clips = []
for i in range(6):
    p = tmp / f"c{i}.mp4"
    if i == 0:
        still_clip(stills / "intro.png", durations[0], p)
    elif i == 5:
        still_clip(stills / "outro.png", durations[5], p)
    else:
        app_clip(i, p)
    clips.append(p)

inputs = []
for p in clips:
    inputs += ["-i", str(p)]
inputs += ["-i", str(vo)]
graph, last, offset = [], "[0:v]", 0.0
transitions = ["fade", "slideup", "slideup", "slideup", "fade"]
for i in range(1, 6):
    offset = cuts[i - 1] - T / 2
    graph.append(f"{last}[{i}:v]xfade=transition={transitions[i-1]}:duration={T}:offset={offset:.3f}[x{i}]")
    last = f"[x{i}]"
ms = int(VO_DELAY * 1000)
graph.append(f"[6:a]adelay={ms}|{ms},apad,atrim=0:{end},afade=t=out:st={end-0.6}:d=0.6,loudnorm=I=-16:TP=-1.5:LRA=11[a]")
run([*inputs, "-filter_complex", ";".join(graph), "-map", last, "-map", "[a]",
     "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p",
     "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", "-t", str(end), str(out)])
print(f"wrote {out}")
