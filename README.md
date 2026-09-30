# secret-squirrel

Bare-bones voice-to-text CLI. It lists your microphones, asks which one to use,
records until you press Enter, and prints the transcript from
[whisper.cpp](https://github.com/ggml-org/whisper.cpp) to the terminal.
Everything runs in Docker Compose.

## Usage

```sh
docker compose build
docker compose run --rm whisper
```

```
Microphones:
  1) HDA Intel PCH - ALC3246 Analog
  2) USB PnP Sound Device - USB Audio
Which mic? [1-2, default 1]: 2
Using USB PnP Sound Device - USB Audio (plughw:1,0). Enter starts and stops recording, Ctrl-C quits.
[Enter] record
Recording... [Enter] stop
Testing, one, two, three.
[Enter] record
```

Use `run`, not `up`: the tool is interactive and `up` does not forward your keyboard.

On first run the model is downloaded from Hugging Face into the `models`
volume; later runs reuse it.

## Options

Set these in the shell or in a `.env` file next to `docker-compose.yml`:

| Variable        | Default   | Meaning |
|-----------------|-----------|---------|
| `WHISPER_MODEL` | `base.en` | Any name `download-ggml-model.sh` accepts: `tiny.en`, `small.en`, `medium`, `large-v3-turbo`, ... |
| `WHISPER_LANG`  | `en`      | Spoken language, or `auto`. `.en` models only do English. |

```sh
WHISPER_MODEL=small WHISPER_LANG=auto docker compose run --rm whisper
```

The whisper.cpp version is pinned by the `WHISPER_CPP_VERSION` build arg in the `Dockerfile`.

## Requirements and troubleshooting

- Linux host with ALSA. The container gets the host's `/dev/snd`; Docker
  Desktop on macOS and Windows cannot pass audio devices through.
- **"No microphones found"**: the host has no capture devices, or `/dev/snd`
  is not being passed through. Check with `arecord -l` on the host.
- **"Device or resource busy"**: another program has the mic open. Close it
  and try again.
