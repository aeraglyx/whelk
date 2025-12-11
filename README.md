# Whelk

A simple, relatively fast keyboard layout generator with support for multiple languages.

At 0.98 bigram coverage, I'm getting roughly 85K layouts/s on my machine. Here's an example English layout generated using the default settings:

```
f b l c p z m o u q
s n r d y v t a e i
x h j g w ' k , . /
```


## Philosophy (TODO)

- punish same hand usage
- punish same finger usage (especially on weaker fingers)
- punish scissors (especially between weaker fingers)
- punish uneven finger load
- prefer inward rolls


## Why?

- idk


## Generate Your Own Layout

- Install Julia
- Clone this repository
- Edit `config.toml` if needed
- Run `julia src/main.jl`


## TODO

- Shuffle all keys, not just the alphas
- Pin letters
- Use corpus as a source to get better skipgram information around words and punctuation
- Plot the effort over time and optimize the generation algorithm
- Calculate all stats, not just the overall effort
- Multithreading
- Matrix math
- Check visited layouts
- Efforts in log space for performance


## Attributions

For the word frequency data I'm accessing hermitdave's [FrequencyWords](https://github.com/hermitdave/FrequencyWords) repository.


---


> We don’t stand a whelk’s chance in a supernova.
