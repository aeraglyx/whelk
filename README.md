# Whelk

A simple, relatively fast keyboard layout generator. Still WIP. 

At 0.98 bigram_quality I'm getting roughly 50K layouts/s. Here's an example English layout generated in under 30s:
```
p l c m k  q h u o y
d r s t f  b n e a i
z j g w v  ~ x ~ ~ ~
```

## Philosophy (TODO)

- punish same hand usage
- punish same finger usage
- punish scissors
- punish eneven finger load
- prefer inward rolls

## Why?

- idk

## How to generate your own layout

- Clone the repository
- Install Julia
- Edit `config.toml`
- Run `main.jl`

## TODO

- Shuffle all keys, not just the alphas.
- Use corpus as a source to get better skipgram information around words and punctuation.
- Plot the effort over time and optimize the generation algorithm.
- Calculate all stats, not just the overall effort.
- Repeat key.
- Modularize the codebase.

## Attributions

For the word frequency data I'm accessing hermitdave's FrequencyWords repository:

https://github.com/hermitdave/FrequencyWords

---

> We don’t stand a whelk’s chance in a supernova.