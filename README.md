# blog-vale-kit

Shared [Vale](https://github.com/vale-cli/vale) setup for blog repos. This kit holds the brand-agnostic checks: AI-sounding phrases, hedging, and passive overload. Each site adds its own voice rules.

Pinned versions: Vale CLI **3.27.0** (`VALE_VERSION`) and `actions/checkout` **v5.1.0** (`fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09`).

The repo is public so a private blog can call the workflow and download the Base styles with the default `GITHUB_TOKEN`.

## Add it to a blog repo

1. Copy [`.vale.ini`](.vale.ini) to the blog repo root.
2. Copy [`templates/STYLE.md`](templates/STYLE.md) to `STYLE.md` and fill it in.
3. Add a site style (see below) and name it in `.vale.ini`.
4. Add `.github/workflows/blog-voice.yml`. The same file is [`examples/caller.yml`](examples/caller.yml):

```yaml
name: Blog voice
on:
  pull_request:
permissions:
  contents: read
jobs:
  vale:
    uses: EricGrill/blog-vale-kit/.github/workflows/vale.yml@v1
    with:
      fail_on_error: false
      kit_ref: v1
```

Pin the `uses:` ref and `kit_ref` to the same tag. The workflow file comes from the `uses:` ref. `kit_ref` is the git ref checked out for `styles/Base` and the scripts. It defaults to `main` when a caller omits it. Pass `v1` so a blog does not follow later commits on `main`.

On a pull request the workflow installs Vale, copies `styles/Base` into the checkout, lints changed Markdown and MDX, and posts annotations.

`fail_on_error` defaults to `false`. Suggestions, warnings, and errors all show up as warnings, and the check stays green. Set `fail_on_error: true` to fail the check on **error**-level alerts only. That means a site rule with `level: error`, or a term in `reject.txt`. Suggestions and warnings still do not fail the check.

Pass `files` (a newline-separated list) to lint specific paths. Leave it empty and a pull request lints changed `*.md` and `*.mdx` files. With no pull-request base, the workflow lints every tracked Markdown and MDX file.

You need `.vale.ini` in the blog repo before a Markdown change will lint. A pull request with no Markdown or MDX changes exits clean even before that file exists.

## Write site rules

Copy `styles/Example/` to `styles/<Site>/` and edit `Banned.yml`, `Preferred.yml`, and `Tone.yml`. Leave the `.test.yml` files; they belong to this kit. In `.vale.ini`, replace the active `BasedOnStyles` and `Vocab` lines:

```ini
BasedOnStyles = Base, YourSite
Vocab = Base, YourSite
```

| STYLE.md section | Where it goes |
| --- | --- |
| Audience | `STYLE.md` only |
| Voice and tone | `styles/<Site>/Tone.yml` |
| Words to use | `styles/<Site>/Preferred.yml` and `accept.txt` |
| Words to avoid | `styles/<Site>/Banned.yml` and `reject.txt` |
| Structure and length | `STYLE.md` only |
| Internal-link rules | `STYLE.md` only |
| Claims and sourcing rules | `STYLE.md` only |
| Examples | `STYLE.md`, plus a Vale rule when a pattern repeats |

Layout:

```text
styles/
  Base/                  # this kit; the workflow refreshes it on each run
    AIPhrases.yml
    Hedging.yml
    PassiveOverload.yml
  YourSite/              # copy styles/Example and rename it
    Banned.yml
    Preferred.yml
    Tone.yml
  config/vocabularies/
    Base/
      accept.txt
      reject.txt
    YourSite/
      accept.txt         # one allowed term per line
      reject.txt         # one banned term per line; Vale reports these as errors
```

`MinAlertLevel = suggestion`, so suggestions show up. `[formats] mdx = md` treats MDX as Markdown. Block and token ignores skip fenced code, MDX comments (`{/* */}`), JSX tags, `{expressions}`, and lines that start with `import` or `export`. A sentence that only contains the word `export` is still checked. Angle brackets that are not a tag are still checked. Prose between JSX tags is still checked.

Turn one shared rule off in `.vale.ini` if a site needs to:

```ini
Base.AIPhrases = NO
```

Rules set `vocab: true`, so a term in `accept.txt` suppresses a hit from those rules. The same entry is the spelling Vale expects: `Vale` in `accept.txt` flags `vale`. `reject.txt` always flags the term, at error level. The shared Base vocabulary ships without terms so it does not police capitalization for every blog.

`styles/Example` is a sample, not a style you should enable in production. The template `.vale.ini` enables `Base` only.

## Run Vale locally

From this repo:

```bash
bash scripts/install-vale.sh .tools
export PATH="$PWD/.tools:$PATH"
vale --no-global fixtures/good.md
bash scripts/test-fixtures.sh
```

From a blog repo, after `.vale.ini` is in place:

```bash
git clone --depth 1 https://github.com/EricGrill/blog-vale-kit.git /tmp/blog-vale-kit
bash /tmp/blog-vale-kit/scripts/install-vale.sh .tools
export PATH="$PWD/.tools:$PATH"
bash /tmp/blog-vale-kit/scripts/install-base-styles.sh .
vale --no-global --config .vale.ini path/to/post.md
```

`install-base-styles.sh` copies `styles/Base` and the Base vocabulary only.

The same wrapper the action uses:

```bash
python3 /tmp/blog-vale-kit/scripts/vale-lint.py --config .vale.ini path/to/post.md
python3 /tmp/blog-vale-kit/scripts/vale-lint.py --fail-on-error --config .vale.ini path/to/post.md
```

## Fixture proof

`bash scripts/test-fixtures.sh` installs the pinned Vale binary and checks all of the following:

- `fixtures/good.md` and `fixtures/good.mdx` produce no alerts. The MDX post plants rejected words inside a comment, a JSX attribute, a multiline tag, and a `{expression}`.
- `fixtures/export-prose.md` is one prose line that contains `export` and `it is important to note`. It still reports `Base.AIPhrases`.
- `fixtures/bad.md` and `fixtures/bad.mdx` each report `Base.AIPhrases`, `Base.Hedging`, `Base.PassiveOverload`, `Example.Banned`, `Example.Preferred`, `Example.Tone`, and an error for `synergy` (`Vale.Example.Avoid`).
- The wrapper exits 0 for those bad posts, and exits 1 with `--fail-on-error`.
- `vale test --coverage` covers every rule under `styles/`.
