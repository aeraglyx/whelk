# Whelk

Just a little 8x3 keyboard layout generator based on user preferences. Still WIP. 

Initial layout the program found (not final):
```
b f r m  u o p j
w s n t  i e h g
v c l d  y a k z
```

## Goal

The initial push for creating this was that after learning Colemak DH and getting into ergonomic keyboards I wanted to ditch the inner columns completely. So I needed a Colemak-y 24 key layout. Also it's a way for me to learn Julia and make something potentially useful.

## Why 8x3

There's a certain simplicity and elegance to it. Lateral motion is bad, #1DFH (one distance from home) is good. If we don't count thumbs, that gives us 24 keys.

Even on 34 or 36 key layouts such as Ferris Sweep or GergoPlex there are 6 "bad" keys (inner columns) and usually 4 punctuation marks in the main zone. If we try to keep only alphas on the main block, 2 low frequency letters won't fit and will have to be on a different layer. Here's what I'm working with:
```
□ □ □ □       □ □ □ □
■ ■ ■ ■       ■ ■ ■ ■
□ □ □ □       □ □ □ □
    □ ■ □   □ ■ □
```

## How to generate your own layout

- Clone the repository
- (install Julia)
- Edit `config.toml`
- Run `main.jl`

## Attributions

For the word frequency data I'm accessing hermitdave's FrequencyWords repository:

https://github.com/hermitdave/FrequencyWords

---

> We don’t stand a whelk’s chance in a supernova.