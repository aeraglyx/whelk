# Whelk

A relatively fast 8x3 keyboard layout generator based on user preferences. Still WIP. 

One of the layouts found (not final):
```
v g n d  o u h w
c s r t  a e i l
f m p b  x y k j
```

## Goal

After learning Colemak DH and getting into ergonomic keyboards I wanted to ditch the inner columns completely. So I needed a Colemak-y 24 key layout. Another inspiration was Ben Vallack's quest to reduce number of keys. Also it's a way for me to learn Julia and make something potentially useful.

## Why 8x3

There's a certain simplicity and elegance to it. #1DFH (one distance from home) is good, lateral motion is bad. If we don't count thumbs, that gives us 24 keys. If we try to keep only alphas on the main block, 2 low frequency letters won't fit and will have to be on a different layer. Here's the form factor I'm working with:
```
□ □ □ □       □ □ □ □
■ ■ ■ ■       ■ ■ ■ ■
□ □ □ □       □ □ □ □
    □ ■ □   □ ■ □
```

## How to generate your own layout

- Clone the repository
- Install Julia
- Edit `config.toml`
- Run `main.jl`

## Attributions

For the word frequency data I'm accessing hermitdave's FrequencyWords repository:

https://github.com/hermitdave/FrequencyWords

---

> We don’t stand a whelk’s chance in a supernova.