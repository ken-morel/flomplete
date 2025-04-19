using Serialization:serialize, deserialize
using ArgParse

const MODEL_PATH = "model.jls"

struct Dictionary 
  words::Vector{String}
end

struct ModelData
  dictionary::Dictionary
  data::Vector{Tuple{Vector{Int}, Int}}
  contextsize::Int
end

mutable struct Timer
  time::Float64
  Timer() = new(time())
end
function timenext(timer::Timer)
    now = time()
    d = now - timer.time
    timer.time = now
    d
end
Main.serialize(dict::Dictionary, txt::String)::Vector{Int} = filter(x -> x !== nothing, indexin(split(txt, r"\s"), dict.words))
Main.deserialize(dict::Dictionary, ser::Vector{Int})::String = join(" ", (x -> dict.words[x]).(ser))
function splittokens(txt)
    tokens = []
    regex = r"([a-zA-Zàâçéèêëîïôûùüÿñæœ]+|['’](?:s|t|re|ve|ll|d|m|on|en|y|jusqu|quoi|l|j|n|d|qu|c|m|t|s|p|z|ai|as|est|et|e|de)|[.!?~«»…,:;\"()\-\n])"
    for m in eachmatch(regex, txt)
        token = m.match
        if occursin(r"^[a-zA-Z]+$", token)
            push!(tokens, lowercase(token))
        else
            push!(tokens, token)
        end
    end
    tokens
end
function loadmodel(path::String)::ModelData
  if isdir(path)
    path = joinpath(path, MODEL_PATH)
  end
  open(path) do f
    deserialize(f)
  end
end
function match_difference(pattern::Vector{Int}, test::Vector{Int},scale::Float64)::Float64
  o = length(pattern) - 1
  gpow(x) = x-o
  sum(enumerate(zip(pattern, test))) do (idx, (p, t))
    Float64(t != p) * (scale ^ gpow(idx)) # give higher scores to last matches to work easily with infinite contexts
  end
end
function adjust_array(arr::Vector{Int}, contextsize::Int)
    len = length(arr)
    if len < contextsize
        return vcat(zeros(Int, contextsize - len),arr)
    elseif len > contextsize
        return arr[(end - contextsize + 1):end]
    else
        return copy(arr)
    end
end
function whatnext(model::ModelData, values::Vector{Int}, contextsize::Int, scale::Float64)::Int
  values = adjust_array(values, contextsize)
  matches::Vector{Tuple{Float64, Int}} = Vector()
  min_match = nothing
  for (leading, word) ∈ model.data
    λ = match_difference(leading, values, scale)
    if λ == 0 && rand() > 0.0
      return word
    end
    if min_match == nothing
      min_match = λ
    elseif min_match > λ
      empty!(matches)
      min_match = λ
    elseif min_match < λ
      continue
    end
    push!(matches, (λ, word))
  end
  sort!(matches)
  if length(matches) == 0
    0
  else
    rand(matches)[2]
  end
end

function complete_word(model::ModelData, text::String, contextsize::Int, scale::Float64)::String
  nxt = whatnext(model, serialize(model.dictionary, text), contextsize, scale)
  if nxt > 0
    text * " " * model.dictionary.words[nxt]
  else
    return text
  end
end

function flomplete(model::ModelData,txt::String, scale::Float64, max::Int)::Channel
  channel = Channel()
  @async begin
    try
      for _ in 1:max
        next = complete_word(model, txt, model.contextsize, scale)
        endswith(next, "~") && break
        if strip(next) == strip(txt)
          break
        end
        txt = next
        put!(channel, txt)
      end
    catch e
      println("Error occured in channel $e")
    finally
      close(channel)
    end
  end
  channel
end

function buildmodel(path::String; contextsize::Int=50)
  timer = Timer()
  total = Timer()
  
  println("Building training data from files in $path")
  words = Vector{String}()
  for filename in readdir(path)
      _, ext = splitext(filename)
      if ext == ".jls"
        continue
      end
      println(" - File: $filename")
      filepath = joinpath(path, filename)
      isfile(filepath) || continue  # Skip directories
      numwords = length(words)
      open(filepath) do f
          content = replace(read(f, String), "\n" => " ")
          tokens = splittokens(content)
          filtered = filter(w -> length(w) > 0, tokens)
          append!(words, filtered)
      end
      println("   Got $(length(words) - numwords) words in $(timenext(timer))")
  end
  println("   Finished collecting words.\n - building dictionary")
  dict = Dictionary(sort(unique(words)))
  println("   Built dictionary with up to $(length(dict.words)) words in $(timenext(timer)).\n - Serializing train dataset")
  dataset = indexin(words, dict.words)
  println("   done in $(timenext(timer))\n - Building ~model~ word groups with context size $contextsize")
  model::Vector{Tuple{Vector{Int}, Int}} = Vector()
  for i ∈ (contextsize + 1):length(dataset)
    push!(model, (dataset[i - contextsize:i - 1], dataset[i]))
  end
  println("   Built model with $(length(model)) word groups in $(timenext(timer)).\n - saving all of that")
  open("$(joinpath(path, MODEL_PATH))", "w") do f
    serialize(f, ModelData(dict, model, contextsize))
  end
  println("  Done in $((timenext(timer))) seconds, you're all set!")
  println("Total took" )
end


function main()
  parser = ArgParseSettings(description="Flomplete cli tool for building and chatting.")
  @add_arg_table parser begin 
    "command"
      help = "What you want me to do, either of buildmodel or chat"
      arg_type = String
      required = true
    "workspace"
      help = "The folder the training data and model are stocked"
      arg_type = String
      required = true
    "--contextsize"
      help = "The maximum lookback size for word matching"
      arg_type = Int
      default = 100
    "--scalefactor"
      help = "How much fraction of the last word should the preceding word match count"
      arg_type = Float64
      default = 0.8
    "--maxtokens"
      help = "Maximum number of words to generate."
      arg_type = Int
      default = 100
  end
  args = parse_args(parser)
  if args["command"] == "buildmodel"
    @time buildmodel(args["workspace"];contextsize=args["contextsize"])
  elseif args["command"] == "chat"
    model = loadmodel(args["workspace"])
    println("Loaded model with $(length(model.data)) tokens, $(length(model.dictionary.words)) words and $(model.contextsize) context.")
    while true
      print("> ")
      channel = flomplete(model, readline(stdin), args["scalefactor"], args["maxtokens"])
      text = take!(channel)
      print(text)
      while isopen(channel)
        new = take!(channel)
        cnew = collect(new)
        chars = collect(text)
        print(join(cnew[length(chars) + 1:end]), "")
        text = new
      end
      println("")
    end
  else
    println("ERROR: Wrong command: $(args["command"])")
  end
end

if (@__MODULE__) == Main
  main()
end
