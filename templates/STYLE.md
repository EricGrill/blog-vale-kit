# Voice style

Fill this in for one site. Vale does not read this file. It reads the rules you write from these sections.

## Audience

[Who reads this site? What do they already know? What should a post help them do?]

## Voice and tone

[How should a post sound? Name the tone in a few plain words.]

Put the limits in `styles/<Site>/Tone.yml`. Start from `styles/Example/Tone.yml`.

## Words to use

[List the house terms. Say which ordinary word each one replaces.]

Put substitutions in `styles/<Site>/Preferred.yml`. Put names Vale should allow in `styles/config/vocabularies/<Site>/accept.txt`, one term per line.

```yaml
extends: substitution
message: "Prefer '%s' instead of '%s'."
level: suggestion
ignorecase: true
vocab: true
swap:
  website: site
```

## Words to avoid

[List words and phrases this site does not use. Say what to write instead.]

Put substitutions in `styles/<Site>/Banned.yml`. Put hard bans in `styles/config/vocabularies/<Site>/reject.txt`, one term per line. Terms in `reject.txt` are errors.

```yaml
extends: substitution
message: "Use '%s' instead of '%s'."
level: warning
ignorecase: true
vocab: true
swap:
  cheap: affordable
```

```text
synergy
```

## Structure and length

[How long is a post? Which sections does every post need? How long is a paragraph? How do headings work?]

## Internal-link rules

[When does a post link to another page on this site? What does the anchor text say? Where do links sit in the post?]

## Claims and sourcing rules

[Which claims need a source? Which claims are off limits? Where do numbers, prices, and quotes come from?]

## Examples of good and bad sentences

Good:

Wash the dog in four steps. Start with warm water. Work the soap through the coat. Rinse until the water runs clear.

Bad:

```text
It is important to note that this tapestry might be able to leverage a cheap website. Act now.
```
