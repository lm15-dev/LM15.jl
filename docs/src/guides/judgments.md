# Ask for a judgment, with probabilities

A judgment is a question whose answer is one of the keys you declare: yes or no, one of
several named options, or a level on an ordered scale. You ask it with an ordinary JSON
schema response format; the answer comes back as a [`DataPart`](@ref) holding the answer
object, and, where the provider can measure it, a probability for every key.

```julia
using LanguageModel15
format = judgments(
    "style" => choice("Dominant style?", ["fruit" => "Fruit-forward", "oak" => "Oak-driven", "mineral" => nothing]),
    "quality" => score("How good is this wine?", ["poor", "fair", "great"]),
    "ageing" => yes_no("Will it improve with age?"),
)
req = Request("typesafe:jev-latest", user("Deep ruby, blackcurrant and cedar, firm tannins.");
    config=Config(; response_format=format, probabilities="required"))
```

Options are given in order as a vector (a plain `Dict` has no order). `score` levels go
from low to high; their keys are `"0"`, `"1"`, …

After `answer = complete(router, req)`:

- `data(answer)` is the answer object, e.g. `Dict("style" => "oak", "quality" => 2, "ageing" => true)`;
- `probabilities(answer)` is `Dict("style" => Dict("fruit" => 0.1, …), …)`, or `nothing`;
- `data_part(answer).method` says how the numbers were measured:
  `"provider_classification"` (TypeSafe) or `"candidate_sequence_likelihood"` (a vLLM
  server that scores named tokens);
- `expected_level(probabilities(answer)["quality"])` is Σ p·level for an ordered judgment.

## Ask where something is: a bounding box

`bounding_box` asks where in the picture something is. The answer is four numbers, each
a fraction of the picture from its top-left corner: `top` and `bottom` of its height,
`left` and `right` of its width. Multiply by the picture's size in pixels to draw or crop.

```julia
format = judgments(
    "mug" => bounding_box("the coffee mug"),
    "mug_visible" => yes_no("Is there a coffee mug in the image?"),
)
req = Request("typesafe:jev-preview", user(image(; path="kitchen.jpg")); config=Config(; response_format=format))
```

`data(answer)["mug"]` is then e.g. `Dict("top" => 0.25, "bottom" => 0.82, "left" => 0.44,
"right" => 0.84)`. A box is always four edges, even when the thing is not there: ask a
`yes_no` beside it, as above. A box has no probabilities. On TypeSafe it needs Jev 1.14
(`jev-preview` or `jev-1.14.0`; `jev-latest` answers "Invalid request."); on other
providers the model writes the four numbers, and how close they are depends on the model.

## Which providers measure a distribution

| Where | What you get |
|---|---|
| `typesafe` | the provider's own classification: always a distribution |
| a vLLM ≥ 0.29 server (`compat="vllm"`) via `complete` | LM15 scores every key as a token path and normalises once over the keys |
| every other provider | the model's pick only |

`config.probabilities` decides what happens where nothing can be measured: `"off"` (the
default) spends nothing extra; `"if_available"` returns the pick and records a `dropped`
adaptation on the response; `"required"` refuses before anything is sent. LM15 never
invents a distribution from a single pick or from a number the model wrote.

On vLLM the scoring path sends two `/tokenize` calls per key, one per judgment, and one
batched `/v1/completions` call; other properties of the same schema are answered by one
extra structured-output call. `stream` never scores: it answers with generated JSON and
records that.
